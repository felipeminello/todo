import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:todo/core/ui/brand_colors.dart';
import 'package:todo/features/tasks/domain/entities/task_timeline.dart';
import 'package:todo/features/tasks/presentation/theme/task_status_colors.dart';
import 'package:todo/features/tasks/presentation/widgets/task_card_list.dart';
import 'package:todo/l10n/app_localizations.dart';

/// One day of the timeline: the date on a rail at the left, the tasks on a
/// card at the right. Overdue days are marked by color, icon and label
/// together, never by color alone.
class TimelineDay extends StatelessWidget {
  const TimelineDay({
    super.key,
    required this.group,
    required this.isLast,
    required this.tiles,
  });

  final DayGroup group;

  /// The rail stops at the last day.
  final bool isLast;
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = TaskStatusColors.of(context);
    final date = group.date.toLocalDateTime();
    final fullDate = DateFormat.yMMMMEEEEd(locale).format(date);
    final accent = group.isOverdue
        ? status.overdue
        : group.isToday
        ? scheme.primary
        : null;
    final month = DateFormat.MMM(locale)
        .format(date)
        .replaceAll('.', '')
        .toUpperCase();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 44,
            // Its own node, or the label merges with the tasks beside it.
            child: Semantics(
              container: true,
              header: true,
              label: group.isOverdue
                  ? l10n.tasksDayOverdueSemantics(fullDate)
                  : group.isToday
                  ? l10n.tasksDayTodaySemantics(fullDate)
                  : fullDate,
              excludeSemantics: true,
              child: Column(
                children: [
                  Text(
                    '${group.date.day}',
                    style: theme.textTheme.titleLarge?.copyWith(color: accent),
                  ),
                  Text(
                    month,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: accent ?? scheme.onSurfaceVariant,
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: BrandColors.of(context).rail,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ExcludeSemantics(
                  child: _DayLabel(
                    weekday: DateFormat.EEEE(locale).format(date),
                    isOverdue: group.isOverdue,
                    isToday: group.isToday,
                  ),
                ),
                const SizedBox(height: 8),
                TaskCardList(tiles: tiles),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayLabel extends StatelessWidget {
  const _DayLabel({
    required this.weekday,
    required this.isOverdue,
    required this.isToday,
  });

  final String weekday;
  final bool isOverdue;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = TaskStatusColors.of(context);
    final scheme = theme.colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 26),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            weekday,
            style: theme.textTheme.titleSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (isOverdue)
            _Pill(
              icon: Icons.warning_amber_rounded,
              label: l10n.tasksOverdueLabel,
              color: status.overdue,
              background: status.overdueContainer,
            )
          else if (isToday)
            _Pill(
              label: l10n.tasksTodayLabel,
              color: scheme.onPrimaryContainer,
              background: scheme.primaryContainer,
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    this.icon,
    required this.label,
    required this.color,
    required this.background,
  });

  final IconData? icon;
  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
