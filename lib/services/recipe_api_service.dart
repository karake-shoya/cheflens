import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../config/app_config.dart';
import '../exceptions/vision_exception.dart';
import '../models/selected_ingredient.dart';

/// レシピ候補の情報を保持するクラス
class RecipeCandidate {
  final String title;
  final String description;

  RecipeCandidate({
    required this.title,
    required this.description,
  });
}

/// レシピ提案用のAI APIサービス
class RecipeApiService {
  static const String _model = 'gemini-2.5-flash';

  /// 選択された食材からレシピ候補を取得（3つ程度）
  static Future<List<RecipeCandidate>> getRecipeCandidates(
    List<SelectedIngredient> ingredients,
  ) async {
    final ingredientNames = ingredients.map((ing) => ing.name).join('、');

    final prompt = '''
以下の食材を使って、3つのレシピ候補を提案してください。

選択された食材: $ingredientNames

以下のJSON形式のみで回答してください：
{"candidates": [{"title": "レシピ名", "description": "簡単な説明（1文程度）"}]}

ルール：
- 候補は必ず3つ
- 日本語で回答すること
''';

    try {
      final model = GenerativeModel(
        model: _model,
        apiKey: AppConfig.geminiApiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
        ),
      );

      final response = await model.generateContent([
        Content.text(prompt),
      ]);

      final content = response.text;

      if (content == null || content.isEmpty) {
        throw const LabelDetectionException(
          message: 'レシピ候補の生成に失敗しました。レスポンスが空です。',
        );
      }

      final decoded = jsonDecode(content) as Map<String, dynamic>;
      final list = decoded['candidates'] as List<dynamic>;

      return list
          .map((e) {
            final m = e as Map<String, dynamic>;
            return RecipeCandidate(
              title: m['title'] as String,
              description: m['description'] as String,
            );
          })
          .take(3)
          .toList();
    } on ApiKeyNotSetException {
      rethrow;
    } on VisionException {
      rethrow;
    } on FormatException catch (e) {
      debugPrint('レシピ候補のパースエラー: $e');
      throw LabelDetectionException(
        message: 'レシピ候補の解析に失敗しました',
        details: e.message,
        originalError: e,
      );
    } catch (e) {
      debugPrint('レシピ候補の取得エラー: $e');
      throw LabelDetectionException(
        message: 'レシピ候補の取得に失敗しました',
        originalError: e,
      );
    }
  }

  /// 選択されたレシピの詳細を取得
  static Future<String> getRecipeDetails(
    List<SelectedIngredient> ingredients,
    String selectedRecipeTitle,
  ) async {
    final ingredientNames = ingredients.map((ing) => ing.name).join('、');

    final prompt = '''
以下の食材を使って、「$selectedRecipeTitle」のレシピの詳細を提案してください。

選択された食材: $ingredientNames

以下の形式でマークダウンで回答してください：

# $selectedRecipeTitle

## 材料
- 材料1: 分量
- 材料2: 分量

## 作り方
1. 手順1
2. 手順2

## ポイント
- ポイント1
- ポイント2

日本語で回答してください。
''';

    try {
      final model = GenerativeModel(
        model: _model,
        apiKey: AppConfig.geminiApiKey,
      );

      final response = await model.generateContent([
        Content.text(prompt),
      ]);

      final content = response.text;

      if (content == null || content.isEmpty) {
        throw const LabelDetectionException(
          message: 'レシピ詳細の生成に失敗しました。レスポンスが空です。',
        );
      }

      return content;
    } on ApiKeyNotSetException {
      rethrow;
    } on VisionException {
      rethrow;
    } catch (e) {
      debugPrint('レシピ詳細の取得エラー: $e');
      throw LabelDetectionException(
        message: 'レシピ詳細の取得に失敗しました',
        originalError: e,
      );
    }
  }
}
