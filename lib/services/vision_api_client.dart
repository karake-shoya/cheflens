import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/logger.dart';
import 'package:http/http.dart' as http;
import '../exceptions/vision_exception.dart';

/// Google Vision APIへのHTTPリクエストを担当するクラス
class VisionApiClient {
  static String get apiKey => dotenv.env['GOOGLE_VISION_API_KEY'] ?? '';
  static const String _baseUrl =
      'https://vision.googleapis.com/v1/images:annotate';

  /// APIキーが設定されているか確認
  static void _validateApiKey() {
    if (apiKey.isEmpty) {
      throw const ApiKeyNotSetException(
        apiName: 'Google Vision API',
        details: 'GOOGLE_VISION_API_KEYが.envファイルに設定されていません',
      );
    }
  }

  /// 画像をbase64エンコード
  static Future<String> _encodeImage(File imageFile) async {
    try {
      if (!await imageFile.exists()) {
        throw const ImageProcessingException(
          message: '画像ファイルが見つかりません',
        );
      }

      final bytes = await imageFile.readAsBytes();
      if (bytes.isEmpty) {
        throw const ImageProcessingException(
          message: '画像ファイルが空です',
        );
      }

      return base64Encode(bytes);
    } on ImageProcessingException {
      rethrow;
    } catch (e) {
      throw ImageProcessingException(
        message: '画像の読み込みに失敗しました',
        details: e.toString(),
        originalError: e,
      );
    }
  }

  /// Vision APIにリクエストを送信
  static Future<Map<String, dynamic>> _postRequest({
    required String base64Image,
    required String featureType,
    required int maxResults,
  }) async {
    _validateApiKey();

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requests': [
            {
              'image': {'content': base64Image},
              'features': [
                {'type': featureType, 'maxResults': maxResults}
              ]
            }
          ]
        }),
      );

      if (response.statusCode != 200) {
        _handleHttpError(response, featureType);
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      // Vision APIのエラーレスポンスをチェック
      final responses = data['responses'] as List?;
      if (responses != null && responses.isNotEmpty) {
        final firstResponse = responses[0] as Map<String, dynamic>;
        if (firstResponse.containsKey('error')) {
          final error = firstResponse['error'] as Map<String, dynamic>;
          throw ApiException(
            message: 'Vision API エラー',
            statusCode: error['code'] as int?,
            details: error['message'] as String?,
          );
        }
      }

      return data;
    } on VisionException {
      rethrow;
    } on SocketException catch (e) {
      throw ApiException(
        message: 'ネットワーク接続エラー',
        details: 'インターネット接続を確認してください',
        originalError: e,
      );
    } on HttpException catch (e) {
      throw ApiException(
        message: 'HTTP通信エラー',
        details: e.message,
        originalError: e,
      );
    } on FormatException catch (e) {
      throw ApiException(
        message: 'レスポンスの解析に失敗しました',
        details: e.message,
        originalError: e,
      );
    } catch (e) {
      throw ApiException(
        message: 'API呼び出しに失敗しました',
        details: e.toString(),
        originalError: e,
      );
    }
  }

  /// HTTPエラーを処理
  static Never _handleHttpError(http.Response response, String featureType) {
    final statusCode = response.statusCode;
    String? details;

    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final error = body['error'] as Map<String, dynamic>?;
      details = error?['message'] as String?;
    } catch (_) {
      details = response.body;
    }

    AppLogger.debug('Vision API Error [$featureType]: $statusCode - $details');

    throw ApiException(
      message: 'Vision API エラー ($featureType)',
      statusCode: statusCode,
      details: details,
    );
  }

  /// Label Detection APIを呼び出し
  static Future<Map<String, dynamic>> callLabelDetection(
    File imageFile, {
    int maxResults = 50,
  }) async {
    try {
      final base64Image = await _encodeImage(imageFile);
      return await _postRequest(
        base64Image: base64Image,
        featureType: 'LABEL_DETECTION',
        maxResults: maxResults,
      );
    } on VisionException {
      rethrow;
    } catch (e) {
      throw LabelDetectionException(
        message: 'Label Detection APIの呼び出しに失敗しました',
        details: e.toString(),
        originalError: e,
      );
    }
  }

  /// Object Localization APIを呼び出し
  static Future<Map<String, dynamic>> callObjectLocalization(
    File imageFile, {
    int maxResults = 20,
  }) async {
    try {
      final base64Image = await _encodeImage(imageFile);
      return await _postRequest(
        base64Image: base64Image,
        featureType: 'OBJECT_LOCALIZATION',
        maxResults: maxResults,
      );
    } on VisionException {
      rethrow;
    } catch (e) {
      throw ObjectDetectionException(
        message: 'Object Localization APIの呼び出しに失敗しました',
        details: e.toString(),
        originalError: e,
      );
    }
  }

  /// Web Detection APIを呼び出し
  static Future<Map<String, dynamic>> callWebDetection(
    File imageFile, {
    int maxResults = 20,
  }) async {
    try {
      final base64Image = await _encodeImage(imageFile);
      return await _postRequest(
        base64Image: base64Image,
        featureType: 'WEB_DETECTION',
        maxResults: maxResults,
      );
    } on VisionException {
      rethrow;
    } catch (e) {
      throw WebDetectionException(
        message: 'Web Detection APIの呼び出しに失敗しました',
        details: e.toString(),
        originalError: e,
      );
    }
  }

  /// Text Detection APIを呼び出し（OCR）
  static Future<Map<String, dynamic>> callTextDetection(
    File imageFile,
  ) async {
    try {
      final base64Image = await _encodeImage(imageFile);
      return await _postRequest(
        base64Image: base64Image,
        featureType: 'TEXT_DETECTION',
        maxResults: 1,
      );
    } on VisionException {
      rethrow;
    } catch (e) {
      throw TextDetectionException(
        message: 'Text Detection APIの呼び出しに失敗しました',
        details: e.toString(),
        originalError: e,
      );
    }
  }
}
