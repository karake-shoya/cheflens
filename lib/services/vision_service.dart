import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/food_data_model.dart';
import '../models/detected_object.dart';
import 'ingredient_filter.dart';
import 'ingredient_translator.dart';
import 'image_processor.dart';
import 'vision/label_detection_service.dart';
import 'vision/object_detection_service.dart';
import 'vision/web_detection_service.dart';
import 'vision/text_detection_service.dart';

/// 統合Vision認識サービス用の定数
class _VisionConstants {
  static const double labelDetectionDefaultScore = 0.8;
  static const int maxIngredientResults = 5;
}

/// 類似食材の統合結果
class _MergeResult {
  final bool shouldAdd;
  final bool shouldSkip;
  final String? shouldReplace;

  _MergeResult({
    required this.shouldAdd,
    required this.shouldSkip,
    this.shouldReplace,
  });
}

/// 各種Vision APIを統合した食材認識サービス
class VisionService {
  final FoodData foodData;
  final IngredientFilter _filter;
  final IngredientTranslator _translator;

  // 各検出サービス
  final LabelDetectionService _labelDetection;
  final ObjectDetectionService _objectDetection;
  final WebDetectionService _webDetection;
  final TextDetectionService _textDetection;
  
  VisionService(this.foodData)
      : _filter = IngredientFilter(foodData),
        _translator = IngredientTranslator(foodData),
        _labelDetection = LabelDetectionService(foodData),
        _objectDetection = ObjectDetectionService(foodData),
        _webDetection = WebDetectionService(foodData),
        _textDetection = TextDetectionService(foodData);

  /// Label Detection APIを使用して食材を検出
  Future<List<String>> detectIngredients(File imageFile) async {
    return await _labelDetection.detectIngredients(imageFile);
  }

  /// Object Detection APIを使って画像内の物体を検出
  Future<List<DetectedObject>> detectObjects(File imageFile) async {
    return await _objectDetection.detectObjects(imageFile);
  }

  /// Web Detection APIを使って画像から商品名や詳細情報を取得（信頼度情報付き）
  Future<List<Map<String, dynamic>>> detectWithWebDetectionWithScores(
      File imageFile) async {
    return await _webDetection.detectWithScores(imageFile);
  }

  /// Web Detection APIを使って画像から商品名や詳細情報を取得
  Future<List<String>> detectWithWebDetection(File imageFile) async {
    return await _webDetection.detect(imageFile);
  }

  /// Text Detection APIを使って画像からテキストを検出し、食材名を抽出
  Future<List<String>> detectIngredientsFromText(File imageFile) async {
    return await _textDetection.detectIngredientsFromText(imageFile);
  }

  /// Object Detection + Text Detection を組み合わせた高精度認識
  Future<List<String>> detectIngredientsWithObjectDetection(
      File imageFile) async {
    try {
      debugPrint('=== Object Detection + Text Detection を開始 ===');
      
      // ステップ1: Object Detectionで物体を検出
      final objects = await detectObjects(imageFile);
      
      if (objects.isEmpty) {
        debugPrint(
            '物体が検出されませんでした。Text Detection + Web Detectionにフォールバック');
        return await detectProductWithTextAndWeb(imageFile);
      }
      
      // 信頼度フィルタを適用
      final filteredObjects = _objectDetection.filterByConfidence(objects);
      
      if (filteredObjects.isEmpty) {
        final threshold = foodData.filtering.objectDetectionConfidenceThreshold;
        debugPrint(
            '信頼度${(threshold * 100).toStringAsFixed(0)}%以上の物体がありませんでした。Text Detection + Web Detectionにフォールバック');
        return await detectProductWithTextAndWeb(imageFile);
      }
      
      debugPrint(
          '${filteredObjects.length}個の物体を個別認識します（Text Detection優先）...');
      
      // 画像を読み込み
      final image = await ImageProcessor.loadImage(imageFile);
      if (image == null) {
        throw Exception('画像の読み込みに失敗しました');
      }
      
      // 各物体から検出された食材と、その物体の信頼度を記録
      final ingredientWeights = <String, Map<String, dynamic>>{};
      
      // ステップ2: 各物体をトリミングしてText Detection優先で認識
      for (int i = 0; i < filteredObjects.length; i++) {
        final obj = filteredObjects[i];
        final objectScore = obj.score;
        debugPrint(
            '物体 ${i + 1}/${filteredObjects.length}: ${obj.name} (${(obj.score * 100).toStringAsFixed(0)}%)');
        
        try {
          final croppedImage =
              ImageProcessor.cropImage(image, obj.boundingBox);
          if (croppedImage == null) {
            debugPrint('  → スキップ（サイズが無効）');
            continue;
          }
          
          // 最小サイズチェック
          final minCropSize = foodData.filtering.minCropSize;
          if (!ImageProcessor.isValidCropSize(
              croppedImage.width, croppedImage.height, minCropSize)) {
            debugPrint(
                '  → スキップ（サイズが小さすぎる: ${croppedImage.width}x${croppedImage.height}px < ${minCropSize}x${minCropSize}px）');
            continue;
          }
          
          // 一時ファイルに保存
          final tempFile =
              await ImageProcessor.saveCroppedImageToTemp(croppedImage, i);
          if (tempFile == null) {
            debugPrint('  → スキップ（一時ファイルの作成に失敗）');
            continue;
          }
          
          // Text Detection優先で個別認識（信頼度情報付き）
          debugPrint('  → Text Detection優先で認識中...');
          final detectedIngredients =
              await _detectIngredientsFromCroppedImage(tempFile, objectScore);
          
          // 重み付けデータを更新
          _updateIngredientWeights(
              ingredientWeights, detectedIngredients, objectScore);
          
          // クリーンアップ
          await tempFile.delete();
          await tempFile.parent.delete();
        } catch (e) {
          debugPrint('  → エラー: $e');
        }
      }
      
      // 重み付けデータをリストに変換
      final ingredientList = ingredientWeights.values.toList();
      
      // 類似食材を統合（検出回数が多い方を優先）
      final mergedIngredients = <String, Map<String, dynamic>>{};
      for (var ingredient in ingredientList) {
        final ingredientName = ingredient['name'] as String;
        
        final mergeResult = _checkAndMergeSimilarIngredient(
          ingredient,
          ingredientName,
          mergedIngredients,
        );
        if (mergeResult.shouldSkip) {
          continue;
        }
        if (mergeResult.shouldAdd) {
        if (mergeResult.shouldReplace != null) {
            debugPrint(
                '類似食材を置き換え: ${mergeResult.shouldReplace} → $ingredientName');
            mergedIngredients.remove(mergeResult.shouldReplace);
          }
          mergedIngredients[ingredientName] =
              Map<String, dynamic>.from(ingredient);
        }
      }
      
      // 重み付けスコアでソート（検出回数 × 統合スコア）
      final sortedIngredients = mergedIngredients.values.toList()
        ..sort((a, b) {
          final countA = a['count'] as int;
          final countB = b['count'] as int;
          final integratedScoreA = a['maxIntegratedScore'] as double? ?? 0.0;
          final integratedScoreB = b['maxIntegratedScore'] as double? ?? 0.0;
          
          if (countA != countB) {
            return countB.compareTo(countA);
          }
          return integratedScoreB.compareTo(integratedScoreA);
        });
      
      final result = sortedIngredients
          .map((ingredient) => ingredient['name'] as String)
          .toList();
      
      debugPrint(
          '=== 最終結果（${ingredientList.length}個 → ${result.length}個）: ${result.join(", ")} ===');
      debugPrint('=== 重み付け詳細 ===');
      for (var ingredient in sortedIngredients) {
        final objectScore = ingredient['maxObjectScore'] as double? ?? 0.0;
        final webScore = ingredient['maxWebScore'] as double? ?? 0.0;
        final integratedScore =
            ingredient['maxIntegratedScore'] as double? ?? 0.0;
        debugPrint(
            '  ${ingredient['name']}: 検出${ingredient['count']}回, Object=${(objectScore * 100).toStringAsFixed(0)}%, Web=${(webScore * 100).toStringAsFixed(0)}%, 統合=${(integratedScore * 100).toStringAsFixed(0)}%');
      }
      
      // 物体から食材が検出されなかった場合、全体画像に対してフォールバック
      if (result.isEmpty) {
        debugPrint(
            '物体から食材が検出されませんでした。全体画像に対してText Detection + Web Detectionを実行');
        final fallbackResult = await detectProductWithTextAndWeb(imageFile);
        if (fallbackResult.isNotEmpty) {
          debugPrint('全体画像から検出: ${fallbackResult.join(", ")}');
          return fallbackResult;
        }
      }
      
      return result;
    } catch (e) {
      throw Exception('Object Detection + Text Detection に失敗しました: $e');
    }
  }

  /// トリミングされた画像から食材を検出（Text Detection優先）
  Future<List<Map<String, dynamic>>> _detectIngredientsFromCroppedImage(
    File tempFile,
    double objectScore,
  ) async {
    // ステップ1: Text Detectionを優先的に試行
    try {
      final textIngredients = await detectIngredientsFromText(tempFile);
      if (textIngredients.isNotEmpty) {
        debugPrint('  → Text Detection結果: ${textIngredients.join(", ")}');
        final textScore = objectScore * 0.9;
        return textIngredients
            .map((ingredient) => {
          'name': ingredient,
          'score': textScore,
          'translated': ingredient,
                })
            .toList();
      }
    } catch (e) {
      debugPrint('  → Text Detectionエラー（スキップ）: $e');
    }
    
    // ステップ2: Text Detectionが失敗した場合、Web Detectionを試行
    final webIngredientsWithScores =
        await detectWithWebDetectionWithScores(tempFile);
    
    if (webIngredientsWithScores.isNotEmpty) {
      debugPrint(
          '  → Web Detection結果: ${webIngredientsWithScores.map((i) => '${i['translated']} (信頼度: ${((i['score'] as double) * 100).toStringAsFixed(0)}%)').join(", ")}');
      return webIngredientsWithScores;
    }
    
    // ステップ3: Web Detectionも失敗した場合、Label Detectionにフォールバック
    debugPrint('  → Label Detectionにフォールバック');
    final labelIngredients = await detectIngredients(tempFile);
    debugPrint('  → Label Detection結果: ${labelIngredients.join(", ")}');
    return labelIngredients
        .map((ingredient) => {
      'name': ingredient,
      'score': _VisionConstants.labelDetectionDefaultScore,
      'translated': ingredient,
            })
        .toList();
  }

  /// 重み付けデータを更新
  void _updateIngredientWeights(
    Map<String, Map<String, dynamic>> ingredientWeights,
    List<Map<String, dynamic>> detectedIngredients,
    double objectScore,
  ) {
    for (var ingredientData in detectedIngredients) {
      final ingredientName = ingredientData['translated'] as String;
      final webScore = ingredientData['score'] as double;
      
      final integratedScore = objectScore * webScore;
      
      if (ingredientWeights.containsKey(ingredientName)) {
        final weight = ingredientWeights[ingredientName]!;
        weight['count'] = (weight['count'] as int) + 1;
        if (integratedScore > (weight['maxIntegratedScore'] as double)) {
          weight['maxIntegratedScore'] = integratedScore;
          weight['maxObjectScore'] = objectScore;
          weight['maxWebScore'] = webScore;
        }
      } else {
        ingredientWeights[ingredientName] = {
          'name': ingredientName,
          'count': 1,
          'maxObjectScore': objectScore,
          'maxWebScore': webScore,
          'maxIntegratedScore': integratedScore,
        };
      }
    }
  }

  /// 類似食材をチェックして統合
  _MergeResult _checkAndMergeSimilarIngredient(
    Map<String, dynamic> ingredient,
    String ingredientName,
    Map<String, Map<String, dynamic>> mergedIngredients,
  ) {
    for (var existingName in mergedIngredients.keys) {
      final englishName1 =
          _translator.getEnglishNameFromJapanese(ingredientName);
      final englishName2 =
          _translator.getEnglishNameFromJapanese(existingName);
      
      if (ingredientName == existingName) {
        final existingWeight = mergedIngredients[existingName]!;
        existingWeight['count'] =
            (existingWeight['count'] as int) + (ingredient['count'] as int);
        if ((ingredient['maxObjectScore'] as double) >
            (existingWeight['maxObjectScore'] as double)) {
          existingWeight['maxObjectScore'] = ingredient['maxObjectScore'];
        }
        return _MergeResult(shouldAdd: false, shouldSkip: true);
      } else if (englishName1 != null &&
          englishName2 != null &&
                 _filter.isSimilarFoodName(englishName1, englishName2)) {
        final existingWeight = mergedIngredients[existingName]!;
        final existingCount = existingWeight['count'] as int;
        final currentCount = ingredient['count'] as int;
        
        final preferred = _filter.getPreferredIngredientFromSimilarPair(
            englishName1, englishName2);
        String? preferredName;
        String? nonPreferredName;
        
        if (preferred != null) {
          if (englishName1.toLowerCase() == preferred.toLowerCase()) {
            preferredName = ingredientName;
            nonPreferredName = existingName;
          } else if (englishName2.toLowerCase() == preferred.toLowerCase()) {
            preferredName = existingName;
            nonPreferredName = ingredientName;
          }
        }
        
        if (preferredName != null && nonPreferredName != null) {
          if (nonPreferredName == ingredientName) {
            debugPrint(
                '最終結果から除外: $ingredientName (類似ペアのprimary: $preferredName を優先)');
            return _MergeResult(shouldAdd: false, shouldSkip: true);
          } else {
            debugPrint(
                '類似食材を置き換え: $existingName → $ingredientName (類似ペアのprimary: $preferredName を優先)');
            return _MergeResult(
                shouldAdd: true, shouldSkip: false, shouldReplace: existingName);
          }
        } else {
          if (currentCount > existingCount) {
            return _MergeResult(
                shouldAdd: true, shouldSkip: false, shouldReplace: existingName);
          } else {
            debugPrint(
                '最終結果から除外: $ingredientName ($currentCount回) - $existingName ($existingCount回) と類似');
            return _MergeResult(shouldAdd: false, shouldSkip: true);
          }
        }
      }
    }
    
    return _MergeResult(shouldAdd: true, shouldSkip: false);
  }

  /// Text Detection + Web Detection を組み合わせた商品認識
  Future<List<String>> detectProductWithTextAndWeb(File imageFile) async {
    try {
      debugPrint('=== Text Detection + Web Detection を開始 ===');
      
      final textIngredients = <String>[];
      final webIngredients = <String>[];
      
      // テキスト検出を試行
      try {
        textIngredients.addAll(await detectIngredientsFromText(imageFile));
        debugPrint('Text Detection結果: ${textIngredients.join(", ")}');
      } catch (e) {
        debugPrint('Text Detectionエラー（スキップ）: $e');
      }
      
      // Web Detectionを試行
      try {
        final webIngredientsWithScores =
            await detectWithWebDetectionWithScores(imageFile);
        final webIngredientsList = webIngredientsWithScores
            .map((c) => c['translated'] as String)
            .toList();
        webIngredients.addAll(webIngredientsList);
        debugPrint('Web Detection結果: ${webIngredients.join(", ")}');
      } catch (e) {
        debugPrint('Web Detectionエラー（スキップ）: $e');
      }
      
      // 結果を統合（テキスト検出を優先）
      final combinedIngredients = <String>{};
      
      combinedIngredients.addAll(textIngredients);
      
      for (var ingredient in webIngredients) {
        final lowerIngredient = ingredient.toLowerCase();
        if (foodData.filtering.genericCategories.contains(lowerIngredient)) {
          debugPrint('統合時に除外: "$ingredient" (一般的なカテゴリ)');
          continue;
        }
        
        bool shouldAdd = true;
        for (var existing in combinedIngredients) {
          final englishExisting =
              _translator.getEnglishNameFromJapanese(existing);
          final englishIngredient =
              _translator.getEnglishNameFromJapanese(ingredient);

          if (englishExisting != null &&
              englishIngredient != null &&
              _filter.isSimilarFoodName(englishExisting, englishIngredient)) {
            debugPrint('統合時に除外: "$ingredient" ($existingと類似)');
            shouldAdd = false;
            break;
          }
        }
        
        if (shouldAdd) {
          combinedIngredients.add(ingredient);
          debugPrint('統合時に追加: "$ingredient"');
        } else {
          debugPrint('統合時にスキップ: "$ingredient" (shouldAdd=false)');
        }
      }
      
      debugPrint(
          '=== 統合前の食材リスト (${combinedIngredients.length}個): ${combinedIngredients.join(", ")} ===');
      final result =
          combinedIngredients.take(_VisionConstants.maxIngredientResults).toList();
      debugPrint('=== 統合結果 (${result.length}個): ${result.join(", ")} ===');
      
      return result;
    } catch (e) {
      throw Exception('Text Detection + Web Detection に失敗しました: $e');
    }
  }
}
