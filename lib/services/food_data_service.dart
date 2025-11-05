import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/food_data_model.dart';
import '../models/food_categories_jp_model.dart';

class FoodDataService {
  static FoodData? _cachedData;
  static FoodCategoriesJp? _cachedCategoriesJp;

  static Future<FoodData> loadFoodData() async {
    if (_cachedData != null) {
      return _cachedData!;
    }

    try {
      // メインデータファイルを読み込み
      final String jsonString = await rootBundle.loadString('lib/data/food_data.json');
      final Map<String, dynamic> jsonData = jsonDecode(jsonString);
      
      // 翻訳ファイルが指定されている場合は読み込む
      final translationFile = jsonData['translation_file'] as String?;
      Map<String, String> translations = {};
      
      if (translationFile != null) {
        try {
          final String translationString = await rootBundle.loadString('lib/data/$translationFile');
          final Map<String, dynamic> translationData = jsonDecode(translationString);
          translations = Map<String, String>.from(translationData['translations'] as Map);
        } catch (e) {
          // 翻訳ファイルの読み込みに失敗した場合は既存のtranslationsを使用
          if (jsonData['translations'] != null) {
            translations = Map<String, String>.from(jsonData['translations'] as Map);
          }
        }
      } else if (jsonData['translations'] != null) {
        // 翻訳ファイルが指定されていない場合は、メインファイル内のtranslationsを使用
        translations = Map<String, String>.from(jsonData['translations'] as Map);
      }
      
      // translationsをマージ
      jsonData['translations'] = translations;
      
      _cachedData = FoodData.fromJson(jsonData);
      return _cachedData!;
    } catch (e) {
      throw Exception('食材データの読み込みに失敗しました: $e');
    }
  }

  static Future<FoodCategoriesJp> loadFoodCategoriesJp() async {
    if (_cachedCategoriesJp != null) {
      return _cachedCategoriesJp!;
    }

    try {
      final String jsonString = await rootBundle.loadString('lib/data/food_categories_jp.json');
      final Map<String, dynamic> jsonData = jsonDecode(jsonString);
      _cachedCategoriesJp = FoodCategoriesJp.fromJson(jsonData);
      return _cachedCategoriesJp!;
    } catch (e) {
      throw Exception('日本語カテゴリデータの読み込みに失敗しました: $e');
    }
  }

  static void clearCache() {
    _cachedData = null;
    _cachedCategoriesJp = null;
  }
}

