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

        // 結果を統合して食材名を抽出
        final ingredients = <String>[];

        // Best Guess Labelsから食材名を抽出
        if (bestGuessLabels != null) {
          for (var label in bestGuessLabels) {
            final labelText = label['label'] as String;
            // 食材関連のキーワードをフィルタリング
            if (_isFoodRelated(labelText)) {
              final translated = _translateToJapanese(labelText);
              ingredients.add(translated);
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
              if (!ingredients.contains(translated)) {
                ingredients.add(translated);
              }
            }
          }
        }

        debugPrint('=== 抽出された食材: ${ingredients.join(", ")} ===');
        
        return ingredients.take(5).toList();
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
      
      debugPrint('${objects.length}個の物体を検出。各物体をWeb Detectionで個別認識します...');
      
      // 画像を読み込み
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        throw Exception('画像の読み込みに失敗しました');
      }
      
      final allIngredients = <String>[];
      
      // ステップ2: 各物体をトリミングしてWeb Detectionで認識
      for (int i = 0; i < objects.length; i++) {
        final obj = objects[i];
        debugPrint('物体 ${i + 1}/${objects.length}: ${obj.name} (${(obj.score * 100).toStringAsFixed(0)}%)');
        
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
          
          // Label Detectionでも認識（フォールバック）
          if (webIngredients.isEmpty) {
            debugPrint('  → Label Detectionにフォールバック');
            final labelIngredients = await detectIngredients(tempFile);
            debugPrint('  → Label Detection結果: ${labelIngredients.join(", ")}');
            allIngredients.addAll(labelIngredients);
          } else {
            allIngredients.addAll(webIngredients);
          }
          
          // クリーンアップ
          await tempFile.delete();
          await tempDir.delete();
          
        } catch (e) {
          debugPrint('  → エラー: $e');
        }
      }
      
      // 重複を削除
      final uniqueIngredients = allIngredients.toSet().toList();
      
      debugPrint('=== 最終結果: ${uniqueIngredients.join(", ")} ===');
      
      return uniqueIngredients;
      
    } catch (e) {
      throw Exception('Object Detection + Web Detection に失敗しました: $e');
    }
  }
}

