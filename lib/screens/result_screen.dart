import 'dart:io';
import 'package:flutter/material.dart';
import '../models/detected_ingredient.dart';
import '../models/selected_ingredient.dart';
import '../theme/app_spacing.dart';
import '../widgets/ingredient_chip.dart';
import 'ingredient_selection_dialog.dart';
import 'recipe_suggestion_screen.dart';

class ResultScreen extends StatefulWidget {
  final List<File> images;
  final List<DetectedIngredient> detectedIngredients;

  const ResultScreen({
    super.key,
    required this.images,
    required this.detectedIngredients,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final Map<String, bool> _ingredientSelectionState = {};

  @override
  void initState() {
    super.initState();
    // メイン食材（primary: true）は選択済み、脇役食材は未選択で初期化
    for (final ingredient in widget.detectedIngredients) {
      _ingredientSelectionState[ingredient.name] = ingredient.isPrimary;
    }
  }

  void _toggleIngredientSelection(String name) {
    setState(() {
      _ingredientSelectionState[name] = !(_ingredientSelectionState[name] ?? false);
    });
  }

  bool _isIngredientSelected(String name) =>
      _ingredientSelectionState[name] ?? false;

  List<SelectedIngredient> get _selectedIngredientsList {
    return _ingredientSelectionState.entries
        .where((e) => e.value)
        .map((e) => SelectedIngredient(
              name: e.key,
              isDetected: widget.detectedIngredients.any((d) => d.name == e.key),
            ))
        .toList();
  }

  List<String> get _allIngredients => _ingredientSelectionState.keys.toList();

  Future<void> _showAddIngredientDialog() async {
    final selected = await showDialog<List<String>>(
      context: context,
      builder: (context) => IngredientSelectionDialog(
        alreadySelectedIngredients: _allIngredients,
      ),
    );

    if (!mounted) return;

    if (selected != null && selected.isNotEmpty) {
      setState(() {
        for (final name in selected) {
          _ingredientSelectionState[name] = true;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${selected.length}個の食材を追加しました'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('認識結果'),
        actions: [
          if (_selectedIngredientsList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.lg),
              child: Center(
                child: Chip(
                  label: Text(
                    '${_selectedIngredientsList.length}個選択中',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: AppSpacing.lg),

              // 画像プレビュー
              _buildImagePreview(colorScheme),

              const SizedBox(height: AppSpacing.xxl),

              // 検出結果 or 未検出メッセージ
              if (widget.detectedIngredients.isNotEmpty)
                _buildDetectedSection(colorScheme)
              else
                _buildEmptyState(colorScheme),

              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  // ── 画像プレビュー ───────────────────────────────────

  Widget _buildImagePreview(ColorScheme colorScheme) {
    if (widget.images.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Image.file(
          widget.images.first,
          height: 280,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    }

    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: widget.images.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) => Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: Image.file(
                widget.images[index],
                height: 180,
                width: 140,
                fit: BoxFit.cover,
              ),
            ),
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
        ),
      ),
    );
  }

  // ── 検出食材セクション ────────────────────────────────

  Widget _buildDetectedSection(ColorScheme colorScheme) {
    return Column(
      children: [
        // セクションカード
        Card(
          color: colorScheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                // ヘッダー
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.restaurant_menu,
                      color: colorScheme.primary,
                      size: AppSpacing.iconMd,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '検出された食材',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Chip(
                      label: Text(
                        '${widget.detectedIngredients.length}件',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onPrimary,
                        ),
                      ),
                      backgroundColor: colorScheme.primary,
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'メイン食材は選択済み・脇役食材は未選択です',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // 食材チップ
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  alignment: WrapAlignment.center,
                  children: _allIngredients.map((name) {
                    final isSelected = _isIngredientSelected(name);
                    final isDetected =
                        widget.detectedIngredients.any((d) => d.name == name);
                    return IngredientChip(
                      name: name,
                      isSelected: isSelected,
                      showAddedBadge: !isDetected,
                      onTap: () => _toggleIngredientSelection(name),
                    );
                  }).toList(),
                ),

                const SizedBox(height: AppSpacing.lg),

                // 食材追加ボタン
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _showAddIngredientDialog,
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    label: const Text('食材を追加'),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.xxl),

        // レシピ提案ボタン（メインアクション）
        if (_selectedIngredientsList.isNotEmpty) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => RecipeSuggestionScreen(
                    selectedIngredients: _selectedIngredientsList,
                  ),
                ),
              ),
              icon: const Icon(Icons.restaurant_menu, size: AppSpacing.iconMd),
              label: const Text(
                'レシピを提案してもらう',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        // カメラ画面に戻るボタン
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, size: 20),
            label: const Text('カメラ画面に戻る'),
          ),
        ),
      ],
    );
  }

  // ── 食材未検出 ───────────────────────────────────────

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Column(
      children: [
        Card(
          color: colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              children: [
                Icon(
                  Icons.search_off,
                  size: 48,
                  color: colorScheme.onErrorContainer,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '食材が検出されませんでした',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onErrorContainer,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '別の画像で再度お試しください',
                  style: TextStyle(color: colorScheme.onErrorContainer),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, size: 20),
            label: const Text('カメラ画面に戻る'),
          ),
        ),
      ],
    );
  }
}
