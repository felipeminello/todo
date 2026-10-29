import 'package:flutter/material.dart';
import 'package:todo/core/ui/widgets/brand_button.dart';
import 'package:todo/core/ui/widgets/task_stack_illustration.dart';
import 'package:todo/l10n/app_localizations.dart';

class TasksLoadFailureView extends StatelessWidget {
  const TasksLoadFailureView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 96),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TaskStackIllustration(
              width: 190,
              muted: true,
              badge: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(Icons.cloud_off, size: 30, color: scheme.error),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              l10n.tasksLoadError,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            BrandButton(
              onPressed: onRetry,
              variant: BrandButtonVariant.secondary,
              foregroundColor: scheme.primary,
              height: 50,
              icon: const Icon(Icons.refresh, size: 20),
              child: Text(l10n.retryAction),
            ),
          ],
        ),
      ),
    );
  }
}
