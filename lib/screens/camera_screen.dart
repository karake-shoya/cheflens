import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/vision_service.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final ImagePicker _picker = ImagePicker();
  final VisionService _visionService = VisionService();
  File? _image;
  bool _loading = false;
  List<String> _detectedIngredients = [];

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
    if (_image == null) return;

    setState(() => _loading = true);
    try {
      final ingredients = await _visionService.detectIngredients(_image!);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cheflens - カメラ')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_loading) const CircularProgressIndicator(),
            if (!_loading && _image == null) const Text('写真を撮って食材を認識できます。'),
            if (_image != null)
              SizedBox(
                height: 300,
                child: Image.file(_image!, fit: BoxFit.cover),
              ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loading ? null : _takePhoto,
              icon: const Icon(Icons.camera_alt),
              label: const Text('写真を撮る'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _loading ? null : _pickFromGallery,
              icon: const Icon(Icons.photo_library),
              label: const Text('ギャラリーから選ぶ'),
            ),
            if (_image != null) ...[
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _loading ? null : _recognizeIngredients,
                child: const Text('認識を実行（次へ）'),
              ),
            ],
            if (_detectedIngredients.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                '検出された食材:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _detectedIngredients
                    .map(
                      (ingredient) => Chip(
                        label: Text(ingredient),
                        backgroundColor: Colors.blue.shade100,
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
