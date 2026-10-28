import 'package:todo/core/usecase/usecase.dart';
import 'package:todo/features/tasks/domain/entities/task.dart';
import 'package:todo/features/tasks/domain/repositories/task_repository.dart';

final class GetTasks implements UseCase<List<Task>, NoParams> {
  const GetTasks(this._repository);

  final TaskRepository _repository;

  @override
  Future<List<Task>> call([NoParams params = const NoParams()]) =>
      _repository.getAll();
}
