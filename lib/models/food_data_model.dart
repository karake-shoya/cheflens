class FoodData {
  final String version;
  final String lastUpdated;
  final String description;
  final FilteringConfig filtering;
  final FoodCategories foods;
  final List<SimilarPair> similarPairs;
  final Map<String, String> translations;

  FoodData({
    required this.version,
    required this.lastUpdated,
    required this.description,
    required this.filtering,
    required this.foods,
    required this.similarPairs,
    required this.translations,
  });

  factory FoodData.fromJson(Map<String, dynamic> json) {
    return FoodData(
      version: json['version'] as String,
      lastUpdated: json['last_updated'] as String,
      description: json['description'] as String,
      filtering: FilteringConfig.fromJson(json['filtering'] as Map<String, dynamic>),
      foods: FoodCategories.fromJson(json['foods'] as Map<String, dynamic>),
      similarPairs: (json['similar_pairs'] as List)
          .map((e) => SimilarPair.fromJson(e as Map<String, dynamic>))
          .toList(),
      translations: Map<String, String>.from(json['translations'] as Map),
    );
  }

  List<String> getAllFoodNames() {
    return [
      ...foods.vegetables,
      ...foods.fruits,
      ...foods.meats,
      ...foods.dairy,
      ...foods.others,
    ];
  }

  String? getCategoryOfFood(String foodName) {
    final lowerName = foodName.toLowerCase();
    
    if (foods.vegetables.any((f) => lowerName.contains(f.toLowerCase()))) {
      return 'vegetable';
    }
    if (foods.fruits.any((f) => lowerName.contains(f.toLowerCase()))) {
      return 'fruit';
    }
    if (foods.meats.any((f) => lowerName.contains(f.toLowerCase()))) {
      return 'meat';
    }
    if (foods.dairy.any((f) => lowerName.contains(f.toLowerCase()))) {
      return 'dairy';
    }
    if (foods.others.any((f) => lowerName.contains(f.toLowerCase()))) {
      return 'other';
    }
    
    return null;
  }
}

class FilteringConfig {
  final double confidenceThreshold;
  final List<String> excludeKeywords;
  final List<String> genericCategories;

  FilteringConfig({
    required this.confidenceThreshold,
    required this.excludeKeywords,
    required this.genericCategories,
  });

  factory FilteringConfig.fromJson(Map<String, dynamic> json) {
    return FilteringConfig(
      confidenceThreshold: (json['confidence_threshold'] as num).toDouble(),
      excludeKeywords: List<String>.from(json['exclude_keywords'] as List),
      genericCategories: List<String>.from(json['generic_categories'] as List),
    );
  }
}

class FoodCategories {
  final List<String> vegetables;
  final List<String> fruits;
  final List<String> meats;
  final List<String> dairy;
  final List<String> others;

  FoodCategories({
    required this.vegetables,
    required this.fruits,
    required this.meats,
    required this.dairy,
    required this.others,
  });

  factory FoodCategories.fromJson(Map<String, dynamic> json) {
    return FoodCategories(
      vegetables: List<String>.from(json['vegetables'] as List),
      fruits: List<String>.from(json['fruits'] as List),
      meats: List<String>.from(json['meats'] as List),
      dairy: List<String>.from(json['dairy'] as List),
      others: List<String>.from(json['others'] as List),
    );
  }
}

class SimilarPair {
  final String primary;
  final List<String> similar;
  final String? note;

  SimilarPair({
    required this.primary,
    required this.similar,
    this.note,
  });

  factory SimilarPair.fromJson(Map<String, dynamic> json) {
    return SimilarPair(
      primary: json['primary'] as String,
      similar: List<String>.from(json['similar'] as List),
      note: json['note'] as String?,
    );
  }

  bool contains(String food1, String food2) {
    final lower1 = food1.toLowerCase();
    final lower2 = food2.toLowerCase();
    final lowerPrimary = primary.toLowerCase();
    
    final allItems = [lowerPrimary, ...similar.map((s) => s.toLowerCase())];
    
    return allItems.contains(lower1) && allItems.contains(lower2);
  }
}

