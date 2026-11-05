import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:todo/core/ui/brand_colors.dart';
import 'package:todo/features/tasks/domain/entities/task.dart';
import 'package:todo/features/tasks/presentation/widgets/task_description.dart';
import 'package:todo/l10n/app_localizations.dart';

/// Title, due date and description of [task], read-only. The title and the
/// description can be selected and copied.
class TaskDetails extends StatelessWidget {
  const TaskDetails({super.key, required this.task, required this.onOpenLink});

  final Task task;
  final ValueChanged<Uri> onOpenLink;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodyLarge?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (task.isCompleted) ...[
            const SelectionContainer.disabled(
              child: Align(
                alignment: Alignment.centerLeft,
                child: _CompletedPill(),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Semantics(
            header: true,
            child: Text(
              task.title,
              key: const Key('task-details-title'),
              style: theme.textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: 14),
          // Copying title and description together shouldn't drag the date
          // label in between them.
          SelectionContainer.disabled(child: _DueDate(task: task)),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 20),
          if (task.description.trim().isEmpty)
            SelectionContainer.disabled(
              child: Text(l10n.taskDetailsNoDescription, style: muted),
            )
          else
            TaskDescription(text: task.description, onOpenLink: onOpenLink),
        ],
      ),
    );
  }
}

class _DueDate extends StatelessWidget {
  const _DueDate({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brand = BrandColors.of(context);
    final date = task.dueDate;
    final label = date == null
        ? l10n.taskFormNoDueDate
        : toBeginningOfSentenceCase(
            DateFormat.yMMMMEEEEd(locale).format(date.toLocalDateTime()),
          );
    final foreground = date == null
        ? scheme.onSurfaceVariant
        : brand.onHighlight;

    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        label: l10n.taskDetailsDueDateSemantics(label),
        excludeSemantics: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: date == null
                  ? [brand.raisedTop, brand.raisedBottom]
                  : [brand.highlightTop, brand.highlightBottom],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.event_outlined, size: 18, color: foreground),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    key: const Key('task-details-due-date'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompletedPill extends StatelessWidget {
  const _CompletedPill();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check, size: 14, color: scheme.onPrimaryContainer),
            const SizedBox(width: 4),
            Text(
              AppLocalizations.of(context).taskDetailsCompleted,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
