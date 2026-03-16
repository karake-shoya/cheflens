/// Geminiが認識した食材と、レシピのメイン食材かどうかを保持するモデル
class DetectedIngredient {
  final String name;

  /// メイン食材かどうか
  /// true : 肉・魚・野菜・豆腐・卵・麺・米など → デフォルトで選択状態
  /// false: 調味料・ソース・スパイスなど       → デフォルトで未選択
  final bool isPrimary;

  const DetectedIngredient({
    required this.name,
    required this.isPrimary,
  });

  factory DetectedIngredient.fromJson(Map<String, dynamic> json) {
    return DetectedIngredient(
      name: (json['name'] as String?)?.trim() ?? '',
      // primary キーが存在しない場合はメイン食材として扱う
      isPrimary: json['primary'] as bool? ?? true,
    );
  }
}
