import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/food_data_model.dart';
import '../models/food_categories_jp_model.dart';
import '../services/vision_service.dart';
import '../services/ingredient_translator.dart';

/// FoodDataのプロバイダー
/// main.dartでオーバーライドされるため、初期値はnullを返すダミー
final foodDataProvider = Provider<FoodData>((ref) {
  throw UnimplementedError('foodDataProvider must be overridden in main.dart');
});

/// FoodCategoriesJpのプロバイダー
/// main.dartでオーバーライドされるため、初期値はnullを返すダミー
final foodCategoriesJpProvider = Provider<FoodCategoriesJp>((ref) {
  throw UnimplementedError('foodCategoriesJpProvider must be overridden in main.dart');
});

/// VisionServiceのプロバイダー（FoodDataに依存）
final visionServiceProvider = Provider<VisionService>((ref) {
  final foodData = ref.watch(foodDataProvider);
  return VisionService(foodData);
});

/// IngredientTranslatorのプロバイダー（FoodDataに依存）
final ingredientTranslatorProvider = Provider<IngredientTranslator>((ref) {
  final foodData = ref.watch(foodDataProvider);
  return IngredientTranslator(foodData);
});
