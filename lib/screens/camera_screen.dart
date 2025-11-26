import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/vision_service.dart';
import '../utils/logger.dart';
import '../services/food_data_service.dart';
import '../exceptions/vision_exception.dart';
import 'result_screen.dart';

/// ステータスメッセージの種類
enum StatusType { info, error, success }

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final ImagePicker _picker = ImagePicker();
  VisionService? _visionService;
  File? _image;
  bool _loading = false;
  String _statusMessage = '';
  StatusType _statusType = StatusType.info;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    try {
      final foodData = await FoodDataService.loadFoodData();
      if (mounted) {
        setState(() {
          _visionService = VisionService(foodData);
        });
      }
    } catch (e) {
      AppLogger.debug('Failed to initialize food data: $e');
      if (mounted) {
        _setStatus('データの読み込みに失敗しました', StatusType.error);
      }
    }
  }

  void _setStatus(String message, StatusType type) {
    setState(() {
      _statusMessage = message;
      _statusType = type;
    });
  }

  void _clearStatus() {
    setState(() {
      _statusMessage = '';
    });
  }

  Future<void> _takePhoto() async {
    setState(() {
      _loading = true;
    });
    _clearStatus();
    
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1280,
      );
      if (file != null) {
        setState(() => _image = File(file.path));
      }
    } catch (e) {
      AppLogger.debug('Camera error: $e');
      if (mounted) {
        _setStatus('カメラの起動に失敗しました', StatusType.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickFromGallery() async {
    setState(() {
      _loading = true;
    });
    _clearStatus();
    
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1280,
      );
      if (file != null) setState(() => _image = File(file.path));
    } catch (e) {
      AppLogger.debug('Gallery error: $e');
      if (mounted) {
        _setStatus('ギャラリー選択に失敗しました', StatusType.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 認識結果を処理して結果画面に遷移
  Future<void> _navigateToResultScreen(List<String> ingredients) async {
    if (!mounted) return;

    setState(() => _loading = false);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ResultScreen(
          image: _image!,
          detectedIngredients: ingredients,
        ),
      ),
    );
    // 結果画面から戻ってきたときにステータスメッセージをクリア
    if (mounted) {
      _clearStatus();
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

    setState(() {
      _loading = false;
    });
    _setStatus(userMessage, StatusType.error);
  }

  Future<void> _detectWithCombinedApproach() async {
    if (_image == null || _visionService == null) {
      if (mounted && _visionService == null) {
        _setStatus('データが読み込まれていません', StatusType.error);
      }
      return;
    }

    setState(() {
      _loading = true;
    });
    _setStatus('高精度認識中...（数秒かかります）', StatusType.info);

    try {
      final ingredients =
          await _visionService!.detectIngredientsWithObjectDetection(_image!);
      
      if (ingredients.isEmpty) {
        if (mounted) {
          setState(() => _loading = false);
          _setStatus('食材が検出されませんでした。別の画像で再試行してください。', StatusType.info);
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
  Color _getStatusColor() {
    switch (_statusType) {
      case StatusType.error:
        return Colors.red;
      case StatusType.success:
        return Colors.green;
      case StatusType.info:
        return Colors.blue;
    }
  }

  /// ステータスメッセージのアイコンを取得
  IconData _getStatusIcon() {
    switch (_statusType) {
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
    final statusColor = _getStatusColor();
    
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
              if (_statusMessage.isNotEmpty)
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
                      Icon(_getStatusIcon(), color: statusColor, size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _statusMessage,
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
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _image != null
                          ? Image.file(_image!, fit: BoxFit.contain)
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
                  onPressed: _loading ? null : _takePhoto,
                  icon: const Icon(Icons.camera_alt, size: 20),
                  label:
                      const Text('写真を撮る', style: TextStyle(fontSize: 14)),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 240,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _pickFromGallery,
                  icon: const Icon(Icons.photo_library, size: 20),
                  label: const Text('ギャラリーから選ぶ',
                      style: TextStyle(fontSize: 14)),
                ),
              ),
              if (_image != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: 240,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _detectWithCombinedApproach,
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
