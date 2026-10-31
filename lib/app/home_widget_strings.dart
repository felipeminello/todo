import 'package:todo/features/tasks/data/widget/widget_count_text.dart';
import 'package:todo/features/tasks/data/widget/widget_strings.dart';
import 'package:todo/l10n/app_localizations.dart';

/// The home screen widget's texts, taken from the same ARB as the app.
WidgetStrings homeWidgetStrings(AppLocalizations l10n) => WidgetStrings(
  header: l10n.widgetHeader,
  empty: l10n.widgetEmpty,
  stale: l10n.widgetStale,
  signedOut: l10n.widgetSignedOut,
  pendingCount: WidgetCountText(
    one: l10n.widgetPendingOne,
    other: l10n.widgetPendingOther(WidgetCountText.countToken),
  ),
  overdueCount: WidgetCountText(
    one: l10n.widgetOverdueOne,
    other: l10n.widgetOverdueOther(WidgetCountText.countToken),
  ),
);
