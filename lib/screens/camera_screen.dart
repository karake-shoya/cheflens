import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/food_data_provider.dart';
import '../providers/camera_state_provider.dart';
import '../providers/ingredient_selection_provider.dart';
import '../exceptions/vision_exception.dart';
import '../utils/logger.dart';
import 'result_screen.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _takePhoto() async {
    final notifier = ref.read(cameraStateProvider.notifier);
    notifier.setLoading(true);
    notifier.clearStatus();

    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1280,
      );
      if (file != null) {
        notifier.setImage(File(file.path));
      }
    } catch (e) {
      AppLogger.debug('Camera error: $e');
      if (mounted) {
        notifier.setError('カメラの起動に失敗しました');
      }
    } finally {
      if (mounted) {
        notifier.setLoading(false);
      }
    }
  }

  Future<void> _pickFromGallery() async {
    final notifier = ref.read(cameraStateProvider.notifier);
    notifier.setLoading(true);
    notifier.clearStatus();

    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1280,
      );
      if (file != null) {
        notifier.setImage(File(file.path));
      }
    } catch (e) {
      AppLogger.debug('Gallery error: $e');
      if (mounted) {
        notifier.setError('ギャラリー選択に失敗しました');
      }
    } finally {
      if (mounted) {
        notifier.setLoading(false);
      }
    }
  }

  /// 認識結果を処理して結果画面に遷移
  Future<void> _navigateToResultScreen(List<String> ingredients) async {
    if (!mounted) return;

    final cameraState = ref.read(cameraStateProvider);
    final notifier = ref.read(cameraStateProvider.notifier);
    notifier.setLoading(false);

    // 食材選択状態を初期化
    ref.read(ingredientSelectionProvider.notifier)
        .initializeWithDetectedIngredients(ingredients);

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ResultScreen(
          image: cameraState.selectedImage!,
        ),
      ),
    );
    // 結果画面から戻ってきたときにステータスメッセージをクリア
    if (mounted) {
      notifier.clearStatus();
    }
  }

  /// エラーハンドリングの共通処理
  void _handleRecognitionError(dynamic error) {
    AppLogger.debug('Recognition error: $error');
    if (!mounted) return;

    String userMessage;

    if (error is VisionException) {
      userMessage = error.userMessage;
      AppLogger.debug('VisionException details: ${error.details}');
    } else if (error is Exception) {
      userMessage = '認識に失敗しました。再試行してください。';
    } else {
      userMessage = '予期せぬエラーが発生しました。';
    }

    ref.read(cameraStateProvider.notifier).setError(userMessage);
  }

  Future<void> _detectWithCombinedApproach() async {
    final cameraState = ref.read(cameraStateProvider);
    final visionServiceAsync = ref.read(visionServiceProvider);
    final notifier = ref.read(cameraStateProvider.notifier);

    if (cameraState.selectedImage == null) {
      return;
    }

    // VisionServiceが読み込まれていない場合
    if (visionServiceAsync.isLoading) {
      notifier.setError('データを読み込み中です。しばらくお待ちください。');
      return;
    }

    if (visionServiceAsync.hasError) {
      notifier.setError('データの読み込みに失敗しました');
      return;
    }

    final visionService = visionServiceAsync.value;
    if (visionService == null) {
      notifier.setError('データが読み込まれていません');
      return;
    }

    notifier.startRecognition();

    try {
      final ingredients = await visionService
          .detectIngredientsWithObjectDetection(cameraState.selectedImage!);

      if (ingredients.isEmpty) {
        if (mounted) {
          notifier.setLoading(false);
          notifier.setStatus(
            '食材が検出されませんでした。別の画像で再試行してください。',
            StatusType.info,
          );
        }
        return;
      }

      await _navigateToResultScreen(ingredients);
    } on VisionException catch (e) {
      _handleRecognitionError(e);
    } catch (e) {
      _handleRecognitionError(e);
    }
  }

  /// ステータスメッセージの色を取得
  Color _getStatusColor(StatusType statusType) {
    switch (statusType) {
      case StatusType.error:
        return Colors.red;
      case StatusType.success:
        return Colors.green;
      case StatusType.info:
        return Colors.blue;
    }
  }

  /// ステータスメッセージのアイコンを取得
  IconData _getStatusIcon(StatusType statusType) {
    switch (statusType) {
      case StatusType.error:
        return Icons.error_outline;
      case StatusType.success:
        return Icons.check_circle_outline;
      case StatusType.info:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cameraState = ref.watch(cameraStateProvider);
    final visionServiceAsync = ref.watch(visionServiceProvider);
    final statusColor = _getStatusColor(cameraState.statusType);

    // VisionService読み込みエラーの場合
    if (visionServiceAsync.hasError) {
      AppLogger.debug('Failed to initialize food data: ${visionServiceAsync.error}');
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Cheflens - カメラ')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              if (cameraState.statusMessage.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        statusColor.withValues(alpha: 0.15),
                        statusColor.withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getStatusIcon(cameraState.statusType),
                          color: statusColor, size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          cameraState.statusMessage,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Center(
                child: SizedBox(
                  height: 220,
                  child: cameraState.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : cameraState.selectedImage != null
                          ? Image.file(cameraState.selectedImage!,
                              fit: BoxFit.contain)
                          : Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                  width: 2,
                                  strokeAlign: BorderSide.strokeAlignInside,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.grey.shade50,
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_photo_alternate_outlined,
                                      size: 64,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      '画像を選択してください',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 240,
                child: ElevatedButton.icon(
                  onPressed: cameraState.isLoading ? null : _takePhoto,
                  icon: const Icon(Icons.camera_alt, size: 20),
                  label:
                      const Text('写真を撮る', style: TextStyle(fontSize: 14)),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 240,
                child: ElevatedButton.icon(
                  onPressed: cameraState.isLoading ? null : _pickFromGallery,
                  icon: const Icon(Icons.photo_library, size: 20),
                  label: const Text('ギャラリーから選ぶ',
                      style: TextStyle(fontSize: 14)),
                ),
              ),
              if (cameraState.selectedImage != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: 240,
                  child: ElevatedButton.icon(
                    onPressed:
                        cameraState.isLoading ? null : _detectWithCombinedApproach,
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    label: const Text('食材を探す',
                        style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
