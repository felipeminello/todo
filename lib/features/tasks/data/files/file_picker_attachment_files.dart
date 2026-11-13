import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:todo/core/error/failure.dart';
import 'package:todo/features/tasks/domain/entities/attachment_file.dart';
import 'package:todo/features/tasks/domain/repositories/attachment_file_picker.dart';
import 'package:todo/features/tasks/domain/repositories/attachment_file_saver.dart';

/// The system's own dialogs to open and to save a file, on every platform.
final class FilePickerAttachmentFiles
    implements AttachmentFilePicker, AttachmentFileSaver {
  const FilePickerAttachmentFiles();

  // Characters Windows refuses in a file name; a file attached on another
  // system may have them.
  static final _unsafeInName = RegExp(r'[<>:"/\\|?*\x00-\x1f]');

  @override
  Future<AttachmentFile?> pick() => _guard(() async {
    final file = await FilePicker.pickFile();
    if (file == null) return null;
    final size = await file.length();
    if (size == null) {
      throw const AttachmentFailure(AttachmentFailureReason.unknown);
    }
    return AttachmentFile(
      name: file.name,
      size: size,
      openRead: file.readAsByteStream,
    );
  });

  @override
  Future<bool> save({
    required String name,
    required String contentType,
    required Uint8List bytes,
  }) => _guard(() async {
    final saved = await FilePicker.saveFile(
      fileName: name.replaceAll(_unsafeInName, '_'),
      bytes: bytes,
      mimeType: contentType,
    );
    return saved != null;
  });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AttachmentFailure {
      rethrow;
    } on Exception {
      throw const AttachmentFailure(AttachmentFailureReason.unknown);
    }
  }
}
