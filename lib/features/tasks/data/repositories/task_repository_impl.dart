import 'package:todo/core/error/exceptions.dart';
import 'package:todo/core/error/failure.dart';
import 'package:todo/features/tasks/data/datasources/task_remote_data_source.dart';
import 'package:todo/features/tasks/data/models/task_model.dart';
import 'package:todo/features/tasks/domain/entities/new_task.dart';
import 'package:todo/features/tasks/domain/entities/task.dart';
import 'package:todo/features/tasks/domain/repositories/task_repository.dart';

final class TaskRepositoryImpl implements TaskRepository {
  const TaskRepositoryImpl(this._dataSource);

  final TaskRemoteDataSource _dataSource;

  @override
  Future<List<Task>> getAll() => _guard(() async {
    final models = await _dataSource.getAll();
    return [for (final model in models) model.toEntity()];
  });

  @override
  Future<Task> add(NewTask task) => _guard(() async {
    final created = await _dataSource.create(TaskModel.draft(task));
    return created.toEntity();
  });

  @override
  Future<void> update(Task task) =>
      _guard(() => _dataSource.update(TaskModel.fromEntity(task)));

  @override
  Future<void> delete(String id) => _guard(() => _dataSource.delete(id));

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on RemoteException catch (e) {
      throw TaskFailure(switch (e.kind) {
        RemoteErrorKind.network => TaskFailureReason.network,
        RemoteErrorKind.unauthenticated ||
        RemoteErrorKind.permissionDenied => TaskFailureReason.permissionDenied,
        RemoteErrorKind.notFound => TaskFailureReason.notFound,
        RemoteErrorKind.unknown => TaskFailureReason.unknown,
      });
    } on FormatException {
      throw const TaskFailure(TaskFailureReason.unknown);
    }
  }
}
