import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/food_data_model.dart';
import '../models/detected_object.dart';
import 'vision_api_client.dart';
import 'ingredient_filter.dart';
import 'ingredient_translator.dart';
import 'image_processor.dart';

/// 定数定義
class _VisionConstants {
  static const double categoryConfidenceDiffThreshold = 0.09; // 9%差以上で除外
  static const double multipleIngredientsThreshold = 0.05; // 5%差未満で複数食材と判定
  static const double webDetectionScoreThreshold = 0.5; // Web Detectionの信頼度閾値
  static const double labelDetectionDefaultScore = 0.8; // Label Detectionのデフォルト信頼度
  static const int maxLabelDetectionResults = 50;
  static const int maxObjectDetectionResults = 20;
  static const int maxWebDetectionResults = 20;
  static const int maxIngredientResults = 5;
  static const int minTextLength = 2; // テキスト検出の最小文字数
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

class VisionService {
  final FoodData foodData;
  final IngredientFilter _filter;
  final IngredientTranslator _translator;
  
  VisionService(this.foodData)
      : _filter = IngredientFilter(foodData),
        _translator = IngredientTranslator(foodData);

  Future<List<String>> detectIngredients(File imageFile) async {
    try {
      final data = await VisionApiClient.callLabelDetection(
        imageFile,
        maxResults: _VisionConstants.maxLabelDetectionResults,
      );
      
      final labels = data['responses'][0]['labelAnnotations'] as List;

        // デバッグ: 全てのラベルを出力
        debugPrint('=== Vision API 検出結果（生データ） ===');
        for (var label in labels) {
          debugPrint('${label['description']} (信頼度: ${label['score']})');
        }
        debugPrint('=====================================');

        // 信頼度でソート（高い順）
        final sortedLabels = List<Map<String, dynamic>>.from(labels)
          ..sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));

        // 信頼度の閾値（JSONデータから取得）
        final confidenceThreshold = foodData.filtering.confidenceThreshold;
        
        // まず、食材関連のラベルだけを抽出（単一/複数食材判定のため）
        final foodRelatedLabels = sortedLabels
            .where((label) => 
                (label['score'] as double) >= confidenceThreshold &&
                _filter.isFoodRelated(label['description'] as String))
            .toList();
        
        // 食材関連ラベルの上位2つの信頼度差を確認して、単一食材か複数食材かを判定
        final isMultipleIngredients = _determineIfMultipleIngredients(foodRelatedLabels);
        
        // フィルタリング処理
        final filteredLabels = <Map<String, dynamic>>[];
        
        for (var label in sortedLabels) {
          final score = label['score'] as double;
          final description = label['description'] as String;
          
          // 閾値以下は除外
          if (score < confidenceThreshold) continue;
          
          // 食材関連でなければ除外
          if (!_filter.isFoodRelated(description)) continue;
          
          // 最初の食材（最も信頼度が高い）
          if (filteredLabels.isEmpty) {
            filteredLabels.add(label);
            continue;
          }
          
          // すでに採用された食材と比較
          if (_shouldExcludeLabel(label, filteredLabels, isMultipleIngredients, confidenceThreshold)) {
            continue;
          }
          
          filteredLabels.add(label);
        }
        
        final ingredients = filteredLabels
            .map((label) => label['description'] as String)
            .map((label) => _translator.translateToJapanese(label))
            .toSet() // 重複を削除
            .take(_VisionConstants.maxIngredientResults)
            .toList();

        debugPrint('=== フィルタリング後（信頼度$confidenceThreshold以上） ===');
        debugPrint('検出された食材: $ingredients');
        debugPrint('========================================');

        return ingredients;
    } catch (e) {
      throw Exception('食材認識に失敗しました: $e');
    }
  }

  /// 単一食材か複数食材かを判定
  bool _determineIfMultipleIngredients(List<Map<String, dynamic>> foodRelatedLabels) {
    if (foodRelatedLabels.length < 2) {
      return false;
    }
    
    final topScore = foodRelatedLabels[0]['score'] as double;
    final secondScore = foodRelatedLabels[1]['score'] as double;
    final topTwoDiff = topScore - secondScore;
    
    // 上位2つの差が閾値未満なら複数食材と判定
    final isMultiple = topTwoDiff < _VisionConstants.multipleIngredientsThreshold;
    debugPrint('${isMultiple ? "複数" : "単一"}食材モード（食材上位2つの差: ${(topTwoDiff * 100).toStringAsFixed(1)}%）');
    return isMultiple;
  }

  /// ラベルを除外すべきか判定
  bool _shouldExcludeLabel(
    Map<String, dynamic> label,
    List<Map<String, dynamic>> filteredLabels,
    bool isMultipleIngredients,
    double confidenceThreshold,
  ) {
    final score = label['score'] as double;
    final description = label['description'] as String;
    
    for (var existingLabel in filteredLabels) {
      final existingDesc = existingLabel['description'] as String;
      final existingScore = existingLabel['score'] as double;
      
      // 1. 食材名が類似しているかチェック
      if (_filter.isSimilarFoodName(description, existingDesc)) {
        debugPrint('除外: $description (信頼度: $score) - $existingDesc と類似');
        return true;
      }
      
      // 2. 単一食材モードの場合、同じカテゴリで信頼度の差が大きければ除外
      if (!isMultipleIngredients) {
        final currentCategory = foodData.getCategoryOfFood(description);
        final existingCategory = foodData.getCategoryOfFood(existingDesc);
        
        if (currentCategory != null && 
            currentCategory == existingCategory &&
            (existingScore - score) >= _VisionConstants.categoryConfidenceDiffThreshold) {
          debugPrint('除外: $description (信頼度: $score) - $existingDesc (信頼度: $existingScore) と同じ$currentCategoryで信頼度の差が大きい');
          return true;
        }
      }
    }
    
    return false;
  }

  /// Object Detection APIを使って画像内の物体を検出
  Future<List<DetectedObject>> detectObjects(File imageFile) async {
    try {
      final data = await VisionApiClient.callObjectLocalization(
        imageFile,
        maxResults: _VisionConstants.maxObjectDetectionResults,
      );
      
      final objects = data['responses'][0]['localizedObjectAnnotations'] as List?;

        if (objects == null || objects.isEmpty) {
          debugPrint('=== Object Detection: 物体が検出されませんでした ===');
          return [];
        }

        // デバッグ: 全ての検出物体を出力
        debugPrint('=== Object Detection 検出結果 ===');
        for (var obj in objects) {
          debugPrint('${obj['name']} (信頼度: ${obj['score']})');
        }
        debugPrint('=====================================');

        // DetectedObjectのリストに変換
        final detectedObjects = objects
            .map((obj) => DetectedObject.fromJson(obj as Map<String, dynamic>))
            .toList();

        return detectedObjects;
    } catch (e) {
      throw Exception('物体検出に失敗しました: $e');
    }
  }

  /// Web Detection APIを使って画像から商品名や詳細情報を取得（信頼度情報付き）
  Future<List<Map<String, dynamic>>> detectWithWebDetectionWithScores(File imageFile) async {
    try {
      final data = await VisionApiClient.callWebDetection(
        imageFile,
        maxResults: _VisionConstants.maxWebDetectionResults,
      );
      
      final webDetection = data['responses'][0]['webDetection'] as Map<String, dynamic>?;

      if (webDetection == null) {
        return [];
      }

      return _processWebDetectionResults(webDetection);
    } catch (e) {
      throw Exception('Web検出に失敗しました: $e');
    }
  }

  /// Web Detection APIを使って画像から商品名や詳細情報を取得
  Future<List<String>> detectWithWebDetection(File imageFile) async {
    try {
      final data = await VisionApiClient.callWebDetection(
        imageFile,
        maxResults: _VisionConstants.maxWebDetectionResults,
      );
      
      final webDetection = data['responses'][0]['webDetection'] as Map<String, dynamic>?;

      if (webDetection == null) {
        debugPrint('=== Web Detection: webDetectionフィールドがありませんでした ===');
        
        final error = data['responses'][0]['error'];
        if (error != null) {
          debugPrint('エラー: $error');
        }
        
        return [];
      }

      _logWebDetectionResults(webDetection);
      
      final ingredientsWithScores = _processWebDetectionResults(webDetection);
      return ingredientsWithScores
          .map((c) => c['translated'] as String)
          .take(1)
          .toList();
    } catch (e) {
      throw Exception('Web検出に失敗しました: $e');
    }
  }

  /// Web Detection結果を処理して食材候補を抽出
  List<Map<String, dynamic>> _processWebDetectionResults(Map<String, dynamic> webDetection) {
    final ingredientCandidates = <Map<String, dynamic>>[];

    // Best Guess Labelsから食材名を抽出（信頼度1.0として扱う）
    final bestGuessLabels = webDetection['bestGuessLabels'] as List?;
    if (bestGuessLabels != null) {
      for (var label in bestGuessLabels) {
        final labelText = label['label'] as String;
        if (_filter.isFoodRelated(labelText)) {
          ingredientCandidates.add({
            'name': labelText,
            'score': 1.0,
            'translated': _translator.translateToJapanese(labelText),
          });
        }
      }
    }

    // Web Entitiesから食材名を抽出（信頼度閾値以上）
    final webEntities = webDetection['webEntities'] as List?;
    if (webEntities != null) {
      for (var entity in webEntities) {
        final description = entity['description'] as String?;
        final score = (entity['score'] as num?)?.toDouble() ?? 0.0;
        
        if (description != null && 
            score >= _VisionConstants.webDetectionScoreThreshold && 
            _filter.isFoodRelated(description)) {
          final translated = _translator.translateToJapanese(description);
          if (!ingredientCandidates.any((c) => c['translated'] == translated)) {
            ingredientCandidates.add({
              'name': description,
              'score': score,
              'translated': translated,
            });
          }
        }
      }
    }

    // 信頼度順にソート（高い順）
    ingredientCandidates.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));

    // 類似食材をフィルタリング（信頼度が高い方を優先）
    return _filterSimilarIngredients(ingredientCandidates);
  }

  /// Web Detection結果をログ出力
  void _logWebDetectionResults(Map<String, dynamic> webDetection) {
    debugPrint('=== Web Detection 検出結果 ===');
    
    final webEntities = webDetection['webEntities'] as List?;
    if (webEntities != null) {
      debugPrint('--- Web Entities ---');
      for (var entity in webEntities) {
        final description = entity['description'] ?? 'N/A';
        final score = entity['score'] ?? 0.0;
        debugPrint('$description (スコア: $score)');
      }
    }

    final bestGuessLabels = webDetection['bestGuessLabels'] as List?;
    if (bestGuessLabels != null && bestGuessLabels.isNotEmpty) {
      debugPrint('--- Best Guess Labels ---');
      for (var label in bestGuessLabels) {
        debugPrint('${label['label']}');
      }
    }

    final pagesWithMatchingImages = webDetection['pagesWithMatchingImages'] as List?;
    if (pagesWithMatchingImages != null) {
      debugPrint('--- 類似画像のページ数: ${pagesWithMatchingImages.length} ---');
    }

    debugPrint('=====================================');
  }

  /// 類似食材をフィルタリング（信頼度が高い方を優先）
  List<Map<String, dynamic>> _filterSimilarIngredients(
    List<Map<String, dynamic>> ingredientCandidates,
  ) {
    final filteredIngredients = <Map<String, dynamic>>[];
    for (var candidate in ingredientCandidates) {
      final candidateName = candidate['name'] as String;
      final candidateTranslated = candidate['translated'] as String;
      
      bool shouldAdd = true;
      for (var existing in filteredIngredients) {
        final existingName = existing['name'] as String;
        if (_filter.isSimilarFoodName(candidateName, existingName) || 
            candidateTranslated == existing['translated']) {
          final candidateScore = candidate['score'] as double;
          final existingScore = existing['score'] as double;
          if (candidateScore <= existingScore) {
            shouldAdd = false;
            break;
          } else {
            filteredIngredients.remove(existing);
            break;
          }
        }
      }
      
      if (shouldAdd) {
        filteredIngredients.add(candidate);
      }
    }
    
    return filteredIngredients;
  }

  /// Object Detection + Text Detection を組み合わせた高精度認識
  /// 各物体を個別に認識し、その物体ごとのテキストから食材を判別
  Future<List<String>> detectIngredientsWithObjectDetection(File imageFile) async {
    try {
      debugPrint('=== Object Detection + Text Detection を開始 ===');
      
      // ステップ1: Object Detectionで物体を検出
      final objects = await detectObjects(imageFile);
      
      if (objects.isEmpty) {
        debugPrint('物体が検出されませんでした。Text Detection + Web Detectionにフォールバック');
        return await detectProductWithTextAndWeb(imageFile);
      }
      
      // 信頼度フィルタを適用
      final confidenceThreshold = foodData.filtering.objectDetectionConfidenceThreshold;
      final filteredObjects = objects.where((obj) => obj.score >= confidenceThreshold).toList();
      
      debugPrint('検出された物体: ${objects.length}個');
      debugPrint('信頼度${(confidenceThreshold * 100).toStringAsFixed(0)}%以上の物体: ${filteredObjects.length}個');
      
      if (filteredObjects.isEmpty) {
        debugPrint('信頼度${(confidenceThreshold * 100).toStringAsFixed(0)}%以上の物体がありませんでした。Text Detection + Web Detectionにフォールバック');
        return await detectProductWithTextAndWeb(imageFile);
      }
      
      debugPrint('${filteredObjects.length}個の物体を個別認識します（Text Detection優先）...');
      
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
        debugPrint('物体 ${i + 1}/${filteredObjects.length}: ${obj.name} (${(obj.score * 100).toStringAsFixed(0)}%)');
        
        try {
          final croppedImage = ImageProcessor.cropImage(image, obj.boundingBox);
          if (croppedImage == null) {
            debugPrint('  → スキップ（サイズが無効）');
            continue;
          }
          
          // 最小サイズチェック
          final minCropSize = foodData.filtering.minCropSize;
          if (!ImageProcessor.isValidCropSize(croppedImage.width, croppedImage.height, minCropSize)) {
            debugPrint('  → スキップ（サイズが小さすぎる: ${croppedImage.width}x${croppedImage.height}px < ${minCropSize}x${minCropSize}px）');
            continue;
          }
          
          // 一時ファイルに保存
          final tempFile = await ImageProcessor.saveCroppedImageToTemp(croppedImage, i);
          if (tempFile == null) {
            debugPrint('  → スキップ（一時ファイルの作成に失敗）');
            continue;
          }
          
          // Text Detection優先で個別認識（信頼度情報付き）
          debugPrint('  → Text Detection優先で認識中...');
          final detectedIngredients = await _detectIngredientsFromCroppedImage(tempFile, objectScore);
          
          // 重み付けデータを更新
          _updateIngredientWeights(ingredientWeights, detectedIngredients, objectScore);
          
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
        
        bool shouldAdd = true;
        String? similarIngredient;
        
        // 既存の食材と類似しているかチェック
        final mergeResult = _checkAndMergeSimilarIngredient(
          ingredient,
          ingredientName,
          mergedIngredients,
        );
        if (mergeResult.shouldSkip) {
          continue;
        }
        if (mergeResult.shouldReplace != null) {
          similarIngredient = mergeResult.shouldReplace;
        }
        shouldAdd = mergeResult.shouldAdd;
        
        if (shouldAdd) {
          if (similarIngredient != null) {
            // 類似食材を置き換え
            debugPrint('類似食材を置き換え: $similarIngredient → $ingredientName');
            mergedIngredients.remove(similarIngredient);
          }
          mergedIngredients[ingredientName] = Map<String, dynamic>.from(ingredient);
        }
      }
      
      // 重み付けスコアでソート（検出回数 × 統合スコア）
      final sortedIngredients = mergedIngredients.values.toList()
        ..sort((a, b) {
          final countA = a['count'] as int;
          final countB = b['count'] as int;
          final integratedScoreA = a['maxIntegratedScore'] as double? ?? 0.0;
          final integratedScoreB = b['maxIntegratedScore'] as double? ?? 0.0;
          
          // 検出回数が多い方を優先
          if (countA != countB) {
            return countB.compareTo(countA);
          }
          // 検出回数が同じ場合は、統合スコア（Object Detection × Web Detection）が高い方を優先
          return integratedScoreB.compareTo(integratedScoreA);
        });
      
      final result = sortedIngredients
          .map((ingredient) => ingredient['name'] as String)
          .toList();
      
      debugPrint('=== 最終結果（${ingredientList.length}個 → ${result.length}個）: ${result.join(", ")} ===');
      debugPrint('=== 重み付け詳細 ===');
      for (var ingredient in sortedIngredients) {
        final objectScore = ingredient['maxObjectScore'] as double? ?? 0.0;
        final webScore = ingredient['maxWebScore'] as double? ?? 0.0;
        final integratedScore = ingredient['maxIntegratedScore'] as double? ?? 0.0;
        debugPrint('  ${ingredient['name']}: 検出${ingredient['count']}回, Object=${(objectScore * 100).toStringAsFixed(0)}%, Web=${(webScore * 100).toStringAsFixed(0)}%, 統合=${(integratedScore * 100).toStringAsFixed(0)}%');
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
        // Text Detectionの場合は信頼度を高めに設定（Object Detectionの信頼度に基づく）
        final textScore = objectScore * 0.9; // Object Detectionの信頼度の90%をText Detectionの信頼度とする
        return textIngredients.map((ingredient) => {
          'name': ingredient,
          'score': textScore,
          'translated': ingredient,
        }).toList();
      }
    } catch (e) {
      debugPrint('  → Text Detectionエラー（スキップ）: $e');
    }
    
    // ステップ2: Text Detectionが失敗した場合、Web Detectionを試行
    final webIngredientsWithScores = await detectWithWebDetectionWithScores(tempFile);
    
    if (webIngredientsWithScores.isNotEmpty) {
      debugPrint('  → Web Detection結果: ${webIngredientsWithScores.map((i) => '${i['translated']} (信頼度: ${((i['score'] as double) * 100).toStringAsFixed(0)}%)').join(", ")}');
      return webIngredientsWithScores;
    }
    
    // ステップ3: Web Detectionも失敗した場合、Label Detectionにフォールバック
    debugPrint('  → Label Detectionにフォールバック');
    final labelIngredients = await detectIngredients(tempFile);
    debugPrint('  → Label Detection結果: ${labelIngredients.join(", ")}');
    // Label Detectionの場合はデフォルト信頼度として扱う
    return labelIngredients.map((ingredient) => {
      'name': ingredient,
      'score': _VisionConstants.labelDetectionDefaultScore,
      'translated': ingredient,
    }).toList();
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
      
      // 統合スコアを計算（Object Detectionの信頼度 × Web Detectionの信頼度）
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
      final englishName1 = _translator.getEnglishNameFromJapanese(ingredientName);
      final englishName2 = _translator.getEnglishNameFromJapanese(existingName);
      
      if (ingredientName == existingName) {
        // 同じ食材の場合は、重み付けデータを統合
        final existingWeight = mergedIngredients[existingName]!;
        existingWeight['count'] = (existingWeight['count'] as int) + (ingredient['count'] as int);
        if ((ingredient['maxObjectScore'] as double) > (existingWeight['maxObjectScore'] as double)) {
          existingWeight['maxObjectScore'] = ingredient['maxObjectScore'];
        }
        return _MergeResult(shouldAdd: false, shouldSkip: true);
      } else if (englishName1 != null && englishName2 != null && 
                 _filter.isSimilarFoodName(englishName1, englishName2)) {
        // 類似食材の場合は、類似ペアのprimaryを優先し、次に検出回数が多い方を優先
        final existingWeight = mergedIngredients[existingName]!;
        final existingCount = existingWeight['count'] as int;
        final currentCount = ingredient['count'] as int;
        
        // 類似ペアから優先すべき食材を取得
        final preferred = _filter.getPreferredIngredientFromSimilarPair(englishName1, englishName2);
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
          // primaryが存在する場合は、primaryを優先（検出回数に関わらず）
          if (nonPreferredName == ingredientName) {
            debugPrint('最終結果から除外: $ingredientName (類似ペアのprimary: $preferredName を優先)');
            return _MergeResult(shouldAdd: false, shouldSkip: true);
          } else {
            debugPrint('類似食材を置き換え: $existingName → $ingredientName (類似ペアのprimary: $preferredName を優先)');
            return _MergeResult(shouldAdd: true, shouldSkip: false, shouldReplace: existingName);
          }
        } else {
          // primaryが存在しない場合は、検出回数が多い方を優先
          if (currentCount > existingCount) {
            return _MergeResult(shouldAdd: true, shouldSkip: false, shouldReplace: existingName);
          } else {
            debugPrint('最終結果から除外: $ingredientName ($currentCount回) - $existingName ($existingCount回) と類似');
            return _MergeResult(shouldAdd: false, shouldSkip: true);
          }
        }
      }
    }
    
    return _MergeResult(shouldAdd: true, shouldSkip: false);
  }

  /// Text Detection APIを使って画像からテキストを検出し、食材名を抽出
  Future<List<String>> detectIngredientsFromText(File imageFile) async {
    try {
      debugPrint('=== Text Detection を開始 ===');
      
      final data = await VisionApiClient.callTextDetection(imageFile);
      final textAnnotations = data['responses'][0]['textAnnotations'] as List?;

      if (textAnnotations == null || textAnnotations.isEmpty) {
        debugPrint('=== Text Detection: テキストが検出されませんでした ===');
        return [];
      }

      // 最初の要素は全テキスト（結合されたテキスト）
      final fullText = textAnnotations[0]['description'] as String?;
      if (fullText == null || fullText.trim().isEmpty) {
        debugPrint('=== Text Detection: テキストが空でした ===');
        return [];
      }

      debugPrint('=== Text Detection 検出テキスト ===');
      debugPrint(fullText);
      debugPrint('=====================================');

      // テキストから最も適切な食材名を1つ抽出
      final ingredient = _extractSingleIngredientFromText(fullText);
      final ingredients = <String>[];
      if (ingredient != null) {
        ingredients.add(ingredient);
      }

      // 個別のテキストブロックも確認（商品名などが単独で書かれている場合）
      // 隣接するテキストブロックを結合して商品名パターンをチェック（例：「さば」+「水煮」→「さば水煮」）
      if (textAnnotations.length > 1) {
        final processedIndices = <int>{};
        
        for (int i = 1; i < textAnnotations.length; i++) {
          if (processedIndices.contains(i)) continue;
          
          final textBlock = textAnnotations[i]['description'] as String?;
          if (textBlock == null || textBlock.trim().length < _VisionConstants.minTextLength) {
            continue;
          }
          
          debugPrint('テキストブロック[$i]: "$textBlock"');
          
          // 隣接するテキストブロックを結合してチェック（最大3つまで）
          String combinedText = textBlock;
          int endIndex = i;
          for (int j = i + 1; j < textAnnotations.length && j <= i + 2; j++) {
            final nextBlock = textAnnotations[j]['description'] as String?;
            if (nextBlock != null && nextBlock.trim().length >= _VisionConstants.minTextLength) {
              combinedText += ' ' + nextBlock;
              endIndex = j;
            }
          }
          
          final blockIngredient = _extractSingleIngredientFromText(combinedText);
          if (blockIngredient != null) {
            // 商品名パターンかどうかをチェック
            final isProductName = _isProductName(blockIngredient);
            
            // 類似食材をチェックして統合
            final shouldAdd = _shouldAddIngredient(blockIngredient, ingredients);
            if (shouldAdd) {
              ingredients.add(blockIngredient);
              // 使用したテキストブロックをマーク
              for (int j = i; j <= endIndex; j++) {
                processedIndices.add(j);
              }
              
              // 商品名が検出された場合、その近くのテキストブロックもマーク（前後10つまで）
              // これにより、商品名のパッケージに書かれている他の食材名を誤検出しないようにする
              if (isProductName) {
                for (int j = i; j <= endIndex; j++) {
                  // 前後10つまでのテキストブロックをマーク
                  for (int k = 1; k <= 10; k++) {
                    if (j - k > 0) processedIndices.add(j - k);
                    if (j + k < textAnnotations.length) processedIndices.add(j + k);
                  }
                }
                debugPrint('商品名「$blockIngredient」が検出されたため、その近くのテキストブロック（前後10個）をスキップします');
              }
            }
          } else {
            debugPrint('テキストブロック[$i]から食材は検出されませんでした');
          }
        }
      }

      debugPrint('=== Text Detection 抽出結果: ${ingredients.join(", ")} ===');
      return ingredients.take(_VisionConstants.maxIngredientResults).toList();
    } catch (e) {
      debugPrint('Text Detection エラー: $e');
      throw Exception('テキスト検出に失敗しました: $e');
    }
  }

  /// テキストから最も適切な食材名を1つ抽出
  /// 優先順位: 商品名パターン > 具体的な食材名（長い順）> 一般的な食材名
  String? _extractSingleIngredientFromText(String text) {
    // ステップ1: 商品名パターンから優先的に抽出（最も具体的な商品名を1つ）
    final productIngredient = _extractSingleProductName(text);
    if (productIngredient != null) {
      debugPrint('商品名パターンから抽出: $productIngredient');
      return productIngredient;
    }
    
    // ステップ2: 商品名が含まれているかチェック（商品名が含まれている場合は他の食材を検出しない）
    if (_hasProductName(text)) {
      debugPrint('商品名が含まれているため、他の食材を検出しません: "$text"');
      return null;
    }
    
    // ステップ3: 日本語テキストから最も適切な食材名を1つ抽出
    final japaneseIngredient = _extractSingleJapaneseIngredient(text);
    if (japaneseIngredient != null) {
      debugPrint('日本語テキストから抽出: $japaneseIngredient');
      return japaneseIngredient;
    }
    
    // ステップ4: 英語の食材名と照合（商品名が英語で書かれている場合）
    final englishIngredient = _extractSingleEnglishIngredient(text);
    if (englishIngredient != null) {
      debugPrint('英語テキストから抽出: $englishIngredient');
      return englishIngredient;
    }
    
    return null;
  }

  /// 食材名が商品名パターンかどうかをチェック
  bool _isProductName(String ingredient) {
    final productNames = [
      'カレールウ', 'カレー粉', 'カレー',
      'さば水煮', 'いわし', 'サンマ', 'まぐろ',
      '梅干し', '納豆', '豆腐',
      '卵',
    ];
    return productNames.contains(ingredient);
  }

  /// テキストに商品名が含まれているかチェック（商品名パターンに一致するか、商品名として認識される文字列が含まれているか）
  bool _hasProductName(String text) {
    // 商品名パターンのキーワードをチェック（完全一致または部分一致）
    final productKeywords = [
      'カレールウ', 'カレー粉', 'ゴールデンカレー', 'カレー',
      'さば水煮', 'さば 水煮', 'サバ水煮', 'サバ 水煮',
      'いわし水煮', 'サンマ水煮', 'まぐろ水煮',
      '梅干し', '梅干', '納豆', '豆腐',
      'たまご', 'タマゴ', '玉子',
    ];
    
    for (var keyword in productKeywords) {
      if (text.contains(keyword)) {
        return true;
      }
    }
    
    return false;
  }

  /// 商品名パターンから最も適切な食材名を1つ抽出
  String? _extractSingleProductName(String text) {
    // 商品名パターン（食材名 + 加工方法/状態）
    final productPatterns = [
      // カレー関連（優先度高い）
      {'pattern': RegExp(r'カレールウ|カレー.*ルウ|curry.*roux', caseSensitive: false), 'ingredient': 'カレールウ'},
      {'pattern': RegExp(r'カレー粉|curry.*powder', caseSensitive: false), 'ingredient': 'カレー粉'},
      {'pattern': RegExp(r'ゴールデンカレー|golden.*curry', caseSensitive: false), 'ingredient': 'カレールウ'},
      {'pattern': RegExp(r'カレー', caseSensitive: false), 'ingredient': 'カレー'},
      
      // 魚類の加工品（さば水煮を優先）- スペースを含む場合も対応
      {'pattern': RegExp(r'さば\s+水煮|サバ\s+水煮|さば水煮|サバ水煮', caseSensitive: false), 'ingredient': 'さば水煮'},
      {'pattern': RegExp(r'いわし\s*水煮|イワシ\s*水煮', caseSensitive: false), 'ingredient': 'いわし'},
      {'pattern': RegExp(r'サンマ\s*水煮|さんま\s*水煮', caseSensitive: false), 'ingredient': 'サンマ'},
      {'pattern': RegExp(r'まぐろ\s*水煮|マグロ\s*水煮', caseSensitive: false), 'ingredient': 'マグロ'},
      {'pattern': RegExp(r'さば\s*味噌|サバ\s*味噌', caseSensitive: false), 'ingredient': 'さば'},
      {'pattern': RegExp(r'さば\s*味付|サバ\s*味付', caseSensitive: false), 'ingredient': 'さば'},
      
      // 卵関連
      {'pattern': RegExp(r'産まれた.*たまご|産まれた.*タマゴ', caseSensitive: false), 'ingredient': '卵'},
      {'pattern': RegExp(r'新鮮.*たまご|新鮮.*タマゴ|新鮮.*玉子', caseSensitive: false), 'ingredient': '卵'},
      {'pattern': RegExp(r'たまご|タマゴ|玉子', caseSensitive: false), 'ingredient': '卵'},
      
      // その他の加工品
      {'pattern': RegExp(r'梅干し|梅干', caseSensitive: false), 'ingredient': '梅干し'},
      {'pattern': RegExp(r'納豆', caseSensitive: false), 'ingredient': '納豆'},
      {'pattern': RegExp(r'豆腐', caseSensitive: false), 'ingredient': '豆腐'},
    ];
    
    // さばが検出されているかチェック（かつおの優先度を下げるため）
    final hasSaba = text.contains('さば') || text.contains('サバ') || text.contains('さば.*水煮') || text.contains('サバ.*水煮');
    
    for (var patternData in productPatterns) {
      final pattern = patternData['pattern'] as RegExp;
      final ingredient = patternData['ingredient'] as String;
      final lowerPriority = patternData['lowerPriority'] as bool? ?? false;
      
      // さばが検出されている場合、かつおは優先度を下げる
      if (lowerPriority && hasSaba && ingredient == 'かつお') {
        continue;
      }
      
      if (pattern.hasMatch(text)) {
        debugPrint('商品名パターンマッチ: "$text" → パターン: ${pattern.pattern}, 食材: $ingredient');
        // 英語名を取得して食材関連かチェック
        final englishName = _translator.getEnglishNameFromJapanese(ingredient);
        if (englishName != null && _filter.isFoodRelated(englishName)) {
          return ingredient;
        } else {
          // translationsにない場合でも、パターンに一致した場合は返す
          return ingredient;
        }
      }
    }
    
    return null;
  }

  /// 日本語テキストから最も適切な食材名を1つ抽出
  String? _extractSingleJapaneseIngredient(String text) {
    // translationsマップから全ての日本語名を取得（長い順にソート）
    final japaneseNames = foodData.translations.values.toSet().toList()
      ..sort((a, b) => b.length.compareTo(a.length)); // 長い順にソート（具体的な名前を優先）
    
    // テキスト内に日本語食材名が含まれているかチェック（長い順なので、最初に見つかったものが最も具体的）
    for (var japaneseName in japaneseNames) {
      if (_containsJapaneseFoodName(text, japaneseName)) {
        // 英語名を取得して食材関連かチェック
        final englishName = _translator.getEnglishNameFromJapanese(japaneseName);
        if (englishName != null && _filter.isFoodRelated(englishName)) {
          return japaneseName;
        }
      }
    }
    
    // 日本語食材名のバリエーションもチェック
    final variantIngredients = _extractFromJapaneseVariants(text);
    if (variantIngredients.isNotEmpty) {
      // 最初の1つを返す（既に優先順位が考慮されている）
      return variantIngredients.first;
    }
    
    return null;
  }

  /// 英語テキストから最も適切な食材名を1つ抽出
  String? _extractSingleEnglishIngredient(String text) {
    final lowerText = text.toLowerCase();
    final allFoodNames = foodData.getAllFoodNames();
    
    // 長い順にソート（具体的な名前を優先）
    final sortedFoodNames = List<String>.from(allFoodNames)
      ..sort((a, b) => b.length.compareTo(a.length));
    
    for (var foodName in sortedFoodNames) {
      final lowerFoodName = foodName.toLowerCase();
      
      if (_containsFoodName(lowerText, lowerFoodName)) {
        if (_filter.isFoodRelated(foodName)) {
          final translated = _translator.translateToJapanese(foodName);
          return translated;
        }
      }
    }
    
    return null;
  }

  /// 新しい食材を追加すべきか判定（類似食材の統合を考慮）
  bool _shouldAddIngredient(String newIngredient, List<String> existingIngredients) {
    // 完全一致の場合は追加しない
    if (existingIngredients.contains(newIngredient)) {
      return false;
    }
    
    // 類似食材をチェック
    for (var existing in existingIngredients) {
      final englishNew = _translator.getEnglishNameFromJapanese(newIngredient);
      final englishExisting = _translator.getEnglishNameFromJapanese(existing);
      
      if (englishNew != null && englishExisting != null) {
        if (_filter.isSimilarFoodName(englishNew, englishExisting)) {
          // 類似ペアから優先すべき食材を取得
          final preferred = _filter.getPreferredIngredientFromSimilarPair(englishNew, englishExisting);
          
          if (preferred != null) {
            // primaryが存在する場合は、primaryを優先
            final preferredIngredient = preferred.toLowerCase() == englishNew.toLowerCase() 
                ? newIngredient 
                : existing;
            final nonPreferredIngredient = preferred.toLowerCase() == englishNew.toLowerCase() 
                ? existing 
                : newIngredient;
            
            if (nonPreferredIngredient == newIngredient) {
              debugPrint('$newIngredientを除外（$existingと類似、類似ペアのprimary: $preferredIngredientを優先）');
              return false;
            } else {
              debugPrint('$existingを除外（$newIngredientと類似、類似ペアのprimary: $preferredIngredientを優先）');
              existingIngredients.remove(existing);
              return true;
            }
          } else {
            // primaryが存在しない場合は、より具体的な方を優先（長い方がより具体的と判断）
            if (newIngredient.length <= existing.length) {
              debugPrint('$newIngredientを除外（$existingと類似、$existingを優先）');
              return false;
            } else {
              debugPrint('$existingを除外（$newIngredientと類似、$newIngredientを優先）');
              existingIngredients.remove(existing);
              return true;
            }
          }
        }
      }
    }
    
    return true;
  }

  /// 誤検出をフィルタリング
  List<String> _filterFalsePositives(List<String> ingredients, String text) {
    final filtered = <String>[];
    
    for (var ingredient in ingredients) {
      // なすの誤検出をチェック
      if (ingredient == 'なす') {
        // 「産まれた」「織りなす」などの誤検出パターンをチェック
        final falsePositivePatterns = [
          RegExp(r'産まれた', caseSensitive: false),
          RegExp(r'織りなす', caseSensitive: false),
          RegExp(r'織り成す', caseSensitive: false),
          RegExp(r'織.*なす', caseSensitive: false),
        ];
        
        bool isFalsePositive = false;
        for (var pattern in falsePositivePatterns) {
          if (pattern.hasMatch(text)) {
            isFalsePositive = true;
            break;
          }
        }
        
        if (isFalsePositive) {
          debugPrint('なすを除外（誤検出の可能性: 誤検出パターンにマッチ）');
          continue;
        }
      }
      
      // かつおの誤検出をチェック（さばが検出されている場合）
      if (ingredient == 'かつお') {
        final hasSaba = ingredients.contains('さば') || 
                       ingredients.contains('さば水煮') || 
                       text.contains('さば.*水煮') || 
                       text.contains('サバ.*水煮');
        if (hasSaba) {
          debugPrint('かつおを除外（さばが検出されているため）');
          continue;
        }
      }
      
      // カレールウが検出されている場合、カレーを除外
      if (ingredient == 'カレー') {
        if (ingredients.contains('カレールウ')) {
          debugPrint('カレーを除外（カレールウが検出されているため）');
          continue;
        }
      }
      
      // さば水煮が検出されている場合、さばを除外
      if (ingredient == 'さば') {
        if (ingredients.contains('さば水煮')) {
          debugPrint('さばを除外（さば水煮が検出されているため）');
          continue;
        }
      }
      
      filtered.add(ingredient);
    }
    
    return filtered;
  }

  /// 日本語テキストから直接食材名を抽出
  List<String> _extractJapaneseIngredientsFromText(String text) {
    final ingredients = <String>[];
    
    // translationsマップから全ての日本語名を取得（長い順にソート）
    final japaneseNames = foodData.translations.values.toSet().toList()
      ..sort((a, b) => b.length.compareTo(a.length)); // 長い順にソート
    
    // テキスト内に日本語食材名が含まれているかチェック
    for (var japaneseName in japaneseNames) {
      if (_containsJapaneseFoodName(text, japaneseName)) {
        // 既に追加済みかチェック
        if (!ingredients.contains(japaneseName)) {
          // 英語名を取得して食材関連かチェック
          final englishName = _translator.getEnglishNameFromJapanese(japaneseName);
          if (englishName != null && _filter.isFoodRelated(englishName)) {
            ingredients.add(japaneseName);
            // なすの場合は、どのテキストから検出されたかをデバッグ出力
            if (japaneseName == 'なす') {
              debugPrint('テキストから抽出（日本語）: $japaneseName [検出元テキスト: "${text.substring(0, text.length > 100 ? 100 : text.length)}..."]');
            } else {
              debugPrint('テキストから抽出（日本語）: $japaneseName');
            }
          }
        }
      }
    }
    
    // 日本語食材名のバリエーションもチェック
    final variantIngredients = _extractFromJapaneseVariants(text);
    for (var variant in variantIngredients) {
      if (!ingredients.contains(variant)) {
        ingredients.add(variant);
      }
    }
    
    return ingredients;
  }

  /// 日本語テキスト内に食材名が含まれているかチェック
  bool _containsJapaneseFoodName(String text, String japaneseName) {
    // 完全一致
    if (text == japaneseName) return true;
    
    // テキスト内に含まれているか（部分一致）
    if (text.contains(japaneseName)) {
      // なすの誤検出を防ぐ（「産まれた」「織りなす」などに「なす」が含まれる場合を除外）
      if (japaneseName == 'なす') {
        // 「なす」が単独で含まれているか、食材としての文脈で使われているかチェック
        // 「産まれた」「織りなす」などの誤検出を防ぐ
        final falsePositivePatterns = [
          RegExp(r'産まれた', caseSensitive: false),
          RegExp(r'産ま', caseSensitive: false),
          RegExp(r'織りなす', caseSensitive: false),
          RegExp(r'織り成す', caseSensitive: false),
          RegExp(r'織.*なす', caseSensitive: false),
        ];
        
        for (var pattern in falsePositivePatterns) {
          if (pattern.hasMatch(text)) {
            // 誤検出パターンにマッチする場合は除外
            return false;
          }
        }
      }
      
      // 商品名などで含まれている場合（例：「さば水煮」に「さば」が含まれる）
      return true;
    }
    
    return false;
  }

  /// 日本語食材名のバリエーションから食材を抽出（最初に見つかった1つを返す）
  List<String> _extractFromJapaneseVariants(String text) {
    final ingredients = <String>[];
    
    // 日本語食材名のバリエーションマップ（優先順位順）
    final variants = [
      {'variant': 'たまご', 'standard': '卵'},
      {'variant': 'タマゴ', 'standard': '卵'},
      {'variant': '玉子', 'standard': '卵'},
      {'variant': 'さば', 'standard': 'さば'},
      {'variant': 'サバ', 'standard': 'さば'},
      {'variant': 'かつお', 'standard': 'かつお'},
      {'variant': 'カツオ', 'standard': 'かつお'},
      {'variant': '梅干', 'standard': '梅干し'},
      {'variant': '梅干し', 'standard': '梅干し'},
    ];
    
    // バリエーションをチェック（最初に見つかった1つを返す）
    for (var entry in variants) {
      final variant = entry['variant'] as String;
      final standardName = entry['standard'] as String;
      
      if (text.contains(variant)) {
        // 標準名がtranslationsに存在するか確認
        final englishName = _translator.getEnglishNameFromJapanese(standardName);
        if (englishName != null && _filter.isFoodRelated(englishName)) {
          if (!ingredients.contains(standardName)) {
            ingredients.add(standardName);
            debugPrint('バリエーションから抽出: $variant → $standardName');
            // 最初に見つかった1つを返す
            return ingredients;
          }
        } else {
          // translationsにない場合は、バリエーション名をそのまま追加
          // （例：「さば」「かつお」「梅干」など）
          if (!ingredients.contains(standardName)) {
            ingredients.add(standardName);
            debugPrint('バリエーションから抽出（新規）: $variant → $standardName');
            // 最初に見つかった1つを返す
            return ingredients;
          }
        }
      }
    }
    
    return ingredients;
  }

  /// 商品名パターンから食材を抽出（例：「さば水煮」「たまご」など）
  List<String> _extractFromProductNames(String text) {
    final ingredients = <String>[];
    
    // 商品名パターン（食材名 + 加工方法/状態）
    final productPatterns = [
      // カレー関連（優先度高い）
      {'pattern': RegExp(r'カレールウ|カレー.*ルウ|curry.*roux', caseSensitive: false), 'ingredient': 'カレールウ'},
      {'pattern': RegExp(r'カレー粉|curry.*powder', caseSensitive: false), 'ingredient': 'カレー粉'},
      {'pattern': RegExp(r'ゴールデンカレー|golden.*curry', caseSensitive: false), 'ingredient': 'カレールウ'},
      {'pattern': RegExp(r'カレー', caseSensitive: false), 'ingredient': 'カレー'},
      
      // 魚類の加工品（さば水煮を優先）
      {'pattern': RegExp(r'さば.*水煮|サバ.*水煮|さば水煮|サバ水煮', caseSensitive: false), 'ingredient': 'さば水煮'},
      {'pattern': RegExp(r'いわし.*水煮|イワシ.*水煮', caseSensitive: false), 'ingredient': 'いわし'},
      {'pattern': RegExp(r'サンマ.*水煮|さんま.*水煮', caseSensitive: false), 'ingredient': 'サンマ'},
      {'pattern': RegExp(r'まぐろ.*水煮|マグロ.*水煮', caseSensitive: false), 'ingredient': 'マグロ'},
      {'pattern': RegExp(r'さば.*味噌|サバ.*味噌', caseSensitive: false), 'ingredient': 'さば'},
      {'pattern': RegExp(r'さば.*味付|サバ.*味付', caseSensitive: false), 'ingredient': 'さば'},
      // かつおはさばが検出されている場合は優先度を下げる
      {'pattern': RegExp(r'かつお.*水煮|カツオ.*水煮', caseSensitive: false), 'ingredient': 'かつお', 'lowerPriority': true},
      
      // 卵関連
      {'pattern': RegExp(r'たまご|タマゴ|玉子', caseSensitive: false), 'ingredient': '卵'},
      {'pattern': RegExp(r'新鮮.*たまご|新鮮.*タマゴ|新鮮.*玉子', caseSensitive: false), 'ingredient': '卵'},
      {'pattern': RegExp(r'産まれた.*たまご|産まれた.*タマゴ', caseSensitive: false), 'ingredient': '卵'},
      
      // その他の加工品
      {'pattern': RegExp(r'梅干し|梅干', caseSensitive: false), 'ingredient': '梅干し'},
      {'pattern': RegExp(r'納豆', caseSensitive: false), 'ingredient': '納豆'},
      {'pattern': RegExp(r'豆腐', caseSensitive: false), 'ingredient': '豆腐'},
    ];
    
    // さばが検出されているかチェック（かつおの優先度を下げるため）
    final hasSaba = text.contains('さば') || text.contains('サバ') || text.contains('さば.*水煮') || text.contains('サバ.*水煮');
    
    for (var patternData in productPatterns) {
      final pattern = patternData['pattern'] as RegExp;
      final ingredient = patternData['ingredient'] as String;
      final lowerPriority = patternData['lowerPriority'] as bool? ?? false;
      
      // さばが検出されている場合、かつおは優先度を下げる
      if (lowerPriority && hasSaba && ingredient == 'かつお') {
        debugPrint('かつおをスキップ（さばが検出されているため）');
        continue;
      }
      
      if (pattern.hasMatch(text)) {
        // 英語名を取得して食材関連かチェック
        final englishName = _translator.getEnglishNameFromJapanese(ingredient);
        if (englishName != null && _filter.isFoodRelated(englishName)) {
          if (!ingredients.contains(ingredient)) {
            ingredients.add(ingredient);
            debugPrint('商品名パターンから抽出: $ingredient');
          }
        } else {
          // translationsにない場合でも、パターンに一致した場合は追加
          if (!ingredients.contains(ingredient)) {
            ingredients.add(ingredient);
            debugPrint('商品名パターンから抽出（新規）: $ingredient');
          }
        }
      }
    }
    
    return ingredients;
  }

  /// テキスト内に食材名が含まれているかチェック（単語境界を考慮）
  bool _containsFoodName(String text, String foodName) {
    // 完全一致
    if (text == foodName) return true;
    
    // 単語境界での一致（空白、改行、句読点、括弧など）
    final wordBoundaryPattern = RegExp(r'(\b|[^\w])');
    final pattern = RegExp('${wordBoundaryPattern.pattern}${RegExp.escape(foodName)}${wordBoundaryPattern.pattern}', caseSensitive: false);
    if (pattern.hasMatch(text)) return true;
    
    // 単語の一部として含まれている場合もチェック（商品名など）
    // 例: "トマトジュース" に "トマト" が含まれる
    final simplePattern = RegExp(RegExp.escape(foodName), caseSensitive: false);
    if (simplePattern.hasMatch(text)) {
      // ただし、除外キーワードを含む場合は除外
      final excludeKeywords = foodData.filtering.excludeKeywords;
      if (excludeKeywords.any((keyword) => text.contains(keyword.toLowerCase()))) {
        return false;
      }
      return true;
    }
    
    return false;
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
        webIngredients.addAll(await detectWithWebDetection(imageFile));
        debugPrint('Web Detection結果: ${webIngredients.join(", ")}');
      } catch (e) {
        debugPrint('Web Detectionエラー（スキップ）: $e');
      }
      
      // 結果を統合（テキスト検出を優先）
      final combinedIngredients = <String>{};
      
      // テキスト検出結果を優先的に追加
      combinedIngredients.addAll(textIngredients);
      
      // Web Detection結果を追加（重複を除く）
      for (var ingredient in webIngredients) {
        // 類似食材チェック
        bool shouldAdd = true;
        for (var existing in combinedIngredients) {
          final englishExisting = _translator.getEnglishNameFromJapanese(existing);
          final englishIngredient = _translator.getEnglishNameFromJapanese(ingredient);
          
          if (englishExisting != null && englishIngredient != null &&
              _filter.isSimilarFoodName(englishExisting, englishIngredient)) {
            shouldAdd = false;
            break;
          }
        }
        
        if (shouldAdd) {
          combinedIngredients.add(ingredient);
        }
      }
      
      final result = combinedIngredients.take(_VisionConstants.maxIngredientResults).toList();
      debugPrint('=== 統合結果: ${result.join(", ")} ===');
      
      return result;
    } catch (e) {
      throw Exception('Text Detection + Web Detection に失敗しました: $e');
    }
  }
}

