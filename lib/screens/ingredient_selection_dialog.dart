import 'package:flutter/material.dart';
import '../models/food_categories_jp_model.dart';
import '../services/food_data_service.dart';
import '../theme/app_spacing.dart';

class IngredientSelectionDialog extends StatefulWidget {
  final List<String> alreadySelectedIngredients;

  const IngredientSelectionDialog({
    super.key,
    required this.alreadySelectedIngredients,
  });

  @override
  State<IngredientSelectionDialog> createState() => _IngredientSelectionDialogState();
}

class _IngredientSelectionDialogState extends State<IngredientSelectionDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _selectedIngredients = {};
  FoodCategoriesJp? _categoriesJp;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _loadCategoriesJp();
  }

  Future<void> _loadCategoriesJp() async {
    try {
      final categoriesJp = await FoodDataService.loadFoodCategoriesJp();
      if (mounted) {
        setState(() {
          _categoriesJp = categoriesJp;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load food categories JP: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggleIngredient(String ingredient) {
    setState(() {
      if (_selectedIngredients.contains(ingredient)) {
        _selectedIngredients.remove(ingredient);
      } else {
        _selectedIngredients.add(ingredient);
      }
    });
  }

  void _addSelectedIngredients() {
    if (_selectedIngredients.isNotEmpty) {
      Navigator.of(context).pop(_selectedIngredients.toList());
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading || _categoriesJp == null) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            // ヘッダー
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '食材を追加',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (_selectedIngredients.isNotEmpty)
                  Chip(
                    label: Text(
                      '${_selectedIngredients.length}個選択中',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                    backgroundColor: colorScheme.primary,
                    padding: EdgeInsets.zero,
                  ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.sm),

            // タブバー
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: const [
                Tab(text: '肉', icon: Icon(Icons.set_meal, size: 18)),
                Tab(text: '魚介', icon: Icon(Icons.water_drop, size: 18)),
                Tab(text: '練り物', icon: Icon(Icons.ramen_dining, size: 18)),
                Tab(text: '野菜', icon: Icon(Icons.eco, size: 18)),
                Tab(text: '果物', icon: Icon(Icons.apple, size: 18)),
                Tab(text: '乳製品', icon: Icon(Icons.local_dining, size: 18)),
                Tab(text: 'その他', icon: Icon(Icons.restaurant, size: 18)),
              ],
            ),

            // タブコンテンツ
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildCategoryList(_categoriesJp!.meats),
                  _buildCategoryList(_categoriesJp!.seafood),
                  _buildCategoryList(_categoriesJp!.processedSeafood),
                  _buildVegetableCategoriesList(_categoriesJp!.vegetableCategories),
                  _buildCategoryList(
                    _categoriesJp!.fruits.toList()..sort((a, b) => a.compareTo(b)),
                  ),
                  _buildCategoryList(_categoriesJp!.dairy),
                  _buildCategoryList(_categoriesJp!.others),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            // フッターボタン
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('キャンセル'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _addSelectedIngredients,
                    child: Text(
                      _selectedIngredients.isEmpty
                          ? '追加'
                          : '${_selectedIngredients.length}個追加',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 食材がない場合の空状態ウィジェット
  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '追加できる食材がありません',
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVegetableCategoriesList(List<VegetableCategory> categories) {
    final allItems = <String>[];
    for (final category in categories) {
      allItems.addAll(category.items);
    }

    if (allItems.isEmpty) {
      return _buildEmptyState();
    }

    final colorScheme = Theme.of(context).colorScheme;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: categories.length,
      itemBuilder: (context, categoryIndex) {
        final category = categories[categoryIndex];
        final availableItems = category.items
            .where((item) => !widget.alreadySelectedIngredients.contains(item))
            .toList();

        if (availableItems.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Text(
                category.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            ...availableItems.map((ingredient) {
              final isSelected = _selectedIngredients.contains(ingredient);
              return InkWell(
                onTap: () => _toggleIngredient(ingredient),
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    vertical: 2,
                    horizontal: AppSpacing.sm,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primaryContainer
                        : colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.outlineVariant,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.check_circle : Icons.circle_outlined,
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                        size: AppSpacing.iconSm,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          ingredient,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected
                                ? colorScheme.onPrimaryContainer
                                : colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: AppSpacing.sm),
          ],
        );
      },
    );
  }

  Widget _buildCategoryList(List<String> ingredients) {
    final availableIngredients = ingredients
        .where((ingredient) => !widget.alreadySelectedIngredients.contains(ingredient))
        .toList();

    if (availableIngredients.isEmpty) {
      return _buildEmptyState();
    }

    final colorScheme = Theme.of(context).colorScheme;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: availableIngredients.length,
      itemBuilder: (context, index) {
        final ingredient = availableIngredients[index];
        final isSelected = _selectedIngredients.contains(ingredient);

        return InkWell(
          onTap: () => _toggleIngredient(ingredient),
          child: Container(
            margin: const EdgeInsets.symmetric(
              vertical: AppSpacing.xs,
              horizontal: AppSpacing.sm,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  size: AppSpacing.iconMd,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    ingredient,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
