import 'package:todo/core/error/failure.dart';
import 'package:todo/core/usecase/usecase.dart';
import 'package:todo/features/tasks/domain/entities/attachment_file.dart';
import 'package:todo/features/tasks/domain/entities/task_attachment.dart';
import 'package:todo/features/tasks/domain/repositories/task_attachment_repository.dart';

final class AddTaskAttachmentParams {
  const AddTaskAttachmentParams({required this.taskId, required this.file});

  final String taskId;
  final AttachmentFile file;
}

/// Attaches a file to a task, refusing empty files and files over
/// [maxBytes] before anything is sent.
final class AddTaskAttachment
    implements UseCase<TaskAttachment, AddTaskAttachmentParams> {
  const AddTaskAttachment(this._repository);

  /// The backend enforces the same limit.
  static const maxBytes = 25 * 1024 * 1024;

  final TaskAttachmentRepository _repository;

  @override
  Future<TaskAttachment> call(AddTaskAttachmentParams params) {
    final size = params.file.size;
    if (size <= 0) {
      throw const AttachmentFailure(AttachmentFailureReason.emptyFile);
    }
    if (size > maxBytes) {
      throw const AttachmentFailure(AttachmentFailureReason.tooLarge);
    }
    return _repository.add(params.taskId, params.file);
  }
}
