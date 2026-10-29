import 'package:flutter/material.dart';
import 'package:todo/core/ui/widgets/brand_button.dart';
import 'package:todo/l10n/app_localizations.dart';

/// Asks before a task is deleted for good.
class DeleteTaskSheet extends StatelessWidget {
  const DeleteTaskSheet({super.key, required this.title});

  /// The title of the task to delete.
  final String title;

  /// Completes with `true` only when the deletion is confirmed.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
  }) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      builder: (_) => DeleteTaskSheet(title: title),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final navigator = Navigator.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Icon(Icons.delete_outline, color: scheme.error),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Semantics(
            header: true,
            child: Text(
              l10n.taskDeleteDialogTitle,
              style: theme.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.taskDeleteDialogMessage(title),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          BrandButton(
            onPressed: () => navigator.pop(true),
            variant: BrandButtonVariant.danger,
            child: Text(l10n.deleteAction),
          ),
          const SizedBox(height: 12),
          BrandButton(
            onPressed: () => navigator.pop(false),
            variant: BrandButtonVariant.secondary,
            child: Text(l10n.cancelAction),
          ),
        ],
      ),
    );
  }
}
