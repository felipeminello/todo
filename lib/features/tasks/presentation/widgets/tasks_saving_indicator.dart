import 'package:flutter/material.dart';
import 'package:todo/l10n/app_localizations.dart';

/// A thin bar under the header while a created or edited task is stored. Its
/// space is always reserved, so the list does not jump when it shows.
class TasksSavingIndicator extends StatelessWidget {
  const TasksSavingIndicator({
    super.key,
    required this.isSaving,
    this.horizontalPadding = 20,
  });

  static const height = 3.0;

  final bool isSaving;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: SizedBox(
        height: height,
        child: isSaving
            ? ClipRRect(
                borderRadius: BorderRadius.circular(height),
                child: LinearProgressIndicator(
                  semanticsLabel: AppLocalizations.of(context).savingLabel,
                ),
              )
            : null,
      ),
    );
  }
}
