import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/app/theme/app_theme.dart';
import 'package:todo/core/error/exceptions.dart';
import 'package:todo/core/time/calendar_date.dart';
import 'package:todo/features/tasks/data/models/task_model.dart';
import 'package:todo/features/tasks/data/repositories/task_repository_impl.dart';
import 'package:todo/features/tasks/domain/entities/task.dart';
import 'package:todo/features/tasks/domain/usecases/add_task.dart';
import 'package:todo/features/tasks/domain/usecases/build_task_timeline.dart';
import 'package:todo/features/tasks/domain/usecases/delete_task.dart';
import 'package:todo/features/tasks/domain/usecases/get_tasks.dart';
import 'package:todo/features/tasks/domain/usecases/toggle_task.dart';
import 'package:todo/features/tasks/domain/usecases/update_task.dart';
import 'package:todo/features/tasks/presentation/bloc/tasks_bloc.dart';
import 'package:todo/features/tasks/presentation/pages/tasks_page.dart';
import 'package:todo/features/tasks/presentation/theme/task_status_colors.dart';
import 'package:todo/features/tasks/presentation/widgets/task_tile.dart';

import '../../../../helpers/fake_task_remote_data_source.dart';
import '../../../../helpers/fixed_clock.dart';
import '../../../../helpers/localized_app.dart';
import '../../../../helpers/task_factory.dart';

/// Counts loads so refresh triggers can be asserted.
final class _CountingDataSource extends FakeTaskRemoteDataSource {
  int loads = 0;

  @override
  Future<List<TaskModel>> getAll() {
    loads++;
    return super.getAll();
  }
}

void main() {
  late _CountingDataSource dataSource;
  late TasksBloc bloc;
  final clock = FixedClock(DateTime(2026, 10, 27, 10));

  Future<void> seed(List<Task> tasks) async {
    for (final task in tasks) {
      await dataSource.create(TaskModel.fromEntity(task));
    }
  }

  Future<void> pump(WidgetTester tester, {Size? size}) async {
    if (size != null) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    final repository = TaskRepositoryImpl(dataSource);
    bloc = TasksBloc(
      getTasks: GetTasks(repository),
      addTask: AddTask(repository, clock),
      updateTask: UpdateTask(repository),
      deleteTask: DeleteTask(repository),
      toggleTask: ToggleTask(repository, clock),
      buildTimeline: const BuildTaskTimeline(),
      clock: clock,
    )..add(const TasksRequested());
    addTearDown(bloc.close);
    await tester.pumpWidget(
      localizedApp(
        home: BlocProvider.value(value: bloc, child: const TasksPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  double topOf(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text)).dy;

  setUp(() => dataSource = _CountingDataSource());

  testWidgets('shows undated, then the timeline, then completed', (
    tester,
  ) async {
    await seed([
      buildTask('1', title: 'Indefinida'),
      buildTask('2', title: 'Com data', dueDate: CalendarDate(2026, 10, 30)),
      buildTask('3', title: 'Feita', completedMinute: 5),
    ]);
    await pump(tester);

    expect(topOf(tester, 'Sem data'), lessThan(topOf(tester, 'Indefinida')));
    expect(topOf(tester, 'Indefinida'), lessThan(topOf(tester, 'Com data')));
    expect(find.text('sex., 30 de out. de 2026'), findsOneWidget);
    expect(
      topOf(tester, 'Com data'),
      lessThan(topOf(tester, 'Concluídas (1)')),
    );
  });

  testWidgets('an empty account shows an invitation to create', (tester) async {
    await pump(tester);

    expect(find.text('Nenhuma tarefa ainda'), findsOneWidget);
    expect(
      find.text('Use o botão + para criar a primeira tarefa.'),
      findsOneWidget,
    );
  });

  testWidgets('empty blocks are not shown', (tester) async {
    await seed([buildTask('1', title: 'Só sem data')]);
    await pump(tester);

    expect(find.textContaining('Concluídas'), findsNothing);
    expect(find.text('Atrasada'), findsNothing);
    expect(find.byType(TaskTile), findsOneWidget);
  });

  testWidgets('overdue days are highlighted with color, icon and label', (
    tester,
  ) async {
    await seed([
      buildTask('1', title: 'Atrasada A', dueDate: CalendarDate(2026, 10, 25)),
      buildTask('2', title: 'Futura', dueDate: CalendarDate(2026, 10, 28)),
    ]);
    await pump(tester);

    final overdueDate = find.text('dom., 25 de out. de 2026');
    final futureDate = find.text('qua., 28 de out. de 2026');
    expect(
      tester.getTopLeft(overdueDate).dy,
      lessThan(tester.getTopLeft(futureDate).dy),
    );
    expect(find.text('Atrasada'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(
      tester.widget<Text>(overdueDate).style?.color,
      TaskStatusColors.light.overdue,
    );
    expect(
      tester.widget<Text>(futureDate).style?.color,
      isNot(TaskStatusColors.light.overdue),
    );
  });

  testWidgets('screen readers hear that a day is overdue', (tester) async {
    final semantics = tester.ensureSemantics();
    await seed([buildTask('1', dueDate: CalendarDate(2026, 10, 25))]);
    await pump(tester);

    expect(
      find.bySemanticsLabel(
        'domingo, 25 de outubro de 2026, tarefas atrasadas',
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('completed tasks start collapsed with their count', (
    tester,
  ) async {
    await seed([
      buildTask('1', title: 'Feita 1', completedMinute: 1),
      buildTask('2', title: 'Feita 2', completedMinute: 2),
      buildTask('3', title: 'Feita 3', completedMinute: 3),
    ]);
    await pump(tester);

    expect(find.text('Concluídas (3)'), findsOneWidget);
    expect(find.text('Feita 1'), findsNothing);

    await tester.tap(find.text('Concluídas (3)'));
    await tester.pumpAndSettle();

    expect(topOf(tester, 'Feita 3'), lessThan(topOf(tester, 'Feita 1')));
  });

  testWidgets('completing moves the task to the completed list', (
    tester,
  ) async {
    await seed([buildTask('1', title: 'Fazer')]);
    await pump(tester);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(find.text('Concluídas (1)'), findsOneWidget);
    expect(find.text('Fazer'), findsNothing);
  });

  testWidgets('reopening returns the task to its day', (tester) async {
    await seed([
      buildTask(
        '1',
        title: 'Reabrir',
        dueDate: CalendarDate(2026, 10, 30),
        completedMinute: 1,
      ),
    ]);
    await pump(tester);
    await tester.tap(find.text('Concluídas (1)'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(find.textContaining('Concluídas'), findsNothing);
    expect(find.text('sex., 30 de out. de 2026'), findsOneWidget);
    expect(find.text('Reabrir'), findsOneWidget);
  });

  testWidgets('a failed completion shows a message and stays pending', (
    tester,
  ) async {
    await seed([buildTask('1', title: 'Fazer')]);
    await pump(tester);
    dataSource.failNext = const RemoteException(RemoteErrorKind.network);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(
      find.text('Sem conexão. Verifique a internet e tente de novo.'),
      findsOneWidget,
    );
    expect(find.text('Fazer'), findsOneWidget);
    expect(find.textContaining('Concluídas'), findsNothing);
  });

  testWidgets('deleting asks for confirmation', (tester) async {
    await seed([buildTask('1', title: 'Apagar')]);
    await pump(tester);

    await tester.tap(find.byTooltip('Excluir tarefa'));
    await tester.pumpAndSettle();
    expect(find.text('Excluir tarefa?'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Apagar'), findsOneWidget);

    await tester.tap(find.byTooltip('Excluir tarefa'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Excluir'));
    await tester.pumpAndSettle();

    expect(find.text('Apagar'), findsNothing);
    expect(await dataSource.getAll(), isEmpty);
  });

  testWidgets('a failed first load offers a retry', (tester) async {
    dataSource.failNext = const RemoteException(RemoteErrorKind.network);
    await pump(tester);

    expect(find.text('Não foi possível carregar as tarefas.'), findsOneWidget);

    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma tarefa ainda'), findsOneWidget);
  });

  testWidgets('creating from the + button adds the task', (tester) async {
    await pump(tester);

    await tester.tap(find.byTooltip('Nova tarefa'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('task-form-title')), 'Nova');
    await tester.tap(find.byKey(const Key('task-form-save')));
    await tester.pumpAndSettle();

    expect(find.text('Nova'), findsOneWidget);
    expect((await dataSource.getAll()).single.title, 'Nova');
  });

  testWidgets('editing from a tap keeps the task position', (tester) async {
    await seed([
      buildTask('1', title: 'Primeira', createdMinute: 1),
      buildTask('2', title: 'Segunda', createdMinute: 2),
    ]);
    await pump(tester);

    await tester.tap(find.text('Primeira'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('task-form-title')), 'Editada');
    await tester.tap(find.byKey(const Key('task-form-save')));
    await tester.pumpAndSettle();

    expect(topOf(tester, 'Segunda'), lessThan(topOf(tester, 'Editada')));
  });

  group('layout', () {
    testWidgets('fits a 360 px phone without overflow', (tester) async {
      await seed([
        buildTask(
          '1',
          title: 'Uma tarefa com um título bem comprido para quebrar linha',
          description: 'E uma descrição igualmente longa para testar o corte',
          dueDate: CalendarDate(2026, 10, 25),
        ),
      ]);
      await pump(tester, size: const Size(360, 740));

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(TaskTile)).width,
        lessThanOrEqualTo(360),
      );
    });

    testWidgets('centers the list at a readable width on a wide window', (
      tester,
    ) async {
      await seed([buildTask('1', title: 'Larga')]);
      await pump(tester, size: const Size(1600, 900));

      final tile = tester.getRect(find.byType(TaskTile));
      expect(tile.width, lessThanOrEqualTo(720));
      expect(tile.center.dx, closeTo(800, 1));
    });
  });

  group('refresh', () {
    testWidgets('loads once when opened', (tester) async {
      await pump(tester);

      expect(dataSource.loads, 1);
    });

    for (final (name, keys) in [
      ('F5', [LogicalKeyboardKey.f5]),
      ('Ctrl+R', [LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyR]),
      ('Cmd+R', [LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.keyR]),
    ]) {
      testWidgets('$name reloads', (tester) async {
        await pump(tester);

        for (final key in keys) {
          await tester.sendKeyDownEvent(key);
        }
        for (final key in keys.reversed) {
          await tester.sendKeyUpEvent(key);
        }
        await tester.pumpAndSettle();

        expect(dataSource.loads, 2);
      });
    }

    testWidgets('the refresh button reloads', (tester) async {
      await pump(tester);

      await tester.tap(find.byTooltip('Atualizar'));
      await tester.pumpAndSettle();

      expect(dataSource.loads, 2);
    });

    testWidgets('pulling down reloads', (tester) async {
      await seed([buildTask('1', title: 'Puxar')]);
      await pump(tester);

      await tester.fling(find.text('Puxar'), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      expect(dataSource.loads, 2);
    });

    testWidgets('returning to the foreground reloads', (tester) async {
      await pump(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(dataSource.loads, 2);
    });
  });

  testWidgets('dark theme uses the dark overdue color', (tester) async {
    await seed([buildTask('1', dueDate: CalendarDate(2026, 10, 25))]);
    final repository = TaskRepositoryImpl(dataSource);
    bloc = TasksBloc(
      getTasks: GetTasks(repository),
      addTask: AddTask(repository, clock),
      updateTask: UpdateTask(repository),
      deleteTask: DeleteTask(repository),
      toggleTask: ToggleTask(repository, clock),
      buildTimeline: const BuildTaskTimeline(),
      clock: clock,
    )..add(const TasksRequested());
    addTearDown(bloc.close);
    await tester.pumpWidget(
      localizedApp(
        theme: AppTheme.dark,
        home: BlocProvider.value(value: bloc, child: const TasksPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.text('Atrasada')).style?.color,
      TaskStatusColors.dark.overdue,
    );
  });
}
