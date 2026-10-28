import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:todo/core/error/failure.dart';
import 'package:todo/features/tasks/domain/entities/task.dart';
import 'package:todo/features/tasks/domain/usecases/add_task.dart';
import 'package:todo/features/tasks/domain/usecases/update_task.dart';
import 'package:todo/features/tasks/presentation/bloc/tasks_bloc.dart';
import 'package:todo/features/tasks/presentation/pages/task_form_page.dart';
import 'package:todo/features/tasks/presentation/widgets/task_failure_message.dart';
import 'package:todo/features/tasks/presentation/widgets/task_timeline_view.dart';
import 'package:todo/l10n/app_localizations.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key, this.onSignOut});

  final VoidCallback? onSignOut;

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Without real-time updates, coming back to the app is when changes made
    // on other devices are most likely to be missing.
    _lifecycle = AppLifecycleListener(onResume: _refresh);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  TasksBloc get _bloc => context.read<TasksBloc>();

  void _refresh() => _bloc.add(const TasksRequested());

  Future<void> _pullToRefresh() async {
    _bloc.add(const TasksRequested());
    await _bloc.stream.firstWhere(
      (state) => !state.isRefreshing && state.status != TasksStatus.loading,
    );
  }

  Future<void> _add() async {
    final result = await TaskFormPage.open(context);
    if (result == null || !mounted) return;
    _bloc.add(
      TaskAdded(
        AddTaskParams(
          title: result.title,
          description: result.description,
          dueDate: result.dueDate,
        ),
      ),
    );
  }

  Future<void> _edit(Task task) async {
    final result = await TaskFormPage.open(context, initial: task);
    if (result == null || !mounted) return;
    _bloc.add(
      TaskUpdated(
        UpdateTaskParams(
          original: task,
          title: result.title,
          description: result.description,
          dueDate: result.dueDate,
        ),
      ),
    );
  }

  Future<void> _delete(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteDialog(title: task.title),
    );
    if (confirmed == true && mounted) _bloc.add(TaskDeleted(task));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f5): _refresh,
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): _refresh,
        const SingleActivator(LogicalKeyboardKey.keyR, meta: true): _refresh,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: Text(l10n.appTitle),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: l10n.refreshTooltip,
                onPressed: _refresh,
              ),
              if (widget.onSignOut case final onSignOut?)
                IconButton(
                  icon: const Icon(Icons.logout),
                  tooltip: l10n.signOutTooltip,
                  onPressed: onSignOut,
                ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            tooltip: l10n.addTaskTooltip,
            onPressed: _add,
            child: const Icon(Icons.add),
          ),
          body: SafeArea(
            child: BlocConsumer<TasksBloc, TasksState>(
              listenWhen: (previous, current) =>
                  current.actionFailure != null &&
                  previous.actionFailure != current.actionFailure,
              listener: (context, state) {
                final failure = state.actionFailure;
                if (failure == null) return;
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(taskFailureMessage(l10n, failure.reason)),
                    ),
                  );
              },
              builder: (context, state) => switch (state.status) {
                TasksStatus.loading => Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: l10n.loadingLabel,
                  ),
                ),
                TasksStatus.failure => _LoadFailureView(
                  message: taskFailureMessage(
                    l10n,
                    state.loadFailure ?? TaskFailureReason.unknown,
                  ),
                  onRetry: _refresh,
                ),
                TasksStatus.loaded => RefreshIndicator(
                  onRefresh: _pullToRefresh,
                  child: state.timeline.isEmpty
                      ? const _EmptyView()
                      : TaskTimelineView(
                          timeline: state.timeline,
                          onToggle: (task) =>
                              _bloc.add(TaskCompletionToggled(task)),
                          onEdit: _edit,
                          onDelete: _delete,
                        ),
                ),
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    // Scrollable so pull-to-refresh also works on an empty list.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.checklist, size: 64),
                  const SizedBox(height: 16),
                  Text(l10n.tasksEmptyTitle, style: textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(l10n.tasksEmptyMessage, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadFailureView extends StatelessWidget {
  const _LoadFailureView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48),
            const SizedBox(height: 16),
            Text(l10n.tasksLoadError, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: Text(l10n.retryAction)),
          ],
        ),
      ),
    );
  }
}

class _DeleteDialog extends StatelessWidget {
  const _DeleteDialog({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.taskDeleteDialogTitle),
      content: Text(l10n.taskDeleteDialogMessage(title)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancelAction),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.deleteAction),
        ),
      ],
    );
  }
}
