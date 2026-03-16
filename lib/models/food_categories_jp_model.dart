/// 食材サブカテゴリ（例: 「牛肉」「魚介類」など）
class FoodSubcategory {
  final String name;
  final List<String> items;

  const FoodSubcategory({required this.name, required this.items});

  factory FoodSubcategory.fromJson(Map<String, dynamic> json) {
    return FoodSubcategory(
      name: json['name'] as String,
      items: List<String>.from(json['items'] as List),
    );
  }
}

/// 食材カテゴリ（タブ1つ分。例: 「肉・魚」「野菜」など）
class FoodCategory {
  final String id;
  final String label;
  final List<FoodSubcategory> subcategories;

  const FoodCategory({
    required this.id,
    required this.label,
    required this.subcategories,
  });

  factory FoodCategory.fromJson(Map<String, dynamic> json) {
    return FoodCategory(
      id: json['id'] as String,
      label: json['label'] as String,
      subcategories: (json['subcategories'] as List)
          .map((s) => FoodSubcategory.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }

  /// このカテゴリの全食材を平坦化して返す（検索などに使用）
  List<String> get allItems =>
      subcategories.expand((s) => s.items).toList();
}

/// 全カテゴリをまとめたルートモデル
class FoodCategoriesJp {
  final String version;
  final List<FoodCategory> categories;

  const FoodCategoriesJp({
    required this.version,
    required this.categories,
  });

  factory FoodCategoriesJp.fromJson(Map<String, dynamic> json) {
    return FoodCategoriesJp(
      version: json['version'] as String,
      categories: (json['categories'] as List)
          .map((c) => FoodCategory.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }

  /// 全カテゴリの食材名を横断して返す（検索に使用）
  List<String> getAllFoodNames() =>
      categories.expand((c) => c.allItems).toList();
}
