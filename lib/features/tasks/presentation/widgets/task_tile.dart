import 'package:flutter/material.dart';
import 'package:todo/core/ui/brand_colors.dart';
import 'package:todo/features/tasks/domain/entities/task.dart';
import 'package:todo/features/tasks/presentation/theme/task_status_colors.dart';
import 'package:todo/l10n/app_localizations.dart';

class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.isOverdue = false,
    this.isSelected = false,
  });

  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// Outlines the box in the overdue color, echoing the day it belongs to.
  final bool isOverdue;

  /// Being edited beside the list.
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brand = BrandColors.of(context);
    final completed = task.isCompleted;
    final radius = BorderRadius.circular(16);

    final row = InkWell(
      onTap: onEdit,
      borderRadius: radius,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 58),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 48,
              child: Center(
                // The design's box is 26 px; the Material checkbox draws 18.
                child: Transform.scale(
                  scale: 1.3,
                  child: Checkbox(
                    value: completed,
                    onChanged: (_) => onToggle(),
                    semanticLabel: completed
                        ? l10n.taskMarkPending
                        : l10n.taskMarkDone,
                    side: isOverdue && !completed
                        ? BorderSide(
                            color: TaskStatusColors.of(context).overdue,
                            width: 2,
                          )
                        : null,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      task.title,
                      style: completed
                          ? theme.textTheme.titleMedium?.copyWith(
                              decoration: TextDecoration.lineThrough,
                              color: scheme.onSurfaceVariant,
                            )
                          : theme.textTheme.titleMedium,
                    ),
                    if (task.description.isNotEmpty)
                      Text(
                        task.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: l10n.taskDeleteTooltip,
              color: scheme.onSurfaceVariant,
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );

    if (!isSelected) return row;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [brand.highlightTop, brand.highlightBottom],
        ),
      ),
      child: row,
    );
  }
}
