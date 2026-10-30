import 'package:todo/features/tasks/data/widget/widget_snapshot_codec.dart';
import 'package:todo/features/tasks/data/widget/widget_storage.dart';
import 'package:todo/features/tasks/domain/entities/widget_task_snapshot.dart';
import 'package:todo/features/tasks/domain/repositories/task_widget_publisher.dart';

final class HomeWidgetTaskPublisher implements TaskWidgetPublisher {
  const HomeWidgetTaskPublisher(this._storage, this._codec);

  /// Read by the native widgets; keep in sync with them.
  static const snapshotKey = 'today_widget_snapshot';

  final WidgetStorage _storage;
  final WidgetSnapshotCodec _codec;

  @override
  Future<void> publish(WidgetTaskSnapshot snapshot) =>
      _write(_codec.encode(snapshot));

  @override
  Future<void> clearForSignOut() => _write(_codec.encodeSignedOut());

  Future<void> _write(String json) async {
    await _storage.save(snapshotKey, json);
    await _storage.refresh();
  }
}
