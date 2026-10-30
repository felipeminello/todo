import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/time/calendar_date.dart';
import 'package:todo/features/tasks/domain/entities/task.dart';
import 'package:todo/features/tasks/domain/entities/widget_task_snapshot.dart';
import 'package:todo/features/tasks/domain/usecases/select_widget_tasks.dart';

import '../../../../helpers/task_factory.dart';

void main() {
  const select = SelectWidgetTasks();
  final today = CalendarDate(2026, 10, 27);
  final generatedAt = DateTime.utc(2026, 10, 27, 15, 30);

  WidgetTaskSnapshot snapshot(List<Task> tasks, {CalendarDate? on}) =>
      select(tasks, today: on ?? today, generatedAt: generatedAt);
  List<String> ids(WidgetTaskSnapshot s) => [for (final t in s.tasks) t.id];

  test('empty list gives an empty snapshot', () {
    final result = snapshot([]);

    expect(result.tasks, isEmpty);
    expect(result.generatedAt, generatedAt);
    expect(result.coversUntil, CalendarDate(2026, 11, 3));
  });

  test('completed tasks are left out, even when due today', () {
    final result = snapshot([
      buildTask('done', dueDate: today, completedMinute: 5),
      buildTask('doneOverdue', dueDate: today.addDays(-2), completedMinute: 6),
    ]);

    expect(result.tasks, isEmpty);
  });

  test('undated tasks are left out', () {
    final result = snapshot([buildTask('a'), buildTask('b')]);

    expect(result.tasks, isEmpty);
  });

  test('future tasks are kept up to the horizon and dropped after it', () {
    final result = snapshot([
      buildTask('lastDay', dueDate: today.addDays(7)),
      buildTask('beyond', dueDate: today.addDays(8)),
      buildTask('tomorrow', dueDate: today.addDays(1)),
    ]);

    expect(ids(result), ['lastDay', 'tomorrow']);
  });

  test('old overdue tasks are kept', () {
    final result = snapshot([
      buildTask('lastYear', dueDate: CalendarDate(2025, 10, 27)),
      buildTask('yesterday', dueDate: today.addDays(-1)),
    ]);

    expect(ids(result), ['yesterday', 'lastYear']);
  });

  test('orders by due date, most recent first', () {
    final result = snapshot([
      buildTask('overdue3', dueDate: today.addDays(-3)),
      buildTask('today', dueDate: today),
      buildTask('tomorrow', dueDate: today.addDays(1)),
      buildTask('overdue1', dueDate: today.addDays(-1)),
    ]);

    expect(ids(result), ['tomorrow', 'today', 'overdue1', 'overdue3']);
  });

  test('same due date: most recently created first', () {
    final result = snapshot([
      buildTask('early', dueDate: today, createdMinute: 1),
      buildTask('late', dueDate: today, createdMinute: 9),
      buildTask('middle', dueDate: today, createdMinute: 5),
    ]);

    expect(ids(result), ['late', 'middle', 'early']);
  });

  test('same due date and creation instant: falls back to the id', () {
    final result = snapshot([
      buildTask('a', dueDate: today, createdMinute: 3),
      buildTask('c', dueDate: today, createdMinute: 3),
      buildTask('b', dueDate: today, createdMinute: 3),
    ]);

    expect(ids(result), ['c', 'b', 'a']);
  });

  test('mixed list keeps only pending dated tasks within the horizon', () {
    final result = snapshot([
      buildTask('undated'),
      buildTask('done', dueDate: today, completedMinute: 1),
      buildTask('beyond', dueDate: today.addDays(30)),
      buildTask('today', dueDate: today),
      buildTask('overdue', dueDate: today.addDays(-1)),
    ]);

    expect(ids(result), ['today', 'overdue']);
  });

  test('horizon crosses the month boundary', () {
    final result = snapshot([
      buildTask('nov3', dueDate: CalendarDate(2026, 11, 3)),
      buildTask('nov4', dueDate: CalendarDate(2026, 11, 4)),
    ]);

    expect(result.coversUntil, CalendarDate(2026, 11, 3));
    expect(ids(result), ['nov3']);
  });

  test('horizon crosses the year boundary', () {
    final result = snapshot([
      buildTask('jan4', dueDate: CalendarDate(2027, 1, 4)),
      buildTask('jan5', dueDate: CalendarDate(2027, 1, 5)),
      buildTask('dec31', dueDate: CalendarDate(2026, 12, 31)),
    ], on: CalendarDate(2026, 12, 28));

    expect(result.coversUntil, CalendarDate(2027, 1, 4));
    expect(ids(result), ['jan4', 'dec31']);
  });

  test('generatedAt is stored in UTC', () {
    final local = DateTime(2026, 10, 27, 9);
    final result = select([], today: today, generatedAt: local);

    expect(result.generatedAt.isUtc, isTrue);
    expect(result.generatedAt, local.toUtc());
  });
}
