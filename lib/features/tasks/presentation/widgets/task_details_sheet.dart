import 'package:flutter/material.dart';
import 'package:todo/core/ui/widgets/brand_button.dart';
import 'package:todo/features/tasks/domain/entities/task.dart';
import 'package:todo/features/tasks/presentation/widgets/task_details.dart';
import 'package:todo/l10n/app_localizations.dart';

/// [TaskDetails] in a bottom sheet that fills the screen, for narrow
/// windows, with buttons to edit the task or close.
class TaskDetailsSheet extends StatelessWidget {
  const TaskDetailsSheet({
    super.key,
    required this.task,
    required this.onOpenLink,
  });

  final Task task;
  final ValueChanged<Uri> onOpenLink;

  /// Completes with `true` when the user asks to edit the task, and with
  /// `false` when the sheet is closed.
  static Future<bool> open(
    BuildContext context, {
    required Task task,
    required ValueChanged<Uri> onOpenLink,
  }) async {
    final edit = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => TaskDetailsSheet(task: task, onOpenLink: onOpenLink),
    );
    return edit ?? false;
  }

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
            child: Row(
              children: [
                Expanded(
                  child: BrandButton(
                    key: const Key('task-details-close'),
                    onPressed: () => navigator.pop(false),
                    variant: BrandButtonVariant.secondary,
                    child: Text(l10n.taskDetailsClose),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BrandButton(
                    key: const Key('task-details-edit'),
                    onPressed: () => navigator.pop(true),
                    icon: const Icon(Icons.edit_outlined),
                    child: Text(l10n.taskDetailsEdit),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
