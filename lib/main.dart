import 'package:flutter/material.dart';
import 'screens/camera_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChefLens',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const CameraScreen(),
    );
  }
}
