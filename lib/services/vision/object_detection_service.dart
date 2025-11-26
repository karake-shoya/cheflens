import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../models/food_data_model.dart';
import '../../models/detected_object.dart';
import '../vision_api_client.dart';

/// Object Detection用の定数
class ObjectDetectionConstants {
  static const int maxObjectDetectionResults = 20;
}

/// Object Detection APIを使用した物体検出サービス
class ObjectDetectionService {
  final FoodData foodData;

  ObjectDetectionService(this.foodData);

  /// Object Detection APIを使って画像内の物体を検出
  Future<List<DetectedObject>> detectObjects(File imageFile) async {
    try {
      final data = await VisionApiClient.callObjectLocalization(
        imageFile,
        maxResults: ObjectDetectionConstants.maxObjectDetectionResults,
      );

      final objects =
          data['responses'][0]['localizedObjectAnnotations'] as List?;

      if (objects == null || objects.isEmpty) {
        debugPrint('=== Object Detection: 物体が検出されませんでした ===');
        return [];
      }

      debugPrint('=== Object Detection 検出結果 ===');
      for (var obj in objects) {
        debugPrint('${obj['name']} (信頼度: ${obj['score']})');
      }
      debugPrint('=====================================');

      // DetectedObjectのリストに変換
      final detectedObjects = objects
          .map((obj) => DetectedObject.fromJson(obj as Map<String, dynamic>))
          .toList();

      return detectedObjects;
    } catch (e) {
      throw Exception('物体検出に失敗しました: $e');
    }
  }

  /// 信頼度フィルタを適用した物体のリストを取得
  List<DetectedObject> filterByConfidence(List<DetectedObject> objects) {
    final confidenceThreshold =
        foodData.filtering.objectDetectionConfidenceThreshold;

    final filtered =
        objects.where((obj) => obj.score >= confidenceThreshold).toList();

    debugPrint('検出された物体: ${objects.length}個');
    debugPrint(
        '信頼度${(confidenceThreshold * 100).toStringAsFixed(0)}%以上の物体: ${filtered.length}個');

    return filtered;
  }
}

