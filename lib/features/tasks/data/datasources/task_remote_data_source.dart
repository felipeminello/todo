import 'package:todo/features/tasks/data/models/task_model.dart';

/// Remote storage of the signed-in user's tasks. Throws only
/// `RemoteException`, plus `FormatException` for malformed stored data.
abstract interface class TaskRemoteDataSource {
  Future<List<TaskModel>> getAll();

  /// Stores [draft] under a new backend-assigned id and returns it with
  /// that id; the draft's own id is ignored.
  Future<TaskModel> create(TaskModel draft);

  /// Overwrites an existing task. Throws `RemoteErrorKind.notFound` when no
  /// task has that id.
  Future<void> update(TaskModel task);

  /// Deleting a task that does not exist succeeds, as in Firestore.
  Future<void> delete(String id);
}
