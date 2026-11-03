part of 'tasks_bloc.dart';

sealed class TasksEvent extends Equatable {
  const TasksEvent();

  @override
  List<Object?> get props => [];
}

/// Load or reload the tasks from the server.
final class TasksRequested extends TasksEvent {
  const TasksRequested();
}

final class TaskAdded extends TasksEvent {
  const TaskAdded(this.params);

  final AddTaskParams params;

  @override
  List<Object?> get props => [params];
}

final class TaskUpdated extends TasksEvent {
  const TaskUpdated(this.params);

  final UpdateTaskParams params;

  @override
  List<Object?> get props => [params];
}

final class TaskDeleted extends TasksEvent {
  const TaskDeleted(this.task);

  final Task task;

  @override
  List<Object?> get props => [task];
}

/// The user confirmed deleting every task in [tasks] at once.
final class CompletedTasksDeleted extends TasksEvent {
  const CompletedTasksDeleted(this.tasks);

  final List<Task> tasks;

  @override
  List<Object?> get props => [tasks];
}

final class TaskCompletionToggled extends TasksEvent {
  const TaskCompletionToggled(this.task);

  final Task task;

  @override
  List<Object?> get props => [task];
}
