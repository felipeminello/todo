import 'package:todo/core/error/failure.dart';
import 'package:todo/core/utils/file_size_format.dart';
import 'package:todo/features/tasks/domain/usecases/add_task_attachment.dart';
import 'package:todo/l10n/app_localizations.dart';

String attachmentFailureMessage(
  AppLocalizations l10n,
  AttachmentFailureReason reason,
) {
  return switch (reason) {
    AttachmentFailureReason.network => l10n.attachmentErrorNetwork,
    AttachmentFailureReason.permissionDenied => l10n.attachmentErrorPermission,
    AttachmentFailureReason.notFound => l10n.attachmentErrorNotFound,
    AttachmentFailureReason.emptyFile => l10n.attachmentErrorEmptyFile,
    AttachmentFailureReason.tooLarge => l10n.attachmentErrorTooLarge(
      formatFileSize(AddTaskAttachment.maxBytes, locale: l10n.localeName),
    ),
    AttachmentFailureReason.limitReached => l10n.attachmentErrorLimitReached,
    AttachmentFailureReason.unknown => l10n.attachmentErrorUnknown,
  };
}
