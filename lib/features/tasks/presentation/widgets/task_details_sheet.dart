import 'package:flutter/material.dart';
import 'package:todo/core/ui/widgets/brand_button.dart';
import 'package:todo/features/tasks/domain/entities/task.dart';
import 'package:todo/features/tasks/presentation/widgets/task_completion_button.dart';
import 'package:todo/features/tasks/presentation/widgets/task_details.dart';
import 'package:todo/l10n/app_localizations.dart';

/// What the user picked on a [TaskDetailsSheet].
enum TaskDetailsAction { edit, toggleCompletion }

/// [TaskDetails] in a bottom sheet that fills the screen, for narrow
/// windows, with buttons to complete (or reopen), edit the task or close.
class TaskDetailsSheet extends StatelessWidget {
  const TaskDetailsSheet({
    super.key,
    required this.task,
    required this.onOpenLink,
  });

  final Task task;
  final ValueChanged<Uri> onOpenLink;

  /// Completes with the action the user asked for, or `null` when the sheet
  /// is closed.
  static Future<TaskDetailsAction?> open(
    BuildContext context, {
    required Task task,
    required ValueChanged<Uri> onOpenLink,
  }) => showModalBottomSheet<TaskDetailsAction>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => TaskDetailsSheet(task: task, onOpenLink: onOpenLink),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SizedBox.expand(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: TaskDetails(task: task, onOpenLink: onOpenLink),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TaskCompletionButton(
                  isCompleted: task.isCompleted,
                  onPressed: () =>
                      navigator.pop(TaskDetailsAction.toggleCompletion),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: BrandButton(
                        key: const Key('task-details-close'),
                        onPressed: navigator.pop,
                        variant: BrandButtonVariant.secondary,
                        child: Text(l10n.taskDetailsClose),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: BrandButton(
                        key: const Key('task-details-edit'),
                        onPressed: () => navigator.pop(TaskDetailsAction.edit),
                        // The completion button leads while the task is
                        // pending.
                        variant: task.isCompleted
                            ? BrandButtonVariant.primary
                            : BrandButtonVariant.secondary,
                        icon: const Icon(Icons.edit_outlined),
                        child: Text(l10n.taskDetailsEdit),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
