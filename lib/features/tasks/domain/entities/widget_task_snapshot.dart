import 'package:equatable/equatable.dart';
import 'package:todo/core/time/calendar_date.dart';
import 'package:todo/features/tasks/domain/entities/task.dart';

/// What the home screen widget can show until the app runs again.
///
/// It holds every pending task due up to [coversUntil], not only today's,
/// so the widget can move to the next day on its own at midnight.
final class WidgetTaskSnapshot extends Equatable {
  const WidgetTaskSnapshot({
    required this.tasks,
    required this.generatedAt,
    required this.coversUntil,
  });

  /// Most recent due date first, then most recently created first. The
  /// order does not depend on the current day, so it stays valid after
  /// midnight.
  final List<Task> tasks;

  /// UTC instant.
  final DateTime generatedAt;

  /// Last day for which [tasks] is complete. Past it the widget can no
  /// longer tell what is due.
  final CalendarDate coversUntil;

  @override
  List<Object> get props => [tasks, generatedAt, coversUntil];
}
