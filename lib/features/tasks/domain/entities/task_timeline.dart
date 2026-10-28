import 'package:equatable/equatable.dart';
import 'package:todo/core/time/calendar_date.dart';
import 'package:todo/features/tasks/domain/entities/task.dart';

/// The tasks as the main screen shows them.
final class TaskTimeline extends Equatable {
  const TaskTimeline({
    this.undated = const [],
    this.days = const [],
    this.completed = const [],
  });

  /// Pending tasks without a due date, most recently created first.
  final List<Task> undated;

  /// Pending tasks with a due date, one group per day, earliest day first.
  final List<DayGroup> days;

  /// Completed tasks, most recently completed first.
  final List<Task> completed;

  bool get isEmpty => undated.isEmpty && days.isEmpty && completed.isEmpty;

  @override
  List<Object> get props => [undated, days, completed];
}

final class DayGroup extends Equatable {
  const DayGroup({
    required this.date,
    required this.isOverdue,
    required this.tasks,
  });

  final CalendarDate date;

  /// Every task in a group is pending, so a day before today means all of
  /// them are overdue.
  final bool isOverdue;

  /// Oldest created first.
  final List<Task> tasks;

  @override
  List<Object> get props => [date, isOverdue, tasks];
}
