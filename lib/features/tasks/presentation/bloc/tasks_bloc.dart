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
import 'package:todo/features/tasks/domain/usecases/publish_widget_tasks.dart';
import 'package:todo/features/tasks/domain/usecases/toggle_task.dart';
import 'package:todo/features/tasks/domain/usecases/update_task.dart';

part 'tasks_event.dart';
part 'tasks_state.dart';

/// Completing and deleting show at once and are stored in the background,
/// undone on screen if storing fails. Creating and editing wait for the server,
/// with [TasksState.isSaving] set meanwhile: a new task only gets its id there.
/// No change reloads the list; the screen keeps it up to date itself.
///
/// Writes and reloads reach the server one at a time, in the order they were
/// made, so two quick changes to the same task never land out of order.
final class TasksBloc extends Bloc<TasksEvent, TasksState> {
  TasksBloc({
    required this._getTasks,
    required this._addTask,
    required this._updateTask,
    required this._deleteTask,
    required this._toggleTask,
    required this._buildTimeline,
    required this._publishWidgetTasks,
    required this._clock,
  }) : super(const TasksState()) {
    on<TasksRequested>((event, emit) => _reload(emit));
    on<TaskAdded>(
      (event, emit) => _save(emit, () => _addTask(event.params), _upserted),
    );
    on<TaskUpdated>(
      (event, emit) => _save(
        emit,
        () => _updateTask(event.params),
        _replaced,
        taskId: event.params.original.id,
      ),
    );
    on<TaskDeleted>(
      (event, emit) => _changeNow(
        emit,
        before: event.task,
        after: null,
        store: () => _deleteTask(event.task.id),
      ),
    );
    on<CompletedTasksDeleted>(
      (event, emit) => _deleteAllNow(emit, event.tasks),
    );
    on<TaskCompletionToggled>((event, emit) {
      final toggled = _toggleTask.toggled(event.task);
      return _changeNow(
        emit,
        before: event.task,
        after: toggled,
        store: () => _toggleTask(toggled),
      );
    });
  }

  final GetTasks _getTasks;
  final AddTask _addTask;
  final UpdateTask _updateTask;
  final DeleteTask _deleteTask;
  final ToggleTask _toggleTask;
  final BuildTaskTimeline _buildTimeline;
  final PublishWidgetTasks _publishWidgetTasks;
  final Clock _clock;
  int _failureSequence = 0;
  int _savesInFlight = 0;

  /// Completes when the last queued server call has finished.
  Future<void> _serverQueue = Future<void>.value();

  Future<void> _reload(Emitter<TasksState> emit) async {
    final hasList = state.status == TasksStatus.loaded;
    final pending = hasList
        ? state.copyWith(isRefreshing: true)
        : state.copyWith(status: TasksStatus.loading, loadFailure: () => null);
    // Bloc emits the first state even when it equals the initial one.
    if (pending != state) emit(pending);
    try {
      final tasks = await _inOrder(_getTasks.call);
      _show(
        emit,
        tasks,
        state.copyWith(
          status: TasksStatus.loaded,
          loadFailure: () => null,
          isRefreshing: false,
        ),
      );
      await _publishToWidget(tasks);
    } on Object catch (error) {
      final reason = _reasonOf(error);
      emit(
        hasList
            ? state.copyWith(
                isRefreshing: false,
                actionFailure: _nextFailure(reason),
              )
            : state.copyWith(
                status: TasksStatus.failure,
                loadFailure: () => reason,
                isRefreshing: false,
              ),
      );
    }
  }

  /// Stores a change that only shows once the server has it.
  Future<void> _save(
    Emitter<TasksState> emit,
    Future<Task> Function() store,
    List<Task> Function(List<Task>, Task) merge, {
    String? taskId,
  }) async {
    _savesInFlight++;
    emit(state.copyWith(isSaving: true));
    try {
      final saved = await _inOrder(store);
      _show(emit, merge(state.tasks, saved), state);
      await _publishToWidget(state.tasks);
    } on Object catch (error) {
      final reason = _reasonOf(error);
      _show(
        emit,
        _withoutIfGone(state.tasks, taskId, reason),
        state.copyWith(actionFailure: _nextFailure(reason)),
      );
    } finally {
      _savesInFlight--;
      emit(state.copyWith(isSaving: _savesInFlight > 0));
    }
  }

  /// Shows [after] in place of [before] at once ([after] `null` removes it)
  /// and stores it in the background, putting [before] back if that fails.
  Future<void> _changeNow(
    Emitter<TasksState> emit, {
    required Task before,
    required Task? after,
    required Future<void> Function() store,
  }) async {
    final id = before.id;
    List<Task> applied(List<Task> tasks) =>
        after == null ? _removed(tasks, id) : _replaced(tasks, after);

    _show(emit, applied(state.tasks), state);
    try {
      await _inOrder(store);
      // A reload queued before this change may have shown the stored task as
      // it was before it.
      _show(emit, applied(state.tasks), state);
      await _publishToWidget(state.tasks);
    } on Object catch (error) {
      final reason = _reasonOf(error);
      final current = state.tasks.where((task) => task.id == id).firstOrNull;
      // A later change to the same task already replaced this one on screen
      // and in the queue, so only an untouched task is put back.
      final tasks = reason == TaskFailureReason.notFound
          ? _removed(state.tasks, id)
          : current == after
          ? _upserted(state.tasks, before)
          : state.tasks;
      _show(emit, tasks, state.copyWith(actionFailure: _nextFailure(reason)));
    }
  }

  /// Hides [tasks] at once and deletes each one in the background, the way
  /// [_changeNow] does for one, but reports a failure only once. Only the
  /// tasks whose deletion failed come back; one the server no longer has is
  /// already gone, which is what was asked.
  Future<void> _deleteAllNow(Emitter<TasksState> emit, List<Task> tasks) async {
    if (tasks.isEmpty) return;
    final ids = {for (final task in tasks) task.id};
    _show(emit, _removedAll(state.tasks, ids), state);

    final reasons = await Future.wait([
      for (final task in tasks)
        _inOrder(() => _deleteTask(task.id)).then<TaskFailureReason?>(
          (_) => null,
          onError: (Object error) => _reasonOf(error),
        ),
    ]);

    final failed = [
      for (final (index, task) in tasks.indexed)
        if (reasons[index] case final reason?
            when reason != TaskFailureReason.notFound)
          (task, reason),
    ];
    final failedIds = {for (final (task, _) in failed) task.id};
    // A reload queued before the deletions may have shown them again.
    var shown = _removedAll(state.tasks, ids.difference(failedIds));
    for (final (task, _) in failed) {
      // A reload may already have brought it back, as the server has it.
      if (!shown.any((current) => current.id == task.id)) {
        shown = [...shown, task];
      }
    }
    _show(
      emit,
      shown,
      failed.isEmpty
          ? state
          : state.copyWith(actionFailure: _nextFailure(failed.first.$2)),
    );
    if (failed.length < tasks.length) await _publishToWidget(state.tasks);
  }

  /// Runs [call] after every server call queued before it.
  Future<T> _inOrder<T>(Future<T> Function() call) {
    final result = _serverQueue.then((_) => call());
    _serverQueue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  void _show(Emitter<TasksState> emit, List<Task> tasks, TasksState base) {
    final today = CalendarDate.fromLocal(_clock.now());
    emit(
      base.copyWith(
        tasks: List.unmodifiable(tasks),
        timeline: _buildTimeline(tasks, today: today),
        today: today,
      ),
    );
  }

  Future<void> _publishToWidget(List<Task> tasks) async {
    try {
      await _publishWidgetTasks(tasks);
    } on Object catch (_) {
      // The widget is secondary: failing to update it must never reach the
      // screen, and the next change tries again.
    }
  }

  TaskActionFailure _nextFailure(TaskFailureReason reason) =>
      TaskActionFailure(reason, ++_failureSequence);

  static TaskFailureReason _reasonOf(Object error) =>
      error is TaskFailure ? error.reason : TaskFailureReason.unknown;

  static List<Task> _removed(List<Task> tasks, String id) => [
    for (final task in tasks)
      if (task.id != id) task,
  ];

  static List<Task> _removedAll(List<Task> tasks, Set<String> ids) => [
    for (final task in tasks)
      if (!ids.contains(task.id)) task,
  ];

  /// Only replaces a task still on screen, so a change confirmed late never
  /// brings back a task deleted meanwhile.
  static List<Task> _replaced(List<Task> tasks, Task changed) => [
    for (final task in tasks) task.id == changed.id ? changed : task,
  ];

  static List<Task> _upserted(List<Task> tasks, Task changed) =>
      tasks.any((task) => task.id == changed.id)
      ? _replaced(tasks, changed)
      : [...tasks, changed];

  /// A task the server no longer has was deleted elsewhere.
  static List<Task> _withoutIfGone(
    List<Task> tasks,
    String? id,
    TaskFailureReason reason,
  ) => id != null && reason == TaskFailureReason.notFound
      ? _removed(tasks, id)
      : tasks;
}
