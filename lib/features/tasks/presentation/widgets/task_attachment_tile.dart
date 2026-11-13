import 'package:flutter/material.dart';
import 'package:todo/core/utils/file_size_format.dart';
import 'package:todo/features/tasks/domain/entities/task_attachment.dart';
import 'package:todo/l10n/app_localizations.dart';

/// One attachment: the name of the uploaded file, its size, and buttons to
/// download and to delete it. While [isBusy], a spinner replaces the buttons.
class TaskAttachmentTile extends StatelessWidget {
  const TaskAttachmentTile({
    super.key,
    required this.attachment,
    required this.isBusy,
    required this.onDownload,
    required this.onDelete,
  });

  // Desktop themes shrink icon buttons below the 48 px touch target.
  static const _touchTarget = BoxConstraints(minWidth: 48, minHeight: 48);

  final TaskAttachment attachment;
  final bool isBusy;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = attachment.name;

    return Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              Icons.insert_drive_file_outlined,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge,
              ),
              Text(
                formatFileSize(attachment.size, locale: l10n.localeName),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        if (isBusy)
          SizedBox(
            width: 96,
            height: 48,
            child: Center(
              child: SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  semanticsLabel: l10n.taskAttachmentBusySemantics(name),
                ),
              ),
            ),
          )
        else ...[
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: l10n.taskAttachmentDownloadTooltip(name),
            constraints: _touchTarget,
            onPressed: onDownload,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.taskAttachmentDeleteTooltip(name),
            constraints: _touchTarget,
            color: scheme.error,
            onPressed: onDelete,
          ),
        ],
      ],
    );
  }
}
