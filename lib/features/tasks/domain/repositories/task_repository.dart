import 'package:todo/features/tasks/domain/entities/new_task.dart';
import 'package:todo/features/tasks/domain/entities/task.dart';

/// Tasks of the signed-in user. Every method throws only `TaskFailure`.
abstract interface class TaskRepository {
  Future<List<Task>> getAll();

  /// Persists [task] and returns it with the id assigned by the backend.
  Future<Task> add(NewTask task);

  /// Replaces the stored task that has the same id as [task].
  Future<void> update(Task task);

  Future<void> delete(String id);
}
