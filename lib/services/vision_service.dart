import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class VisionService {
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

        // 信頼度の閾値と差分設定
        const double confidenceThreshold = 0.70;  // 70%以上
        const double confidenceDiffThreshold = 0.05;  // 5%差以内は除外
        
        // フィルタリング処理
        final filteredLabels = <Map<String, dynamic>>[];
        double? highestScore;
        
        for (var label in sortedLabels) {
          final score = label['score'] as double;
          final description = label['description'] as String;
          
          // 閾値以下は除外
          if (score < confidenceThreshold) continue;
          
          // 食材関連でなければ除外
          if (!_isFoodRelated(description)) continue;
          
          // 最初の食材（最も信頼度が高い）
          if (highestScore == null) {
            filteredLabels.add(label);
            highestScore = score;
            continue;
          }
          
          // 最高信頼度との差が5%以内なら除外（似た食材として扱う）
          if ((highestScore - score) <= confidenceDiffThreshold) {
            debugPrint('除外: $description (信頼度: $score) - 上位の食材に近すぎる');
            continue;
          }
          
          // 信頼度の差が5%より大きければ、別の食材として追加
          filteredLabels.add(label);
          highestScore = score;  // 次の比較基準を更新
        }
        
        final ingredients = filteredLabels
            .map((label) => label['description'] as String)
            .map((label) => _translateToJapanese(label))
            .toSet() // 重複を削除
            .take(5) // 最大5つまで
            .toList();

        debugPrint('=== フィルタリング後（信頼度$confidenceThreshold以上、差分$confidenceDiffThreshold考慮） ===');
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

  bool _isFoodRelated(String label) {
    final lowerLabel = label.toLowerCase();

    // 除外キーワード（冷蔵庫、容器、家電など）
    final excludeKeywords = [
      'refrigerator',
      'appliance',
      'container',
      'plastic',
      'storage',
      'kitchen',
      'home',
      'shelf',
      'drawer',
      'door',
      'photography',
      'stock',
      'close-up',
      'still life',
      'red',  // 色は除外
      'green',
      'yellow',
      'blue',
      'purple',
      'white',
      'black',
    ];

    // 除外キーワードが含まれていたらfalse
    if (excludeKeywords.any((keyword) => lowerLabel.contains(keyword))) {
      return false;
    }

    // 一般的すぎるカテゴリを除外（具体的な名前だけ残す）
    final genericCategories = [
      'food',
      'fruit',
      'vegetable',
      'produce',
      'ingredient',
      'natural foods',
      'staple food',
      'superfood',
      'seedless fruit',
      'cuisine',
      'dish',
      'dairy',
      'beverage',
      'drink',
      'meat',
      'fish',
    ];

    // 一般的なカテゴリは除外
    if (genericCategories.contains(lowerLabel)) {
      return false;
    }

    // 具体的な食材名のリスト
    final specificFoods = [
      'apple',
      'tomato',
      'carrot',
      'onion',
      'potato',
      'lettuce',
      'romaine lettuce',
      'iceberg lettuce',
      'leaf lettuce',
      'cabbage',
      'chinese cabbage',
      'napa cabbage',
      'wild cabbage',
      'banana',
      'orange',
      'grape',
      'strawberry',
      'broccoli',
      'spinach',
      'pepper',
      'cucumber',
      'beef',
      'pork',
      'chicken',
      'salmon',
      'tuna',
      'egg',
      'cheese',
      'milk',
      'yogurt',
      'butter',
      'bread',
      'rice',
      'noodle',
      'sauce',
      'condiment',
      'watermelon',
      'melon',
      'lemon',
      'lime',
      'peach',
      'pear',
      'cherry',
      'kiwi',
      'mango',
      'pineapple',
      'avocado',
      'mushroom',
      'garlic',
      'ginger',
      'celery',
      'radish',
      'daikon',
      'eggplant',
      'zucchini',
      'corn',
      'peas',
      'beans',
      'tofu',
      'soy',
      'kale',
    ];

    // 具体的な食材名が含まれているかチェック
    return specificFoods.any((food) => lowerLabel.contains(food));
  }

  String _translateToJapanese(String englishLabel) {
    final translations = {
      // 野菜
      'tomato': 'トマト',
      'carrot': 'にんじん',
      'onion': '玉ねぎ',
      'potato': 'じゃがいも',
      'cucumber': 'きゅうり',
      'lettuce': 'レタス',
      'romaine lettuce': 'ロメインレタス',
      'iceberg lettuce': 'アイスバーグレタス',
      'leaf lettuce': 'リーフレタス',
      'cabbage': 'キャベツ',
      'chinese cabbage': '白菜',
      'napa cabbage': '白菜',
      'wild cabbage': 'ケール',
      'kale': 'ケール',
      'broccoli': 'ブロッコリー',
      'spinach': 'ほうれん草',
      'pepper': 'ピーマン',
      'eggplant': 'なす',
      'radish': '大根',
      'daikon': '大根',
      'celery': 'セロリ',
      'zucchini': 'ズッキーニ',
      'corn': 'とうもろこし',
      'peas': 'えんどう豆',
      'beans': '豆',
      'mushroom': 'きのこ',
      'garlic': 'にんにく',
      'ginger': 'しょうが',
      'avocado': 'アボカド',
      
      // 果物
      'apple': 'りんご',
      'apples': 'りんご',
      'mcintosh': 'マッキントッシュ',
      'banana': 'バナナ',
      'orange': 'オレンジ',
      'grape': 'ぶどう',
      'grapes': 'ぶどう',
      'strawberry': 'いちご',
      'watermelon': 'スイカ',
      'melon': 'メロン',
      'lemon': 'レモン',
      'lime': 'ライム',
      'peach': '桃',
      'pear': '梨',
      'cherry': 'さくらんぼ',
      'kiwi': 'キウイ',
      'mango': 'マンゴー',
      'pineapple': 'パイナップル',
      
      // 肉・魚
      'beef': '牛肉',
      'pork': '豚肉',
      'chicken': '鶏肉',
      'salmon': 'サーモン',
      'tuna': 'マグロ',
      
      // 乳製品
      'milk': '牛乳',
      'cheese': 'チーズ',
      'butter': 'バター',
      'yogurt': 'ヨーグルト',
      'egg': '卵',
      'eggs': '卵',
      
      // 飲料
      'juice': 'ジュース',
      'water': '水',
      
      // その他
      'bread': 'パン',
      'rice': 'ご飯',
      'noodle': '麺',
      'sauce': 'ソース',
      'condiment': '調味料',
      'tofu': '豆腐',
      'soy': '大豆',
      
      // 色（品種名の一部として）
      'red': '赤',
      'green': '緑',
      'yellow': '黄色',
    };

    final lowerLabel = englishLabel.toLowerCase();
    
    // 完全一致を探す
    if (translations.containsKey(lowerLabel)) {
      return translations[lowerLabel]!;
    }
    
    // 部分一致を探す
    for (final entry in translations.entries) {
      if (lowerLabel.contains(entry.key)) {
        return entry.value;
      }
    }
    
    // 翻訳が見つからない場合は元の英語を返す（英語のまま）
    return englishLabel;
  }
}

