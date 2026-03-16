import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/selected_ingredient.dart';
import '../exceptions/vision_exception.dart';
import '../services/recipe_api_service.dart';
import '../theme/app_spacing.dart';
import '../widgets/ingredient_chip.dart';
import '../widgets/status_message.dart';

class RecipeSuggestionScreen extends StatefulWidget {
  final List<SelectedIngredient> selectedIngredients;

  const RecipeSuggestionScreen({
    super.key,
    required this.selectedIngredients,
  });

  @override
  State<RecipeSuggestionScreen> createState() => _RecipeSuggestionScreenState();
}

class _RecipeSuggestionScreenState extends State<RecipeSuggestionScreen> {
  List<RecipeCandidate>? _recipeCandidates;
  String? _selectedRecipeTitle;
  String? _recipeContent;
  bool _isLoadingCandidates = false;
  bool _isLoadingDetails = false;
  String? _errorMessage;
  final Map<String, String> _recipeDetailsCache = {};

  // ── API呼び出し ─────────────────────────────────────

  Future<void> _requestRecipeCandidates() async {
    setState(() {
      _isLoadingCandidates = true;
      _errorMessage = null;
      _recipeCandidates = null;
      _selectedRecipeTitle = null;
      _recipeContent = null;
    });

    try {
      final candidates = await RecipeApiService.getRecipeCandidates(
        widget.selectedIngredients,
      );
      if (mounted) {
        setState(() {
          _recipeCandidates = candidates;
          _isLoadingCandidates = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _toUserMessage(e);
          _isLoadingCandidates = false;
        });
      }
    }
  }

  Future<void> _requestRecipeDetails(String recipeTitle) async {
    if (_recipeDetailsCache.containsKey(recipeTitle)) {
      setState(() {
        _selectedRecipeTitle = recipeTitle;
        _recipeContent = _recipeDetailsCache[recipeTitle];
      });
      return;
    }

    setState(() {
      _isLoadingDetails = true;
      _errorMessage = null;
      _selectedRecipeTitle = recipeTitle;
      _recipeContent = null;
    });

    try {
      final details = await RecipeApiService.getRecipeDetails(
        widget.selectedIngredients,
        recipeTitle,
      );
      if (mounted) {
        _recipeDetailsCache[recipeTitle] = details;
        setState(() {
          _recipeContent = details;
          _isLoadingDetails = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _toUserMessage(e);
          _isLoadingDetails = false;
          _selectedRecipeTitle = null;
        });
      }
    }
  }

  String _toUserMessage(dynamic e) {
    if (e is VisionException) return e.userMessage;
    return '予期せぬエラーが発生しました';
  }

  void _resetToCandidates() {
    setState(() {
      _selectedRecipeTitle = null;
      _recipeContent = null;
    });
  }

  void _handleBackButton() {
    if (_recipeContent != null) {
      _resetToCandidates();
    } else {
      Navigator.of(context).pop();
    }
  }

  // ── ウィジェット構築 ─────────────────────────────────

  /// レシピ候補の1アイテム
  Widget _buildRecipeCandidateItem(int index, RecipeCandidate candidate) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _selectedRecipeTitle == candidate.title;
    final isLoading = _isLoadingDetails && isSelected;
    final isCached = _recipeDetailsCache.containsKey(candidate.title);

    return Card(
      color: isSelected
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _isLoadingDetails && !isSelected
            ? null
            : () => _requestRecipeDetails(candidate.title),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              // 番号 or ローディング
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primary.withValues(alpha: 0.2)
                      : colorScheme.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.primary,
                          ),
                        )
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),

              // タイトル・説明
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            candidate.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? colorScheme.onPrimaryContainer
                                      : colorScheme.onSurface,
                                ),
                          ),
                        ),
                        if (isCached && !isLoading)
                          Icon(
                            Icons.check_circle,
                            size: AppSpacing.iconSm,
                            color: colorScheme.tertiary,
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      isLoading ? 'レシピ詳細を読み込み中...' : candidate.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: isLoading
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                        fontStyle:
                            isLoading ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: AppSpacing.sm),
              if (!isLoading)
                Icon(
                  isCached
                      ? Icons.check_circle_outline
                      : Icons.arrow_forward_ios,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('レシピ提案'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _handleBackButton,
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 選択食材カード
              Card(
                color: colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.shopping_basket,
                            color: colorScheme.onPrimaryContainer,
                            size: AppSpacing.iconMd,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            '選択された食材',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: widget.selectedIngredients
                            .map((i) => IngredientChip(name: i.name))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // レシピ候補取得ボタン
              if (_recipeCandidates == null && _recipeContent == null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoadingCandidates
                        ? null
                        : _requestRecipeCandidates,
                    icon: _isLoadingCandidates
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.restaurant_menu, size: 22),
                    label: Text(
                      _isLoadingCandidates
                          ? 'レシピ候補を生成中...'
                          : 'レシピ候補を提案してもらう',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              // レシピ候補リスト
              if (_recipeCandidates != null && _recipeContent == null) ...[
                Text(
                  'レシピ候補',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: AppSpacing.md),
                ...List.generate(
                  _recipeCandidates!.length,
                  (i) => Padding(
                    padding: EdgeInsets.only(
                      bottom: i < _recipeCandidates!.length - 1
                          ? AppSpacing.md
                          : 0,
                    ),
                    child: _buildRecipeCandidateItem(
                        i, _recipeCandidates![i]),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],

              // エラーメッセージ
              if (_errorMessage != null) ...[
                StatusMessage(
                  message: _errorMessage!,
                  type: MessageType.error,
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],

              // レシピ詳細（マークダウン）
              if (_recipeContent != null) ...[
                if (_isLoadingDetails)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.xxl),
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: AppSpacing.lg),
                          Text('レシピ詳細を生成中...'),
                        ],
                      ),
                    ),
                  )
                else ...[
                  OutlinedButton.icon(
                    onPressed: _resetToCandidates,
                    icon: const Icon(Icons.arrow_back, size: 20),
                    label: const Text('レシピ候補に戻る'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Card(
                    color: colorScheme.surfaceContainerLow,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: MarkdownBody(
                        data: _recipeContent!,
                        styleSheet: MarkdownStyleSheet(
                          h1: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                          h2: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.secondary,
                          ),
                          p: const TextStyle(fontSize: 15, height: 1.6),
                          listBullet: TextStyle(color: colorScheme.primary),
                          strong: const TextStyle(fontWeight: FontWeight.bold),
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
