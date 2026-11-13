import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:todo/core/error/failure.dart';
import 'package:todo/core/ui/widgets/brand_button.dart';
import 'package:todo/features/tasks/domain/entities/task_attachment.dart';
import 'package:todo/features/tasks/presentation/bloc/task_attachments_bloc.dart';
import 'package:todo/features/tasks/presentation/widgets/attachment_failure_message.dart';
import 'package:todo/features/tasks/presentation/widgets/delete_task_sheet.dart';
import 'package:todo/features/tasks/presentation/widgets/task_attachment_tile.dart';
import 'package:todo/l10n/app_localizations.dart';

/// The files attached to the task [taskId], with a button to attach another
/// and, on each one, buttons to download and to delete it.
///
/// It loads the attachments itself, with a bloc built by [createBloc] that
/// lives as long as the details of that task stay open.
class TaskAttachmentsSection extends StatelessWidget {
  const TaskAttachmentsSection({
    super.key,
    required this.taskId,
    required this.createBloc,
  });

  final String taskId;
  final TaskAttachmentsBlocFactory createBloc;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // Another task gets another bloc.
      key: ValueKey(taskId),
      create: (_) => createBloc(taskId)..add(const TaskAttachmentsRequested()),
      child: const _AttachmentsView(),
    );
  }
}

class _AttachmentsView extends StatelessWidget {
  const _AttachmentsView();

  Future<void> _delete(BuildContext context, TaskAttachment attachment) async {
    final bloc = context.read<TaskAttachmentsBloc>();
    final confirmed = await DeleteTaskSheet.confirmAttachment(
      context,
      name: attachment.name,
    );
    // The details may have been closed while the question was open.
    if (confirmed && !bloc.isClosed) {
      bloc.add(TaskAttachmentDeleted(attachment));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodyLarge?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return BlocBuilder<TaskAttachmentsBloc, TaskAttachmentsState>(
      builder: (context, state) {
        final bloc = context.read<TaskAttachmentsBloc>();
        final loaded = state.status == TaskAttachmentsStatus.loaded;
        final actionFailure = state.actionFailure;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.taskAttachmentsTitle,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                BrandButton(
                  key: const Key('task-attachments-add'),
                  onPressed: loaded && !state.isUploading
                      ? () => bloc.add(const TaskAttachmentAddRequested())
                      : null,
                  variant: BrandButtonVariant.secondary,
                  height: 48,
                  icon: const Icon(Icons.attach_file, size: 20),
                  child: Text(l10n.taskAttachmentsAdd),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _UploadIndicator(isUploading: state.isUploading),
            const SizedBox(height: 10),
            if (actionFailure != null) ...[
              _FailureBanner(
                message: attachmentFailureMessage(l10n, actionFailure),
              ),
              const SizedBox(height: 12),
            ],
            switch (state.status) {
              TaskAttachmentsStatus.loading => Align(
                alignment: Alignment.centerLeft,
                child: SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    semanticsLabel: l10n.loadingLabel,
                  ),
                ),
              ),
              TaskAttachmentsStatus.failure => _LoadFailure(
                reason: state.loadFailure ?? AttachmentFailureReason.unknown,
                onRetry: () => bloc.add(const TaskAttachmentsRequested()),
              ),
              TaskAttachmentsStatus.loaded when state.attachments.isEmpty =>
                Text(l10n.taskAttachmentsEmpty, style: muted),
              TaskAttachmentsStatus.loaded => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final attachment in state.attachments)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: TaskAttachmentTile(
                        key: ValueKey(attachment.id),
                        attachment: attachment,
                        isBusy: state.busyIds.contains(attachment.id),
                        onDownload: () => bloc.add(
                          TaskAttachmentDownloadRequested(attachment),
                        ),
                        onDelete: () => _delete(context, attachment),
                      ),
                    ),
                ],
              ),
            },
          ],
        );
      },
    );
  }
}

/// A thin bar while a file is sent. Its space is always reserved, so the
/// list below does not jump when it shows.
class _UploadIndicator extends StatelessWidget {
  const _UploadIndicator({required this.isUploading});

  static const _height = 3.0;

  final bool isUploading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      child: isUploading
          ? ClipRRect(
              borderRadius: BorderRadius.circular(_height),
              child: LinearProgressIndicator(
                semanticsLabel: AppLocalizations.of(context)
                    .taskAttachmentsUploading,
              ),
            )
          : null,
    );
  }
}

/// Why the last attach, download or delete failed. It stays in the section,
/// since a snack bar would show behind the sheet the details open in.
class _FailureBanner extends StatelessWidget {
  const _FailureBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                Icons.error_outline,
                size: 20,
                color: scheme.onErrorContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  key: const Key('task-attachments-failure'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.reason, required this.onRetry});

  final AttachmentFailureReason reason;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.taskAttachmentsLoadError, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 4),
        Text(
          attachmentFailureMessage(l10n, reason),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        BrandButton(
          key: const Key('task-attachments-retry'),
          onPressed: onRetry,
          variant: BrandButtonVariant.secondary,
          foregroundColor: scheme.primary,
          height: 48,
          icon: const Icon(Icons.refresh, size: 20),
          child: Text(l10n.retryAction),
        ),
      ],
    );
  }
}
