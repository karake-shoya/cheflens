import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

/// メッセージの種類
enum MessageType { info, success, error, warning }

/// ステータス・エラーメッセージを表示する共通Widget
///
/// camera_screen のステータス表示や recipe_suggestion_screen の
/// エラー表示など、複数画面で共通して使用する。
class StatusMessage extends StatelessWidget {
  final String message;
  final MessageType type;

  const StatusMessage({
    super.key,
    required this.message,
    this.type = MessageType.info,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final (Color bg, Color fg, IconData icon) = switch (type) {
      MessageType.info    => (
          colorScheme.primaryContainer,
          colorScheme.onPrimaryContainer,
          Icons.info_outline,
        ),
      MessageType.success => (
          colorScheme.tertiaryContainer,
          colorScheme.onTertiaryContainer,
          Icons.check_circle_outline,
        ),
      MessageType.error   => (
          colorScheme.errorContainer,
          colorScheme.onErrorContainer,
          Icons.error_outline,
        ),
      MessageType.warning => (
          colorScheme.secondaryContainer,
          colorScheme.onSecondaryContainer,
          Icons.warning_amber_outlined,
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg, size: AppSpacing.iconSm),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
