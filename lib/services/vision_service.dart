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

  /// Object Detection + Web Detection を組み合わせた高精度認識
  Future<List<String>> detectIngredientsWithObjectDetection(File imageFile) async {
    try {
      debugPrint('=== Object Detection + Web Detection を開始 ===');
      
      // ステップ1: Object Detectionで物体を検出
      final objects = await detectObjects(imageFile);
      
      if (objects.isEmpty) {
        debugPrint('物体が検出されませんでした。通常のWeb Detectionにフォールバック');
        return await detectWithWebDetection(imageFile);
      }
      
      // 信頼度フィルタを適用
      final confidenceThreshold = foodData.filtering.objectDetectionConfidenceThreshold;
      final filteredObjects = objects.where((obj) => obj.score >= confidenceThreshold).toList();
      
      debugPrint('検出された物体: ${objects.length}個');
      debugPrint('信頼度${(confidenceThreshold * 100).toStringAsFixed(0)}%以上の物体: ${filteredObjects.length}個');
      
      if (filteredObjects.isEmpty) {
        debugPrint('信頼度${(confidenceThreshold * 100).toStringAsFixed(0)}%以上の物体がありませんでした。通常のWeb Detectionにフォールバック');
        return await detectWithWebDetection(imageFile);
      }
      
      debugPrint('${filteredObjects.length}個の物体をWeb Detectionで個別認識します...');
      
      // 画像を読み込み
      final image = await ImageProcessor.loadImage(imageFile);
      if (image == null) {
        throw Exception('画像の読み込みに失敗しました');
      }
      
      // 各物体から検出された食材と、その物体の信頼度を記録
      final ingredientWeights = <String, Map<String, dynamic>>{};
      
      // ステップ2: 各物体をトリミングしてWeb Detectionで認識
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
          
          // Web Detectionで個別認識（信頼度情報付き）
          debugPrint('  → Web Detectionで認識中...');
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
      throw Exception('Object Detection + Web Detection に失敗しました: $e');
    }
  }

  /// トリミングされた画像から食材を検出
  Future<List<Map<String, dynamic>>> _detectIngredientsFromCroppedImage(
    File tempFile,
    double objectScore,
  ) async {
    final webIngredientsWithScores = await detectWithWebDetectionWithScores(tempFile);
    
    if (webIngredientsWithScores.isEmpty) {
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
    
    debugPrint('  → Web Detection結果: ${webIngredientsWithScores.map((i) => '${i['translated']} (信頼度: ${((i['score'] as double) * 100).toStringAsFixed(0)}%)').join(", ")}');
    return webIngredientsWithScores;
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
}

