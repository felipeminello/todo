import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:todo/core/time/calendar_date.dart';
import 'package:todo/features/tasks/domain/entities/widget_task_snapshot.dart';
import 'package:todo/features/tasks/domain/repositories/task_widget_publisher.dart';
import 'package:todo/features/tasks/domain/usecases/clear_widget_tasks.dart';
import 'package:todo/features/tasks/domain/usecases/publish_widget_tasks.dart';

import '../../../../helpers/fixed_clock.dart';
import '../../../../helpers/task_factory.dart';

class _MockTaskWidgetPublisher extends Mock implements TaskWidgetPublisher {}

void main() {
  late _MockTaskWidgetPublisher publisher;

  setUpAll(() {
    registerFallbackValue(
      WidgetTaskSnapshot(
        tasks: const [],
        generatedAt: baseInstant,
        coversUntil: CalendarDate(2026, 1, 1),
      ),
    );
  });

  setUp(() {
    publisher = _MockTaskWidgetPublisher();
    when(() => publisher.publish(any())).thenAnswer((_) async {});
    when(() => publisher.clearForSignOut()).thenAnswer((_) async {});
  });

  group('PublishWidgetTasks', () {
    test('publishes the selection for the local day of the clock', () async {
      final now = DateTime(2026, 10, 27, 23, 50);
      final today = CalendarDate(2026, 10, 27);
      final tasks = [
        buildTask('today', dueDate: today),
        buildTask('undated'),
        buildTask('overdue', dueDate: today.addDays(-1)),
      ];

      await PublishWidgetTasks(publisher, FixedClock(now))(tasks);

      final snapshot =
          verify(() => publisher.publish(captureAny())).captured.single
              as WidgetTaskSnapshot;
      expect([for (final t in snapshot.tasks) t.id], ['today', 'overdue']);
      expect(snapshot.coversUntil, CalendarDate(2026, 11, 3));
      expect(snapshot.generatedAt, now.toUtc());
    });

    test('propagates publisher errors to the caller', () {
      when(() => publisher.publish(any()))
          .thenAnswer((_) async => throw StateError('storage'));

      expect(
        PublishWidgetTasks(publisher, FixedClock(baseInstant))(const []),
        throwsStateError,
      );
    });
  });

  group('ClearWidgetTasks', () {
    test('clears the widget for sign-out', () async {
      await ClearWidgetTasks(publisher)();

      verify(() => publisher.clearForSignOut()).called(1);
      verifyNever(() => publisher.publish(any()));
    });
  });

  test('the domain layer imports neither Flutter nor home_widget', () {
    final offending = [
      for (final entity in Directory(
        'lib/features/tasks/domain',
      ).listSync(recursive: true))
        if (entity is File && entity.path.endsWith('.dart'))
          for (final line in entity.readAsLinesSync())
            if (line.startsWith('import') &&
                (line.contains('package:flutter/') ||
                    line.contains('package:home_widget/')))
              '${entity.path}: $line',
    ];

    expect(offending, isEmpty);
  });
}
