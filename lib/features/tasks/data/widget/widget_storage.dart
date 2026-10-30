/// Key-value storage shared with the native home screen widgets.
abstract interface class WidgetStorage {
  Future<void> save(String key, String value);

  /// Asks the system to redraw the widgets from the stored values.
  Future<void> refresh();
}
