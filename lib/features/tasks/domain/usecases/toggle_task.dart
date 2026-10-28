import 'package:todo/core/time/clock.dart';
import 'package:todo/core/usecase/usecase.dart';
import 'package:todo/features/tasks/domain/entities/task.dart';
import 'package:todo/features/tasks/domain/repositories/task_repository.dart';

/// Completes a pending task or reopens a completed one.
final class ToggleTask implements UseCase<Task, Task> {
  const ToggleTask(this._repository, this._clock);

  final TaskRepository _repository;
  final Clock _clock;

  @override
  Future<Task> call(Task task) async {
    final toggled = task.copyWith(
      completedAt: () => task.isCompleted ? null : _clock.now().toUtc(),
    );
    await _repository.update(toggled);
    return toggled;
  }
}
