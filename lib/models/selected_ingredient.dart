class SelectedIngredient {
  final String name;
  final String? category;
  final bool isDetected;

  SelectedIngredient({
    required this.name,
    this.category,
    this.isDetected = false,
  });

  SelectedIngredient copyWith({
    String? name,
    String? category,
    bool? isDetected,
  }) {
    return SelectedIngredient(
      name: name ?? this.name,
      category: category ?? this.category,
      isDetected: isDetected ?? this.isDetected,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SelectedIngredient &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;
}

