import 'package:todo/core/time/calendar_date.dart';
import 'package:todo/features/tasks/domain/entities/task.dart';

/// Builds a task created [createdMinute] minutes after a fixed base instant,
/// so tests can express creation order with small integers.
Task buildTask(
  String id, {
  String? title,
  String description = '',
  CalendarDate? dueDate,
  int createdMinute = 0,
  int? completedMinute,
}) {
  return Task(
    id: id,
    title: title ?? 'Task $id',
    description: description,
    dueDate: dueDate,
    createdAt: baseInstant.add(Duration(minutes: createdMinute)),
    completedAt: completedMinute == null
        ? null
        : baseInstant.add(Duration(minutes: completedMinute)),
  );
}

final baseInstant = DateTime.utc(2026, 10, 1, 12);
