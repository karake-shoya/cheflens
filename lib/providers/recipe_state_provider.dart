import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/selected_ingredient.dart';
import '../services/recipe_api_service.dart';

/// レシピ画面の状態
class RecipeState {
  final List<RecipeCandidate>? recipeCandidates;
  final String? selectedRecipeTitle;
  final String? recipeContent;
  final bool isLoadingCandidates;
  final bool isLoadingDetails;
  final String? errorMessage;
  final Map<String, String> recipeDetailsCache;

  const RecipeState({
    this.recipeCandidates,
    this.selectedRecipeTitle,
    this.recipeContent,
    this.isLoadingCandidates = false,
    this.isLoadingDetails = false,
    this.errorMessage,
    this.recipeDetailsCache = const {},
  });

  RecipeState copyWith({
    List<RecipeCandidate>? recipeCandidates,
    String? selectedRecipeTitle,
    String? recipeContent,
    bool? isLoadingCandidates,
    bool? isLoadingDetails,
    String? errorMessage,
    Map<String, String>? recipeDetailsCache,
    bool clearCandidates = false,
    bool clearSelectedRecipe = false,
    bool clearContent = false,
    bool clearError = false,
  }) {
    return RecipeState(
      recipeCandidates: clearCandidates ? null : (recipeCandidates ?? this.recipeCandidates),
      selectedRecipeTitle: clearSelectedRecipe ? null : (selectedRecipeTitle ?? this.selectedRecipeTitle),
      recipeContent: clearContent ? null : (recipeContent ?? this.recipeContent),
      isLoadingCandidates: isLoadingCandidates ?? this.isLoadingCandidates,
      isLoadingDetails: isLoadingDetails ?? this.isLoadingDetails,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      recipeDetailsCache: recipeDetailsCache ?? this.recipeDetailsCache,
    );
  }
}

/// レシピ状態を管理するNotifier
class RecipeStateNotifier extends StateNotifier<RecipeState> {
  RecipeStateNotifier() : super(const RecipeState());

  /// レシピ候補を取得
  Future<void> fetchRecipeCandidates(List<SelectedIngredient> ingredients) async {
    state = state.copyWith(
      isLoadingCandidates: true,
      clearError: true,
      clearCandidates: true,
      clearSelectedRecipe: true,
      clearContent: true,
    );

    try {
      final candidates = await RecipeApiService.getRecipeCandidates(ingredients);
      state = state.copyWith(
        recipeCandidates: candidates,
        isLoadingCandidates: false,
      );
    } catch (e) {
      state = state.copyWith(
        errorMessage: e.toString(),
        isLoadingCandidates: false,
      );
    }
  }

  /// レシピ詳細を取得
  Future<void> fetchRecipeDetails(
    List<SelectedIngredient> ingredients,
    String recipeTitle,
  ) async {
    // キャッシュに既に詳細がある場合はそれを使用
    if (state.recipeDetailsCache.containsKey(recipeTitle)) {
      state = state.copyWith(
        selectedRecipeTitle: recipeTitle,
        recipeContent: state.recipeDetailsCache[recipeTitle],
        isLoadingDetails: false,
      );
      return;
    }

    state = state.copyWith(
      isLoadingDetails: true,
      clearError: true,
      selectedRecipeTitle: recipeTitle,
      clearContent: true,
    );

    try {
      final details = await RecipeApiService.getRecipeDetails(ingredients, recipeTitle);
      
      // キャッシュに保存
      final newCache = Map<String, String>.from(state.recipeDetailsCache);
      newCache[recipeTitle] = details;
      
      state = state.copyWith(
        recipeContent: details,
        isLoadingDetails: false,
        recipeDetailsCache: newCache,
      );
    } catch (e) {
      state = state.copyWith(
        errorMessage: e.toString(),
        isLoadingDetails: false,
        clearSelectedRecipe: true,
      );
    }
  }

  /// 候補一覧に戻る
  void resetToCandidates() {
    state = state.copyWith(
      clearSelectedRecipe: true,
      clearContent: true,
    );
  }

  /// 状態をリセット
  void reset() {
    state = const RecipeState();
  }
}

/// レシピ状態のプロバイダー
final recipeStateProvider =
    StateNotifierProvider<RecipeStateNotifier, RecipeState>((ref) {
  return RecipeStateNotifier();
});

