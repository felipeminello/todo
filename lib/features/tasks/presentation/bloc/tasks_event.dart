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

final class TaskCompletionToggled extends TasksEvent {
  const TaskCompletionToggled(this.task);

  final Task task;

  @override
  List<Object?> get props => [task];
}
