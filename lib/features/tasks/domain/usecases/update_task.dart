import 'package:equatable/equatable.dart';
import 'package:todo/core/time/calendar_date.dart';
import 'package:todo/core/usecase/usecase.dart';
import 'package:todo/features/tasks/domain/entities/task.dart';
import 'package:todo/features/tasks/domain/repositories/task_repository.dart';
import 'package:todo/features/tasks/domain/usecases/task_title.dart';

/// The editable fields of [original]. Anything not listed here (creation and
/// completion instants) is kept from [original].
final class UpdateTaskParams extends Equatable {
  const UpdateTaskParams({
    required this.original,
    required this.title,
    required this.description,
    required this.dueDate,
  });

  final Task original;
  final String title;
  final String description;
  final CalendarDate? dueDate;

  @override
  List<Object?> get props => [original, title, description, dueDate];
}

final class UpdateTask implements UseCase<Task, UpdateTaskParams> {
  const UpdateTask(this._repository);

  final TaskRepository _repository;

  @override
  Future<Task> call(UpdateTaskParams params) async {
    final updated = params.original.copyWith(
      title: normalizeTaskTitle(params.title),
      description: params.description,
      dueDate: () => params.dueDate,
    );
    await _repository.update(updated);
    return updated;
  }
}
