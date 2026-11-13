import 'package:todo/features/tasks/domain/entities/attachment_file.dart';

/// Lets the user choose a file on the device. Throws only
/// `AttachmentFailure`.
abstract interface class AttachmentFilePicker {
  /// Completes with `null` when the user gives up choosing.
  Future<AttachmentFile?> pick();
}
