import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

/// 食材を表示する共通チップWidget
///
/// - [onTap] を指定すると選択トグル可能（result_screen用）
/// - [onTap] が null の場合は常に選択済みスタイルで表示（recipe_suggestion_screen用）
class IngredientChip extends StatelessWidget {
  final String name;
  final bool isSelected;

  /// 手動追加された食材に表示する「+」バッジ
  final bool showAddedBadge;

  /// null の場合はタップ不可（表示専用）
  final VoidCallback? onTap;

  const IngredientChip({
    super.key,
    required this.name,
    this.isSelected = true,
    this.showAddedBadge = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final interactive = onTap != null;

    final bgColor = isSelected
        ? colorScheme.primary
        : colorScheme.surfaceContainerLow;
    final fgColor = isSelected
        ? colorScheme.onPrimary
        : colorScheme.onSurfaceVariant;
    final borderColor = isSelected
        ? colorScheme.primary
        : colorScheme.outlineVariant;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (interactive) ...[
              Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                size: AppSpacing.iconSm,
                color: fgColor,
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Text(
              name,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: fgColor,
              ),
            ),
            if (showAddedBadge && isSelected) ...[
              const SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.add_circle,
                size: 14,
                color: fgColor.withValues(alpha: 0.8),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
