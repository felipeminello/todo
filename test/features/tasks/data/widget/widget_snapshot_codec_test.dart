import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/time/calendar_date.dart';
import 'package:todo/features/tasks/data/widget/widget_snapshot_codec.dart';
import 'package:todo/features/tasks/data/widget/widget_strings.dart';
import 'package:todo/features/tasks/domain/entities/widget_task_snapshot.dart';

import '../../../../helpers/task_factory.dart';

void main() {
  const strings = WidgetStrings(
    header: 'Hoje',
    empty: 'Nada para hoje',
    stale: 'Abra o app para atualizar',
    signedOut: 'Entre no app para ver suas tarefas',
    overdue: 'Atrasada',
  );
  const codec = WidgetSnapshotCodec(strings);
  const stringsJson = {
    'header': 'Hoje',
    'empty': 'Nada para hoje',
    'stale': 'Abra o app para atualizar',
    'signedOut': 'Entre no app para ver suas tarefas',
    'overdue': 'Atrasada',
  };

  Map<String, Object?> decode(String json) =>
      jsonDecode(json) as Map<String, Object?>;

  test('encodes a snapshot with tasks in the v1 format', () {
    final snapshot = WidgetTaskSnapshot(
      tasks: [
        buildTask(
          'b2',
          title: 'Reunião',
          dueDate: CalendarDate(2026, 10, 29),
          createdMinute: 120,
        ),
        buildTask(
          'e5',
          title: 'Ligar banco',
          dueDate: CalendarDate(2026, 10, 28),
        ),
      ],
      generatedAt: DateTime.utc(2026, 10, 29, 13, 2),
      coversUntil: CalendarDate(2026, 11, 5),
    );

    expect(decode(codec.encode(snapshot)), {
      'version': 1,
      'signedIn': true,
      'generatedAt': '2026-10-29T13:02:00.000Z',
      'coversUntil': '2026-11-05',
      'tasks': [
        {
          'id': 'b2',
          'title': 'Reunião',
          'dueDate': '2026-10-29',
          'createdAt': '2026-10-01T14:00:00.000Z',
        },
        {
          'id': 'e5',
          'title': 'Ligar banco',
          'dueDate': '2026-10-28',
          'createdAt': '2026-10-01T12:00:00.000Z',
        },
      ],
      'strings': stringsJson,
    });
  });

  test('keeps the task order of the snapshot', () {
    final snapshot = WidgetTaskSnapshot(
      tasks: [
        for (final id in ['z', 'a', 'm'])
          buildTask(id, dueDate: CalendarDate(2026, 10, 29)),
      ],
      generatedAt: baseInstant,
      coversUntil: CalendarDate(2026, 11, 5),
    );

    final tasks = decode(codec.encode(snapshot))['tasks']! as List<Object?>;

    expect([for (final t in tasks) (t! as Map)['id']], ['z', 'a', 'm']);
  });

  test('due dates are calendar days, never shifted by time zone', () {
    final snapshot = WidgetTaskSnapshot(
      tasks: [buildTask('a', dueDate: CalendarDate(2026, 10, 27))],
      generatedAt: baseInstant,
      coversUntil: CalendarDate(2026, 11, 3),
    );

    final task =
        (decode(codec.encode(snapshot))['tasks']! as List<Object?>).single!
            as Map;

    expect(task['dueDate'], '2026-10-27');
  });

  test('instants are written in UTC even when given in local time', () {
    final local = DateTime(2026, 10, 29, 10, 2);
    final snapshot = WidgetTaskSnapshot(
      tasks: const [],
      generatedAt: local,
      coversUntil: CalendarDate(2026, 11, 5),
    );

    final generatedAt =
        decode(codec.encode(snapshot))['generatedAt']! as String;

    expect(generatedAt, endsWith('Z'));
    expect(DateTime.parse(generatedAt), local.toUtc());
  });

  test('signed-out snapshot carries no task data', () {
    expect(decode(codec.encodeSignedOut()), {
      'version': 1,
      'signedIn': false,
      'tasks': <Object>[],
      'strings': stringsJson,
    });
  });
}
