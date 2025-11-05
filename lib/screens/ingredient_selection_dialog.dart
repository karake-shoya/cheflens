import 'package:flutter/material.dart';
import '../models/food_categories_jp_model.dart';
import '../services/food_data_service.dart';

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
    if (_isLoading || _categoriesJp == null) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(16),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '食材を追加',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_selectedIngredients.isNotEmpty)
                  Chip(
                    label: Text(
                      '${_selectedIngredients.length}個選択中',
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: Colors.blue.shade100,
                  ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildCategoryList(_categoriesJp!.meats),
                  _buildCategoryList(_categoriesJp!.seafood),
                  _buildCategoryList(_categoriesJp!.processedSeafood),
                  _buildVegetableCategoriesList(_categoriesJp!.vegetableCategories),
                  _buildCategoryList(_categoriesJp!.fruits.toList()..sort((a, b) => a.compareTo(b))),
                  _buildCategoryList(_categoriesJp!.dairy),
                  _buildCategoryList(_categoriesJp!.others),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('キャンセル'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _addSelectedIngredients,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
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

  Widget _buildVegetableCategoriesList(List<VegetableCategory> categories) {
    final allItems = <String>[];
    for (var category in categories) {
      allItems.addAll(category.items);
    }
    
    if (allItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              '追加できる食材がありません',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                category.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            ...availableItems.map((ingredient) {
              final isSelected = _selectedIngredients.contains(ingredient);
              return InkWell(
                onTap: () => _toggleIngredient(ingredient),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue.shade50 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? Colors.blue.shade300 : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.check_circle : Icons.circle_outlined,
                        color: isSelected ? Colors.blue.shade600 : Colors.grey.shade400,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          ingredient,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected ? Colors.blue.shade900 : Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              '追加できる食材がありません',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: availableIngredients.length,
      itemBuilder: (context, index) {
        final ingredient = availableIngredients[index];
        final isSelected = _selectedIngredients.contains(ingredient);

        return InkWell(
          onTap: () => _toggleIngredient(ingredient),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue.shade50 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Colors.blue.shade300 : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  color: isSelected ? Colors.blue.shade600 : Colors.grey.shade400,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    ingredient,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected ? Colors.blue.shade900 : Colors.grey.shade800,
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

