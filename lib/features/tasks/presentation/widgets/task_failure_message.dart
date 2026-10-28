import 'package:todo/core/error/failure.dart';
import 'package:todo/l10n/app_localizations.dart';

String taskFailureMessage(AppLocalizations l10n, TaskFailureReason reason) {
  return switch (reason) {
    TaskFailureReason.emptyTitle => l10n.taskFormTitleRequired,
    TaskFailureReason.network => l10n.taskErrorNetwork,
    TaskFailureReason.permissionDenied => l10n.taskErrorPermission,
    TaskFailureReason.notFound => l10n.taskErrorNotFound,
    TaskFailureReason.unknown => l10n.taskErrorUnknown,
  };
}
