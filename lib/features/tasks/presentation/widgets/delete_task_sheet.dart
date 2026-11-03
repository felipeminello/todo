import 'package:flutter/material.dart';
import 'package:todo/core/ui/widgets/brand_button.dart';
import 'package:todo/l10n/app_localizations.dart';

/// Asks before tasks are deleted for good.
class DeleteTaskSheet extends StatelessWidget {
  const DeleteTaskSheet({
    super.key,
    required this.heading,
    required this.message,
  });

  final String heading;

  /// Says what will be deleted.
  final String message;

  /// Asks about the task titled [title]. Completes with `true` only when the
  /// deletion is confirmed.
  static Future<bool> confirm(BuildContext context, {required String title}) {
    final l10n = AppLocalizations.of(context);
    return _ask(
      context,
      DeleteTaskSheet(
        heading: l10n.taskDeleteDialogTitle,
        message: l10n.taskDeleteDialogMessage(title),
      ),
    );
  }

  /// Asks about all [count] completed tasks. Completes with `true` only when
  /// the deletion is confirmed.
  static Future<bool> confirmCompleted(
    BuildContext context, {
    required int count,
  }) {
    final l10n = AppLocalizations.of(context);
    return _ask(
      context,
      DeleteTaskSheet(
        heading: l10n.completedDeleteDialogTitle,
        message: l10n.completedDeleteDialogMessage(count),
      ),
    );
  }

  static Future<bool> _ask(BuildContext context, DeleteTaskSheet sheet) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      builder: (_) => sheet,
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
            child: Text(heading, style: theme.textTheme.titleLarge),
          ),
          const SizedBox(height: 8),
          Text(
            message,
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
