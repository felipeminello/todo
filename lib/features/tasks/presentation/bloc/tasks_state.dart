part of 'tasks_bloc.dart';

enum TasksStatus { loading, loaded, failure }

final class TasksState extends Equatable {
  const TasksState({
    this.status = TasksStatus.loading,
    this.timeline = const TaskTimeline(),
    this.loadFailure,
    this.isRefreshing = false,
    this.actionFailure,
  });

  final TasksStatus status;

  /// The last successfully loaded tasks, kept while refreshing or after a
  /// failed change.
  final TaskTimeline timeline;

  /// Why the first load failed; set only when [status] is
  /// [TasksStatus.failure].
  final TaskFailureReason? loadFailure;

  /// A reload is in flight while [timeline] is still shown.
  final bool isRefreshing;

  /// The most recent failed change or reload over a shown list, for a
  /// one-off message.
  final TaskActionFailure? actionFailure;

  TasksState copyWith({
    TasksStatus? status,
    TaskTimeline? timeline,
    TaskFailureReason? Function()? loadFailure,
    bool? isRefreshing,
    TaskActionFailure? actionFailure,
  }) {
    return TasksState(
      status: status ?? this.status,
      timeline: timeline ?? this.timeline,
      loadFailure: loadFailure != null ? loadFailure() : this.loadFailure,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      actionFailure: actionFailure ?? this.actionFailure,
    );
  }

  @override
  List<Object?> get props => [
    status,
    timeline,
    loadFailure,
    isRefreshing,
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
