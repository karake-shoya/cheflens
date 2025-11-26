import 'dart:io';
import '../../models/food_data_model.dart';
import '../../utils/logger.dart';
import '../../exceptions/vision_exception.dart';
import '../vision_api_client.dart';
import '../ingredient_filter.dart';
import '../ingredient_translator.dart';

/// Text Detection用の定数
class TextDetectionConstants {
  static const int minTextLength = 2;
  static const int maxIngredientResults = 5;
}

/// Text Detection APIを使用したテキスト認識サービス
class TextDetectionService {
  final FoodData foodData;
  final IngredientFilter _filter;
  final IngredientTranslator _translator;

  TextDetectionService(this.foodData)
      : _filter = IngredientFilter(foodData),
        _translator = IngredientTranslator(foodData);

  IngredientFilter get filter => _filter;
  IngredientTranslator get translator => _translator;

  /// Text Detection設定を取得（nullの場合はデフォルト値を使用）
  TextDetectionConfig? get _config => foodData.textDetection;

  /// Text Detection APIを使って画像からテキストを検出し、食材名を抽出
  Future<List<String>> detectIngredientsFromText(File imageFile) async {
    try {
      AppLogger.debug('=== Text Detection を開始 ===');

      final data = await VisionApiClient.callTextDetection(imageFile);

      final responses = data['responses'] as List?;
      if (responses == null || responses.isEmpty) {
        throw const TextDetectionException(
          message: 'APIレスポンスが空です',
        );
      }

      final textAnnotations = responses[0]['textAnnotations'] as List?;

      if (textAnnotations == null || textAnnotations.isEmpty) {
        AppLogger.debug('=== Text Detection: テキストが検出されませんでした ===');
        return [];
      }

      // 最初の要素は全テキスト（結合されたテキスト）
      final fullText = textAnnotations[0]['description'] as String?;
      if (fullText == null || fullText.trim().isEmpty) {
        AppLogger.debug('=== Text Detection: テキストが空でした ===');
        return [];
      }

      AppLogger.debug('=== Text Detection 検出テキスト ===');
      AppLogger.debug(fullText);
      AppLogger.debug('=====================================');

      // テキストから最も適切な食材名を1つ抽出
      final ingredient = _extractSingleIngredientFromText(fullText);
      final ingredients = <String>[];
      if (ingredient != null) {
        ingredients.add(ingredient);
      }

      // 個別のテキストブロックも確認（商品名などが単独で書かれている場合）
      if (textAnnotations.length > 1) {
        final processedIndices = <int>{};

        for (int i = 1; i < textAnnotations.length; i++) {
          if (processedIndices.contains(i)) continue;

          final textBlock = textAnnotations[i]['description'] as String?;
          if (textBlock == null ||
              textBlock.trim().length < TextDetectionConstants.minTextLength) {
            continue;
          }

          AppLogger.debug('テキストブロック[$i]: "$textBlock"');

          // 隣接するテキストブロックを結合してチェック（最大3つまで）
          String combinedText = textBlock;
          int endIndex = i;
          for (int j = i + 1;
              j < textAnnotations.length && j <= i + 2;
              j++) {
            final nextBlock = textAnnotations[j]['description'] as String?;
            if (nextBlock != null &&
                nextBlock.trim().length >=
                    TextDetectionConstants.minTextLength) {
              combinedText += ' $nextBlock';
              endIndex = j;
            }
          }

          final blockIngredient = _extractSingleIngredientFromText(combinedText);
          if (blockIngredient != null) {
            final isProductName = _isProductName(blockIngredient);

            final shouldAdd = _shouldAddIngredient(blockIngredient, ingredients);
            if (shouldAdd) {
              ingredients.add(blockIngredient);
              for (int j = i; j <= endIndex; j++) {
                processedIndices.add(j);
              }

              if (isProductName) {
                for (int j = i; j <= endIndex; j++) {
                  for (int k = 1; k <= 10; k++) {
                    if (j - k > 0) processedIndices.add(j - k);
                    if (j + k < textAnnotations.length) {
                      processedIndices.add(j + k);
                    }
                  }
                }
                AppLogger.debug(
                    '商品名「$blockIngredient」が検出されたため、その近くのテキストブロック（前後10個）をスキップします');
              }
            }
          } else {
            AppLogger.debug('テキストブロック[$i]から食材は検出されませんでした');
          }
        }
      }

      AppLogger.debug('=== Text Detection 抽出結果: ${ingredients.join(", ")} ===');
      return ingredients
          .take(TextDetectionConstants.maxIngredientResults)
          .toList();
    } on VisionException {
      rethrow;
    } catch (e) {
      AppLogger.debug('Text Detection エラー: $e');
      throw TextDetectionException(
        message: 'テキスト検出に失敗しました',
        details: e.toString(),
        originalError: e,
      );
    }
  }

  /// テキストから最も適切な食材名を1つ抽出
  String? _extractSingleIngredientFromText(String text) {
    // ステップ1: 商品名パターンから優先的に抽出
    final productIngredient = _extractSingleProductName(text);
    if (productIngredient != null) {
      AppLogger.debug('商品名パターンから抽出: $productIngredient');
      return productIngredient;
    }

    // ステップ2: 商品名が含まれているかチェック
    if (_hasProductName(text)) {
      AppLogger.debug('商品名が含まれているため、他の食材を検出しません: "$text"');
      return null;
    }

    // ステップ3: 日本語テキストから最も適切な食材名を1つ抽出
    final japaneseIngredient = _extractSingleJapaneseIngredient(text);
    if (japaneseIngredient != null) {
      AppLogger.debug('日本語テキストから抽出: $japaneseIngredient');
      return japaneseIngredient;
    }

    // ステップ4: 英語の食材名と照合
    final englishIngredient = _extractSingleEnglishIngredient(text);
    if (englishIngredient != null) {
      AppLogger.debug('英語テキストから抽出: $englishIngredient');
      return englishIngredient;
    }

    return null;
  }

  /// 食材名が商品名パターンかどうかをチェック
  bool _isProductName(String ingredient) {
    final productNames = _config?.productNames ?? _defaultProductNames;
    return productNames.contains(ingredient);
  }

  /// テキストに商品名が含まれているかチェック
  bool _hasProductName(String text) {
    final productKeywords = _config?.productKeywords ?? _defaultProductKeywords;
    for (var keyword in productKeywords) {
      if (text.contains(keyword)) {
        return true;
      }
    }
    return false;
  }

  /// 商品名パターンから最も適切な食材名を1つ抽出
  String? _extractSingleProductName(String text) {
    final patterns = _config?.productPatterns;
    
    if (patterns != null && patterns.isNotEmpty) {
      // JSONから読み込んだパターンを使用
      // 優先度順にソート（低い値が先）
      final sortedPatterns = List<ProductPattern>.from(patterns)
        ..sort((a, b) => a.priority.compareTo(b.priority));
      
      final hasSaba = text.contains('さば') ||
          text.contains('サバ') ||
          text.contains('さば.*水煮') ||
          text.contains('サバ.*水煮');

      for (var patternData in sortedPatterns) {
        final pattern = patternData.toRegExp();
        final ingredient = patternData.ingredient;

        // さばが検出されている場合、かつおは優先度を下げる
        if (hasSaba && ingredient == 'かつお') {
          continue;
        }

        if (pattern.hasMatch(text)) {
          AppLogger.debug(
              '商品名パターンマッチ: "$text" → パターン: ${pattern.pattern}, 食材: $ingredient');
          final englishName = _translator.getEnglishNameFromJapanese(ingredient);
          if (englishName != null && _filter.isFoodRelated(englishName)) {
            return ingredient;
          } else {
            return ingredient;
          }
        }
      }
    } else {
      // デフォルトのハードコードされたパターンを使用（フォールバック）
      return _extractSingleProductNameDefault(text);
    }

    return null;
  }

  /// デフォルトの商品名パターンマッチング（フォールバック用）
  String? _extractSingleProductNameDefault(String text) {
    final productPatterns = [
      {
        'pattern':
            RegExp(r'カレールウ|カレー.*ルウ|curry.*roux', caseSensitive: false),
        'ingredient': 'カレールウ'
      },
      {
        'pattern': RegExp(r'カレー粉|curry.*powder', caseSensitive: false),
        'ingredient': 'カレー粉'
      },
      {
        'pattern':
            RegExp(r'ゴールデンカレー|golden.*curry', caseSensitive: false),
        'ingredient': 'カレールウ'
      },
      {
        'pattern': RegExp(r'カレー', caseSensitive: false),
        'ingredient': 'カレー'
      },
      {
        'pattern': RegExp(r'さば\s*水煮|サバ\s*水煮', caseSensitive: false),
        'ingredient': 'さば水煮'
      },
      {
        'pattern':
            RegExp(r'いわし\s*水煮|イワシ\s*水煮', caseSensitive: false),
        'ingredient': 'いわし'
      },
      {
        'pattern':
            RegExp(r'サンマ\s*水煮|さんま\s*水煮', caseSensitive: false),
        'ingredient': 'サンマ'
      },
      {
        'pattern':
            RegExp(r'まぐろ\s*水煮|マグロ\s*水煮', caseSensitive: false),
        'ingredient': 'マグロ'
      },
      {
        'pattern': RegExp(r'さば\s*味噌|サバ\s*味噌', caseSensitive: false),
        'ingredient': 'さば'
      },
      {
        'pattern': RegExp(r'さば\s*味付|サバ\s*味付', caseSensitive: false),
        'ingredient': 'さば'
      },
      {
        'pattern':
            RegExp(r'産まれた.*たまご|産まれた.*タマゴ', caseSensitive: false),
        'ingredient': '卵'
      },
      {
        'pattern':
            RegExp(r'新鮮.*たまご|新鮮.*タマゴ|新鮮.*玉子', caseSensitive: false),
        'ingredient': '卵'
      },
      {
        'pattern': RegExp(r'たまご|タマゴ|玉子', caseSensitive: false),
        'ingredient': '卵'
      },
      {
        'pattern': RegExp(r'梅干し|梅干', caseSensitive: false),
        'ingredient': '梅干し'
      },
      {'pattern': RegExp(r'納豆', caseSensitive: false), 'ingredient': '納豆'},
      {'pattern': RegExp(r'豆腐', caseSensitive: false), 'ingredient': '豆腐'},
    ];

    final hasSaba = text.contains('さば') ||
        text.contains('サバ') ||
        text.contains('さば.*水煮') ||
        text.contains('サバ.*水煮');

    for (var patternData in productPatterns) {
      final pattern = patternData['pattern'] as RegExp;
      final ingredient = patternData['ingredient'] as String;

      if (hasSaba && ingredient == 'かつお') {
        continue;
      }

      if (pattern.hasMatch(text)) {
        AppLogger.debug(
            '商品名パターンマッチ(デフォルト): "$text" → パターン: ${pattern.pattern}, 食材: $ingredient');
        return ingredient;
      }
    }

    return null;
  }

  /// 日本語テキストから最も適切な食材名を1つ抽出
  String? _extractSingleJapaneseIngredient(String text) {
    final japaneseNames = foodData.translations.values.toSet().toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (var japaneseName in japaneseNames) {
      if (_containsJapaneseFoodName(text, japaneseName)) {
        final englishName =
            _translator.getEnglishNameFromJapanese(japaneseName);
        if (englishName != null && _filter.isFoodRelated(englishName)) {
          return japaneseName;
        }
      }
    }

    final variantIngredients = _extractFromJapaneseVariants(text);
    if (variantIngredients.isNotEmpty) {
      return variantIngredients.first;
    }

    return null;
  }

  /// 英語テキストから最も適切な食材名を1つ抽出
  String? _extractSingleEnglishIngredient(String text) {
    final lowerText = text.toLowerCase();
    final allFoodNames = foodData.getAllFoodNames();

    final sortedFoodNames = List<String>.from(allFoodNames)
      ..sort((a, b) => b.length.compareTo(a.length));

    for (var foodName in sortedFoodNames) {
      final lowerFoodName = foodName.toLowerCase();

      if (_containsFoodName(lowerText, lowerFoodName)) {
        if (_filter.isFoodRelated(foodName)) {
          final translated = _translator.translateToJapanese(foodName);
          return translated;
        }
      }
    }

    return null;
  }

  /// 新しい食材を追加すべきか判定
  bool _shouldAddIngredient(
      String newIngredient, List<String> existingIngredients) {
    if (existingIngredients.contains(newIngredient)) {
      return false;
    }

    for (var existing in existingIngredients) {
      final englishNew = _translator.getEnglishNameFromJapanese(newIngredient);
      final englishExisting = _translator.getEnglishNameFromJapanese(existing);

      if (englishNew != null && englishExisting != null) {
        if (_filter.isSimilarFoodName(englishNew, englishExisting)) {
          final preferred = _filter.getPreferredIngredientFromSimilarPair(
              englishNew, englishExisting);

          if (preferred != null) {
            final preferredIngredient =
                preferred.toLowerCase() == englishNew.toLowerCase()
                    ? newIngredient
                    : existing;
            final nonPreferredIngredient =
                preferred.toLowerCase() == englishNew.toLowerCase()
                    ? existing
                    : newIngredient;

            if (nonPreferredIngredient == newIngredient) {
              AppLogger.debug(
                  '$newIngredientを除外（$existingと類似、類似ペアのprimary: $preferredIngredientを優先）');
              return false;
            } else {
              AppLogger.debug(
                  '$existingを除外（$newIngredientと類似、類似ペアのprimary: $preferredIngredientを優先）');
              existingIngredients.remove(existing);
              return true;
            }
          } else {
            if (newIngredient.length <= existing.length) {
              AppLogger.debug('$newIngredientを除外（$existingと類似、$existingを優先）');
              return false;
            } else {
              AppLogger.debug(
                  '$existingを除外（$newIngredientと類似、$newIngredientを優先）');
              existingIngredients.remove(existing);
              return true;
            }
          }
        }
      }
    }

    return true;
  }

  /// 日本語テキスト内に食材名が含まれているかチェック
  bool _containsJapaneseFoodName(String text, String japaneseName) {
    if (text == japaneseName) return true;

    if (text.contains(japaneseName)) {
      // 誤検出パターンをチェック
      final falsePositivePatterns = _config?.falsePositivePatterns[japaneseName];
      if (falsePositivePatterns != null) {
        for (var patternStr in falsePositivePatterns) {
          final pattern = RegExp(patternStr, caseSensitive: false);
          if (pattern.hasMatch(text)) {
            return false;
          }
        }
      } else if (japaneseName == 'なす') {
        // デフォルトの誤検出パターン（フォールバック）
        final defaultPatterns = [
          RegExp(r'産まれた', caseSensitive: false),
          RegExp(r'産ま', caseSensitive: false),
          RegExp(r'織りなす', caseSensitive: false),
          RegExp(r'織り成す', caseSensitive: false),
          RegExp(r'織.*なす', caseSensitive: false),
        ];

        for (var pattern in defaultPatterns) {
          if (pattern.hasMatch(text)) {
            return false;
          }
        }
      }

      return true;
    }

    return false;
  }

  /// 日本語食材名のバリエーションから食材を抽出
  List<String> _extractFromJapaneseVariants(String text) {
    final ingredients = <String>[];
    final variants = _config?.japaneseVariants;

    if (variants != null && variants.isNotEmpty) {
      // JSONから読み込んだバリエーションを使用
      for (var entry in variants) {
        for (var variant in entry.variants) {
          if (text.contains(variant)) {
            final standardName = entry.standard;
            final englishName =
                _translator.getEnglishNameFromJapanese(standardName);
            if (englishName != null && _filter.isFoodRelated(englishName)) {
              if (!ingredients.contains(standardName)) {
                ingredients.add(standardName);
                AppLogger.debug('バリエーションから抽出: $variant → $standardName');
                return ingredients;
              }
            } else {
              if (!ingredients.contains(standardName)) {
                ingredients.add(standardName);
                AppLogger.debug('バリエーションから抽出（新規）: $variant → $standardName');
                return ingredients;
              }
            }
          }
        }
      }
    } else {
      // デフォルトのバリエーション（フォールバック）
      final defaultVariants = [
        {'variant': 'たまご', 'standard': '卵'},
        {'variant': 'タマゴ', 'standard': '卵'},
        {'variant': '玉子', 'standard': '卵'},
        {'variant': 'さば', 'standard': 'さば'},
        {'variant': 'サバ', 'standard': 'さば'},
        {'variant': 'かつお', 'standard': 'かつお'},
        {'variant': 'カツオ', 'standard': 'かつお'},
        {'variant': '梅干', 'standard': '梅干し'},
        {'variant': '梅干し', 'standard': '梅干し'},
      ];

      for (var entry in defaultVariants) {
        final variant = entry['variant'] as String;
        final standardName = entry['standard'] as String;

        if (text.contains(variant)) {
          final englishName =
              _translator.getEnglishNameFromJapanese(standardName);
          if (englishName != null && _filter.isFoodRelated(englishName)) {
            if (!ingredients.contains(standardName)) {
              ingredients.add(standardName);
              AppLogger.debug('バリエーションから抽出(デフォルト): $variant → $standardName');
              return ingredients;
            }
          } else {
            if (!ingredients.contains(standardName)) {
              ingredients.add(standardName);
              AppLogger.debug(
                  'バリエーションから抽出（デフォルト・新規）: $variant → $standardName');
              return ingredients;
            }
          }
        }
      }
    }

    return ingredients;
  }

  /// テキスト内に食材名が含まれているかチェック
  bool _containsFoodName(String text, String foodName) {
    if (text == foodName) return true;

    final wordBoundaryPattern = RegExp(r'(\b|[^\w])');
    final pattern = RegExp(
        '${wordBoundaryPattern.pattern}${RegExp.escape(foodName)}${wordBoundaryPattern.pattern}',
        caseSensitive: false);
    if (pattern.hasMatch(text)) return true;

    final simplePattern = RegExp(RegExp.escape(foodName), caseSensitive: false);
    if (simplePattern.hasMatch(text)) {
      final excludeKeywords = foodData.filtering.excludeKeywords;
      if (excludeKeywords
          .any((keyword) => text.contains(keyword.toLowerCase()))) {
        return false;
      }
      return true;
    }

    return false;
  }

  // デフォルト値（フォールバック用）
  static const List<String> _defaultProductNames = [
    'カレールウ',
    'カレー粉',
    'カレー',
    'さば水煮',
    'いわし',
    'サンマ',
    'まぐろ',
    '梅干し',
    '納豆',
    '豆腐',
    '卵',
  ];

  static const List<String> _defaultProductKeywords = [
    'カレールウ',
    'カレー粉',
    'ゴールデンカレー',
    'カレー',
    'さば水煮',
    'さば 水煮',
    'サバ水煮',
    'サバ 水煮',
    'いわし水煮',
    'サンマ水煮',
    'まぐろ水煮',
    '梅干し',
    '梅干',
    '納豆',
    '豆腐',
    'たまご',
    'タマゴ',
    '玉子',
  ];
}
