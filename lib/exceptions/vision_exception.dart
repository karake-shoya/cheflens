/// Vision API関連の例外の基底クラス
abstract class VisionException implements Exception {
  final String message;
  final String? details;
  final dynamic originalError;

  const VisionException({
    required this.message,
    this.details,
    this.originalError,
  });

  @override
  String toString() {
    if (details != null) {
      return '$runtimeType: $message ($details)';
    }
    return '$runtimeType: $message';
  }

  /// ユーザー向けのメッセージを取得
  String get userMessage => message;
}

/// API通信エラー
class ApiException extends VisionException {
  final int? statusCode;

  const ApiException({
    required super.message,
    this.statusCode,
    super.details,
    super.originalError,
  });

  @override
  String get userMessage {
    if (statusCode == 401 || statusCode == 403) {
      return 'APIキーが無効です。設定を確認してください。';
    }
    if (statusCode == 429) {
      return 'APIの使用制限に達しました。しばらく待ってから再試行してください。';
    }
    if (statusCode != null && statusCode! >= 500) {
      return 'サーバーエラーが発生しました。しばらく待ってから再試行してください。';
    }
    return 'ネットワークエラーが発生しました。接続を確認してください。';
  }
}

/// APIキー未設定エラー
class ApiKeyNotSetException extends VisionException {
  final String apiName;

  const ApiKeyNotSetException({
    required this.apiName,
    super.details,
  }) : super(message: '$apiNameのAPIキーが設定されていません');

  @override
  String get userMessage => '$apiNameのAPIキーが設定されていません。.envファイルを確認してください。';
}

/// Label Detection エラー
class LabelDetectionException extends VisionException {
  const LabelDetectionException({
    required super.message,
    super.details,
    super.originalError,
  });

  @override
  String get userMessage => '食材の認識に失敗しました。別の画像で再試行してください。';
}

/// Object Detection エラー
class ObjectDetectionException extends VisionException {
  const ObjectDetectionException({
    required super.message,
    super.details,
    super.originalError,
  });

  @override
  String get userMessage => '物体の検出に失敗しました。別の画像で再試行してください。';
}

/// Web Detection エラー
class WebDetectionException extends VisionException {
  const WebDetectionException({
    required super.message,
    super.details,
    super.originalError,
  });

  @override
  String get userMessage => '商品の認識に失敗しました。別の画像で再試行してください。';
}

/// Text Detection エラー
class TextDetectionException extends VisionException {
  const TextDetectionException({
    required super.message,
    super.details,
    super.originalError,
  });

  @override
  String get userMessage => 'テキストの検出に失敗しました。別の画像で再試行してください。';
}

/// 画像処理エラー
class ImageProcessingException extends VisionException {
  const ImageProcessingException({
    required super.message,
    super.details,
    super.originalError,
  });

  @override
  String get userMessage => '画像の処理に失敗しました。別の画像を選択してください。';
}

/// 検出結果なしエラー（エラーではないが特別な状態として扱う）
class NoDetectionResultException extends VisionException {
  const NoDetectionResultException({
    super.message = '検出結果がありませんでした',
    super.details,
  });

  @override
  String get userMessage => '食材が検出されませんでした。別の画像で再試行してください。';
}

/// 統合認識エラー
class CombinedDetectionException extends VisionException {
  const CombinedDetectionException({
    required super.message,
    super.details,
    super.originalError,
  });

  @override
  String get userMessage => '認識に失敗しました。別の画像で再試行してください。';
}

