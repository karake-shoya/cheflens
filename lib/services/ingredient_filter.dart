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
    return allFoods.any((food) => lowerLabel.contains(food));
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
    
    // 単語に分割して共通する主要な単語があるかチェック
    final words1 = lower1.split(' ').where((w) => w.length > 3).toSet();
    final words2 = lower2.split(' ').where((w) => w.length > 3).toSet();
    
    // 共通する単語があれば類似
    final commonWords = words1.intersection(words2);
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

