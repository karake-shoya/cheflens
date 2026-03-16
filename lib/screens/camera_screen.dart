import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../config/app_config.dart';
import '../services/gemini_ingredient_service.dart';
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
  final _ingredientService = GeminiIngredientService();

  /// 選択済み画像リスト（最大 AppConfig.maxImagesPerScan 枚）
  final List<File> _images = [];
  bool _loading = false;
  String _statusMessage = '';
  StatusType _statusType = StatusType.info;

  int get _maxImages => AppConfig.maxImagesPerScan;

  bool get _canAddImage => _images.length < _maxImages;

  void _setStatus(String message, StatusType type) {
    setState(() {
      _statusMessage = message;
      _statusType = type;
    });
  }

  /// 画像を1枚追加する（上限に達している場合は何もしない）
  Future<void> _pickImage(ImageSource source) async {
    if (!_canAddImage) return;

    setState(() => _loading = true);
    _setStatus('', StatusType.info);

    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1280,
      );
      if (file != null) {
        setState(() => _images.add(File(file.path)));
      }
    } catch (e) {
      debugPrint('Image pick error: $e');
      if (mounted) {
        final message = source == ImageSource.camera
            ? 'カメラの起動に失敗しました'
            : 'ギャラリー選択に失敗しました';
        _setStatus(message, StatusType.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 指定インデックスの画像を削除する
  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
  }

  /// 認識結果を処理して結果画面に遷移
  Future<void> _navigateToResultScreen(List<String> ingredients) async {
    if (!mounted) return;

    setState(() => _loading = false);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ResultScreen(
          images: List.unmodifiable(_images),
          detectedIngredients: ingredients,
        ),
      ),
    );
    // 結果画面から戻ってきたときにステータスをクリア
    if (mounted) {
      _setStatus('', StatusType.info);
    }
  }

  /// エラーハンドリングの共通処理
  void _handleRecognitionError(dynamic error) {
    debugPrint('Recognition error: $error');
    if (!mounted) return;

    String userMessage;
    if (error is VisionException) {
      userMessage = error.userMessage;
      debugPrint('VisionException details: ${error.details}');
    } else if (error is Exception) {
      userMessage = '認識に失敗しました。再試行してください。';
    } else {
      userMessage = '予期せぬエラーが発生しました。';
    }

    setState(() => _loading = false);
    _setStatus(userMessage, StatusType.error);
  }

  Future<void> _detectIngredients() async {
    if (_images.isEmpty) return;

    setState(() => _loading = true);
    _setStatus(
      '食材を認識中...（数秒かかります）',
      StatusType.info,
    );

    try {
      final ingredients =
          await _ingredientService.recognizeIngredients(_images);

      if (ingredients.isEmpty) {
        if (mounted) {
          setState(() => _loading = false);
          _setStatus(
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

  // ────────────────────────────────────────────────
  // ウィジェット構築
  // ────────────────────────────────────────────────

  /// 画像未選択時のプレースホルダー
  Widget _buildImagePlaceholder() {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300, width: 2),
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
            const SizedBox(height: 4),
            Text(
              '最大$_maxImages枚まで追加できます',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 選択済み画像のサムネイル1枚
  Widget _buildThumbnail(int index, File file) {
    return Stack(
      children: [
        Container(
          width: 140,
          height: 180,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(file, fit: BoxFit.cover),
          ),
        ),
        // 削除ボタン
        Positioned(
          top: 6,
          right: 14,
          child: GestureDetector(
            onTap: _loading ? null : () => _removeImage(index),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
        // 枚数バッジ
        Positioned(
          bottom: 6,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${index + 1}枚目',
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }

  /// 追加スロット（上限未満のときのみ表示）
  Widget _buildAddSlot() {
    return Container(
      width: 140,
      height: 180,
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.grey.shade300,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade50,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 40,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 8),
          Text(
            'ここに追加',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  /// 選択済み画像のサムネイル一覧
  Widget _buildImageThumbnails() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ..._images.asMap().entries.map(
                (entry) => _buildThumbnail(entry.key, entry.value),
              ),
          if (_canAddImage) _buildAddSlot(),
        ],
      ),
    );
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              // ステータスメッセージ
              if (_statusMessage.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
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
              // 画像表示エリア（ローディング中はインジケーター）
              SizedBox(
                height: 180,
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _images.isEmpty
                        ? _buildImagePlaceholder()
                        : _buildImageThumbnails(),
              ),
              const SizedBox(height: 8),
              // 枚数インジケーター
              if (_images.isNotEmpty)
                Text(
                  '${_images.length} / $_maxImages 枚選択中',
                  style: TextStyle(
                    fontSize: 13,
                    color: _canAddImage
                        ? Colors.grey.shade600
                        : Colors.orange.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              const SizedBox(height: 12),
              // 写真追加ボタン群
              SizedBox(
                width: 240,
                child: ElevatedButton.icon(
                  onPressed:
                      (_loading || !_canAddImage) ? null : () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt, size: 20),
                  label: Text(
                    _images.isEmpty ? '写真を撮る' : '写真を追加',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 240,
                child: ElevatedButton.icon(
                  onPressed:
                      (_loading || !_canAddImage) ? null : () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library, size: 20),
                  label: Text(
                    _images.isEmpty ? 'ギャラリーから選ぶ' : 'ギャラリーから追加',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
              // 上限到達時のメッセージ
              if (!_canAddImage && _images.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '最大$_maxImages枚に達しました',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ),
              // 認識ボタン
              if (_images.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: 240,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _detectIngredients,
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    label: Text(
                      _images.length == 1 ? '食材を探す' : '${_images.length}枚から食材を探す',
                      style: const TextStyle(fontSize: 13),
                    ),
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
