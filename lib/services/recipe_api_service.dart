import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
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
  static String? get apiKey => dotenv.env['GEMINI_API_KEY'];
  static const String _model = 'gemini-2.5-flash';

  /// 選択された食材からレシピ候補を取得（3つ程度）
  static Future<List<RecipeCandidate>> getRecipeCandidates(
    List<SelectedIngredient> ingredients,
  ) async {
    if (apiKey == null || apiKey!.isEmpty) {
      throw Exception('GEMINI_API_KEYが設定されていません。.envファイルを確認してください。');
    }

    final ingredientNames = ingredients.map((ing) => ing.name).join('、');
    
    final prompt = '''
以下の食材を使って、3つのレシピ候補を提案してください。

選択された食材: $ingredientNames

以下の形式で回答してください（番号付きリスト）：

1. レシピ名1 - 簡単な説明（1文程度）
2. レシピ名2 - 簡単な説明（1文程度）
3. レシピ名3 - 簡単な説明（1文程度）

各レシピは1行で、レシピ名と説明を「 - 」で区切ってください。
日本語で回答してください。
''';

    try {
      final model = GenerativeModel(
        model: _model,
        apiKey: apiKey!,
      );

      final response = await model.generateContent([
        Content.text(prompt),
      ]);

      final content = response.text;
      
      if (content == null || content.isEmpty) {
        throw Exception('レシピ候補の生成に失敗しました。レスポンスが空です。');
      }

      // レスポンスをパースして候補リストを作成
      final candidates = _parseCandidates(content);
      
      return candidates;
    } catch (e) {
      if (e.toString().contains('GEMINI_API_KEY')) {
        rethrow;
      }
      throw Exception('レシピ候補の取得に失敗しました: $e');
    }
  }

  /// レスポンスからレシピ候補をパース
  static List<RecipeCandidate> _parseCandidates(String content) {
    final candidates = <RecipeCandidate>[];
    final lines = content.split('\n');
    
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      
      // 番号付きリストの形式（例: "1. レシピ名 - 説明"）をパース
      final regex = RegExp(r'^\d+\.\s*(.+?)\s*-\s*(.+)$');
      final match = regex.firstMatch(trimmed);
      
      if (match != null) {
        final title = match.group(1)?.trim() ?? '';
        final description = match.group(2)?.trim() ?? '';
        if (title.isNotEmpty) {
          candidates.add(RecipeCandidate(
            title: title,
            description: description,
          ));
        }
      } else if (trimmed.contains(' - ')) {
        // 番号なしでも「 - 」で区切られている場合
        final parts = trimmed.split(' - ');
        if (parts.length >= 2) {
          final title = parts[0].replaceAll(RegExp(r'^\d+\.\s*'), '').trim();
          final description = parts.sublist(1).join(' - ').trim();
          if (title.isNotEmpty) {
            candidates.add(RecipeCandidate(
              title: title,
              description: description,
            ));
          }
        }
      }
    }
    
    // 3つに満たない場合は、コンテンツ全体を1つの候補として扱う
    if (candidates.isEmpty && content.isNotEmpty) {
      final firstLine = content.split('\n').first.trim();
      candidates.add(RecipeCandidate(
        title: firstLine.replaceAll(RegExp(r'^\d+\.\s*'), ''),
        description: '詳細はレシピ詳細で確認できます',
      ));
    }
    
    return candidates.take(3).toList();
  }

  /// 選択されたレシピの詳細を取得
  static Future<String> getRecipeDetails(
    List<SelectedIngredient> ingredients,
    String selectedRecipeTitle,
  ) async {
    if (apiKey == null || apiKey!.isEmpty) {
      throw Exception('GEMINI_API_KEYが設定されていません。.envファイルを確認してください。');
    }

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
        apiKey: apiKey!,
      );

      final response = await model.generateContent([
        Content.text(prompt),
      ]);

      final content = response.text;
      
      if (content == null || content.isEmpty) {
        throw Exception('レシピ詳細の生成に失敗しました。レスポンスが空です。');
      }
      
      return content;
    } catch (e) {
      if (e.toString().contains('GEMINI_API_KEY')) {
        rethrow;
      }
      throw Exception('レシピ詳細の取得に失敗しました: $e');
    }
  }
}

