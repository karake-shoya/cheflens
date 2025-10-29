import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/vision_service.dart';
import '../services/food_data_service.dart';

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
  List<String> _detectedIngredients = [];
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    try {
      final foodData = await FoodDataService.loadFoodData();
      setState(() {
        _visionService = VisionService(foodData);
      });
    } catch (e) {
      debugPrint('Failed to initialize food data: $e');
      if (mounted) {
        setState(() => _statusMessage = 'データの読み込みに失敗しました');
      }
    }
  }

  Future<void> _takePhoto() async {
    setState(() {
      _loading = true;
      _detectedIngredients = [];
      _statusMessage = '';
    });
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
      debugPrint('Camera error: $e');
      if (mounted) {
        setState(() => _statusMessage = 'カメラの起動に失敗しました');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickFromGallery() async {
    setState(() {
      _loading = true;
      _detectedIngredients = [];
      _statusMessage = '';
    });
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1280,
      );
      if (file != null) setState(() => _image = File(file.path));
    } catch (e) {
      debugPrint('Gallery error: $e');
      if (mounted) {
        setState(() => _statusMessage = 'ギャラリー選択に失敗しました');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _recognizeIngredients() async {
    if (_image == null || _visionService == null) {
      if (mounted && _visionService == null) {
        setState(() => _statusMessage = 'データが読み込まれていません');
      }
      return;
    }

    setState(() {
      _loading = true;
      _statusMessage = '認識中...';
    });
    try {
      final ingredients = await _visionService!.detectIngredients(_image!);
      if (mounted) {
        setState(() {
          _detectedIngredients = ingredients;
          _statusMessage = '${ingredients.length}件の食材を検出しました';
        });
      }
    } catch (e) {
      debugPrint('Recognition error: $e');
      if (mounted) {
        setState(() => _statusMessage = '認識に失敗しました');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _detectObjectsInFridge() async {
    if (_image == null || _visionService == null) {
      if (mounted && _visionService == null) {
        setState(() => _statusMessage = 'データが読み込まれていません');
      }
      return;
    }

    setState(() {
      _loading = true;
      _statusMessage = '物体検出中...';
    });
    try {
      final objects = await _visionService!.detectObjects(_image!);
      if (mounted) {
        final objectNames = objects.map((obj) => '${obj.name} (${(obj.score * 100).toStringAsFixed(0)}%)').toList();
        setState(() {
          _detectedIngredients = objectNames;
          _statusMessage = '${objects.length}個の物体を検出しました';
        });
      }
    } catch (e) {
      debugPrint('Object detection error: $e');
      if (mounted) {
        setState(() => _statusMessage = '物体検出に失敗しました');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _detectWithCombinedApproach() async {
    if (_image == null || _visionService == null) {
      if (mounted && _visionService == null) {
        setState(() => _statusMessage = 'データが読み込まれていません');
      }
      return;
    }

    setState(() {
      _loading = true;
      _statusMessage = '高精度認識中...（数秒かかります）';
    });
    try {
      final ingredients = await _visionService!.detectIngredientsWithObjectDetection(_image!);
      if (mounted) {
        setState(() {
          _detectedIngredients = ingredients;
          _statusMessage = '${ingredients.length}件の食材を検出しました';
        });
      }
    } catch (e) {
      debugPrint('Combined detection error: $e');
      if (mounted) {
        setState(() => _statusMessage = '認識に失敗しました');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _detectWithWebDetection() async {
    if (_image == null || _visionService == null) {
      if (mounted && _visionService == null) {
        setState(() => _statusMessage = 'データが読み込まれていません');
      }
      return;
    }

    setState(() {
      _loading = true;
      _statusMessage = 'Web検出中...';
    });
    try {
      final ingredients = await _visionService!.detectWithWebDetection(_image!);
      if (mounted) {
        setState(() {
          _detectedIngredients = ingredients;
          _statusMessage = '${ingredients.length}件の食材を検出しました';
        });
      }
    } catch (e) {
      debugPrint('Web detection error: $e');
      if (mounted) {
        setState(() => _statusMessage = 'Web検出に失敗しました');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            if (_statusMessage.isNotEmpty && _detectedIngredients.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade100, Colors.blue.shade50],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _statusMessage,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
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
                label: const Text('写真を撮る', style: TextStyle(fontSize: 14)),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 240,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _pickFromGallery,
                icon: const Icon(Icons.photo_library, size: 20),
                label: const Text('ギャラリーから選ぶ', style: TextStyle(fontSize: 14)),
              ),
            ),
            if (_image != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: 240,
                child: ElevatedButton(
                  onPressed: _loading ? null : _recognizeIngredients,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text('食材認識', style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 240,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _detectObjectsInFridge,
                  icon: const Icon(Icons.search, size: 18),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  label: const Text('物体検出', style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 240,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _detectWithWebDetection,
                  icon: const Icon(Icons.language, size: 18),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  label: const Text('商品認識', style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(height: 6),
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
                  label: const Text('高精度認識（統合）', style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
            if (_detectedIngredients.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade50, Colors.green.shade100],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.restaurant_menu,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '検出された食材',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_detectedIngredients.length}件',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: _detectedIngredients
                          .map(
                            (ingredient) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.white, Colors.blue.shade50],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    size: 16,
                                    color: Colors.green.shade600,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    ingredient,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green.shade900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
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
