import 'dart:typed_data';

import 'package:todo/core/error/failure.dart';
import 'package:todo/features/tasks/domain/entities/attachment_file.dart';
import 'package:todo/features/tasks/domain/repositories/attachment_file_picker.dart';
import 'package:todo/features/tasks/domain/repositories/attachment_file_saver.dart';

/// Stands in for the system dialogs that open and save a file.
final class FakeAttachmentFiles
    implements AttachmentFilePicker, AttachmentFileSaver {
  /// What the user chooses next; `null` is giving up.
  AttachmentFile? nextPick;

  /// Whether the user confirms the next save dialog.
  bool acceptSave = true;

  /// When set, the next dialog throws it and clears it.
  AttachmentFailure? failNext;

  int picks = 0;
  final saved = <({String name, String contentType, Uint8List bytes})>[];

  @override
  Future<AttachmentFile?> pick() async {
    picks++;
    _maybeFail();
    return nextPick;
  }

  @override
  Future<bool> save({
    required String name,
    required String contentType,
    required Uint8List bytes,
  }) async {
    _maybeFail();
    if (!acceptSave) return false;
    saved.add((name: name, contentType: contentType, bytes: bytes));
    return true;
  }

  void _maybeFail() {
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
  }
}

/// A file on the device named [name] holding [bytes].
AttachmentFile attachmentFile(String name, List<int> bytes) => AttachmentFile(
  name: name,
  size: bytes.length,
  openRead: () => Stream.value(bytes),
);
