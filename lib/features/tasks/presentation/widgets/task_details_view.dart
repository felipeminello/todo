import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:todo/core/ui/widgets/brand_button.dart';
import 'package:todo/core/ui/widgets/raised_card.dart';
import 'package:todo/features/tasks/domain/entities/task.dart';
import 'package:todo/features/tasks/presentation/widgets/task_details.dart';
import 'package:todo/features/tasks/presentation/widgets/task_timeline_view.dart';
import 'package:todo/l10n/app_localizations.dart';

/// [TaskDetails] in place of the list, for wide windows, with buttons on top
/// to go back to the list or edit the task in the panel beside it.
class TaskDetailsView extends StatelessWidget {
  const TaskDetailsView({
    super.key,
    required this.task,
    required this.onBack,
    required this.onEdit,
    required this.onOpenLink,
    this.horizontalPadding = 20,
  });

  final Task task;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final ValueChanged<Uri> onOpenLink;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return LayoutBuilder(
      // Same readable width as the list it replaces.
      builder: (context, constraints) {
        final side = math.max(
          horizontalPadding,
          (constraints.maxWidth - TaskTimelineView.maxContentWidth) / 2,
        );
        return ListView(
          padding: EdgeInsets.fromLTRB(side, 4, side, 32),
          children: [
            Row(
              children: [
                BrandButton(
                  key: const Key('task-details-back'),
                  onPressed: onBack,
                  variant: BrandButtonVariant.secondary,
                  height: 46,
                  icon: const Icon(Icons.arrow_back),
                  child: Text(l10n.taskDetailsBack),
                ),
                const Spacer(),
                BrandButton(
                  key: const Key('task-details-edit'),
                  onPressed: onEdit,
                  height: 46,
                  icon: const Icon(Icons.edit_outlined),
                  child: Text(l10n.taskDetailsEdit),
                ),
              ],
            ),
            const SizedBox(height: 18),
            RaisedCard(
              radius: 26,
              padding: const EdgeInsets.all(24),
              child: TaskDetails(task: task, onOpenLink: onOpenLink),
            ),
          ],
        );
      },
    );
  }
}
