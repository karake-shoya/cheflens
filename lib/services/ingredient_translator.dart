import '../models/food_data_model.dart';

/// 食材名の翻訳を担当するクラス
class IngredientTranslator {
  final FoodData foodData;

  IngredientTranslator(this.foodData);

  /// 英語名を日本語に翻訳
  String translateToJapanese(String englishLabel) {
    final lowerLabel = englishLabel.toLowerCase();
    
    // 完全一致を探す
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

  /// 日本語名から英語名を逆引き
  String? getEnglishNameFromJapanese(String japaneseName) {
    // 翻訳マップを逆引き
    for (final entry in foodData.translations.entries) {
      if (entry.value == japaneseName) {
        return entry.key;
      }
    }
    return null;
  }
}

