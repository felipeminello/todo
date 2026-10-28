import 'package:todo/core/error/exceptions.dart';
import 'package:todo/features/tasks/data/datasources/task_remote_data_source.dart';
import 'package:todo/features/tasks/data/models/task_model.dart';

/// In-memory stand-in for the remote task store, with Firestore semantics.
class FakeTaskRemoteDataSource implements TaskRemoteDataSource {
  final Map<String, TaskModel> _tasks = {};
  int _nextId = 1;

  /// When set, the next call throws it and clears it.
  RemoteException? failNext;

  @override
  Future<List<TaskModel>> getAll() async {
    _maybeFail();
    return _tasks.values.toList();
  }

  @override
  Future<TaskModel> create(TaskModel draft) async {
    _maybeFail();
    final created = draft.withId('task-${_nextId++}');
    _tasks[created.id] = created;
    return created;
  }

  @override
  Future<void> update(TaskModel task) async {
    _maybeFail();
    if (!_tasks.containsKey(task.id)) {
      throw const RemoteException(RemoteErrorKind.notFound);
    }
    _tasks[task.id] = task;
  }

  @override
  Future<void> delete(String id) async {
    _maybeFail();
    _tasks.remove(id);
  }

  void _maybeFail() {
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
  }
}
