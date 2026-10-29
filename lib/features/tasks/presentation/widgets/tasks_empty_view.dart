import 'package:flutter/material.dart';
import 'package:todo/core/ui/widgets/task_stack_illustration.dart';
import 'package:todo/l10n/app_localizations.dart';

class TasksEmptyView extends StatelessWidget {
  const TasksEmptyView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // Scrollable so pull-to-refresh also works on an empty list.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 24, 32, 96),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const TaskStackIllustration(width: 190, rows: [false, false]),
                  const SizedBox(height: 32),
                  Text(
                    l10n.tasksEmptyTitle,
                    style: theme.textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.tasksEmptyMessage,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
