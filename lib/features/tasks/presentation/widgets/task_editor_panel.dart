import 'package:flutter/material.dart';
import 'package:todo/core/ui/widgets/raised_card.dart';
import 'package:todo/features/tasks/domain/entities/task.dart';
import 'package:todo/features/tasks/presentation/widgets/task_form.dart';

/// [TaskForm] on a card beside the list, for wide windows. It edits [task],
/// or creates a new one when there is none.
class TaskEditorPanel extends StatelessWidget {
  const TaskEditorPanel({
    super.key,
    this.task,
    required this.onSubmit,
    required this.onCancel,
    this.autofocus = false,
  });

  final Task? task;
  final ValueChanged<TaskFormResult> onSubmit;
  final VoidCallback onCancel;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return RaisedCard(
      radius: 26,
      padding: const EdgeInsets.all(24),
      child: TaskForm(
        initial: task,
        autofocus: autofocus,
        onSubmit: onSubmit,
        onCancel: onCancel,
      ),
    );
  }
}
