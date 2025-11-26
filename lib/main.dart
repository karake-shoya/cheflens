import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/food_data_model.dart';
import 'models/food_categories_jp_model.dart';
import 'services/food_data_service.dart';
import 'providers/food_data_provider.dart';
import 'screens/camera_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 環境変数を読み込み
  await dotenv.load(fileName: '.env');
  
  // アプリ起動時に一度だけデータをロード
  final FoodData foodData = await FoodDataService.loadFoodData();
  final FoodCategoriesJp foodCategoriesJp = await FoodDataService.loadFoodCategoriesJp();
  
  runApp(
    ProviderScope(
      overrides: [
        // プリロードしたデータでプロバイダーをオーバーライド
        foodDataProvider.overrideWithValue(foodData),
        foodCategoriesJpProvider.overrideWithValue(foodCategoriesJp),
      ],
      child: const MyApp(),
    ),
  );
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
