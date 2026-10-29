import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:todo/core/error/failure.dart';
import 'package:todo/core/ui/widgets/brand_background.dart';
import 'package:todo/features/tasks/domain/entities/task.dart';
import 'package:todo/features/tasks/domain/usecases/add_task.dart';
import 'package:todo/features/tasks/domain/usecases/update_task.dart';
import 'package:todo/features/tasks/presentation/bloc/tasks_bloc.dart';
import 'package:todo/features/tasks/presentation/widgets/add_task_button.dart';
import 'package:todo/features/tasks/presentation/widgets/delete_task_sheet.dart';
import 'package:todo/features/tasks/presentation/widgets/task_editor_panel.dart';
import 'package:todo/features/tasks/presentation/widgets/task_failure_message.dart';
import 'package:todo/features/tasks/presentation/widgets/task_form.dart';
import 'package:todo/features/tasks/presentation/widgets/task_form_sheet.dart';
import 'package:todo/features/tasks/presentation/widgets/task_list_skeleton.dart';
import 'package:todo/features/tasks/presentation/widgets/task_timeline_view.dart';
import 'package:todo/features/tasks/presentation/widgets/tasks_empty_view.dart';
import 'package:todo/features/tasks/presentation/widgets/tasks_header.dart';
import 'package:todo/features/tasks/presentation/widgets/tasks_load_failure_view.dart';
import 'package:todo/l10n/app_localizations.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key, this.onSignOut});

  /// Windows at least this wide edit tasks in a panel beside the list
  /// instead of a bottom sheet.
  static const twoPaneBreakpoint = 960.0;

  final VoidCallback? onSignOut;

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  static const _wideMaxWidth = 1200.0;
  static const _panelWidth = 380.0;

  late final AppLifecycleListener _lifecycle;

  /// The task open in the side panel; without one the panel creates.
  Task? _editing;

  /// Bumped to give the side panel a fresh form.
  int _panelGeneration = 0;
  bool _focusPanel = false;

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

  bool get _isWide =>
      MediaQuery.sizeOf(context).width >= TasksPage.twoPaneBreakpoint;

  void _refresh() => _bloc.add(const TasksRequested());

  Future<void> _pullToRefresh() async {
    _bloc.add(const TasksRequested());
    await _bloc.stream.firstWhere(
      (state) => !state.isRefreshing && state.status != TasksStatus.loading,
    );
  }

  void _openPanel({Task? task, bool focus = false}) => setState(() {
    _editing = task;
    _panelGeneration++;
    _focusPanel = focus;
  });

  Future<void> _add() async {
    if (_isWide) return _openPanel(focus: true);
    final result = await TaskFormSheet.open(context);
    if (result == null || !mounted) return;
    _save(result);
  }

  Future<void> _edit(Task task) async {
    if (_isWide) return _openPanel(task: task, focus: true);
    final result = await TaskFormSheet.open(context, initial: task);
    if (result == null || !mounted) return;
    _save(result, original: task);
  }

  void _save(TaskFormResult result, {Task? original}) {
    _bloc.add(
      original == null
          ? TaskAdded(
              AddTaskParams(
                title: result.title,
                description: result.description,
                dueDate: result.dueDate,
              ),
            )
          : TaskUpdated(
              UpdateTaskParams(
                original: original,
                title: result.title,
                description: result.description,
                dueDate: result.dueDate,
              ),
            ),
    );
  }

  void _saveFromPanel(TaskFormResult result) {
    _save(result, original: _editing);
    _openPanel();
  }

  Future<void> _delete(Task task) async {
    final confirmed = await DeleteTaskSheet.confirm(context, title: task.title);
    if (!confirmed || !mounted) return;
    _bloc.add(TaskDeleted(task));
    if (_editing?.id == task.id) _openPanel();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final wide = _isWide;
    final padding = wide ? 32.0 : 20.0;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f5): _refresh,
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): _refresh,
        const SingleActivator(LogicalKeyboardKey.keyR, meta: true): _refresh,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          floatingActionButton: wide ? null : AddTaskButton(onPressed: _add),
          body: BrandBackground(
            child: SafeArea(
              bottom: false,
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
                builder: (context, state) {
                  final loaded = state.status == TasksStatus.loaded;
                  final header = TasksHeader(
                    today: state.today,
                    pendingCount: loaded ? state.timeline.pendingCount : null,
                    completedCount: loaded
                        ? state.timeline.completed.length
                        : null,
                    onRefresh: _refresh,
                    onSignOut: widget.onSignOut,
                    onAdd: wide ? _add : null,
                    horizontalPadding: padding,
                  );
                  final content = switch (state.status) {
                    TasksStatus.loading => TaskListSkeleton(
                      horizontalPadding: padding,
                    ),
                    TasksStatus.failure => TasksLoadFailureView(
                      message: taskFailureMessage(
                        l10n,
                        state.loadFailure ?? TaskFailureReason.unknown,
                      ),
                      onRetry: _refresh,
                    ),
                    TasksStatus.loaded => RefreshIndicator(
                      onRefresh: _pullToRefresh,
                      child: state.timeline.isEmpty
                          ? const TasksEmptyView()
                          : TaskTimelineView(
                              timeline: state.timeline,
                              selectedTaskId: wide ? _editing?.id : null,
                              horizontalPadding: padding,
                              onToggle: (task) =>
                                  _bloc.add(TaskCompletionToggled(task)),
                              onEdit: _edit,
                              onDelete: _delete,
                            ),
                    ),
                  };

                  if (!wide) {
                    return Column(
                      children: [
                        Center(
                          heightFactor: 1,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth:
                                  TaskTimelineView.maxContentWidth +
                                  2 * padding,
                            ),
                            child: header,
                          ),
                        ),
                        Expanded(child: content),
                      ],
                    );
                  }
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: _wideMaxWidth,
                      ),
                      child: Column(
                        children: [
                          header,
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: content),
                                if (loaded)
                                  SizedBox(
                                    width: _panelWidth + padding,
                                    child: SingleChildScrollView(
                                      padding: EdgeInsets.fromLTRB(
                                        0,
                                        4,
                                        padding,
                                        32,
                                      ),
                                      child: TaskEditorPanel(
                                        key: ValueKey(_panelGeneration),
                                        task: _editing,
                                        autofocus: _focusPanel,
                                        onSubmit: _saveFromPanel,
                                        onCancel: _openPanel,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
