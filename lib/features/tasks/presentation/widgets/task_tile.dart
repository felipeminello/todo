import 'package:flutter/material.dart';
import 'package:todo/features/tasks/domain/entities/task.dart';
import 'package:todo/l10n/app_localizations.dart';

class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final completed = task.isCompleted;

    return ListTile(
      leading: Checkbox(
        value: completed,
        onChanged: (_) => onToggle(),
        semanticLabel: completed ? l10n.taskMarkPending : l10n.taskMarkDone,
      ),
      title: Text(
        task.title,
        style: completed
            ? TextStyle(
                decoration: TextDecoration.lineThrough,
                color: theme.colorScheme.onSurfaceVariant,
              )
            : null,
      ),
      subtitle: task.description.isEmpty
          ? null
          : Text(
              task.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: l10n.taskDeleteTooltip,
        onPressed: onDelete,
      ),
      onTap: onEdit,
    );
  }
}
