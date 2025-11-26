import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../models/food_data_model.dart';
import '../vision_api_client.dart';
import '../ingredient_filter.dart';
import '../ingredient_translator.dart';

/// Label Detection用の定数
class LabelDetectionConstants {
  static const double categoryConfidenceDiffThreshold = 0.09;
  static const double multipleIngredientsThreshold = 0.05;
  static const int maxLabelDetectionResults = 50;
  static const int maxIngredientResults = 5;
}

/// Label Detection APIを使用した食材認識サービス
class LabelDetectionService {
  final FoodData foodData;
  final IngredientFilter _filter;
  final IngredientTranslator _translator;

  LabelDetectionService(this.foodData)
      : _filter = IngredientFilter(foodData),
        _translator = IngredientTranslator(foodData);

  /// Label Detection APIを使用して食材を検出
  Future<List<String>> detectIngredients(File imageFile) async {
    try {
      final data = await VisionApiClient.callLabelDetection(
        imageFile,
        maxResults: LabelDetectionConstants.maxLabelDetectionResults,
      );

      final labels = data['responses'][0]['labelAnnotations'] as List;

      debugPrint('=== Vision API 検出結果（生データ） ===');
      for (var label in labels) {
        debugPrint('${label['description']} (信頼度: ${label['score']})');
      }
      debugPrint('=====================================');

      // 信頼度でソート（高い順）
      final sortedLabels = List<Map<String, dynamic>>.from(labels)
        ..sort(
            (a, b) => (b['score'] as double).compareTo(a['score'] as double));

      // 信頼度の閾値（JSONデータから取得）
      final confidenceThreshold = foodData.filtering.confidenceThreshold;

      // まず、食材関連のラベルだけを抽出（単一/複数食材判定のため）
      final foodRelatedLabels = sortedLabels
          .where((label) =>
              (label['score'] as double) >= confidenceThreshold &&
              _filter.isFoodRelated(label['description'] as String))
          .toList();

      // 食材関連ラベルの上位2つの信頼度差を確認して、単一食材か複数食材かを判定
      final isMultipleIngredients =
          _determineIfMultipleIngredients(foodRelatedLabels);

      // フィルタリング処理
      final filteredLabels = <Map<String, dynamic>>[];

      for (var label in sortedLabels) {
        final score = label['score'] as double;
        final description = label['description'] as String;

        // 閾値以下は除外
        if (score < confidenceThreshold) continue;

        // 食材関連でなければ除外
        if (!_filter.isFoodRelated(description)) continue;

        // 最初の食材（最も信頼度が高い）
        if (filteredLabels.isEmpty) {
          filteredLabels.add(label);
          continue;
        }

        // すでに採用された食材と比較
        if (_shouldExcludeLabel(
            label, filteredLabels, isMultipleIngredients, confidenceThreshold)) {
          continue;
        }

        filteredLabels.add(label);
      }

      final ingredients = filteredLabels
          .map((label) => label['description'] as String)
          .map((label) => _translator.translateToJapanese(label))
          .toSet()
          .take(LabelDetectionConstants.maxIngredientResults)
          .toList();

      debugPrint('=== フィルタリング後（信頼度$confidenceThreshold以上） ===');
      debugPrint('検出された食材: $ingredients');
      debugPrint('========================================');

      return ingredients;
    } catch (e) {
      throw Exception('食材認識に失敗しました: $e');
    }
  }

  /// 単一食材か複数食材かを判定
  bool _determineIfMultipleIngredients(
      List<Map<String, dynamic>> foodRelatedLabels) {
    if (foodRelatedLabels.length < 2) {
      return false;
    }

    final topScore = foodRelatedLabels[0]['score'] as double;
    final secondScore = foodRelatedLabels[1]['score'] as double;
    final topTwoDiff = topScore - secondScore;

    // 上位2つの差が閾値未満なら複数食材と判定
    final isMultiple =
        topTwoDiff < LabelDetectionConstants.multipleIngredientsThreshold;
    debugPrint(
        '${isMultiple ? "複数" : "単一"}食材モード（食材上位2つの差: ${(topTwoDiff * 100).toStringAsFixed(1)}%）');
    return isMultiple;
  }

  /// ラベルを除外すべきか判定
  bool _shouldExcludeLabel(
    Map<String, dynamic> label,
    List<Map<String, dynamic>> filteredLabels,
    bool isMultipleIngredients,
    double confidenceThreshold,
  ) {
    final score = label['score'] as double;
    final description = label['description'] as String;

    for (var existingLabel in filteredLabels) {
      final existingDesc = existingLabel['description'] as String;
      final existingScore = existingLabel['score'] as double;

      // 1. 食材名が類似しているかチェック
      if (_filter.isSimilarFoodName(description, existingDesc)) {
        debugPrint('除外: $description (信頼度: $score) - $existingDesc と類似');
        return true;
      }

      // 2. 単一食材モードの場合、同じカテゴリで信頼度の差が大きければ除外
      if (!isMultipleIngredients) {
        final currentCategory = foodData.getCategoryOfFood(description);
        final existingCategory = foodData.getCategoryOfFood(existingDesc);

        if (currentCategory != null &&
            currentCategory == existingCategory &&
            (existingScore - score) >=
                LabelDetectionConstants.categoryConfidenceDiffThreshold) {
          debugPrint(
              '除外: $description (信頼度: $score) - $existingDesc (信頼度: $existingScore) と同じ$currentCategoryで信頼度の差が大きい');
          return true;
        }
      }
    }

    return false;
  }
}

