class FoodData {
  final String version;
  final String lastUpdated;
  final String description;
  final FilteringConfig filtering;
  final TextDetectionConfig? textDetection;
  final FoodCategories foods;
  final List<SimilarPair> similarPairs;
  final Map<String, String> translations;
  final String? translationFile;

  FoodData({
    required this.version,
    required this.lastUpdated,
    required this.description,
    required this.filtering,
    this.textDetection,
    required this.foods,
    required this.similarPairs,
    required this.translations,
    this.translationFile,
  });

  factory FoodData.fromJson(Map<String, dynamic> json) {
    return FoodData(
      version: json['version'] as String,
      lastUpdated: json['last_updated'] as String,
      description: json['description'] as String,
      filtering:
          FilteringConfig.fromJson(json['filtering'] as Map<String, dynamic>),
      textDetection: json['text_detection'] != null
          ? TextDetectionConfig.fromJson(
              json['text_detection'] as Map<String, dynamic>)
          : null,
      foods: FoodCategories.fromJson(json['foods'] as Map<String, dynamic>),
      similarPairs: (json['similar_pairs'] as List)
          .map((e) => SimilarPair.fromJson(e as Map<String, dynamic>))
          .toList(),
      translations: json['translations'] != null
          ? Map<String, String>.from(json['translations'] as Map)
          : <String, String>{},
      translationFile: json['translation_file'] as String?,
    );
  }

  List<String> getAllFoodNames() {
    return [
      ...foods.vegetables,
      ...foods.fruits,
      ...foods.meats,
      ...foods.seafood,
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
    if (foods.seafood.any((f) => lowerName.contains(f.toLowerCase()))) {
      return 'seafood';
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
  final double objectDetectionConfidenceThreshold;
  final int minCropSize;
  final List<String> excludeKeywords;
  final List<String> genericCategories;
  final List<String> genericPatterns;
  final List<String> genericKeywords;

  FilteringConfig({
    required this.confidenceThreshold,
    required this.objectDetectionConfidenceThreshold,
    required this.minCropSize,
    required this.excludeKeywords,
    required this.genericCategories,
    required this.genericPatterns,
    required this.genericKeywords,
  });

  factory FilteringConfig.fromJson(Map<String, dynamic> json) {
    return FilteringConfig(
      confidenceThreshold: (json['confidence_threshold'] as num).toDouble(),
      objectDetectionConfidenceThreshold:
          (json['object_detection_confidence_threshold'] as num?)?.toDouble() ??
              0.50,
      minCropSize: (json['min_crop_size'] as num?)?.toInt() ?? 50,
      excludeKeywords: List<String>.from(json['exclude_keywords'] as List),
      genericCategories: List<String>.from(json['generic_categories'] as List),
      genericPatterns:
          List<String>.from(json['generic_patterns'] as List? ?? []),
      genericKeywords:
          List<String>.from(json['generic_keywords'] as List? ?? []),
    );
  }
}

class TextDetectionConfig {
  final List<ProductPattern> productPatterns;
  final List<String> productNames;
  final List<String> productKeywords;
  final List<JapaneseVariant> japaneseVariants;
  final Map<String, List<String>> falsePositivePatterns;

  TextDetectionConfig({
    required this.productPatterns,
    required this.productNames,
    required this.productKeywords,
    required this.japaneseVariants,
    required this.falsePositivePatterns,
  });

  factory TextDetectionConfig.fromJson(Map<String, dynamic> json) {
    return TextDetectionConfig(
      productPatterns: (json['product_patterns'] as List?)
              ?.map((e) => ProductPattern.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      productNames: List<String>.from(json['product_names'] as List? ?? []),
      productKeywords:
          List<String>.from(json['product_keywords'] as List? ?? []),
      japaneseVariants: (json['japanese_variants'] as List?)
              ?.map((e) => JapaneseVariant.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      falsePositivePatterns:
          (json['false_positive_patterns'] as Map<String, dynamic>?)?.map(
                (key, value) =>
                    MapEntry(key, List<String>.from(value as List)),
              ) ??
              {},
    );
  }
}

class ProductPattern {
  final String pattern;
  final String ingredient;
  final int priority;

  ProductPattern({
    required this.pattern,
    required this.ingredient,
    this.priority = 1,
  });

  factory ProductPattern.fromJson(Map<String, dynamic> json) {
    return ProductPattern(
      pattern: json['pattern'] as String,
      ingredient: json['ingredient'] as String,
      priority: (json['priority'] as num?)?.toInt() ?? 1,
    );
  }

  RegExp toRegExp() => RegExp(pattern, caseSensitive: false);
}

class JapaneseVariant {
  final List<String> variants;
  final String standard;

  JapaneseVariant({
    required this.variants,
    required this.standard,
  });

  factory JapaneseVariant.fromJson(Map<String, dynamic> json) {
    return JapaneseVariant(
      variants: List<String>.from(json['variants'] as List),
      standard: json['standard'] as String,
    );
  }
}

class FoodCategories {
  final List<String> vegetables;
  final List<String> fruits;
  final List<String> meats;
  final List<String> seafood;
  final List<String> dairy;
  final List<String> others;

  FoodCategories({
    required this.vegetables,
    required this.fruits,
    required this.meats,
    required this.seafood,
    required this.dairy,
    required this.others,
  });

  factory FoodCategories.fromJson(Map<String, dynamic> json) {
    return FoodCategories(
      vegetables: List<String>.from(json['vegetables'] as List),
      fruits: List<String>.from(json['fruits'] as List),
      meats: List<String>.from(json['meats'] as List),
      seafood: List<String>.from(json['seafood'] as List? ?? []),
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
