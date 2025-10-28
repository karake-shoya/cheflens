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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('データの読み込みに失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    setState(() {
      _loading = true;
      _detectedIngredients = [];
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('カメラの起動に失敗しました: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickFromGallery() async {
    setState(() {
      _loading = true;
      _detectedIngredients = [];
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('ギャラリー選択に失敗しました: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _recognizeIngredients() async {
    if (_image == null || _visionService == null) {
      if (mounted && _visionService == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('データが読み込まれていません。少々お待ちください。')),
        );
      }
      return;
    }

    setState(() => _loading = true);
    try {
      final ingredients = await _visionService!.detectIngredients(_image!);
      if (mounted) {
        setState(() => _detectedIngredients = ingredients);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${ingredients.length}件の食材を検出しました！')),
        );
      }
    } catch (e) {
      debugPrint('Recognition error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('認識に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _detectObjectsInFridge() async {
    if (_image == null || _visionService == null) {
      if (mounted && _visionService == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('データが読み込まれていません。少々お待ちください。')),
        );
      }
      return;
    }

    setState(() => _loading = true);
    try {
      final objects = await _visionService!.detectObjects(_image!);
      if (mounted) {
        // 物体検出の結果を表示（デバッグ用）
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${objects.length}個の物体を検出しました！')),
        );
        
        // 検出された物体名をリストに表示
        final objectNames = objects.map((obj) => '${obj.name} (${(obj.score * 100).toStringAsFixed(0)}%)').toList();
        setState(() => _detectedIngredients = objectNames);
      }
    } catch (e) {
      debugPrint('Object detection error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('物体検出に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _detectWithCombinedApproach() async {
    if (_image == null || _visionService == null) {
      if (mounted && _visionService == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('データが読み込まれていません。少々お待ちください。')),
        );
      }
      return;
    }

    setState(() => _loading = true);
    try {
      final ingredients = await _visionService!.detectIngredientsWithObjectDetection(_image!);
      if (mounted) {
        setState(() => _detectedIngredients = ingredients);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${ingredients.length}件の食材を検出しました！')),
        );
      }
    } catch (e) {
      debugPrint('Combined detection error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('認識に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _detectWithWebDetection() async {
    if (_image == null || _visionService == null) {
      if (mounted && _visionService == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('データが読み込まれていません。少々お待ちください。')),
        );
      }
      return;
    }

    setState(() => _loading = true);
    try {
      final ingredients = await _visionService!.detectWithWebDetection(_image!);
      if (mounted) {
        setState(() => _detectedIngredients = ingredients);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${ingredients.length}件の食材を検出しました！')),
        );
      }
    } catch (e) {
      debugPrint('Web detection error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Web検出に失敗しました: $e')),
        );
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
            if (_loading) const CircularProgressIndicator(),
            if (!_loading && _image == null) const Text('写真を撮って食材を認識できます。'),
            if (_image != null)
              Center(
                child: SizedBox(
                  height: 300,
                  child: Image.file(_image!, fit: BoxFit.contain),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: 280,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _takePhoto,
                icon: const Icon(Icons.camera_alt),
                label: const Text('写真を撮る'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 280,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _pickFromGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text('ギャラリーから選ぶ'),
              ),
            ),
            if (_image != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: 280,
                child: ElevatedButton(
                  onPressed: _loading ? null : _recognizeIngredients,
                  child: const Text('食材認識（Label Detection）'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 280,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _detectObjectsInFridge,
                  icon: const Icon(Icons.search),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  label: const Text('物体検出（Object Detection）'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 280,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _detectWithWebDetection,
                  icon: const Icon(Icons.language),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                  label: const Text('商品認識（Web Detection）'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 280,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _detectWithCombinedApproach,
                  icon: const Icon(Icons.auto_awesome),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  label: const Text('高精度認識（統合）'),
                ),
              ),
            ],
            if (_detectedIngredients.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                '検出された食材:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Center(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: _detectedIngredients
                      .map(
                        (ingredient) => Chip(
                          label: Text(ingredient),
                          backgroundColor: Colors.blue.shade100,
                        ),
                      )
                      .toList(),
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
