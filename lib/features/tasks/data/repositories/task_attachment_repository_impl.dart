import 'dart:typed_data';

import 'package:todo/core/error/exceptions.dart';
import 'package:todo/core/error/failure.dart';
import 'package:todo/features/tasks/data/datasources/task_attachment_remote_data_source.dart';
import 'package:todo/features/tasks/domain/entities/attachment_file.dart';
import 'package:todo/features/tasks/domain/entities/task_attachment.dart';
import 'package:todo/features/tasks/domain/repositories/task_attachment_repository.dart';

final class TaskAttachmentRepositoryImpl implements TaskAttachmentRepository {
  const TaskAttachmentRepositoryImpl(this._dataSource);

  final TaskAttachmentRemoteDataSource _dataSource;

  @override
  Future<List<TaskAttachment>> getAll(String taskId) => _guard(() async {
    final models = await _dataSource.getAll(taskId);
    return [for (final model in models) model.toEntity()];
  });

  @override
  Future<TaskAttachment> add(String taskId, AttachmentFile file) =>
      _guard(() async {
        final stored = await _dataSource.upload(
          taskId,
          name: file.name,
          size: file.size,
          openRead: file.openRead,
        );
        return stored.toEntity();
      });

  @override
  Future<Uint8List> download(String taskId, String attachmentId) =>
      _guard(() => _dataSource.download(taskId, attachmentId));

  @override
  Future<void> delete(String taskId, String attachmentId) =>
      _guard(() => _dataSource.delete(taskId, attachmentId));

  @override
  Future<void> deleteAll(String taskId) =>
      _guard(() => _dataSource.deleteAll(taskId));

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AttachmentRemoteException catch (e) {
      throw AttachmentFailure(switch (e.kind) {
        AttachmentErrorKind.network => AttachmentFailureReason.network,
        AttachmentErrorKind.unauthenticated ||
        AttachmentErrorKind.permissionDenied =>
          AttachmentFailureReason.permissionDenied,
        AttachmentErrorKind.notFound => AttachmentFailureReason.notFound,
        AttachmentErrorKind.tooLarge => AttachmentFailureReason.tooLarge,
        AttachmentErrorKind.limitReached =>
          AttachmentFailureReason.limitReached,
        AttachmentErrorKind.unknown => AttachmentFailureReason.unknown,
      });
    } on FormatException {
      throw const AttachmentFailure(AttachmentFailureReason.unknown);
    }
  }
}
