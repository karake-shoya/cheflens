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
  State<IngredientSelectionDialog> createState() =>
      _IngredientSelectionDialogState();
}

class _IngredientSelectionDialogState extends State<IngredientSelectionDialog>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  final Set<String> _selectedIngredients = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  FoodCategoriesJp? _categoriesJp;
  bool _isLoading = true;

  // カテゴリIDとアイコンのマッピング
  static const _categoryIcons = <String, IconData>{
    'meat_fish': Icons.set_meal,
    'vegetables': Icons.eco,
    'fruits_dairy': Icons.apple,
    'others': Icons.restaurant,
  };

  @override
  void initState() {
    super.initState();
    _loadCategoriesJp();
  }

  Future<void> _loadCategoriesJp() async {
    try {
      final data = await FoodDataService.loadFoodCategoriesJp();
      if (mounted) {
        setState(() {
          _categoriesJp = data;
          _tabController = TabController(
            length: data.categories.length,
            vsync: this,
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load food categories: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _searchController.dispose();
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
    Navigator.of(context).pop(
      _selectedIngredients.isNotEmpty ? _selectedIngredients.toList() : null,
    );
  }

  // ── ウィジェット構築 ─────────────────────────────────

  /// 食材1行分のリストアイテム
  Widget _buildIngredientItem(String ingredient) {
    final colorScheme = Theme.of(context).colorScheme;
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
            color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
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
                  fontSize: 15,
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
  }

  /// 空状態ウィジェット
  Widget _buildEmptyState(String message) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 56,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            message,
            style: TextStyle(fontSize: 15, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  /// サブカテゴリ表示（各タブ共通）
  Widget _buildSubcategoryList(FoodCategory category) {
    final colorScheme = Theme.of(context).colorScheme;

    // 追加可能なアイテムが1件もない場合
    final hasAny = category.subcategories.any((sub) => sub.items
        .any((item) => !widget.alreadySelectedIngredients.contains(item)));
    if (!hasAny) return _buildEmptyState('追加できる食材がありません');

    final items = <Widget>[];
    for (final sub in category.subcategories) {
      final available = sub.items
          .where((item) => !widget.alreadySelectedIngredients.contains(item))
          .toList();
      if (available.isEmpty) continue;

      // サブカテゴリヘッダー
      items.add(
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.lg,
            bottom: AppSpacing.xs,
          ),
          child: Text(
            sub.name,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );

      for (final ingredient in available) {
        items.add(_buildIngredientItem(ingredient));
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      children: items,
    );
  }

  /// 検索結果ビュー（全カテゴリ横断）
  Widget _buildSearchResults() {
    final query = _searchQuery.toLowerCase();
    final results = <String>[];

    for (final cat in _categoriesJp!.categories) {
      for (final item in cat.allItems) {
        if (!widget.alreadySelectedIngredients.contains(item) &&
            item.contains(query)) {
          results.add(item);
        }
      }
    }

    if (results.isEmpty) {
      return _buildEmptyState('「$_searchQuery」に一致する食材が見つかりません');
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: results.length,
      itemBuilder: (_, i) => _buildIngredientItem(results[i]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // ── ロード中 ──────────────────────────────────────
    if (_isLoading || _categoriesJp == null) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final isSearching = _searchQuery.isNotEmpty;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            // ── ヘッダー ───────────────────────────────
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

            // ── 検索バー ──────────────────────────────
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '食材を検索...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: isSearching
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.sm,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),

            const SizedBox(height: AppSpacing.sm),

            // ── メインコンテンツ ──────────────────────
            if (!isSearching) ...[
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: _categoriesJp!.categories.map((cat) {
                  return Tab(
                    text: cat.label,
                    icon: Icon(
                      _categoryIcons[cat.id] ?? Icons.category,
                      size: 18,
                    ),
                    iconMargin: const EdgeInsets.only(bottom: 2),
                  );
                }).toList(),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: _categoriesJp!.categories
                      .map(_buildSubcategoryList)
                      .toList(),
                ),
              ),
            ] else
              Expanded(child: _buildSearchResults()),

            const SizedBox(height: AppSpacing.sm),

            // ── フッターボタン ─────────────────────────
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
}
