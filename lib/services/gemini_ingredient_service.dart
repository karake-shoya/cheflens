import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

/// Gemini Vision APIを使用した食材認識サービス
class GeminiIngredientService {
  static String? get _apiKey => dotenv.env['GEMINI_API_KEY'];

  // レシピ生成と同じモデルを統一して使用（精度・コストのバランス最良）
  static const String _model = 'gemini-2.5-flash';

  static const String _prompt = '''
この画像に写っている食材・食品をすべて特定してください。

以下のJSON形式のみで回答してください。説明文は不要です：
{"ingredients": ["にんじん", "玉ねぎ", "鶏もも肉"]}

ルール：
- 食材・食品のみ記載すること（容器、棚、包装、照明などは含めない）
- 日本語で出力すること
- 自信を持って識別できる食材のみ含めること
- 食材が見つからない場合は {"ingredients": []} を返すこと
''';

  /// 画像から食材リストを認識して返す
  Future<List<String>> recognizeIngredients(File imageFile) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('GEMINI_API_KEYが設定されていません。.envファイルを確認してください。');
    }

    try {
      final bytes = await imageFile.readAsBytes();
      final mimeType = _resolveMimeType(imageFile.path);

      final model = GenerativeModel(
        model: _model,
        apiKey: _apiKey!,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
        ),
      );

      debugPrint('=== Gemini Vision 食材認識を開始 ===');

      final response = await model.generateContent([
        Content.multi([
          DataPart(mimeType, bytes),
          TextPart(_prompt),
        ]),
      ]);

      final text = response.text;
      if (text == null || text.isEmpty) {
        debugPrint('Gemini Vision: レスポンスが空でした');
        return [];
      }

      debugPrint('Gemini Vision レスポンス: $text');

      final decoded = jsonDecode(text) as Map<String, dynamic>;
      final ingredients = (decoded['ingredients'] as List<dynamic>?)
              ?.map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList() ??
          [];

      debugPrint('=== 認識結果（${ingredients.length}件）: ${ingredients.join('、')} ===');
      return ingredients;
    } on GenerativeAIException catch (e) {
      debugPrint('Gemini API エラー: $e');
      throw Exception('食材認識に失敗しました（APIエラー）: ${e.message}');
    } on FormatException catch (e) {
      debugPrint('Gemini レスポンスのパースエラー: $e');
      throw Exception('認識結果の解析に失敗しました: ${e.message}');
    } catch (e) {
      debugPrint('Gemini Vision エラー: $e');
      throw Exception('食材認識に失敗しました: $e');
    }
  }

  /// ファイル拡張子からMIMEタイプを判定
  String _resolveMimeType(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
      case 'heif':
        return 'image/heic';
      default:
        // jpg / jpeg、または不明な拡張子はJPEGとして扱う
        return 'image/jpeg';
    }
  }
}
