import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:todo/core/time/calendar_date.dart';
import 'package:todo/features/tasks/domain/entities/task.dart';
import 'package:todo/l10n/app_localizations.dart';

/// What the form returns on save. Cancelling returns nothing.
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

/// Creates a task, or edits [initial] when given.
class TaskFormPage extends StatefulWidget {
  const TaskFormPage({super.key, this.initial});

  final Task? initial;

  static Future<TaskFormResult?> open(BuildContext context, {Task? initial}) {
    return Navigator.of(context).push<TaskFormResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => TaskFormPage(initial: initial),
      ),
    );
  }

  @override
  State<TaskFormPage> createState() => _TaskFormPageState();
}

class _TaskFormPageState extends State<TaskFormPage> {
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
    Navigator.of(context).pop(
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initial == null
              ? l10n.taskFormNewTitle
              : l10n.taskFormEditTitle,
        ),
        actions: [
          TextButton(
            key: const Key('task-form-save'),
            onPressed: _save,
            child: Text(l10n.taskFormSave),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    key: const Key('task-form-title'),
                    controller: _title,
                    autofocus: widget.initial == null,
                    decoration: InputDecoration(
                      labelText: l10n.taskFormTitleLabel,
                    ),
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
                ],
              ),
            ),
          ),
        ),
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
    final date = dueDate;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Icon(Icons.event_outlined),
        Text(
          date == null
              ? l10n.taskFormNoDueDate
              : DateFormat.yMMMMEEEEd(locale).format(date.toLocalDateTime()),
          key: const Key('task-form-due-date'),
        ),
        OutlinedButton(onPressed: onPick, child: Text(l10n.taskFormPickDate)),
        if (date != null)
          IconButton(
            icon: const Icon(Icons.clear),
            tooltip: l10n.taskFormClearDate,
            onPressed: onClear,
          ),
      ],
    );
  }
}
