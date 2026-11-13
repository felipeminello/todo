import 'dart:async';
import 'dart:typed_data';

import 'package:todo/core/error/exceptions.dart';
import 'package:todo/features/tasks/data/datasources/task_attachment_remote_data_source.dart';
import 'package:todo/features/tasks/data/models/task_attachment_model.dart';

/// In-memory stand-in for the attachments API and its bucket: one folder per
/// task, each file stored under a name of its own.
class FakeTaskAttachmentRemoteDataSource
    implements TaskAttachmentRemoteDataSource {
  final Map<String, Map<String, (TaskAttachmentModel, Uint8List)>> _folders =
      {};
  int _nextId = 1;

  /// When set, the next call throws it and clears it.
  AttachmentRemoteException? failNext;

  /// When set, every call waits for it to complete.
  Completer<void>? gate;

  /// The task ids whose folder was asked to be emptied, in order.
  final List<String> clearedFolders = [];

  /// The stored file names (not the shown ones) in the folder of a task.
  List<String> storedNames(String taskId) => [...?_folders[taskId]?.keys];

  Uint8List? content(String taskId, String attachmentId) =>
      _folders[taskId]?[attachmentId]?.$2;

  @override
  Future<List<TaskAttachmentModel>> getAll(String taskId) async {
    await _enter();
    return [for (final (model, _) in _folder(taskId).values) model];
  }

  @override
  Future<TaskAttachmentModel> upload(
    String taskId, {
    required String name,
    required int size,
    required Stream<List<int>> Function() openRead,
  }) async {
    await _enter();
    final bytes = Uint8List.fromList([
      await for (final chunk in openRead()) ...chunk,
    ]);
    if (bytes.length != size) {
      throw const AttachmentRemoteException(AttachmentErrorKind.unknown);
    }
    final dot = name.lastIndexOf('.');
    final extension = dot > 0 ? name.substring(dot).toLowerCase() : '';
    final model = TaskAttachmentModel(
      id: 'file-${_nextId++}$extension',
      name: name,
      size: size,
      contentType: 'application/octet-stream',
      createdAt: DateTime.utc(2026, 11, 12, 12, _nextId),
    );
    _folder(taskId)[model.id] = (model, bytes);
    return model;
  }

  @override
  Future<Uint8List> download(String taskId, String attachmentId) async {
    await _enter();
    final stored = _folder(taskId)[attachmentId];
    if (stored == null) {
      throw const AttachmentRemoteException(AttachmentErrorKind.notFound);
    }
    return stored.$2;
  }

  @override
  Future<void> delete(String taskId, String attachmentId) async {
    await _enter();
    if (_folder(taskId).remove(attachmentId) == null) {
      throw const AttachmentRemoteException(AttachmentErrorKind.notFound);
    }
  }

  @override
  Future<void> deleteAll(String taskId) async {
    await _enter();
    clearedFolders.add(taskId);
    _folders.remove(taskId);
  }

  Map<String, (TaskAttachmentModel, Uint8List)> _folder(String taskId) =>
      _folders.putIfAbsent(taskId, () => {});

  Future<void> _enter() async {
    await gate?.future;
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
  }
}
