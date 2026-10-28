import 'package:equatable/equatable.dart';
import 'package:todo/core/time/calendar_date.dart';
import 'package:todo/core/time/clock.dart';
import 'package:todo/core/usecase/usecase.dart';
import 'package:todo/features/tasks/domain/entities/new_task.dart';
import 'package:todo/features/tasks/domain/entities/task.dart';
import 'package:todo/features/tasks/domain/repositories/task_repository.dart';
import 'package:todo/features/tasks/domain/usecases/task_title.dart';

final class AddTaskParams extends Equatable {
  const AddTaskParams({
    required this.title,
    this.description = '',
    this.dueDate,
  });

  final String title;
  final String description;
  final CalendarDate? dueDate;

  @override
  List<Object?> get props => [title, description, dueDate];
}

final class AddTask implements UseCase<Task, AddTaskParams> {
  const AddTask(this._repository, this._clock);

  final TaskRepository _repository;
  final Clock _clock;

  @override
  Future<Task> call(AddTaskParams params) {
    final title = normalizeTaskTitle(params.title);
    return _repository.add(
      NewTask(
        title: title,
        description: params.description,
        dueDate: params.dueDate,
        createdAt: _clock.now().toUtc(),
      ),
    );
  }
}
