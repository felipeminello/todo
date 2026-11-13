import 'package:todo/core/usecase/usecase.dart';
import 'package:todo/features/tasks/domain/entities/attachment_file.dart';
import 'package:todo/features/tasks/domain/repositories/attachment_file_picker.dart';

/// Asks the user for the file to attach; `null` when they give up.
final class PickAttachmentFile implements UseCase<AttachmentFile?, NoParams> {
  const PickAttachmentFile(this._picker);

  final AttachmentFilePicker _picker;

  @override
  Future<AttachmentFile?> call([NoParams params = const NoParams()]) =>
      _picker.pick();
}
