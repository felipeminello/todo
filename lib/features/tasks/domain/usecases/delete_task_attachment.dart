import 'package:todo/core/usecase/usecase.dart';
import 'package:todo/features/tasks/domain/repositories/task_attachment_repository.dart';

final class DeleteTaskAttachmentParams {
  const DeleteTaskAttachmentParams({
    required this.taskId,
    required this.attachmentId,
  });

  final String taskId;
  final String attachmentId;
}

final class DeleteTaskAttachment
    implements UseCase<void, DeleteTaskAttachmentParams> {
  const DeleteTaskAttachment(this._repository);

  final TaskAttachmentRepository _repository;

  @override
  Future<void> call(DeleteTaskAttachmentParams params) =>
      _repository.delete(params.taskId, params.attachmentId);
}
