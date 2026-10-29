import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/time/calendar_date.dart';
import 'package:todo/features/tasks/domain/entities/task.dart';
import 'package:todo/features/tasks/domain/entities/task_timeline.dart';
import 'package:todo/features/tasks/domain/usecases/build_task_timeline.dart';

import '../../../../helpers/task_factory.dart';

void main() {
  const build = BuildTaskTimeline();
  final today = CalendarDate(2026, 10, 27);

  TaskTimeline timeline(List<Task> tasks) => build(tasks, today: today);
  List<String> ids(List<Task> tasks) => [for (final t in tasks) t.id];
  List<CalendarDate> dates(TaskTimeline t) => [for (final g in t.days) g.date];

  test('empty list gives an empty timeline', () {
    final result = timeline([]);

    expect(result.isEmpty, isTrue);
    expect(result, const TaskTimeline());
  });

  test('only undated tasks: most recently created first', () {
    final result = timeline([
      buildTask('a', createdMinute: 1),
      buildTask('c', createdMinute: 3),
      buildTask('b', createdMinute: 2),
    ]);

    expect(ids(result.undated), ['c', 'b', 'a']);
    expect(result.days, isEmpty);
    expect(result.completed, isEmpty);
  });

  test('only dated tasks: grouped by day in ascending order', () {
    final result = timeline([
      buildTask('nov2', dueDate: CalendarDate(2026, 11, 2)),
      buildTask('oct27', dueDate: CalendarDate(2026, 10, 27)),
      buildTask('oct30', dueDate: CalendarDate(2026, 10, 30)),
    ]);

    expect(result.undated, isEmpty);
    expect(dates(result), [
      CalendarDate(2026, 10, 27),
      CalendarDate(2026, 10, 30),
      CalendarDate(2026, 11, 2),
    ]);
  });

  test('mixed tasks land in exactly one block each', () {
    final result = timeline([
      buildTask('undated'),
      buildTask('dated', dueDate: CalendarDate(2026, 10, 30)),
      buildTask('done', completedMinute: 5),
      buildTask(
        'doneDated',
        dueDate: CalendarDate(2026, 10, 30),
        completedMinute: 6,
      ),
    ]);

    expect(ids(result.undated), ['undated']);
    expect(result.days, hasLength(1));
    expect(ids(result.days.single.tasks), ['dated']);
    expect(ids(result.completed), ['doneDated', 'done']);
  });

  test('same day becomes a single group ordered by creation, oldest first', () {
    final day = CalendarDate(2026, 10, 27);
    final result = timeline([
      buildTask('second', dueDate: day, createdMinute: 2),
      buildTask('third', dueDate: day, createdMinute: 3),
      buildTask('first', dueDate: day, createdMinute: 1),
    ]);

    expect(result.days, hasLength(1));
    expect(ids(result.days.single.tasks), ['first', 'second', 'third']);
  });

  test('ties on creation instant are broken by id, deterministically', () {
    final day = CalendarDate(2026, 10, 27);
    final tasks = [
      buildTask('b', dueDate: day),
      buildTask('a', dueDate: day),
      buildTask('y'),
      buildTask('x'),
    ];

    final result = timeline(tasks);
    final reversed = timeline(tasks.reversed.toList());

    expect(ids(result.days.single.tasks), ['a', 'b']);
    expect(ids(result.undated), ['y', 'x']);
    expect(reversed, result);
  });

  test('month boundary', () {
    final result = timeline([
      buildTask('nov1', dueDate: CalendarDate(2026, 11, 1)),
      buildTask('oct31', dueDate: CalendarDate(2026, 10, 31)),
    ]);

    expect(dates(result), [
      CalendarDate(2026, 10, 31),
      CalendarDate(2026, 11, 1),
    ]);
  });

  test('year boundary', () {
    final result = timeline([
      buildTask('jan1', dueDate: CalendarDate(2027, 1, 1)),
      buildTask('dec31', dueDate: CalendarDate(2026, 12, 31)),
    ]);

    expect(dates(result), [
      CalendarDate(2026, 12, 31),
      CalendarDate(2027, 1, 1),
    ]);
  });

  test('a day before today is overdue; today and later are not', () {
    final result = timeline([
      buildTask('yesterday', dueDate: CalendarDate(2026, 10, 26)),
      buildTask('today', dueDate: CalendarDate(2026, 10, 27)),
      buildTask('tomorrow', dueDate: CalendarDate(2026, 10, 28)),
      buildTask('lastYear', dueDate: CalendarDate(2025, 12, 31)),
    ]);

    expect(
      [for (final g in result.days) g.isOverdue],
      [true, true, false, false],
    );
    expect(dates(result).first, CalendarDate(2025, 12, 31));
  });

  test('overdue tasks stay in the timeline in date order', () {
    final result = timeline([
      buildTask('late', dueDate: CalendarDate(2026, 10, 25)),
      buildTask('soon', dueDate: CalendarDate(2026, 10, 28)),
    ]);

    expect(dates(result), [
      CalendarDate(2026, 10, 25),
      CalendarDate(2026, 10, 28),
    ]);
    expect(result.days.first.isOverdue, isTrue);
    expect(result.days.last.isOverdue, isFalse);
  });

  test('a task becomes overdue when the day turns', () {
    final tasks = [buildTask('t', dueDate: CalendarDate(2026, 10, 27))];

    expect(build(tasks, today: today).days.single.isOverdue, isFalse);
    expect(
      build(tasks, today: CalendarDate(2026, 10, 28)).days.single.isOverdue,
      isTrue,
    );
  });

  test('completed tasks with past due dates leave the timeline', () {
    final result = timeline([
      buildTask(
        'done',
        dueDate: CalendarDate(2026, 10, 20),
        completedMinute: 1,
      ),
    ]);

    expect(result.days, isEmpty);
    expect(ids(result.completed), ['done']);
  });

  test('completed tasks: most recently completed first', () {
    final result = timeline([
      buildTask('a', createdMinute: 1, completedMinute: 10),
      buildTask('b', createdMinute: 2, completedMinute: 30),
      buildTask('c', createdMinute: 3, completedMinute: 20),
    ]);

    expect(ids(result.completed), ['b', 'c', 'a']);
  });

  test('reopening a dated task returns it to its day', () {
    final done = buildTask(
      'r',
      dueDate: CalendarDate(2026, 10, 30),
      completedMinute: 5,
    );
    final reopened = done.copyWith(completedAt: () => null);

    expect(timeline([done]).days, isEmpty);

    final result = timeline([reopened]);
    expect(result.completed, isEmpty);
    expect(result.days.single.date, CalendarDate(2026, 10, 30));
    expect(ids(result.days.single.tasks), ['r']);
  });

  test('reopening an undated task returns it to the undated block', () {
    final reopened = buildTask(
      'r',
      completedMinute: 5,
    ).copyWith(completedAt: () => null);

    expect(ids(timeline([reopened]).undated), ['r']);
  });

  test('only the group of today is marked as today', () {
    final result = timeline([
      buildTask('yesterday', dueDate: CalendarDate(2026, 10, 26)),
      buildTask('today', dueDate: today),
      buildTask('tomorrow', dueDate: CalendarDate(2026, 10, 28)),
    ]);

    expect([for (final g in result.days) g.isToday], [false, true, false]);
  });

  test('pending count adds undated and dated tasks, not completed ones', () {
    final result = timeline([
      buildTask('undated'),
      buildTask('a', dueDate: CalendarDate(2026, 10, 30)),
      buildTask('b', dueDate: CalendarDate(2026, 10, 30)),
      buildTask('c', dueDate: CalendarDate(2026, 11, 2)),
      buildTask('done', completedMinute: 5),
    ]);

    expect(result.pendingCount, 4);
    expect(timeline([]).pendingCount, 0);
  });
}
