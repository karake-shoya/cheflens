import 'dart:io';
import 'package:image/image.dart' as img;
import '../models/detected_object.dart';
import '../exceptions/vision_exception.dart';

/// 画像処理を担当するクラス
class ImageProcessor {
  /// 画像を読み込む
  static Future<img.Image?> loadImage(File imageFile) async {
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

      final image = img.decodeImage(bytes);
      if (image == null) {
        throw const ImageProcessingException(
          message: '画像のデコードに失敗しました',
          details: 'サポートされていない画像形式の可能性があります',
        );
      }

      return image;
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

  /// バウンディングボックスに基づいて画像をトリミング
  static img.Image? cropImage(
    img.Image image,
    BoundingBox boundingBox,
  ) {
    try {
      final x1 =
          (boundingBox.vertices[0].x * image.width).round().clamp(0, image.width);
      final y1 =
          (boundingBox.vertices[0].y * image.height).round().clamp(0, image.height);
      final x2 =
          (boundingBox.vertices[2].x * image.width).round().clamp(0, image.width);
      final y2 =
          (boundingBox.vertices[2].y * image.height).round().clamp(0, image.height);

      final width = (x2 - x1).clamp(1, image.width);
      final height = (y2 - y1).clamp(1, image.height);

      if (width <= 0 || height <= 0) {
        return null;
      }

      return img.copyCrop(image, x: x1, y: y1, width: width, height: height);
    } catch (e) {
      // トリミングに失敗した場合はnullを返す（エラーは投げない）
      return null;
    }
  }

  /// トリミングされた画像を一時ファイルに保存
  static Future<File?> saveCroppedImageToTemp(
    img.Image croppedImage,
    int index,
  ) async {
    try {
      final tempDir = await Directory.systemTemp.createTemp('cheflens_crop');
      final tempFile = File('${tempDir.path}/crop_$index.jpg');
      await tempFile.writeAsBytes(img.encodeJpg(croppedImage));
      return tempFile;
    } catch (e) {
      // 一時ファイルの作成に失敗した場合はnullを返す
      return null;
    }
  }

  /// トリミング画像のサイズが有効かチェック
  static bool isValidCropSize(int width, int height, int minSize) {
    return width >= minSize && height >= minSize;
  }
}
