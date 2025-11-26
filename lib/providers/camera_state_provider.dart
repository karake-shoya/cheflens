import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ステータスメッセージの種類
enum StatusType { info, error, success }

/// カメラ画面の状態
class CameraState {
  final File? selectedImage;
  final bool isLoading;
  final String statusMessage;
  final StatusType statusType;

  const CameraState({
    this.selectedImage,
    this.isLoading = false,
    this.statusMessage = '',
    this.statusType = StatusType.info,
  });

  CameraState copyWith({
    File? selectedImage,
    bool? isLoading,
    String? statusMessage,
    StatusType? statusType,
    bool clearImage = false,
  }) {
    return CameraState(
      selectedImage: clearImage ? null : (selectedImage ?? this.selectedImage),
      isLoading: isLoading ?? this.isLoading,
      statusMessage: statusMessage ?? this.statusMessage,
      statusType: statusType ?? this.statusType,
    );
  }
}

/// カメラ状態を管理するNotifier
class CameraStateNotifier extends StateNotifier<CameraState> {
  CameraStateNotifier() : super(const CameraState());

  /// 画像を設定
  void setImage(File? image) {
    state = state.copyWith(selectedImage: image);
  }

  /// ローディング状態を設定
  void setLoading(bool isLoading) {
    state = state.copyWith(isLoading: isLoading);
  }

  /// ステータスメッセージを設定
  void setStatus(String message, StatusType type) {
    state = state.copyWith(statusMessage: message, statusType: type);
  }

  /// ステータスメッセージをクリア
  void clearStatus() {
    state = state.copyWith(statusMessage: '');
  }

  /// 認識開始時の状態を設定
  void startRecognition() {
    state = state.copyWith(
      isLoading: true,
      statusMessage: '高精度認識中...（数秒かかります）',
      statusType: StatusType.info,
    );
  }

  /// 認識終了時の状態を設定
  void endRecognition() {
    state = state.copyWith(isLoading: false);
  }

  /// エラー状態を設定
  void setError(String message) {
    state = state.copyWith(
      isLoading: false,
      statusMessage: message,
      statusType: StatusType.error,
    );
  }

  /// 状態をリセット
  void reset() {
    state = const CameraState();
  }
}

/// カメラ状態のプロバイダー
final cameraStateProvider =
    StateNotifierProvider<CameraStateNotifier, CameraState>((ref) {
  return CameraStateNotifier();
});

