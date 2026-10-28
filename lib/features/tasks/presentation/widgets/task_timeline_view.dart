import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:todo/features/tasks/domain/entities/task.dart';
import 'package:todo/features/tasks/domain/entities/task_timeline.dart';
import 'package:todo/features/tasks/presentation/widgets/day_header.dart';
import 'package:todo/features/tasks/presentation/widgets/section_header.dart';
import 'package:todo/features/tasks/presentation/widgets/task_tile.dart';
import 'package:todo/l10n/app_localizations.dart';

/// The three blocks of the main screen. Empty blocks are left out.
class TaskTimelineView extends StatelessWidget {
  const TaskTimelineView({
    super.key,
    required this.timeline,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  static const maxContentWidth = 720.0;

  final TaskTimeline timeline;
  final ValueChanged<Task> onToggle;
  final ValueChanged<Task> onEdit;
  final ValueChanged<Task> onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    TaskTile tile(Task task) => TaskTile(
      key: ValueKey(task.id),
      task: task,
      onToggle: () => onToggle(task),
      onEdit: () => onEdit(task),
      onDelete: () => onDelete(task),
    );

    return LayoutBuilder(
      // Side padding instead of a narrower list keeps the whole window
      // scrollable while the content stays at a readable width.
      builder: (context, constraints) {
        final side = math.max(
          0.0,
          (constraints.maxWidth - maxContentWidth) / 2,
        );
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(left: side, right: side, bottom: 96),
          children: [
            if (timeline.undated.isNotEmpty) ...[
              SectionHeader(title: l10n.tasksUndatedHeader),
              for (final task in timeline.undated) tile(task),
            ],
            for (final group in timeline.days) ...[
              DayHeader(date: group.date, isOverdue: group.isOverdue),
              for (final task in group.tasks) tile(task),
            ],
            if (timeline.completed.isNotEmpty)
              ExpansionTile(
                key: const PageStorageKey('completed-tasks'),
                title: Text(
                  l10n.tasksCompletedHeader(timeline.completed.length),
                ),
                children: [for (final task in timeline.completed) tile(task)],
              ),
          ],
        );
      },
    );
  }
}
