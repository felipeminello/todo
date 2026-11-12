import 'package:flutter/material.dart';
import 'package:todo/core/ui/widgets/brand_button.dart';
import 'package:todo/l10n/app_localizations.dart';

/// Completes a pending task or, for a completed one, reopens it.
class TaskCompletionButton extends StatelessWidget {
  const TaskCompletionButton({
    super.key,
    required this.isCompleted,
    required this.onPressed,
    this.height = 54,
  });

  final bool isCompleted;
  final VoidCallback onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BrandButton(
      key: const Key('task-details-toggle'),
      onPressed: onPressed,
      height: height,
      variant: isCompleted
          ? BrandButtonVariant.secondary
          : BrandButtonVariant.primary,
      icon: Icon(isCompleted ? Icons.undo : Icons.check),
      child: Text(
        isCompleted ? l10n.taskDetailsReopen : l10n.taskDetailsComplete,
      ),
    );
  }
}
