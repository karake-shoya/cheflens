import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/food_data_provider.dart';
import '../providers/ingredient_selection_provider.dart';
import '../providers/recipe_state_provider.dart';
import 'ingredient_selection_dialog.dart';
import 'recipe_suggestion_screen.dart';

class ResultScreen extends ConsumerWidget {
  final File image;

  const ResultScreen({
    super.key,
    required this.image,
  });

  String _getDisplayName(String ingredientName, WidgetRef ref) {
    final translator = ref.read(ingredientTranslatorProvider);
    return translator.translateToJapanese(ingredientName);
  }

  Future<void> _showAddIngredientDialog(BuildContext context, WidgetRef ref) async {
    final selectionState = ref.read(ingredientSelectionProvider);
    final selectedIngredients = await showDialog<List<String>>(
      context: context,
      builder: (context) => IngredientSelectionDialog(
        alreadySelectedIngredients: selectionState.allIngredients,
      ),
    );

    if (selectedIngredients != null && selectedIngredients.isNotEmpty) {
      ref.read(ingredientSelectionProvider.notifier).addIngredients(selectedIngredients);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${selectedIngredients.length}個の食材を追加しました'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectionState = ref.watch(ingredientSelectionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('認識結果'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (selectionState.selectedIngredients.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Chip(
                  label: Text(
                    '${selectionState.selectedIngredients.length}個選択中',
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: Colors.blue.shade100,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              // 画像プレビュー
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      image,
                      height: 300,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // 検出結果
              if (selectionState.detectedIngredients.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade50, Colors.green.shade100],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(20),
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
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.restaurant_menu,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '検出された食材',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '${selectionState.detectedIngredients.length}件',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '使用する食材を選択してください',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: selectionState.allIngredients
                            .map(
                              (ingredientName) {
                                final isSelected = selectionState.selectionState[ingredientName] ?? false;
                                final isDetected = selectionState.detectedIngredients.contains(ingredientName);

                                return GestureDetector(
                                  onTap: () => ref
                                      .read(ingredientSelectionProvider.notifier)
                                      .toggleIngredient(ingredientName),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: isSelected
                                            ? [Colors.blue.shade400, Colors.blue.shade600]
                                            : [Colors.white, Colors.grey.shade100],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.blue.shade700
                                            : Colors.grey.shade300,
                                        width: isSelected ? 2 : 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: isSelected
                                              ? Colors.blue.withValues(alpha: 0.3)
                                              : Colors.black.withValues(alpha: 0.1),
                                          blurRadius: isSelected ? 6 : 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isSelected
                                              ? Icons.check_circle
                                              : Icons.circle_outlined,
                                          size: 20,
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _getDisplayName(ingredientName, ref),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.green.shade900,
                                          ),
                                        ),
                                        if (!isDetected && isSelected) ...[
                                          const SizedBox(width: 4),
                                          Icon(
                                            Icons.add_circle,
                                            size: 16,
                                            color: Colors.white.withValues(alpha: 0.8),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _showAddIngredientDialog(context, ref),
                          icon: const Icon(Icons.add_circle_outline, size: 20),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(
                                color: Colors.green.shade400, width: 1.5),
                          ),
                          label: Text(
                            '食材を追加',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (selectionState.selectedIngredients.isNotEmpty) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // レシピ画面に遷移する前にレシピ状態をリセット
                        ref.read(recipeStateProvider.notifier).reset();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => RecipeSuggestionScreen(
                              selectedIngredients: selectionState.selectedIngredients,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.restaurant_menu, size: 22),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      label: const Text(
                        'レシピを提案してもらう',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: 280,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, size: 20),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    label: const Text(
                      'カメラ画面に戻る',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 48,
                        color: Colors.orange.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '食材が検出されませんでした',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '別の画像で再度お試しください',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 280,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, size: 20),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    label: const Text(
                      'カメラ画面に戻る',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
