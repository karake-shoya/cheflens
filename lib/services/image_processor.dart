import 'dart:io';
import 'package:image/image.dart' as img;
import '../models/detected_object.dart';

/// 画像処理を担当するクラス
class ImageProcessor {
  /// 画像を読み込む
  static Future<img.Image?> loadImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      return img.decodeImage(bytes);
    } catch (e) {
      return null;
    }
  }

  /// バウンディングボックスに基づいて画像をトリミング
  static img.Image? cropImage(
    img.Image image,
    BoundingBox boundingBox,
  ) {
    final x1 = (boundingBox.vertices[0].x * image.width).round().clamp(0, image.width);
    final y1 = (boundingBox.vertices[0].y * image.height).round().clamp(0, image.height);
    final x2 = (boundingBox.vertices[2].x * image.width).round().clamp(0, image.width);
    final y2 = (boundingBox.vertices[2].y * image.height).round().clamp(0, image.height);
    
    final width = (x2 - x1).clamp(1, image.width);
    final height = (y2 - y1).clamp(1, image.height);
    
    if (width <= 0 || height <= 0) {
      return null;
    }
    
    return img.copyCrop(image, x: x1, y: y1, width: width, height: height);
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
      return null;
    }
  }

  /// トリミング画像のサイズが有効かチェック
  static bool isValidCropSize(int width, int height, int minSize) {
    return width >= minSize && height >= minSize;
  }
}

