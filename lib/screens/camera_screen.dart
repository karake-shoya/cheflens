import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import '../config/app_config.dart';
import '../models/detected_ingredient.dart';
import '../services/gemini_ingredient_service.dart';
import '../exceptions/vision_exception.dart';
import '../theme/app_spacing.dart';
import '../widgets/status_message.dart';
import 'result_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final ImagePicker _picker = ImagePicker();
  final _ingredientService = GeminiIngredientService();

  /// カメラで撮影した画像
  final List<File> _cameraFiles = [];

  /// ギャラリーから選択したアセット（再オープン時の事前選択に使用）
  final List<AssetEntity> _galleryAssets = [];

  /// ギャラリーアセットをFileに変換した結果（表示・認識用）
  final List<File> _galleryFiles = [];

  bool _loading = false;
  String _statusMessage = '';
  MessageType _messageType = MessageType.info;

  /// カメラ画像とギャラリー画像を結合した全画像リスト
  List<File> get _images => [..._cameraFiles, ..._galleryFiles];

  int get _maxImages => AppConfig.maxImagesPerScan;
  bool get _canAddImage => _images.length < _maxImages;

  void _setStatus(String message, MessageType type) {
    setState(() {
      _statusMessage = message;
      _messageType = type;
    });
  }

  // ── 画像選択 ────────────────────────────────────────

  Future<void> _pickFromCamera() async {
    if (!_canAddImage) return;
    setState(() => _loading = true);
    _setStatus('', MessageType.info);

    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1280,
      );
      if (file != null && mounted) {
        setState(() => _cameraFiles.add(File(file.path)));
      }
    } catch (e) {
      debugPrint('Camera error: $e');
      if (mounted) _setStatus('カメラの起動に失敗しました', MessageType.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickFromGallery() async {
    if (!_canAddImage) return;

    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.hasAccess) {
      if (mounted) {
        _setStatus(
          '写真へのアクセスが許可されていません。設定から許可してください。',
          MessageType.error,
        );
      }
      return;
    }

    final maxGallery = _maxImages - _cameraFiles.length;
    if (!mounted) return;

    final result = await AssetPicker.pickAssets(
      context,
      pickerConfig: AssetPickerConfig(
        maxAssets: maxGallery,
        selectedAssets: _galleryAssets,
        requestType: RequestType.image,
      ),
    );

    if (result == null || !mounted) return;

    setState(() => _loading = true);
    try {
      final files = await Future.wait(result.map((a) => a.originFile));
      if (!mounted) return;
      setState(() {
        _galleryAssets
          ..clear()
          ..addAll(result);
        _galleryFiles
          ..clear()
          ..addAll(files.whereType<File>());
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _removeImage(int index) {
    setState(() {
      if (index < _cameraFiles.length) {
        _cameraFiles.removeAt(index);
      } else {
        final gi = index - _cameraFiles.length;
        _galleryAssets.removeAt(gi);
        _galleryFiles.removeAt(gi);
      }
    });
  }

  // ── 食材認識 ────────────────────────────────────────

  Future<void> _navigateToResultScreen(
      List<DetectedIngredient> ingredients) async {
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
    if (mounted) _setStatus('', MessageType.info);
  }

  void _handleRecognitionError(dynamic error) {
    debugPrint('Recognition error: $error');
    if (!mounted) return;

    final userMessage = error is VisionException
        ? error.userMessage
        : error is Exception
            ? '認識に失敗しました。再試行してください。'
            : '予期せぬエラーが発生しました。';

    setState(() => _loading = false);
    _setStatus(userMessage, MessageType.error);
  }

  Future<void> _detectIngredients() async {
    if (_images.isEmpty) return;
    setState(() => _loading = true);
    _setStatus('食材を認識中...（数秒かかります）', MessageType.info);

    try {
      final ingredients =
          await _ingredientService.recognizeIngredients(_images);

      if (ingredients.isEmpty) {
        if (mounted) {
          setState(() => _loading = false);
          _setStatus('食材が検出されませんでした。別の画像で再試行してください。', MessageType.warning);
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

  // ── ウィジェット構築 ─────────────────────────────────

  Widget _buildImagePlaceholder() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        color: colorScheme.surfaceContainerLow,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 56,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '画像を選択してください',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '最大$_maxImages枚まで追加できます',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(int index, File file) {
    final colorScheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Container(
          width: 140,
          height: 180,
          margin: const EdgeInsets.only(right: AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.1),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            child: Image.file(file, fit: BoxFit.cover),
          ),
        ),
        // 削除ボタン
        Positioned(
          top: AppSpacing.sm,
          right: AppSpacing.md,
          child: GestureDetector(
            onTap: _loading ? null : () => _removeImage(index),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: colorScheme.error,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close,
                size: 14,
                color: colorScheme.onError,
              ),
            ),
          ),
        ),
        // 枚数バッジ
        Positioned(
          bottom: AppSpacing.sm,
          left: AppSpacing.sm,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: colorScheme.scrim.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppSpacing.sm),
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

  Widget _buildAddSlot() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 140,
      height: 180,
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        color: colorScheme.surfaceContainerLow,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 36,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'ここに追加',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageThumbnails() {
    final images = _images;
    final children = [
      ...images.asMap().entries.map(
            (e) => _buildThumbnail(e.key, e.value),
          ),
      if (_canAddImage) _buildAddSlot(),
    ];

    if (images.length == 1) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: children,
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: children),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final images = _images;

    return Scaffold(
      appBar: AppBar(title: const Text('Cheflens')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: AppSpacing.lg),

              // ステータスメッセージ
              if (_statusMessage.isNotEmpty) ...[
                StatusMessage(message: _statusMessage, type: _messageType),
                const SizedBox(height: AppSpacing.md),
              ],

              // 画像表示エリア
              SizedBox(
                height: 180,
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : images.isEmpty
                        ? _buildImagePlaceholder()
                        : _buildImageThumbnails(),
              ),

              const SizedBox(height: AppSpacing.sm),

              // 枚数インジケーター
              if (images.isNotEmpty)
                Text(
                  '${images.length} / $_maxImages 枚選択中',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _canAddImage
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.primary,
                  ),
                ),

              const SizedBox(height: AppSpacing.md),

              // 写真追加ボタン群
              SizedBox(
                width: 240,
                child: OutlinedButton.icon(
                  onPressed: (_loading || !_canAddImage) ? null : _pickFromCamera,
                  icon: const Icon(Icons.camera_alt, size: 20),
                  label: Text(images.isEmpty ? '写真を撮る' : '写真を追加'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: 240,
                child: OutlinedButton.icon(
                  onPressed: (_loading || !_canAddImage) ? null : _pickFromGallery,
                  icon: const Icon(Icons.photo_library, size: 20),
                  label: Text(images.isEmpty ? 'ギャラリーから選ぶ' : 'ギャラリーから追加'),
                ),
              ),

              if (!_canAddImage && images.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    '最大$_maxImages枚に達しました',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.primary,
                    ),
                  ),
                ),

              // 認識ボタン（メインアクション）
              if (images.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: 240,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _detectIngredients,
                    icon: const Icon(Icons.auto_awesome, size: 20),
                    label: Text(
                      images.length == 1 ? '食材を探す' : '${images.length}枚から食材を探す',
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
