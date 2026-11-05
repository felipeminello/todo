import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/time/calendar_date.dart';
import 'package:todo/features/tasks/domain/entities/task_timeline.dart';

import '../../../../helpers/task_factory.dart';

void main() {
  group('taskById', () {
    final undated = buildTask('1');
    final dated = buildTask('2', dueDate: CalendarDate(2026, 10, 30));
    final completed = buildTask('3', completedMinute: 1);
    final timeline = TaskTimeline(
      undated: [undated],
      days: [
        DayGroup(
          date: CalendarDate(2026, 10, 30),
          isOverdue: false,
          isToday: false,
          tasks: [dated],
        ),
      ],
      completed: [completed],
    );

    test('finds a task in any block', () {
      expect(timeline.taskById('1'), undated);
      expect(timeline.taskById('2'), dated);
      expect(timeline.taskById('3'), completed);
    });

    test('is null for a task that is not shown', () {
      expect(timeline.taskById('4'), isNull);
      expect(const TaskTimeline().taskById('1'), isNull);
    });
  });
}
