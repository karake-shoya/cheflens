import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/food_categories_jp_model.dart';

class FoodDataService {
  static FoodCategoriesJp? _cachedCategoriesJp;

  static Future<FoodCategoriesJp> loadFoodCategoriesJp() async {
    if (_cachedCategoriesJp != null) return _cachedCategoriesJp!;

    try {
      final jsonString =
          await rootBundle.loadString('assets/data/food_categories_jp.json');
      _cachedCategoriesJp =
          FoodCategoriesJp.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
      return _cachedCategoriesJp!;
    } catch (e) {
      throw Exception('日本語カテゴリデータの読み込みに失敗しました: $e');
    }
  }

  static void clearCache() => _cachedCategoriesJp = null;
}
