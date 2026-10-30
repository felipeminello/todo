import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/time/calendar_date.dart';
import 'package:todo/features/tasks/data/widget/home_widget_task_publisher.dart';
import 'package:todo/features/tasks/data/widget/noop_task_widget_publisher.dart';
import 'package:todo/features/tasks/data/widget/widget_snapshot_codec.dart';
import 'package:todo/features/tasks/data/widget/widget_storage.dart';
import 'package:todo/features/tasks/data/widget/widget_strings.dart';
import 'package:todo/features/tasks/domain/entities/widget_task_snapshot.dart';

import '../../../../helpers/task_factory.dart';

final class _FakeWidgetStorage implements WidgetStorage {
  final values = <String, String>{};

  /// Every call in order, to check that the save comes before the refresh.
  final calls = <String>[];

  @override
  Future<void> save(String key, String value) async {
    values[key] = value;
    calls.add('save $key');
  }

  @override
  Future<void> refresh() async => calls.add('refresh');
}

void main() {
  const codec = WidgetSnapshotCodec(
    WidgetStrings(
      header: 'Hoje',
      empty: 'Nada para hoje',
      stale: 'Abra o app para atualizar',
      signedOut: 'Entre no app para ver suas tarefas',
      overdue: 'Atrasada',
    ),
  );
  final snapshot = WidgetTaskSnapshot(
    tasks: [buildTask('a', dueDate: CalendarDate(2026, 10, 29))],
    generatedAt: baseInstant,
    coversUntil: CalendarDate(2026, 11, 5),
  );

  late _FakeWidgetStorage storage;
  late HomeWidgetTaskPublisher publisher;

  setUp(() {
    storage = _FakeWidgetStorage();
    publisher = HomeWidgetTaskPublisher(storage, codec);
  });

  test('publish saves the snapshot and then refreshes the widget', () async {
    await publisher.publish(snapshot);

    expect(storage.values, {'today_widget_snapshot': codec.encode(snapshot)});
    expect(storage.calls, ['save today_widget_snapshot', 'refresh']);
  });

  test('sign-out replaces the tasks and refreshes the widget', () async {
    await publisher.publish(snapshot);
    await publisher.clearForSignOut();

    final stored = jsonDecode(
      storage.values['today_widget_snapshot']!,
    ) as Map<String, Object?>;
    expect(stored['signedIn'], isFalse);
    expect(stored['tasks'], isEmpty);
    expect(storage.calls.last, 'refresh');
  });

  test('no-op publisher completes without doing anything', () async {
    const noop = NoopTaskWidgetPublisher();

    await expectLater(noop.publish(snapshot), completes);
    await expectLater(noop.clearForSignOut(), completes);
  });
}
