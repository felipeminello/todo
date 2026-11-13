import 'dart:typed_data';

import 'package:todo/features/tasks/data/models/task_attachment_model.dart';

/// Remote storage of the files attached to the signed-in user's tasks.
/// Throws only `AttachmentRemoteException`, plus `FormatException` for a
/// malformed answer.
abstract interface class TaskAttachmentRemoteDataSource {
  /// The attachments of a task, oldest first.
  Future<List<TaskAttachmentModel>> getAll(String taskId);

  /// Stores [size] bytes read from [openRead] in the folder of the task,
  /// under a backend-assigned name, keeping [name] as the name to show.
  Future<TaskAttachmentModel> upload(
    String taskId, {
    required String name,
    required int size,
    required Stream<List<int>> Function() openRead,
  });

  Future<Uint8List> download(String taskId, String attachmentId);

  /// Throws `AttachmentErrorKind.notFound` when there is no such attachment.
  Future<void> delete(String taskId, String attachmentId);

  /// Succeeds when the task has no attachment.
  Future<void> deleteAll(String taskId);
}
