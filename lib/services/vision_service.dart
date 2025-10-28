import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/food_data_model.dart';

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
                {'type': 'LABEL_DETECTION', 'maxResults': 20}
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
            
            // 食材名が類似しているかチェック
            if (_isSimilarFoodName(description, existingDesc)) {
              // 類似している場合は常に除外（信頼度に関わらず）
              debugPrint('除外: $description (信頼度: $score) - $existingDesc と類似');
              shouldAdd = false;
              break;
            }
            // 類似していない場合は、信頼度に関わらず別の食材として扱う
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
    
    // 部分一致を探す
    for (final entry in foodData.translations.entries) {
      if (lowerLabel.contains(entry.key)) {
        return entry.value;
      }
    }
    
    // 翻訳が見つからない場合は元の英語を返す
    return englishLabel;
  }
}

