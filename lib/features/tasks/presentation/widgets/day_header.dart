import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:todo/core/time/calendar_date.dart';
import 'package:todo/features/tasks/presentation/theme/task_status_colors.dart';
import 'package:todo/l10n/app_localizations.dart';

/// Heading of one day in the timeline. Overdue days are marked by color,
/// icon and label together, never by color alone.
class DayHeader extends StatelessWidget {
  const DayHeader({super.key, required this.date, required this.isOverdue});

  final CalendarDate date;
  final bool isOverdue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final local = date.toLocalDateTime();
    final shortDate = DateFormat.yMMMEd(locale).format(local);
    final fullDate = DateFormat.yMMMMEEEEd(locale).format(local);
    final textTheme = Theme.of(context).textTheme;
    final color = isOverdue ? TaskStatusColors.of(context).overdue : null;

    return Semantics(
      header: true,
      label: isOverdue ? l10n.tasksDayOverdueSemantics(fullDate) : fullDate,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              shortDate,
              style: textTheme.titleSmall?.copyWith(color: color),
            ),
            if (isOverdue) ...[
              Icon(Icons.warning_amber_rounded, size: 18, color: color),
              Text(
                l10n.tasksOverdueLabel,
                style: textTheme.labelLarge?.copyWith(color: color),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
