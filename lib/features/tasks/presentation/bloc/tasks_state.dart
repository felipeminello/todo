part of 'tasks_bloc.dart';

enum TasksStatus { loading, loaded, failure }

final class TasksState extends Equatable {
  const TasksState({
    this.status = TasksStatus.loading,
    this.tasks = const [],
    this.timeline = const TaskTimeline(),
    this.today,
    this.loadFailure,
    this.isRefreshing = false,
    this.isSaving = false,
    this.actionFailure,
  });

  final TasksStatus status;

  /// The tasks on screen: the last load plus the changes made since, some of
  /// them possibly not yet confirmed by the server.
  final List<Task> tasks;

  /// [tasks] organized for display.
  final TaskTimeline timeline;

  /// The day [timeline] was built for, as the device saw it.
  final CalendarDate? today;

  /// Why the first load failed; set only when [status] is
  /// [TasksStatus.failure].
  final TaskFailureReason? loadFailure;

  /// A reload is in flight while [timeline] is still shown.
  final bool isRefreshing;

  /// A created or edited task is being stored; it shows once the server
  /// confirms it.
  final bool isSaving;

  /// The most recent failed change or reload over a shown list, for a
  /// one-off message.
  final TaskActionFailure? actionFailure;

  TasksState copyWith({
    TasksStatus? status,
    List<Task>? tasks,
    TaskTimeline? timeline,
    CalendarDate? today,
    TaskFailureReason? Function()? loadFailure,
    bool? isRefreshing,
    bool? isSaving,
    TaskActionFailure? actionFailure,
  }) {
    return TasksState(
      status: status ?? this.status,
      tasks: tasks ?? this.tasks,
      timeline: timeline ?? this.timeline,
      today: today ?? this.today,
      loadFailure: loadFailure != null ? loadFailure() : this.loadFailure,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isSaving: isSaving ?? this.isSaving,
      actionFailure: actionFailure ?? this.actionFailure,
    );
  }

  @override
  List<Object?> get props => [
    status,
    tasks,
    timeline,
    today,
    loadFailure,
    isRefreshing,
    isSaving,
    actionFailure,
  ];
}

/// A failure to report once. [sequence] grows with every failure, so two
/// equal reasons in a row still count as two messages.
final class TaskActionFailure extends Equatable {
  const TaskActionFailure(this.reason, this.sequence);

  final TaskFailureReason reason;
  final int sequence;

  @override
  List<Object> get props => [reason, sequence];
}
