import 'dart:io';
import '../../models/food_data_model.dart';
import '../../utils/logger.dart';
import '../../exceptions/vision_exception.dart';
import '../vision_api_client.dart';
import '../ingredient_filter.dart';
import '../ingredient_translator.dart';

/// Web Detection用の定数
class WebDetectionConstants {
  static const double webDetectionScoreThreshold = 0.35;
  static const int maxWebDetectionResults = 20;
}

/// Web Detection APIを使用した商品認識サービス
class WebDetectionService {
  final FoodData foodData;
  final IngredientFilter _filter;
  final IngredientTranslator _translator;

  WebDetectionService(this.foodData)
      : _filter = IngredientFilter(foodData),
        _translator = IngredientTranslator(foodData);

  /// Web Detection APIを使って画像から商品名や詳細情報を取得（信頼度情報付き）
  Future<List<Map<String, dynamic>>> detectWithScores(File imageFile) async {
    try {
      final data = await VisionApiClient.callWebDetection(
        imageFile,
        maxResults: WebDetectionConstants.maxWebDetectionResults,
      );

      final responses = data['responses'] as List?;
      if (responses == null || responses.isEmpty) {
        throw const WebDetectionException(
          message: 'APIレスポンスが空です',
        );
      }

      final webDetection =
          responses[0]['webDetection'] as Map<String, dynamic>?;

      if (webDetection == null) {
        AppLogger.debug(
            '=== Web Detection: webDetectionフィールドがありませんでした ===');

        final error = responses[0]['error'];
        if (error != null) {
          AppLogger.debug('エラー: $error');
          throw WebDetectionException(
            message: 'Web Detection APIエラー',
            details: error.toString(),
          );
        }

        return [];
      }

      _logWebDetectionResults(webDetection);
      return _processWebDetectionResults(webDetection);
    } on VisionException {
      rethrow;
    } catch (e) {
      throw WebDetectionException(
        message: 'Web検出に失敗しました',
        details: e.toString(),
        originalError: e,
      );
    }
  }

  /// Web Detection APIを使って画像から商品名や詳細情報を取得
  Future<List<String>> detect(File imageFile) async {
    try {
      final ingredientsWithScores = await detectWithScores(imageFile);
      return ingredientsWithScores
          .map((c) => c['translated'] as String)
          .take(1)
          .toList();
    } on VisionException {
      rethrow;
    } catch (e) {
      throw WebDetectionException(
        message: 'Web検出に失敗しました',
        details: e.toString(),
        originalError: e,
      );
    }
  }

  /// Web Detection結果を処理して食材候補を抽出
  List<Map<String, dynamic>> _processWebDetectionResults(
      Map<String, dynamic> webDetection) {
    final ingredientCandidates = <Map<String, dynamic>>[];

    // Best Guess Labelsから食材名を抽出（信頼度1.0として扱う）
    final bestGuessLabels = webDetection['bestGuessLabels'] as List?;
    if (bestGuessLabels != null) {
      for (var label in bestGuessLabels) {
        final labelText = label['label'] as String;

        // 多言語や一般的な表現を除外
        if (_shouldExcludeBestGuessLabel(labelText)) {
          AppLogger.debug(
              'Best Guess Labelを除外: "$labelText" (一般的な表現または多言語)');
          continue;
        }

        if (_filter.isFoodRelated(labelText)) {
          ingredientCandidates.add({
            'name': labelText,
            'score': 1.0,
            'translated': _translator.translateToJapanese(labelText),
          });
        }
      }
    }

    // Web Entitiesから食材名を抽出（信頼度閾値以上）
    final webEntities = webDetection['webEntities'] as List?;
    if (webEntities != null) {
      for (var entity in webEntities) {
        final description = entity['description'] as String?;
        final score = (entity['score'] as num?)?.toDouble() ?? 0.0;

        if (description != null &&
            score >= WebDetectionConstants.webDetectionScoreThreshold) {
          if (!_filter.isFoodRelated(description)) {
            AppLogger.debug(
                'Web Entityを除外: "$description" (スコア: ${(score * 100).toStringAsFixed(1)}%) - 食材関連でない');
            continue;
          }

          final translated = _translator.translateToJapanese(description);
          if (!ingredientCandidates.any((c) => c['translated'] == translated)) {
            ingredientCandidates.add({
              'name': description,
              'score': score,
              'translated': translated,
            });
            AppLogger.debug(
                'Web Entityを追加: "$description" → "$translated" (スコア: ${(score * 100).toStringAsFixed(1)}%)');
          } else {
            AppLogger.debug(
                'Web Entityをスキップ: "$description" → "$translated" (既に追加済み)');
          }
        }
      }
    }

    // 信頼度順にソート（高い順）
    ingredientCandidates
        .sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));

    // 類似食材をフィルタリング（信頼度が高い方を優先）
    return _filterSimilarIngredients(ingredientCandidates);
  }

  /// Best Guess Labelを除外すべきか判定
  bool _shouldExcludeBestGuessLabel(String labelText) {
    final lowerLabel = labelText.toLowerCase();

    // JSONから読み込んだパターンを使用
    final genericPatterns = foodData.filtering.genericPatterns;
    final genericKeywords = foodData.filtering.genericKeywords;

    // パターンマッチング
    if (genericPatterns.isNotEmpty) {
      for (var patternStr in genericPatterns) {
        if (RegExp(patternStr, caseSensitive: false).hasMatch(lowerLabel)) {
          return true;
        }
      }
    } else {
      // デフォルトのパターン（フォールバック）
      final defaultPatterns = [
        r'^vegetable',
        r'^fruit',
        r'^food',
        r'^ingredient',
        r'^produce',
        r'^grocery',
        r'^kitchen',
        r'^refrigerator',
        r'^fridge',
        r'^storage',
        r'^container',
        r'^salad',
        r'^meal',
        r'^dish',
        r'^recipe',
        r'^cooking',
        r'^diet',
        r'^nutrition',
        r'^healthy',
        r'^organic',
        r'^fresh',
        r'^superfood',
        r'^plant',
        r'^legume',
        r'^cruciferous',
        r'.*\s+in\s+.*',
        r'.*\s+on\s+.*',
        r'.*\s+with\s+.*',
        r'.*\s+and\s+.*',
      ];

      for (var pattern in defaultPatterns) {
        if (RegExp(pattern, caseSensitive: false).hasMatch(lowerLabel)) {
          return true;
        }
      }
    }

    // 一般的なキーワードをチェック
    final keywords = genericKeywords.isNotEmpty
        ? genericKeywords
        : _defaultGenericKeywords;

    final hasGenericKeyword =
        keywords.any((keyword) => lowerLabel.contains(keyword.toLowerCase()));

    final allFoods = foodData.getAllFoodNames();
    final hasSpecificFoodName = allFoods.any(
        (food) => lowerLabel.contains(food.toLowerCase()) && food.length > 3);

    if (labelText.contains(' ') && hasGenericKeyword && !hasSpecificFoodName) {
      return true;
    }

    final japanesePattern =
        RegExp(r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FAF]');
    final hasJapanese = japanesePattern.hasMatch(labelText);

    if (!hasJapanese) {
      final nonAsciiPattern = RegExp(r'[^\x00-\x7F]');
      final nonAsciiCount = nonAsciiPattern.allMatches(labelText).length;
      if (labelText.isNotEmpty && nonAsciiCount / labelText.length > 0.3) {
        return true;
      }
    }

    if (hasGenericKeyword && !hasSpecificFoodName) {
      return true;
    }

    return false;
  }

  /// Web Detection結果をログ出力
  void _logWebDetectionResults(Map<String, dynamic> webDetection) {
    AppLogger.debug('=== Web Detection 検出結果 ===');

    final webEntities = webDetection['webEntities'] as List?;
    if (webEntities != null) {
      AppLogger.debug('--- Web Entities ---');
      for (var entity in webEntities) {
        final description = entity['description'] ?? 'N/A';
        final score = entity['score'] ?? 0.0;
        AppLogger.debug('$description (スコア: $score)');
      }
    }

    final bestGuessLabels = webDetection['bestGuessLabels'] as List?;
    if (bestGuessLabels != null && bestGuessLabels.isNotEmpty) {
      AppLogger.debug('--- Best Guess Labels ---');
      for (var label in bestGuessLabels) {
        AppLogger.debug('${label['label']}');
      }
    }

    final pagesWithMatchingImages =
        webDetection['pagesWithMatchingImages'] as List?;
    if (pagesWithMatchingImages != null) {
      AppLogger.debug('--- 類似画像のページ数: ${pagesWithMatchingImages.length} ---');
    }

    AppLogger.debug('=====================================');
  }

  /// 類似食材をフィルタリング（信頼度が高い方を優先）
  List<Map<String, dynamic>> _filterSimilarIngredients(
    List<Map<String, dynamic>> ingredientCandidates,
  ) {
    final filteredIngredients = <Map<String, dynamic>>[];
    for (var candidate in ingredientCandidates) {
      final candidateName = candidate['name'] as String;
      final candidateTranslated = candidate['translated'] as String;
      final candidateScore = candidate['score'] as double;

      bool shouldAdd = true;
      for (var existing in filteredIngredients) {
        final existingName = existing['name'] as String;
        final existingTranslated = existing['translated'] as String;
        final existingScore = existing['score'] as double;

        // 翻訳後の名前が同じ場合は除外
        if (candidateTranslated == existingTranslated) {
          AppLogger.debug(
              '類似食材フィルタリング: "$candidateName" → "$candidateTranslated" を除外（$existingName → $existingTranslated と重複）');
          shouldAdd = false;
          break;
        }

        // 類似食材チェック
        if (_filter.isSimilarFoodName(candidateName, existingName)) {
          if (candidateScore <= existingScore) {
            AppLogger.debug(
                '類似食材フィルタリング: "$candidateName" → "$candidateTranslated" (スコア: ${(candidateScore * 100).toStringAsFixed(1)}%) を除外（$existingName → $existingTranslated (スコア: ${(existingScore * 100).toStringAsFixed(1)}%) と類似、信頼度が低い）');
            shouldAdd = false;
            break;
          } else {
            AppLogger.debug(
                '類似食材フィルタリング: "$existingName" → "$existingTranslated" (スコア: ${(existingScore * 100).toStringAsFixed(1)}%) を除外（$candidateName → $candidateTranslated (スコア: ${(candidateScore * 100).toStringAsFixed(1)}%) と類似、信頼度が低い）');
            filteredIngredients.remove(existing);
            break;
          }
        }
      }

      if (shouldAdd) {
        filteredIngredients.add(candidate);
        AppLogger.debug(
            '類似食材フィルタリング: "$candidateName" → "$candidateTranslated" (スコア: ${(candidateScore * 100).toStringAsFixed(1)}%) を追加');
      }
    }

    return filteredIngredients;
  }

  // デフォルトの一般的なキーワード（フォールバック用）
  static const List<String> _defaultGenericKeywords = [
    'vegetable',
    'fruit',
    'food',
    'ingredient',
    'produce',
    'grocery',
    'kitchen',
    'refrigerator',
    'fridge',
    'storage',
    'container',
    'salad',
    'meal',
    'dish',
    'recipe',
    'cooking',
    'diet',
    'nutrition',
    'healthy',
    'organic',
    'fresh',
    'superfood',
    'plant',
    'legume',
    'cruciferous',
    'sayuran',
    'kulkas',
  ];
}
