import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:todo/core/error/failure.dart';
import 'package:todo/core/time/calendar_date.dart';
import 'package:todo/core/time/clock.dart';
import 'package:todo/features/tasks/domain/entities/task.dart';
import 'package:todo/features/tasks/domain/entities/task_timeline.dart';
import 'package:todo/features/tasks/domain/usecases/add_task.dart';
import 'package:todo/features/tasks/domain/usecases/build_task_timeline.dart';
import 'package:todo/features/tasks/domain/usecases/delete_task.dart';
import 'package:todo/features/tasks/domain/usecases/get_tasks.dart';
import 'package:todo/features/tasks/domain/usecases/toggle_task.dart';
import 'package:todo/features/tasks/domain/usecases/update_task.dart';

part 'tasks_event.dart';
part 'tasks_state.dart';

/// Every change goes to the server first and the list is then reloaded from
/// it, so what is shown is always what is stored.
final class TasksBloc extends Bloc<TasksEvent, TasksState> {
  TasksBloc({
    required this._getTasks,
    required this._addTask,
    required this._updateTask,
    required this._deleteTask,
    required this._toggleTask,
    required this._buildTimeline,
    required this._clock,
  }) : super(const TasksState()) {
    on<TasksRequested>((event, emit) => _reload(emit, reportFailure: true));
    on<TaskAdded>((event, emit) => _change(emit, () => _addTask(event.params)));
    on<TaskUpdated>(
      (event, emit) => _change(emit, () => _updateTask(event.params)),
    );
    on<TaskDeleted>(
      (event, emit) => _change(emit, () => _deleteTask(event.task.id)),
    );
    on<TaskCompletionToggled>(
      (event, emit) => _change(emit, () => _toggleTask(event.task)),
    );
  }

  final GetTasks _getTasks;
  final AddTask _addTask;
  final UpdateTask _updateTask;
  final DeleteTask _deleteTask;
  final ToggleTask _toggleTask;
  final BuildTaskTimeline _buildTimeline;
  final Clock _clock;
  int _failureSequence = 0;

  Future<void> _reload(
    Emitter<TasksState> emit, {
    required bool reportFailure,
  }) async {
    final hasList = state.status == TasksStatus.loaded;
    final pending = hasList
        ? state.copyWith(isRefreshing: true)
        : state.copyWith(status: TasksStatus.loading, loadFailure: () => null);
    // Bloc emits the first state even when it equals the initial one.
    if (pending != state) emit(pending);
    try {
      final tasks = await _getTasks();
      final today = CalendarDate.fromLocal(_clock.now());
      emit(
        state.copyWith(
          status: TasksStatus.loaded,
          timeline: _buildTimeline(tasks, today: today),
          today: today,
          loadFailure: () => null,
          isRefreshing: false,
        ),
      );
    } on Object catch (error) {
      final reason = _reasonOf(error);
      emit(
        hasList
            ? state.copyWith(
                isRefreshing: false,
                actionFailure: reportFailure ? _nextFailure(reason) : null,
              )
            : state.copyWith(
                status: TasksStatus.failure,
                loadFailure: () => reason,
                isRefreshing: false,
              ),
      );
    }
  }

  Future<void> _change(
    Emitter<TasksState> emit,
    Future<Object?> Function() action,
  ) async {
    var failed = false;
    try {
      await action();
    } on Object catch (error) {
      failed = true;
      emit(state.copyWith(actionFailure: _nextFailure(_reasonOf(error))));
    }
    // After a failed change the cause was already reported; the reload only
    // makes sure the list matches what is stored.
    await _reload(emit, reportFailure: !failed);
  }

  TaskActionFailure _nextFailure(TaskFailureReason reason) =>
      TaskActionFailure(reason, ++_failureSequence);

  static TaskFailureReason _reasonOf(Object error) =>
      error is TaskFailure ? error.reason : TaskFailureReason.unknown;
}
