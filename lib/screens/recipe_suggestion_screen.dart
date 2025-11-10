import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/selected_ingredient.dart';
import '../services/recipe_api_service.dart';
import '../services/ingredient_translator.dart';
import '../models/food_data_model.dart';
import '../services/food_data_service.dart';

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
  IngredientTranslator? _translator;
  // レシピ詳細のキャッシュ（タイトル -> 詳細内容）
  final Map<String, String> _recipeDetailsCache = {};

  @override
  void initState() {
    super.initState();
    _loadTranslator();
  }

  Future<void> _loadTranslator() async {
    try {
      final foodData = await FoodDataService.loadFoodData();
      if (mounted) {
        setState(() {
          _translator = IngredientTranslator(foodData);
        });
      }
    } catch (e) {
      debugPrint('Failed to load translator: $e');
    }
  }

  String _getDisplayName(String ingredientName) {
    if (_translator == null) {
      return ingredientName;
    }
    return _translator!.translateToJapanese(ingredientName);
  }

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
          _errorMessage = e.toString();
          _isLoadingCandidates = false;
        });
      }
    }
  }

  Future<void> _requestRecipeDetails(String recipeTitle) async {
    // キャッシュに既に詳細がある場合はそれを使用
    if (_recipeDetailsCache.containsKey(recipeTitle)) {
      setState(() {
        _selectedRecipeTitle = recipeTitle;
        _recipeContent = _recipeDetailsCache[recipeTitle];
        _isLoadingDetails = false;
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
        // キャッシュに保存
        _recipeDetailsCache[recipeTitle] = details;
        setState(() {
          _recipeContent = details;
          _isLoadingDetails = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoadingDetails = false;
          _selectedRecipeTitle = null;
        });
      }
    }
  }

  void _resetToCandidates() {
    setState(() {
      _selectedRecipeTitle = null;
      _recipeContent = null;
    });
  }

  void _handleBackButton() {
    // レシピ詳細が表示されている場合は候補一覧に戻る
    if (_recipeContent != null) {
      _resetToCandidates();
    } else {
      // 候補一覧の場合は前の画面に戻る
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      children: widget.selectedIngredients.map((ingredient) {
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
                                _getDisplayName(ingredient.name),
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
              if (_recipeCandidates == null && _recipeContent == null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoadingCandidates ? null : _requestRecipeCandidates,
                    icon: _isLoadingCandidates
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
                      _isLoadingCandidates ? 'レシピ候補を生成中...' : 'レシピ候補を提案してもらう',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              // レシピ候補の表示
              if (_recipeCandidates != null && _recipeContent == null) ...[
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
                      ..._recipeCandidates!.asMap().entries.map((entry) {
                        final index = entry.key;
                        final candidate = entry.value;
                        final isSelected = _selectedRecipeTitle == candidate.title;
                        final isLoading = _isLoadingDetails && isSelected;
                        final isCached = _recipeDetailsCache.containsKey(candidate.title);
                        
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index < _recipeCandidates!.length - 1 ? 12 : 0,
                          ),
                          child: InkWell(
                            onTap: _isLoadingDetails && !isSelected
                                ? null
                                : () => _requestRecipeDetails(candidate.title),
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
                                                valueColor: AlwaysStoppedAnimation<Color>(
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
                                      crossAxisAlignment: CrossAxisAlignment.start,
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
              if (_errorMessage != null) ...[
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
                          _errorMessage!,
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
              if (_recipeContent != null) ...[
                if (_isLoadingDetails)
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
                      onPressed: _resetToCandidates,
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
                      data: _recipeContent!,
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

