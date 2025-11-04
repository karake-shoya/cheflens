import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import '../models/food_data_model.dart';
import '../models/detected_object.dart';

class VisionService {
  final FoodData foodData;
  
  VisionService(this.foodData);
  
  static String get apiKey => dotenv.env['GOOGLE_VISION_API_KEY'] ?? '';
  static const String _baseUrl =
      'https://vision.googleapis.com/v1/images:annotate';

  Future<List<String>> detectIngredients(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await http.post(
        Uri.parse('$_baseUrl?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requests': [
            {
              'image': {'content': base64Image},
              'features': [
                {'type': 'LABEL_DETECTION', 'maxResults': 50}
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
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
        
        // 同じカテゴリ内での信頼度差の閾値（単一食材モードのみ適用）
        const double categoryConfidenceDiffThreshold = 0.09;  // 9%差以上で除外
        
        // まず、食材関連のラベルだけを抽出（単一/複数食材判定のため）
        final foodRelatedLabels = sortedLabels
            .where((label) => 
                (label['score'] as double) >= confidenceThreshold &&
                _isFoodRelated(label['description'] as String))
            .toList();
        
        // 食材関連ラベルの上位2つの信頼度差を確認して、単一食材か複数食材かを判定
        bool isMultipleIngredients = false;
        if (foodRelatedLabels.length >= 2) {
          final topScore = foodRelatedLabels[0]['score'] as double;
          final secondScore = foodRelatedLabels[1]['score'] as double;
          final topTwoDiff = topScore - secondScore;
          
          // 上位2つの差が5%未満なら複数食材と判定
          if (topTwoDiff < 0.05) {
            isMultipleIngredients = true;
            debugPrint('複数食材モード（食材上位2つの差: ${(topTwoDiff * 100).toStringAsFixed(1)}%）');
          } else {
            debugPrint('単一食材モード（食材上位2つの差: ${(topTwoDiff * 100).toStringAsFixed(1)}%）');
          }
        }
        
        // フィルタリング処理
        final filteredLabels = <Map<String, dynamic>>[];
        
        for (var label in sortedLabels) {
          final score = label['score'] as double;
          final description = label['description'] as String;
          
          // 閾値以下は除外
          if (score < confidenceThreshold) continue;
          
          // 食材関連でなければ除外
          if (!_isFoodRelated(description)) continue;
          
          // 最初の食材（最も信頼度が高い）
          if (filteredLabels.isEmpty) {
            filteredLabels.add(label);
            continue;
          }
          
          // すでに採用された食材と比較
          bool shouldAdd = true;
          
          for (var existingLabel in filteredLabels) {
            final existingDesc = existingLabel['description'] as String;
            final existingScore = existingLabel['score'] as double;
            
            // 1. 食材名が類似しているかチェック
            if (_isSimilarFoodName(description, existingDesc)) {
              // 類似している場合は常に除外（信頼度に関わらず）
              debugPrint('除外: $description (信頼度: $score) - $existingDesc と類似');
              shouldAdd = false;
              break;
            }
            
            // 2. 単一食材モードの場合、同じカテゴリで信頼度の差が大きければ除外
            if (!isMultipleIngredients) {
              final currentCategory = foodData.getCategoryOfFood(description);
              final existingCategory = foodData.getCategoryOfFood(existingDesc);
              
              if (currentCategory != null && 
                  currentCategory == existingCategory &&
                  (existingScore - score) >= categoryConfidenceDiffThreshold) {
                // 同じカテゴリで、既存の方が9%以上高い信頼度を持つ場合は除外
                debugPrint('除外: $description (信頼度: $score) - $existingDesc (信頼度: $existingScore) と同じ$currentCategoryで信頼度の差が大きい');
                shouldAdd = false;
                break;
              }
            }
          }
          
          if (shouldAdd) {
            filteredLabels.add(label);
          }
        }
        
        final ingredients = filteredLabels
            .map((label) => label['description'] as String)
            .map((label) => _translateToJapanese(label))
            .toSet() // 重複を削除
            .take(5) // 最大5つまで
            .toList();

        debugPrint('=== フィルタリング後（信頼度$confidenceThreshold以上） ===');
        debugPrint('検出された食材: $ingredients');
        debugPrint('========================================');

        return ingredients;
      } else {
        throw Exception('Vision API Error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('食材認識に失敗しました: $e');
    }
  }

  bool _isSimilarFoodName(String name1, String name2) {
    final lower1 = name1.toLowerCase();
    final lower2 = name2.toLowerCase();
    
    // 同じ文字列なら類似
    if (lower1 == lower2) return true;
    
    // 一方が他方を含む場合は類似
    if (lower1.contains(lower2) || lower2.contains(lower1)) return true;
    
    // JSONデータから読み込んだ類似ペアをチェック
    for (var pair in foodData.similarPairs) {
      if (pair.contains(name1, name2)) {
        return true;
      }
    }
    
    // 単語に分割して共通する主要な単語があるかチェック
    final words1 = lower1.split(' ').where((w) => w.length > 3).toSet();
    final words2 = lower2.split(' ').where((w) => w.length > 3).toSet();
    
    // 共通する単語があれば類似
    final commonWords = words1.intersection(words2);
    if (commonWords.isNotEmpty) return true;
    
    return false;
  }

  /// 類似ペアから優先すべき食材名を取得（primaryを優先）
  String? _getPreferredIngredientFromSimilarPair(String name1, String name2) {
    final lower1 = name1.toLowerCase();
    final lower2 = name2.toLowerCase();
    
    // JSONデータから読み込んだ類似ペアをチェック
    for (var pair in foodData.similarPairs) {
      if (pair.contains(name1, name2)) {
        final lowerPrimary = pair.primary.toLowerCase();
        // primaryがname1またはname2のどちらかに一致するか、またはそれらの翻訳が一致するかチェック
        if (lower1 == lowerPrimary || lower2 == lowerPrimary) {
          return pair.primary;
        }
        // 翻訳された日本語名から英語名を逆引きしてチェック
        final trans1 = _getEnglishNameFromJapanese(name1);
        final trans2 = _getEnglishNameFromJapanese(name2);
        if (trans1 != null && trans1.toLowerCase() == lowerPrimary) {
          return trans1;
        }
        if (trans2 != null && trans2.toLowerCase() == lowerPrimary) {
          return trans2;
        }
        // primaryが含まれている場合は、primaryを優先
        if (lower1.contains(lowerPrimary)) {
          return name1;
        }
        if (lower2.contains(lowerPrimary)) {
          return name2;
        }
      }
    }
    
    return null;
  }

  bool _isFoodRelated(String label) {
    final lowerLabel = label.toLowerCase();

    // 除外キーワード（JSONデータから取得）
    if (foodData.filtering.excludeKeywords.any((keyword) => lowerLabel.contains(keyword))) {
      return false;
    }

    // 一般的すぎるカテゴリを除外（JSONデータから取得）
    if (foodData.filtering.genericCategories.contains(lowerLabel)) {
      return false;
    }

    // 具体的な食材名が含まれているかチェック（JSONデータから取得）
    final allFoods = foodData.getAllFoodNames();
    return allFoods.any((food) => lowerLabel.contains(food));
  }

  String _translateToJapanese(String englishLabel) {
    final lowerLabel = englishLabel.toLowerCase();
    
    // 完全一致を探す（JSONデータから取得）
    if (foodData.translations.containsKey(lowerLabel)) {
      return foodData.translations[lowerLabel]!;
    }
    
    // 複合語の部分一致を探す（長い方から順に）
    // 例: "rice wine" を "rice" より優先
    final sortedEntries = foodData.translations.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length)); // 長い順
    
    for (final entry in sortedEntries) {
      if (lowerLabel.contains(entry.key)) {
        return entry.value;
      }
    }
    
    // 翻訳が見つからない場合は元の英語を返す
    return englishLabel;
  }

  /// 日本語名から英語名を逆引き（翻訳マップから）
  String? _getEnglishNameFromJapanese(String japaneseName) {
    // 翻訳マップを逆引き
    for (final entry in foodData.translations.entries) {
      if (entry.value == japaneseName) {
        return entry.key;
      }
    }
    return null;
  }

  /// Object Detection APIを使って画像内の物体を検出
  Future<List<DetectedObject>> detectObjects(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await http.post(
        Uri.parse('$_baseUrl?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requests': [
            {
              'image': {'content': base64Image},
              'features': [
                {'type': 'OBJECT_LOCALIZATION', 'maxResults': 20}
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
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
      } else {
        throw Exception('Vision API Error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('物体検出に失敗しました: $e');
    }
  }

  /// Web Detection APIを使って画像から商品名や詳細情報を取得
  Future<List<String>> detectWithWebDetection(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await http.post(
        Uri.parse('$_baseUrl?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requests': [
            {
              'image': {'content': base64Image},
              'features': [
                {'type': 'WEB_DETECTION', 'maxResults': 20}
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // デバッグ: レスポンス全体を確認
        debugPrint('=== Web Detection API レスポンス ===');
        debugPrint(jsonEncode(data));
        debugPrint('=====================================');
        
        final webDetection = data['responses'][0]['webDetection'] as Map<String, dynamic>?;

        if (webDetection == null) {
          debugPrint('=== Web Detection: webDetectionフィールドがありませんでした ===');
          
          // エラーメッセージがあるか確認
          final error = data['responses'][0]['error'];
          if (error != null) {
            debugPrint('エラー: $error');
          }
          
          return [];
        }

        debugPrint('=== Web Detection 検出結果 ===');
        
        // Web Entities（関連するエンティティ）
        final webEntities = webDetection['webEntities'] as List?;
        if (webEntities != null) {
          debugPrint('--- Web Entities ---');
          for (var entity in webEntities) {
            final description = entity['description'] ?? 'N/A';
            final score = entity['score'] ?? 0.0;
            debugPrint('$description (スコア: $score)');
          }
        }

        // Best Guess Labels（推測ラベル）
        final bestGuessLabels = webDetection['bestGuessLabels'] as List?;
        if (bestGuessLabels != null && bestGuessLabels.isNotEmpty) {
          debugPrint('--- Best Guess Labels ---');
          for (var label in bestGuessLabels) {
            debugPrint('${label['label']}');
          }
        }

        // Pages with Matching Images（類似画像があるページ）
        final pagesWithMatchingImages = webDetection['pagesWithMatchingImages'] as List?;
        if (pagesWithMatchingImages != null) {
          debugPrint('--- 類似画像のページ数: ${pagesWithMatchingImages.length} ---');
        }

        debugPrint('=====================================');

        // 結果を統合して食材名を抽出（信頼度と食材名のペア）
        final ingredientCandidates = <Map<String, dynamic>>[];

        // Best Guess Labelsから食材名を抽出（信頼度1.0として扱う）
        if (bestGuessLabels != null) {
          for (var label in bestGuessLabels) {
            final labelText = label['label'] as String;
            // 食材関連のキーワードをフィルタリング
            if (_isFoodRelated(labelText)) {
              ingredientCandidates.add({
                'name': labelText,
                'score': 1.0,
                'translated': _translateToJapanese(labelText),
              });
            }
          }
        }

        // Web Entitiesから食材名を抽出（信頼度0.5以上）
        if (webEntities != null) {
          for (var entity in webEntities) {
            final description = entity['description'] as String?;
            final score = (entity['score'] as num?)?.toDouble() ?? 0.0;
            
            if (description != null && score >= 0.5 && _isFoodRelated(description)) {
              final translated = _translateToJapanese(description);
              // 既に同じ日本語名が追加されていないかチェック
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
        final filteredIngredients = <Map<String, dynamic>>[];
        for (var candidate in ingredientCandidates) {
          final candidateName = candidate['name'] as String;
          final candidateTranslated = candidate['translated'] as String;
          
          bool shouldAdd = true;
          for (var existing in filteredIngredients) {
            final existingName = existing['name'] as String;
            // 英語名または日本語名が類似しているかチェック
            if (_isSimilarFoodName(candidateName, existingName) || 
                candidateTranslated == existing['translated']) {
              // 類似している場合は、信頼度が高い方を優先
              final candidateScore = candidate['score'] as double;
              final existingScore = existing['score'] as double;
              if (candidateScore <= existingScore) {
                debugPrint('除外: $candidateTranslated (信頼度: ${(candidateScore * 100).toStringAsFixed(0)}%) - ${existing['translated']} (信頼度: ${(existingScore * 100).toStringAsFixed(0)}%) と類似');
                shouldAdd = false;
                break;
              } else {
                // 新しい候補の方が信頼度が高い場合は、既存のものを削除
                filteredIngredients.remove(existing);
                break;
              }
            }
          }
          
          if (shouldAdd) {
            filteredIngredients.add(candidate);
          }
        }

        // 最も信頼度の高い食材のみを返す（単一食材モード）
        final result = filteredIngredients
            .map((c) => c['translated'] as String)
            .take(1) // 最も信頼度の高い1つだけ
            .toList();

        debugPrint('=== 抽出された食材: ${ingredientCandidates.map((c) => '${c['translated']} (${(c['score'] * 100).toStringAsFixed(0)}%)').join(", ")} ===');
        debugPrint('=== フィルタリング後: ${result.join(", ")} ===');
        
        return result;
      } else {
        throw Exception('Vision API Error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Web検出に失敗しました: $e');
    }
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
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        throw Exception('画像の読み込みに失敗しました');
      }
      
      // 各物体から検出された食材と、その物体の信頼度を記録
      final ingredientWeights = <String, Map<String, dynamic>>{};
      
      // ステップ2: 各物体をトリミングしてWeb Detectionで認識
      for (int i = 0; i < filteredObjects.length; i++) {
        final obj = filteredObjects[i];
        final objectScore = obj.score; // Object Detectionの信頼度
        debugPrint('物体 ${i + 1}/${filteredObjects.length}: ${obj.name} (${(obj.score * 100).toStringAsFixed(0)}%)');
        
        try {
          // トリミング座標を計算（normalized coordinates: 0.0-1.0）
          final box = obj.boundingBox;
          final x1 = (box.vertices[0].x * image.width).round().clamp(0, image.width);
          final y1 = (box.vertices[0].y * image.height).round().clamp(0, image.height);
          final x2 = (box.vertices[2].x * image.width).round().clamp(0, image.width);
          final y2 = (box.vertices[2].y * image.height).round().clamp(0, image.height);
          
          final width = (x2 - x1).clamp(1, image.width);
          final height = (y2 - y1).clamp(1, image.height);
          
          if (width <= 0 || height <= 0) {
            debugPrint('  → スキップ（サイズが無効）');
            continue;
          }
          
          // 最小サイズチェック
          final minCropSize = foodData.filtering.minCropSize;
          if (width < minCropSize || height < minCropSize) {
            debugPrint('  → スキップ（サイズが小さすぎる: ${width}x${height}px < ${minCropSize}x${minCropSize}px）');
            continue;
          }
          
          // トリミング
          final croppedImage = img.copyCrop(image, x: x1, y: y1, width: width, height: height);
          
          // 一時ファイルに保存
          final tempDir = await Directory.systemTemp.createTemp('cheflens_crop');
          final tempFile = File('${tempDir.path}/crop_$i.jpg');
          await tempFile.writeAsBytes(img.encodeJpg(croppedImage));
          
          // Web Detectionで個別認識
          debugPrint('  → Web Detectionで認識中...');
          final webIngredients = await detectWithWebDetection(tempFile);
          debugPrint('  → Web Detection結果: ${webIngredients.join(", ")}');
          
          // 検出された食材を重み付けデータに追加
          List<String> detectedIngredients;
          if (webIngredients.isEmpty) {
            debugPrint('  → Label Detectionにフォールバック');
            final labelIngredients = await detectIngredients(tempFile);
            debugPrint('  → Label Detection結果: ${labelIngredients.join(", ")}');
            detectedIngredients = labelIngredients;
          } else {
            detectedIngredients = webIngredients;
          }
          
          // 各食材の重み付けデータを更新
          for (var ingredient in detectedIngredients) {
            if (ingredientWeights.containsKey(ingredient)) {
              // 既に存在する場合は、検出回数を増やし、最大信頼度を更新
              final weight = ingredientWeights[ingredient]!;
              weight['count'] = (weight['count'] as int) + 1;
              if (objectScore > (weight['maxObjectScore'] as double)) {
                weight['maxObjectScore'] = objectScore;
              }
            } else {
              // 新規の場合は、初期データを作成
              ingredientWeights[ingredient] = {
                'name': ingredient,
                'count': 1,
                'maxObjectScore': objectScore,
              };
            }
          }
          
          // クリーンアップ
          await tempFile.delete();
          await tempDir.delete();
          
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
        for (var existingName in mergedIngredients.keys) {
          final englishName1 = _getEnglishNameFromJapanese(ingredientName);
          final englishName2 = _getEnglishNameFromJapanese(existingName);
          
          if (ingredientName == existingName) {
            // 同じ食材の場合は、重み付けデータを統合
            final existingWeight = mergedIngredients[existingName]!;
            existingWeight['count'] = (existingWeight['count'] as int) + (ingredient['count'] as int);
            if ((ingredient['maxObjectScore'] as double) > (existingWeight['maxObjectScore'] as double)) {
              existingWeight['maxObjectScore'] = ingredient['maxObjectScore'];
            }
            shouldAdd = false;
            break;
          } else if (englishName1 != null && englishName2 != null && _isSimilarFoodName(englishName1, englishName2)) {
            // 類似食材の場合は、類似ペアのprimaryを優先し、次に検出回数が多い方を優先
            final existingWeight = mergedIngredients[existingName]!;
            final existingCount = existingWeight['count'] as int;
            final currentCount = ingredient['count'] as int;
            
            // 類似ペアから優先すべき食材を取得
            final preferred = _getPreferredIngredientFromSimilarPair(englishName1, englishName2);
            String? preferredName;
            String? nonPreferredName;
            
            if (preferred != null) {
              // primaryが存在する場合は、primaryを優先
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
                shouldAdd = false;
                break;
              } else {
                // 既存の方を置き換え
                debugPrint('類似食材を置き換え: $existingName → $ingredientName (類似ペアのprimary: $preferredName を優先)');
                similarIngredient = existingName;
                break;
              }
            } else {
              // primaryが存在しない場合は、検出回数が多い方を優先
              if (currentCount > existingCount) {
                // 新しい食材の方が検出回数が多い場合は、既存を置き換え
                similarIngredient = existingName;
                break;
              } else {
                // 既存の方が多い場合は、スキップ
                debugPrint('最終結果から除外: $ingredientName ($currentCount回) - $existingName ($existingCount回) と類似');
                shouldAdd = false;
                break;
              }
            }
          }
        }
        
        if (shouldAdd) {
          if (similarIngredient != null) {
            // 類似食材を置き換え
            debugPrint('類似食材を置き換え: $similarIngredient → $ingredientName');
            mergedIngredients.remove(similarIngredient);
          }
          mergedIngredients[ingredientName] = Map<String, dynamic>.from(ingredient);
        }
      }
      
      // 重み付けスコアでソート（検出回数 × 最大信頼度）
      final sortedIngredients = mergedIngredients.values.toList()
        ..sort((a, b) {
          final countA = a['count'] as int;
          final countB = b['count'] as int;
          final scoreA = a['maxObjectScore'] as double;
          final scoreB = b['maxObjectScore'] as double;
          
          // 検出回数が多い方を優先
          if (countA != countB) {
            return countB.compareTo(countA);
          }
          // 検出回数が同じ場合は、信頼度が高い方を優先
          return scoreB.compareTo(scoreA);
        });
      
      final result = sortedIngredients
          .map((ingredient) => ingredient['name'] as String)
          .toList();
      
      debugPrint('=== 最終結果（${ingredientList.length}個 → ${result.length}個）: ${result.join(", ")} ===');
      debugPrint('=== 重み付け詳細 ===');
      for (var ingredient in sortedIngredients) {
        debugPrint('  ${ingredient['name']}: 検出${ingredient['count']}回, 最大信頼度${((ingredient['maxObjectScore'] as double) * 100).toStringAsFixed(0)}%');
      }
      
      return result;
      
    } catch (e) {
      throw Exception('Object Detection + Web Detection に失敗しました: $e');
    }
  }
}

