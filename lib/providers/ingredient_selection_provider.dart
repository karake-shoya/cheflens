import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/selected_ingredient.dart';

/// 食材選択状態
class IngredientSelectionState {
  final Map<String, bool> selectionState;
  final List<String> detectedIngredients;

  const IngredientSelectionState({
    this.selectionState = const {},
    this.detectedIngredients = const [],
  });

  /// 選択された食材のリスト
  List<SelectedIngredient> get selectedIngredients {
    return selectionState.entries
        .where((entry) => entry.value == true)
        .map((entry) => SelectedIngredient(
              name: entry.key,
              isDetected: detectedIngredients.contains(entry.key),
            ))
        .toList();
  }

  /// 全ての食材のリスト
  List<String> get allIngredients {
    return selectionState.keys.toList();
  }

  IngredientSelectionState copyWith({
    Map<String, bool>? selectionState,
    List<String>? detectedIngredients,
  }) {
    return IngredientSelectionState(
      selectionState: selectionState ?? this.selectionState,
      detectedIngredients: detectedIngredients ?? this.detectedIngredients,
    );
  }
}

/// 食材選択を管理するNotifier
class IngredientSelectionNotifier extends StateNotifier<IngredientSelectionState> {
  IngredientSelectionNotifier() : super(const IngredientSelectionState());

  /// 検出された食材で初期化（全て選択状態）
  void initializeWithDetectedIngredients(List<String> ingredients) {
    final selectionState = <String, bool>{};
    for (var ingredient in ingredients) {
      selectionState[ingredient] = true;
    }
    state = IngredientSelectionState(
      selectionState: selectionState,
      detectedIngredients: ingredients,
    );
  }

  /// 食材の選択状態をトグル
  void toggleIngredient(String ingredientName) {
    final newState = Map<String, bool>.from(state.selectionState);
    newState[ingredientName] = !(newState[ingredientName] ?? false);
    state = state.copyWith(selectionState: newState);
  }

  /// 食材が選択されているかどうか
  bool isSelected(String ingredientName) {
    return state.selectionState[ingredientName] ?? false;
  }

  /// 新しい食材を追加（選択状態で）
  void addIngredients(List<String> ingredients) {
    final newState = Map<String, bool>.from(state.selectionState);
    for (var ingredient in ingredients) {
      newState[ingredient] = true;
    }
    state = state.copyWith(selectionState: newState);
  }

  /// 状態をリセット
  void reset() {
    state = const IngredientSelectionState();
  }
}

/// 食材選択状態のプロバイダー
final ingredientSelectionProvider =
    StateNotifierProvider<IngredientSelectionNotifier, IngredientSelectionState>((ref) {
  return IngredientSelectionNotifier();
});

