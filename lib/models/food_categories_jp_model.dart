class FoodCategoriesJp {
  final List<String> rootVegetables;
  final List<String> leafStemVegetables;
  final List<String> fruitVegetablesBeans;
  final List<String> tubers;
  final List<String> aromaticVegetables;
  final List<String> mushrooms;
  final List<String> seaweed;
  final List<String> soyProducts;
  final List<String> fruits;
  final List<String> meats;
  final List<String> seafood;
  final List<String> processedSeafood;
  final List<String> dairy;
  final List<String> others;

  FoodCategoriesJp({
    required this.rootVegetables,
    required this.leafStemVegetables,
    required this.fruitVegetablesBeans,
    required this.tubers,
    required this.aromaticVegetables,
    required this.mushrooms,
    required this.seaweed,
    required this.soyProducts,
    required this.fruits,
    required this.meats,
    required this.seafood,
    required this.processedSeafood,
    required this.dairy,
    required this.others,
  });

  factory FoodCategoriesJp.fromJson(Map<String, dynamic> json) {
    final categories = json['categories'] as Map<String, dynamic>;
    return FoodCategoriesJp(
      rootVegetables: List<String>.from(categories['root_vegetables'] as List? ?? []),
      leafStemVegetables: List<String>.from(categories['leaf_stem_vegetables'] as List? ?? []),
      fruitVegetablesBeans: List<String>.from(categories['fruit_vegetables_beans'] as List? ?? []),
      tubers: List<String>.from(categories['tubers'] as List? ?? []),
      aromaticVegetables: List<String>.from(categories['aromatic_vegetables'] as List? ?? []),
      mushrooms: List<String>.from(categories['mushrooms'] as List? ?? []),
      seaweed: List<String>.from(categories['seaweed'] as List? ?? []),
      soyProducts: List<String>.from(categories['soy_products'] as List? ?? []),
      fruits: List<String>.from(categories['fruits'] as List),
      meats: List<String>.from(categories['meats'] as List),
      seafood: List<String>.from(categories['seafood'] as List),
      processedSeafood: List<String>.from(categories['processed_seafood'] as List? ?? []),
      dairy: List<String>.from(categories['dairy'] as List),
      others: List<String>.from(categories['others'] as List),
    );
  }

  List<String> getAllFoodNames() {
    return [
      ...rootVegetables,
      ...leafStemVegetables,
      ...fruitVegetablesBeans,
      ...tubers,
      ...aromaticVegetables,
      ...mushrooms,
      ...seaweed,
      ...soyProducts,
      ...fruits,
      ...meats,
      ...seafood,
      ...processedSeafood,
      ...dairy,
      ...others,
    ];
  }

  List<VegetableCategory> get vegetableCategories {
    return [
      VegetableCategory(name: '根菜類', items: rootVegetables),
      VegetableCategory(name: '葉茎菜類', items: leafStemVegetables),
      VegetableCategory(name: '果菜類・豆類', items: fruitVegetablesBeans),
      VegetableCategory(name: '芋類', items: tubers),
      VegetableCategory(name: '香味野菜・薬味', items: aromaticVegetables),
      VegetableCategory(name: 'きのこ類', items: mushrooms),
      VegetableCategory(name: '海藻類', items: seaweed),
      VegetableCategory(name: '豆・豆腐・加工品', items: soyProducts),
    ];
  }
}

class VegetableCategory {
  final String name;
  final List<String> items;

  VegetableCategory({
    required this.name,
    required this.items,
  });
}


