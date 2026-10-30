import 'package:todo/core/time/clock.dart';
import 'package:todo/core/usecase/usecase.dart';
import 'package:todo/features/tasks/domain/entities/task.dart';
import 'package:todo/features/tasks/domain/repositories/task_repository.dart';

/// Completes a pending task or reopens a completed one, in two steps so the
/// screen can show the result before the server confirms it, with the same
/// completion instant that gets stored.
final class ToggleTask implements UseCase<void, Task> {
  const ToggleTask(this._repository, this._clock);

  final TaskRepository _repository;
  final Clock _clock;

  /// [task] with its completion switched; stores nothing.
  Task toggled(Task task) => task.copyWith(
    completedAt: () => task.isCompleted ? null : _clock.now().toUtc(),
  );

  /// Stores a task returned by [toggled].
  @override
  Future<void> call(Task toggled) async {
    await _repository.update(toggled);
  }
}
