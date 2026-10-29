import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:todo/core/time/calendar_date.dart';
import 'package:todo/core/ui/widgets/brand_button.dart';
import 'package:todo/core/ui/widgets/raised_icon_button.dart';
import 'package:todo/core/ui/widgets/task_stack_illustration.dart';
import 'package:todo/l10n/app_localizations.dart';

/// Today's date, the app title, how many tasks there are and the screen
/// actions.
class TasksHeader extends StatelessWidget {
  const TasksHeader({
    super.key,
    required this.onRefresh,
    this.today,
    this.pendingCount,
    this.completedCount,
    this.onSignOut,
    this.onAdd,
    this.horizontalPadding = 20,
  });

  final VoidCallback onRefresh;
  final CalendarDate? today;

  /// Both counts are needed for the summary line to show.
  final int? pendingCount;
  final int? completedCount;
  final VoidCallback? onSignOut;

  /// Shows a labelled create button and the brand mark, for wide windows
  /// where there is no floating button.
  final VoidCallback? onAdd;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final locale = Localizations.localeOf(context).toString();
    final today = this.today;
    final pending = pendingCount;
    final completed = completedCount;
    final onSignOut = this.onSignOut;
    final onAdd = this.onAdd;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        24,
        horizontalPadding,
        16,
      ),
      // Full width, so the actions sit at the right edge.
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.start,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onAdd != null) ...[
                  const TaskStackIllustration(width: 52),
                  const SizedBox(width: 16),
                ],
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (today != null)
                        Text(
                          toBeginningOfSentenceCase(
                            DateFormat.MMMMEEEEd(locale)
                                .format(today.toLocalDateTime()),
                          ),
                          style: muted,
                        ),
                      Semantics(
                        header: true,
                        child: Text(
                          l10n.appTitle,
                          style: theme.textTheme.headlineMedium,
                        ),
                      ),
                      if (pending != null && completed != null)
                        Text(
                          l10n.tasksSummary(pending, completed),
                          style: muted,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                RaisedIconButton(
                  icon: Icons.refresh,
                  tooltip: l10n.refreshTooltip,
                  onPressed: onRefresh,
                ),
                if (onSignOut != null)
                  RaisedIconButton(
                    icon: Icons.logout,
                    tooltip: l10n.signOutTooltip,
                    onPressed: onSignOut,
                  ),
                if (onAdd != null)
                  BrandButton(
                    onPressed: onAdd,
                    height: 46,
                    icon: const Icon(Icons.add),
                    child: Text(l10n.addTaskTooltip),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
