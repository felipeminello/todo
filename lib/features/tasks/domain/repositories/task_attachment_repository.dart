import 'dart:typed_data';

import 'package:todo/features/tasks/domain/entities/attachment_file.dart';
import 'package:todo/features/tasks/domain/entities/task_attachment.dart';

/// Files attached to the signed-in user's tasks. Every method throws only
/// `AttachmentFailure`.
abstract interface class TaskAttachmentRepository {
  /// The attachments of a task, oldest first.
  Future<List<TaskAttachment>> getAll(String taskId);

  /// Stores [file] and returns it as an attachment, with the id assigned by
  /// the backend.
  Future<TaskAttachment> add(String taskId, AttachmentFile file);

  /// The content of an attachment.
  Future<Uint8List> download(String taskId, String attachmentId);

  Future<void> delete(String taskId, String attachmentId);

  /// Deletes every attachment of a task; succeeds when it has none.
  Future<void> deleteAll(String taskId);
}
