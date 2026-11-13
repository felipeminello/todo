import 'package:todo/core/usecase/usecase.dart';
import 'package:todo/features/tasks/domain/entities/task_attachment.dart';
import 'package:todo/features/tasks/domain/repositories/attachment_file_saver.dart';
import 'package:todo/features/tasks/domain/repositories/task_attachment_repository.dart';

final class DownloadTaskAttachmentParams {
  const DownloadTaskAttachmentParams({
    required this.taskId,
    required this.attachment,
  });

  final String taskId;
  final TaskAttachment attachment;
}

/// Downloads an attachment and saves it where the user chooses, under the
/// name it was uploaded with. Completes with `false` when the user gives up
/// saving.
final class DownloadTaskAttachment
    implements UseCase<bool, DownloadTaskAttachmentParams> {
  const DownloadTaskAttachment(this._repository, this._saver);

  final TaskAttachmentRepository _repository;
  final AttachmentFileSaver _saver;

  @override
  Future<bool> call(DownloadTaskAttachmentParams params) async {
    final attachment = params.attachment;
    final bytes = await _repository.download(params.taskId, attachment.id);
    return _saver.save(
      name: attachment.name,
      contentType: attachment.contentType,
      bytes: bytes,
    );
  }
}
