import 'package:home_widget/home_widget.dart';
import 'package:todo/features/tasks/data/widget/widget_storage.dart';

/// [WidgetStorage] over `home_widget`: an App Group on iOS and the plugin's
/// SharedPreferences on Android.
final class HomeWidgetStorage implements WidgetStorage {
  const HomeWidgetStorage({this.appGroupId});

  /// Must match the App Group of the Runner and widget extension
  /// entitlements.
  static const iOSAppGroupId = 'group.br.dev.minello.todo';

  /// `kind` of the WidgetKit widget.
  static const iOSWidgetKind = 'TodayWidget';

  static const androidReceiver =
      'br.dev.minello.todo.widget.TodayWidgetReceiver';

  /// Only iOS needs one. Passed on each call instead of through
  /// `HomeWidget.setAppGroupId`, which keeps it in static state.
  final String? appGroupId;

  @override
  Future<void> save(String key, String value) =>
      HomeWidget.saveWidgetData<String>(key, value, appGroupId: appGroupId);

  @override
  Future<void> refresh() => HomeWidget.updateWidget(
    iOSName: iOSWidgetKind,
    qualifiedAndroidName: androidReceiver,
  );
}
