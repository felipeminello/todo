import 'package:todo/core/time/calendar_date.dart';
import 'package:todo/features/tasks/domain/entities/task.dart';
import 'package:todo/features/tasks/domain/entities/widget_task_snapshot.dart';

/// Chooses and orders the tasks the home screen widget needs.
///
/// The widget itself only drops the tasks due after its current day, keeps
/// as many as fit and draws them bottom-up, so the rule lives here alone.
final class SelectWidgetTasks {
  const SelectWidgetTasks();

  /// Days after today that the snapshot covers.
  static const horizonDays = 7;

  WidgetTaskSnapshot call(
    List<Task> tasks, {
    required CalendarDate today,
    required DateTime generatedAt,
  }) {
    final coversUntil = today.addDays(horizonDays);
    final selected = [
      for (final task in tasks)
        if (task.dueDate case final dueDate?
            when !task.isCompleted && !dueDate.isAfter(coversUntil))
          (dueDate, task),
    ]..sort(_mostRecentFirst);

    return WidgetTaskSnapshot(
      tasks: List.unmodifiable([for (final (_, task) in selected) task]),
      generatedAt: generatedAt.toUtc(),
      coversUntil: coversUntil,
    );
  }

  // Ties on the instant fall back to the id so the order never changes
  // between reloads.
  static int _mostRecentFirst((CalendarDate, Task) a, (CalendarDate, Task) b) {
    final byDueDate = b.$1.compareTo(a.$1);
    if (byDueDate != 0) return byDueDate;
    final byCreation = b.$2.createdAt.compareTo(a.$2.createdAt);
    return byCreation != 0 ? byCreation : b.$2.id.compareTo(a.$2.id);
  }
}
