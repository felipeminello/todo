import 'package:todo/core/time/calendar_date.dart';
import 'package:todo/features/tasks/domain/entities/task.dart';
import 'package:todo/features/tasks/domain/entities/task_timeline.dart';

/// Organizes tasks into the main screen's blocks: undated, timeline by day
/// and completed.
final class BuildTaskTimeline {
  const BuildTaskTimeline();

  TaskTimeline call(List<Task> tasks, {required CalendarDate today}) {
    final undated = <Task>[];
    final byDay = <CalendarDate, List<Task>>{};
    final completed = <(DateTime, Task)>[];

    for (final task in tasks) {
      final dueDate = task.dueDate;
      final completedAt = task.completedAt;
      if (completedAt != null) {
        completed.add((completedAt, task));
      } else if (dueDate == null) {
        undated.add(task);
      } else {
        (byDay[dueDate] ??= []).add(task);
      }
    }

    undated.sort((a, b) => _byCreation(b, a));
    completed.sort(_byCompletionDescending);

    final days = byDay.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    return TaskTimeline(
      undated: List.unmodifiable(undated),
      days: List.unmodifiable([
        for (final MapEntry(key: date, value: dayTasks) in days)
          DayGroup(
            date: date,
            isOverdue: date.isBefore(today),
            tasks: List.unmodifiable(dayTasks..sort(_byCreation)),
          ),
      ]),
      completed: List.unmodifiable([for (final (_, task) in completed) task]),
    );
  }

  // Ties on the instant fall back to the id so the order never changes
  // between reloads.
  static int _byCreation(Task a, Task b) {
    final byInstant = a.createdAt.compareTo(b.createdAt);
    return byInstant != 0 ? byInstant : a.id.compareTo(b.id);
  }

  static int _byCompletionDescending((DateTime, Task) a, (DateTime, Task) b) {
    final byInstant = b.$1.compareTo(a.$1);
    return byInstant != 0 ? byInstant : b.$2.id.compareTo(a.$2.id);
  }
}
