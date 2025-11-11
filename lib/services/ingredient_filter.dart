import '../models/food_data_model.dart';

/// 食材フィルタリングロジックを担当するクラス
class IngredientFilter {
  final FoodData foodData;

  IngredientFilter(this.foodData);

  /// 食材関連かどうかを判定
  bool isFoodRelated(String label) {
    final lowerLabel = label.toLowerCase();

    // 除外キーワードチェック
    if (foodData.filtering.excludeKeywords.any((keyword) => lowerLabel.contains(keyword))) {
      return false;
    }

    // 一般的すぎるカテゴリを除外
    if (foodData.filtering.genericCategories.contains(lowerLabel)) {
      return false;
    }

    // 具体的な食材名が含まれているかチェック
    final allFoods = foodData.getAllFoodNames();
    
    // まず、ラベル全体が食材名に含まれているかチェック
    if (allFoods.any((food) => lowerLabel.contains(food))) {
      return true;
    }
    
    // 複合語（例：「radish salad」）から最初の単語を抽出してチェック
    final words = lowerLabel.split(RegExp(r'[\s\-_]+'));
    if (words.isNotEmpty) {
      final firstWord = words[0];
      // 最初の単語が食材名に含まれているかチェック
      if (allFoods.any((food) => firstWord.contains(food) || food.contains(firstWord))) {
        return true;
      }
    }
    
    return false;
  }

  /// 2つの食材名が類似しているか判定
  bool isSimilarFoodName(String name1, String name2) {
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
    
    // 複合語の場合、最初の単語（食材名）を比較
    final words1 = lower1.split(RegExp(r'[\s\-_]+'));
    final words2 = lower2.split(RegExp(r'[\s\-_]+'));
    
    if (words1.isNotEmpty && words2.isNotEmpty) {
      final firstWord1 = words1[0];
      final firstWord2 = words2[0];
      
      // 最初の単語が食材名リストに含まれている場合、最初の単語を比較
      final allFoods = foodData.getAllFoodNames();
      final isFirstWord1Food = allFoods.any((food) => firstWord1.contains(food.toLowerCase()) || food.toLowerCase().contains(firstWord1));
      final isFirstWord2Food = allFoods.any((food) => firstWord2.contains(food.toLowerCase()) || food.toLowerCase().contains(firstWord2));
      
      if (isFirstWord1Food && isFirstWord2Food) {
        // 両方の最初の単語が食材名の場合、最初の単語を比較
        if (firstWord1 == firstWord2) return true;
        if (firstWord1.contains(firstWord2) || firstWord2.contains(firstWord1)) return true;
        // 最初の単語が異なる場合は類似ではない
        return false;
      }
    }
    
    // 単語に分割して共通する主要な単語があるかチェック（一般的な単語を除外）
    final excludeWords = {'salad', 'soup', 'dish', 'meal', 'recipe', 'cooking', 'food'};
    final words1Filtered = lower1.split(' ').where((w) => w.length > 3 && !excludeWords.contains(w)).toSet();
    final words2Filtered = lower2.split(' ').where((w) => w.length > 3 && !excludeWords.contains(w)).toSet();
    
    // 共通する単語があれば類似
    final commonWords = words1Filtered.intersection(words2Filtered);
    if (commonWords.isNotEmpty) return true;
    
    return false;
  }

  /// 類似ペアから優先すべき食材名を取得（primaryを優先）
  String? getPreferredIngredientFromSimilarPair(String name1, String name2) {
    final lower1 = name1.toLowerCase();
    final lower2 = name2.toLowerCase();
    
    // JSONデータから読み込んだ類似ペアをチェック
    for (var pair in foodData.similarPairs) {
      if (pair.contains(name1, name2)) {
        final lowerPrimary = pair.primary.toLowerCase();
        // primaryがname1またはname2のどちらかに一致するかチェック
        if (lower1 == lowerPrimary || lower2 == lowerPrimary) {
          return pair.primary;
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
}

