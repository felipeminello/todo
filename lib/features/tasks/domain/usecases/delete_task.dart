import 'package:todo/core/error/failure.dart';
import 'package:todo/core/usecase/usecase.dart';
import 'package:todo/features/tasks/domain/repositories/task_attachment_repository.dart';
import 'package:todo/features/tasks/domain/repositories/task_repository.dart';

/// Deletes a task together with its attachments.
final class DeleteTask implements UseCase<void, String> {
  const DeleteTask(this._repository, this._attachments);

  final TaskRepository _repository;
  final TaskAttachmentRepository _attachments;

  @override
  Future<void> call(String taskId) async {
    // Files first: once the task is gone nothing in the app leads to them,
    // so a task whose files could not be deleted stays.
    try {
      await _attachments.deleteAll(taskId);
    } on AttachmentFailure catch (failure) {
      throw TaskFailure(switch (failure.reason) {
        AttachmentFailureReason.network => TaskFailureReason.network,
        AttachmentFailureReason.permissionDenied =>
          TaskFailureReason.permissionDenied,
        _ => TaskFailureReason.unknown,
      });
    }
    await _repository.delete(taskId);
  }
}
