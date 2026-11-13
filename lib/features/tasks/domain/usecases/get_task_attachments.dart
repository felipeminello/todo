import 'package:todo/core/usecase/usecase.dart';
import 'package:todo/features/tasks/domain/entities/task_attachment.dart';
import 'package:todo/features/tasks/domain/repositories/task_attachment_repository.dart';

final class GetTaskAttachments
    implements UseCase<List<TaskAttachment>, String> {
  const GetTaskAttachments(this._repository);

  final TaskAttachmentRepository _repository;

  @override
  Future<List<TaskAttachment>> call(String taskId) =>
      _repository.getAll(taskId);
}
