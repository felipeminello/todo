import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:todo/core/time/calendar_date.dart';
import 'package:todo/core/ui/brand_colors.dart';
import 'package:todo/core/ui/widgets/brand_button.dart';
import 'package:todo/core/ui/widgets/raised_icon_button.dart';
import 'package:todo/features/tasks/domain/entities/task.dart';
import 'package:todo/l10n/app_localizations.dart';

/// What the form returns on save.
final class TaskFormResult extends Equatable {
  const TaskFormResult({
    required this.title,
    required this.description,
    required this.dueDate,
  });

  final String title;
  final String description;
  final CalendarDate? dueDate;

  @override
  List<Object?> get props => [title, description, dueDate];
}

/// Creates a task, or edits [initial] when given. Hosted by a bottom sheet
/// on narrow screens and by a side panel on wide ones.
class TaskForm extends StatefulWidget {
  const TaskForm({
    super.key,
    this.initial,
    required this.onSubmit,
    required this.onCancel,
    this.autofocus = false,
  });

  final Task? initial;
  final ValueChanged<TaskFormResult> onSubmit;
  final VoidCallback onCancel;
  final bool autofocus;

  @override
  State<TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<TaskForm> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.initial?.title);
  late final _description = TextEditingController(
    text: widget.initial?.description,
  );
  late CalendarDate? _dueDate = widget.initial?.dueDate;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate?.toLocalDateTime() ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10, 12, 31),
    );
    if (picked != null) {
      setState(() => _dueDate = CalendarDate.fromLocal(picked));
    }
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    widget.onSubmit(
      TaskFormResult(
        title: _title.text,
        description: _description.text,
        dueDate: _dueDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    widget.initial == null
                        ? l10n.taskFormNewTitle
                        : l10n.taskFormEditTitle,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ),
              RaisedIconButton(
                icon: Icons.close,
                tooltip: l10n.cancelAction,
                onPressed: widget.onCancel,
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextFormField(
            key: const Key('task-form-title'),
            controller: _title,
            autofocus: widget.autofocus,
            decoration: InputDecoration(labelText: l10n.taskFormTitleLabel),
            textInputAction: TextInputAction.next,
            validator: (value) => (value ?? '').trim().isEmpty
                ? l10n.taskFormTitleRequired
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('task-form-description'),
            controller: _description,
            decoration: InputDecoration(
              labelText: l10n.taskFormDescriptionLabel,
              alignLabelWithHint: true,
            ),
            keyboardType: TextInputType.multiline,
            minLines: 3,
            maxLines: 6,
          ),
          const SizedBox(height: 16),
          _DueDateField(
            dueDate: _dueDate,
            onPick: _pickDate,
            onClear: () => setState(() => _dueDate = null),
          ),
          const SizedBox(height: 24),
          BrandButton(
            key: const Key('task-form-save'),
            onPressed: _save,
            child: Text(l10n.taskFormSave),
          ),
        ],
      ),
    );
  }
}

class _DueDateField extends StatelessWidget {
  const _DueDateField({
    required this.dueDate,
    required this.onPick,
    required this.onClear,
  });

  final CalendarDate? dueDate;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brand = BrandColors.of(context);
    final date = dueDate;
    final hasDate = date != null;
    final foreground = hasDate ? brand.onHighlight : scheme.onSurfaceVariant;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: hasDate
              ? [brand.highlightTop, brand.highlightBottom]
              : [brand.raisedTop, brand.raisedBottom],
        ),
        boxShadow: [
          BoxShadow(color: brand.raisedEdge, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        child: Row(
          children: [
            Icon(Icons.event_outlined, size: 20, color: foreground),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                date == null
                    ? l10n.taskFormNoDueDate
                    : DateFormat.yMMMEd(locale).format(date.toLocalDateTime()),
                key: const Key('task-form-due-date'),
                style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
              ),
            ),
            BrandButton(
              onPressed: onPick,
              variant: BrandButtonVariant.secondary,
              foregroundColor: scheme.primary,
              height: 44,
              child: Text(l10n.taskFormPickDate),
            ),
            if (hasDate)
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                tooltip: l10n.taskFormClearDate,
                color: foreground,
                onPressed: onClear,
              ),
          ],
        ),
      ),
    );
  }
}
