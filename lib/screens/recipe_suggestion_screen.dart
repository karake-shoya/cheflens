import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/selected_ingredient.dart';
import '../providers/food_data_provider.dart';
import '../providers/recipe_state_provider.dart';

class RecipeSuggestionScreen extends ConsumerWidget {
  final List<SelectedIngredient> selectedIngredients;

  const RecipeSuggestionScreen({
    super.key,
    required this.selectedIngredients,
  });

  String _getDisplayName(String ingredientName, WidgetRef ref) {
    final translator = ref.read(ingredientTranslatorProvider);
    return translator.translateToJapanese(ingredientName);
  }

  void _handleBackButton(BuildContext context, WidgetRef ref) {
    final recipeState = ref.read(recipeStateProvider);
    // レシピ詳細が表示されている場合は候補一覧に戻る
    if (recipeState.recipeContent != null) {
      ref.read(recipeStateProvider.notifier).resetToCandidates();
    } else {
      // 候補一覧の場合は前の画面に戻る
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipeState = ref.watch(recipeStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('レシピ提案'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _handleBackButton(context, ref),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 選択食材の表示
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade50, Colors.blue.shade100],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.shopping_basket,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          '選択された食材',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: selectedIngredients.map((ingredient) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 18,
                                color: Colors.blue.shade600,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _getDisplayName(ingredient.name, ref),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // 「レシピ候補を取得」ボタン（候補が未取得の場合のみ表示）
              if (recipeState.recipeCandidates == null && recipeState.recipeContent == null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: recipeState.isLoadingCandidates
                        ? null
                        : () => ref
                            .read(recipeStateProvider.notifier)
                            .fetchRecipeCandidates(selectedIngredients),
                    icon: recipeState.isLoadingCandidates
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.restaurant_menu, size: 22),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    label: Text(
                      recipeState.isLoadingCandidates
                          ? 'レシピ候補を生成中...'
                          : 'レシピ候補を提案してもらう',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              // レシピ候補の表示
              if (recipeState.recipeCandidates != null &&
                  recipeState.recipeContent == null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.restaurant_menu,
                            color: Colors.orange.shade700,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'レシピ候補',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...recipeState.recipeCandidates!.asMap().entries.map((entry) {
                        final index = entry.key;
                        final candidate = entry.value;
                        final isSelected =
                            recipeState.selectedRecipeTitle == candidate.title;
                        final isLoading = recipeState.isLoadingDetails && isSelected;
                        final isCached = recipeState.recipeDetailsCache
                            .containsKey(candidate.title);

                        return Padding(
                          padding: EdgeInsets.only(
                            bottom:
                                index < recipeState.recipeCandidates!.length - 1
                                    ? 12
                                    : 0,
                          ),
                          child: InkWell(
                            onTap: recipeState.isLoadingDetails && !isSelected
                                ? null
                                : () => ref
                                    .read(recipeStateProvider.notifier)
                                    .fetchRecipeDetails(
                                        selectedIngredients, candidate.title),
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.orange.shade50
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.orange.shade400
                                      : Colors.orange.shade200,
                                  width: isSelected ? 3 : 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isSelected
                                        ? Colors.orange.withValues(alpha: 0.2)
                                        : Colors.orange.withValues(alpha: 0.1),
                                    blurRadius: isSelected ? 12 : 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.orange.shade200
                                          : Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Center(
                                      child: isLoading
                                          ? SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<Color>(
                                                  Colors.orange.shade700,
                                                ),
                                              ),
                                            )
                                          : Text(
                                              '${index + 1}',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.orange.shade700,
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                candidate.title,
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: isSelected
                                                      ? Colors.orange.shade900
                                                      : Colors.black87,
                                                ),
                                              ),
                                            ),
                                            if (isCached && !isLoading)
                                              Icon(
                                                Icons.check_circle,
                                                size: 18,
                                                color: Colors.green.shade600,
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          isLoading
                                              ? 'レシピ詳細を読み込み中...'
                                              : candidate.description,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: isLoading
                                                ? Colors.orange.shade700
                                                : Colors.grey.shade700,
                                            fontStyle: isLoading
                                                ? FontStyle.italic
                                                : FontStyle.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (isLoading)
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.orange.shade700,
                                        ),
                                      ),
                                    )
                                  else
                                    Icon(
                                      isCached
                                          ? Icons.check_circle_outline
                                          : Icons.arrow_forward_ios,
                                      size: 20,
                                      color: isSelected
                                          ? Colors.orange.shade700
                                          : Colors.orange.shade600,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              // エラーメッセージ表示
              if (recipeState.errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.red.shade700,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          recipeState.errorMessage!,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              // レシピ詳細の表示（マークダウン対応）
              if (recipeState.recipeContent != null) ...[
                if (recipeState.isLoadingDetails)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(40),
                    child: const Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'レシピ詳細を生成中...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  // 候補に戻るボタン
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          ref.read(recipeStateProvider.notifier).resetToCandidates(),
                      icon: const Icon(Icons.arrow_back, size: 20),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Colors.blue.shade400),
                      ),
                      label: const Text(
                        'レシピ候補に戻る',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: MarkdownBody(
                      data: recipeState.recipeContent!,
                      styleSheet: MarkdownStyleSheet(
                        h1: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                        h2: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                        p: const TextStyle(
                          fontSize: 16,
                          height: 1.6,
                        ),
                        listBullet: const TextStyle(
                          fontSize: 16,
                          color: Colors.blue,
                        ),
                        strong: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
