import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/food_data_model.dart';

class FoodDataService {
  static FoodData? _cachedData;

  static Future<FoodData> loadFoodData() async {
    if (_cachedData != null) {
      return _cachedData!;
    }

    try {
      final String jsonString = await rootBundle.loadString('lib/data/food_data.json');
      final Map<String, dynamic> jsonData = jsonDecode(jsonString);
      _cachedData = FoodData.fromJson(jsonData);
      return _cachedData!;
    } catch (e) {
      throw Exception('食材データの読み込みに失敗しました: $e');
    }
  }

  static void clearCache() {
    _cachedData = null;
  }
}

