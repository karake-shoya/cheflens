import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/food_data_model.dart';
import '../models/food_categories_jp_model.dart';
import '../services/food_data_service.dart';
import '../services/vision_service.dart';
import '../services/ingredient_translator.dart';

/// FoodDataの非同期プロバイダー
final foodDataProvider = FutureProvider<FoodData>((ref) async {
  return await FoodDataService.loadFoodData();
});

/// FoodCategoriesJpの非同期プロバイダー
final foodCategoriesJpProvider = FutureProvider<FoodCategoriesJp>((ref) async {
  return await FoodDataService.loadFoodCategoriesJp();
});

/// VisionServiceのプロバイダー（FoodDataに依存）
final visionServiceProvider = FutureProvider<VisionService>((ref) async {
  final foodData = await ref.watch(foodDataProvider.future);
  return VisionService(foodData);
});

/// IngredientTranslatorのプロバイダー（FoodDataに依存）
final ingredientTranslatorProvider = FutureProvider<IngredientTranslator>((ref) async {
  final foodData = await ref.watch(foodDataProvider.future);
  return IngredientTranslator(foodData);
});

