import 'package:todo/core/usecase/usecase.dart';
import 'package:todo/features/tasks/domain/repositories/task_repository.dart';

final class DeleteTask implements UseCase<void, String> {
  const DeleteTask(this._repository);

  final TaskRepository _repository;

  @override
  Future<void> call(String taskId) => _repository.delete(taskId);
}
