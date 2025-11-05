import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Google Vision APIへのHTTPリクエストを担当するクラス
class VisionApiClient {
  static String get apiKey => dotenv.env['GOOGLE_VISION_API_KEY'] ?? '';
  static const String _baseUrl = 'https://vision.googleapis.com/v1/images:annotate';

  /// 画像をbase64エンコード
  static Future<String> _encodeImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    return base64Encode(bytes);
  }

  /// Vision APIにリクエストを送信
  static Future<Map<String, dynamic>> _postRequest({
    required String base64Image,
    required String featureType,
    required int maxResults,
  }) async {
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
      throw Exception('Vision API Error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    return data;
  }

  /// Label Detection APIを呼び出し
  static Future<Map<String, dynamic>> callLabelDetection(
    File imageFile, {
    int maxResults = 50,
  }) async {
    final base64Image = await _encodeImage(imageFile);
    return await _postRequest(
      base64Image: base64Image,
      featureType: 'LABEL_DETECTION',
      maxResults: maxResults,
    );
  }

  /// Object Localization APIを呼び出し
  static Future<Map<String, dynamic>> callObjectLocalization(
    File imageFile, {
    int maxResults = 20,
  }) async {
    final base64Image = await _encodeImage(imageFile);
    return await _postRequest(
      base64Image: base64Image,
      featureType: 'OBJECT_LOCALIZATION',
      maxResults: maxResults,
    );
  }

  /// Web Detection APIを呼び出し
  static Future<Map<String, dynamic>> callWebDetection(
    File imageFile, {
    int maxResults = 20,
  }) async {
    final base64Image = await _encodeImage(imageFile);
    return await _postRequest(
      base64Image: base64Image,
      featureType: 'WEB_DETECTION',
      maxResults: maxResults,
    );
  }

  /// Text Detection APIを呼び出し（OCR）
  static Future<Map<String, dynamic>> callTextDetection(
    File imageFile,
  ) async {
    final base64Image = await _encodeImage(imageFile);
    return await _postRequest(
      base64Image: base64Image,
      featureType: 'TEXT_DETECTION',
      maxResults: 1, // テキスト検出ではmaxResultsは使用されないが、必須パラメータ
    );
  }
}

