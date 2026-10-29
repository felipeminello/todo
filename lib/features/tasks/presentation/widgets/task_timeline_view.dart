import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:todo/features/tasks/domain/entities/task.dart';
import 'package:todo/features/tasks/domain/entities/task_timeline.dart';
import 'package:todo/features/tasks/presentation/widgets/completed_section.dart';
import 'package:todo/features/tasks/presentation/widgets/section_header.dart';
import 'package:todo/features/tasks/presentation/widgets/task_card_list.dart';
import 'package:todo/features/tasks/presentation/widgets/task_tile.dart';
import 'package:todo/features/tasks/presentation/widgets/timeline_day.dart';
import 'package:todo/l10n/app_localizations.dart';

/// The three blocks of the main screen. Empty blocks are left out.
class TaskTimelineView extends StatelessWidget {
  const TaskTimelineView({
    super.key,
    required this.timeline,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.selectedTaskId,
    this.horizontalPadding = 20,
  });

  static const maxContentWidth = 720.0;

  final TaskTimeline timeline;
  final ValueChanged<Task> onToggle;
  final ValueChanged<Task> onEdit;
  final ValueChanged<Task> onDelete;

  /// The task open in the editor beside the list, if any.
  final String? selectedTaskId;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    TaskTile tile(Task task, {bool isOverdue = false}) => TaskTile(
      key: ValueKey(task.id),
      task: task,
      isOverdue: isOverdue,
      isSelected: task.id == selectedTaskId,
      onToggle: () => onToggle(task),
      onEdit: () => onEdit(task),
      onDelete: () => onDelete(task),
    );

    final sections = <Widget>[
      if (timeline.undated.isNotEmpty)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(title: l10n.tasksUndatedHeader),
            TaskCardList(
              stacked: true,
              tiles: [for (final task in timeline.undated) tile(task)],
            ),
          ],
        ),
      for (final (index, group) in timeline.days.indexed)
        TimelineDay(
          group: group,
          isLast: index == timeline.days.length - 1,
          tiles: [
            for (final task in group.tasks)
              tile(task, isOverdue: group.isOverdue),
          ],
        ),
      if (timeline.completed.isNotEmpty)
        CompletedSection(
          key: const PageStorageKey('completed-tasks'),
          tiles: [for (final task in timeline.completed) tile(task)],
        ),
    ];

    return LayoutBuilder(
      // Side padding instead of a narrower list keeps the whole window
      // scrollable while the content stays at a readable width.
      builder: (context, constraints) {
        final side = math.max(
          horizontalPadding,
          (constraints.maxWidth - maxContentWidth) / 2,
        );
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(side, 4, side, 120),
          children: [
            for (final (index, section) in sections.indexed) ...[
              if (index > 0) const SizedBox(height: 22),
              section,
            ],
          ],
        );
      },
    );
  }
}
