import 'package:flutter/material.dart';
import 'package:todo/features/tasks/domain/entities/task.dart';
import 'package:todo/features/tasks/presentation/widgets/task_form.dart';

/// [TaskForm] in a bottom sheet that rises above the keyboard.
class TaskFormSheet extends StatelessWidget {
  const TaskFormSheet({super.key, this.initial});

  final Task? initial;

  /// Completes with the saved values, or with nothing when cancelled.
  static Future<TaskFormResult?> open(BuildContext context, {Task? initial}) {
    return showModalBottomSheet<TaskFormResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => TaskFormSheet(initial: initial),
    );
  }

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: TaskForm(
          initial: initial,
          autofocus: initial == null,
          onSubmit: (result) => navigator.pop(result),
          onCancel: () => navigator.pop(),
        ),
      ),
    );
  }
}
