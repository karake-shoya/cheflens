import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../exceptions/vision_exception.dart';

/// アプリケーション設定の一元管理クラス
class AppConfig {
  /// Gemini APIキーを取得する
  /// キーが未設定の場合は [ApiKeyNotSetException] をスローする
  static String get geminiApiKey {
    final key = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (key.isEmpty) {
      throw const ApiKeyNotSetException(apiName: 'Gemini');
    }
    return key;
  }

  /// 1スキャンあたりの最大画像枚数
  /// 将来的にはユーザープランに応じて動的に変更する（無料: 1枚 / 有料: 3枚）
  static int get maxImagesPerScan => 3;
}
