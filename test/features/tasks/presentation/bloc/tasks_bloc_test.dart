import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:todo/core/error/failure.dart';
import 'package:todo/core/time/calendar_date.dart';
import 'package:todo/features/tasks/domain/entities/new_task.dart';
import 'package:todo/features/tasks/domain/entities/task.dart';
import 'package:todo/features/tasks/domain/entities/task_timeline.dart';
import 'package:todo/features/tasks/domain/entities/widget_task_snapshot.dart';
import 'package:todo/features/tasks/domain/repositories/task_repository.dart';
import 'package:todo/features/tasks/domain/repositories/task_widget_publisher.dart';
import 'package:todo/features/tasks/domain/usecases/add_task.dart';
import 'package:todo/features/tasks/domain/usecases/build_task_timeline.dart';
import 'package:todo/features/tasks/domain/usecases/delete_task.dart';
import 'package:todo/features/tasks/domain/usecases/get_tasks.dart';
import 'package:todo/features/tasks/domain/usecases/publish_widget_tasks.dart';
import 'package:todo/features/tasks/domain/usecases/toggle_task.dart';
import 'package:todo/features/tasks/domain/usecases/update_task.dart';
import 'package:todo/features/tasks/presentation/bloc/tasks_bloc.dart';

import '../../../../helpers/fixed_clock.dart';
import '../../../../helpers/task_factory.dart';

class _MockTaskRepository extends Mock implements TaskRepository {}

class _MockTaskWidgetPublisher extends Mock implements TaskWidgetPublisher {}

void main() {
  final today = CalendarDate(2026, 10, 27);
  final pending = buildTask('p', dueDate: CalendarDate(2026, 10, 30));
  final overdue = buildTask('o', dueDate: CalendarDate(2026, 10, 25));
  late _MockTaskRepository repository;
  late _MockTaskWidgetPublisher widgetPublisher;
  late FixedClock clock;

  TasksBloc build() => TasksBloc(
    getTasks: GetTasks(repository),
    addTask: AddTask(repository, clock),
    updateTask: UpdateTask(repository),
    deleteTask: DeleteTask(repository),
    toggleTask: ToggleTask(repository, clock),
    buildTimeline: const BuildTaskTimeline(),
    publishWidgetTasks: PublishWidgetTasks(widgetPublisher, clock),
    clock: clock,
  );

  TaskTimeline timelineOf(List<Task> tasks) =>
      const BuildTaskTimeline()(tasks, today: today);

  TasksState loaded(
    List<Task> tasks, {
    TaskActionFailure? failure,
    bool isSaving = false,
  }) => TasksState(
    status: TasksStatus.loaded,
    tasks: tasks,
    timeline: timelineOf(tasks),
    today: today,
    isSaving: isSaving,
    actionFailure: failure,
  );

  TaskActionFailure failureOf(TaskFailureReason reason, [int sequence = 1]) =>
      TaskActionFailure(reason, sequence);

  void stored(List<Task> tasks) =>
      when(() => repository.getAll()).thenAnswer((_) async => tasks);

  Future<Never> fail(TaskFailureReason reason) async =>
      throw TaskFailure(reason);

  setUpAll(() {
    registerFallbackValue(NewTask(title: '', createdAt: baseInstant));
    registerFallbackValue(buildTask('fallback'));
    registerFallbackValue(
      WidgetTaskSnapshot(
        tasks: const [],
        generatedAt: baseInstant,
        coversUntil: CalendarDate(2026, 1, 1),
      ),
    );
  });

  setUp(() {
    repository = _MockTaskRepository();
    widgetPublisher = _MockTaskWidgetPublisher();
    when(() => widgetPublisher.publish(any())).thenAnswer((_) async {});
    clock = FixedClock(DateTime(2026, 10, 27, 9));
    when(() => repository.update(any())).thenAnswer((_) async {});
    when(() => repository.delete(any())).thenAnswer((_) async {});
  });

  test('starts loading', () {
    expect(build().state, const TasksState());
  });

  group('loading', () {
    blocTest<TasksBloc, TasksState>(
      'builds the timeline for today on the device clock',
      setUp: () => stored([pending, overdue]),
      build: build,
      act: (bloc) => bloc.add(const TasksRequested()),
      expect: () => [
        loaded([pending, overdue]),
      ],
      verify: (bloc) {
        expect(bloc.state.timeline.days.first.isOverdue, isTrue);
        expect(bloc.state.today, today);
      },
    );

    blocTest<TasksBloc, TasksState>(
      'the first load failing shows a failure with its reason',
      setUp: () =>
          when(() => repository.getAll())
              .thenAnswer((_) => fail(TaskFailureReason.network)),
      build: build,
      act: (bloc) => bloc.add(const TasksRequested()),
      expect: () => [
        const TasksState(
          status: TasksStatus.failure,
          loadFailure: TaskFailureReason.network,
        ),
      ],
    );

    blocTest<TasksBloc, TasksState>(
      'retrying after a failure goes back to loading',
      setUp: () => stored([pending]),
      build: build,
      seed: () => const TasksState(
        status: TasksStatus.failure,
        loadFailure: TaskFailureReason.network,
      ),
      act: (bloc) => bloc.add(const TasksRequested()),
      expect: () => [
        const TasksState(),
        loaded([pending]),
      ],
    );

    blocTest<TasksBloc, TasksState>(
      'reloading keeps the list on screen while refreshing',
      setUp: () => stored([pending, overdue]),
      build: build,
      seed: () => loaded([pending]),
      act: (bloc) => bloc.add(const TasksRequested()),
      expect: () => [
        loaded([pending]).copyWith(isRefreshing: true),
        loaded([pending, overdue]),
      ],
    );

    blocTest<TasksBloc, TasksState>(
      'a failed reload keeps the list and reports once',
      setUp: () =>
          when(() => repository.getAll())
              .thenAnswer((_) => fail(TaskFailureReason.network)),
      build: build,
      seed: () => loaded([pending]),
      act: (bloc) => bloc.add(const TasksRequested()),
      skip: 1,
      expect: () => [
        loaded([
          pending,
        ], failure: const TaskActionFailure(TaskFailureReason.network, 1)),
      ],
    );

    blocTest<TasksBloc, TasksState>(
      'unexpected errors never escape and become unknown',
      setUp: () =>
          when(() => repository.getAll())
              .thenAnswer((_) async => throw StateError('boom')),
      build: build,
      act: (bloc) => bloc.add(const TasksRequested()),
      expect: () => [
        const TasksState(
          status: TasksStatus.failure,
          loadFailure: TaskFailureReason.unknown,
        ),
      ],
    );

    blocTest<TasksBloc, TasksState>(
      'a task becomes overdue on a reload after midnight',
      setUp: () =>
          stored([buildTask('t', dueDate: CalendarDate(2026, 10, 27))]),
      build: build,
      act: (bloc) async {
        bloc.add(const TasksRequested());
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.timeline.days.single.isOverdue, isFalse);
        clock.advance(const Duration(days: 1));
        bloc.add(const TasksRequested());
      },
      verify: (bloc) =>
          expect(bloc.state.timeline.days.single.isOverdue, isTrue),
    );
  });

  group('creating and editing', () {
    final created = buildTask('new');
    final edited = pending.copyWith(
      title: 'Editada',
      description: 'd',
      dueDate: () => null,
    );
    final editParams = UpdateTaskParams(
      original: pending,
      title: 'Editada',
      description: 'd',
      dueDate: null,
    );

    blocTest<TasksBloc, TasksState>(
      'adding shows saving, then the stored task, without reloading',
      setUp: () =>
          when(() => repository.add(any())).thenAnswer((_) async => created),
      build: build,
      seed: () => loaded([pending]),
      act: (bloc) => bloc.add(const TaskAdded(AddTaskParams(title: 'Nova'))),
      expect: () => [
        loaded([pending], isSaving: true),
        loaded([pending, created], isSaving: true),
        loaded([pending, created]),
      ],
      verify: (_) {
        verify(() => repository.add(any())).called(1);
        verifyNever(() => repository.getAll());
      },
    );

    blocTest<TasksBloc, TasksState>(
      'updating stores the edited fields and shows them in place',
      build: build,
      seed: () => loaded([pending, overdue]),
      act: (bloc) => bloc.add(TaskUpdated(editParams)),
      expect: () => [
        loaded([pending, overdue], isSaving: true),
        loaded([edited, overdue], isSaving: true),
        loaded([edited, overdue]),
      ],
      verify: (_) {
        verify(() => repository.update(edited)).called(1);
        verifyNever(() => repository.getAll());
      },
    );

    blocTest<TasksBloc, TasksState>(
      'saving stays on until every save has finished',
      setUp: () =>
          when(() => repository.add(any())).thenAnswer((_) async => created),
      build: build,
      seed: () => loaded([pending]),
      act: (bloc) => bloc
        ..add(const TaskAdded(AddTaskParams(title: 'Nova')))
        ..add(TaskUpdated(editParams)),
      verify: (bloc) {
        expect(bloc.state.isSaving, isFalse);
        expect(bloc.state.tasks, [edited, created]);
      },
    );

    blocTest<TasksBloc, TasksState>(
      'a failed save keeps the list and reports once',
      setUp: () =>
          when(() => repository.update(any()))
              .thenAnswer((_) => fail(TaskFailureReason.network)),
      build: build,
      seed: () => loaded([pending]),
      act: (bloc) => bloc.add(TaskUpdated(editParams)),
      expect: () => [
        loaded([pending], isSaving: true),
        loaded(
          [pending],
          isSaving: true,
          failure: failureOf(TaskFailureReason.network),
        ),
        loaded([pending], failure: failureOf(TaskFailureReason.network)),
      ],
    );

    blocTest<TasksBloc, TasksState>(
      'editing a task deleted elsewhere removes it',
      setUp: () =>
          when(() => repository.update(any()))
              .thenAnswer((_) => fail(TaskFailureReason.notFound)),
      build: build,
      seed: () => loaded([pending]),
      act: (bloc) => bloc.add(TaskUpdated(editParams)),
      verify: (bloc) => expect(
        bloc.state,
        loaded([], failure: failureOf(TaskFailureReason.notFound)),
      ),
    );
  });

  group('completing and deleting', () {
    late Completer<void> server;
    final completed = pending.copyWith(
      completedAt: () => DateTime.utc(2026, 10, 27, 12),
    );

    setUp(() => server = Completer<void>());

    blocTest<TasksBloc, TasksState>(
      'completing shows at once, stamped with the instant that is stored',
      setUp: () =>
          when(() => repository.update(any())).thenAnswer((_) => server.future),
      build: build,
      seed: () => loaded([pending]),
      act: (bloc) async {
        bloc.add(TaskCompletionToggled(pending));
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.timeline.completed.single.id, 'p');
        expect(bloc.state.timeline.days, isEmpty);
        server.complete();
      },
      expect: () => [
        loaded([completed]),
      ],
      verify: (_) {
        verify(() => repository.update(completed)).called(1);
        verifyNever(() => repository.getAll());
      },
    );

    blocTest<TasksBloc, TasksState>(
      'deleting hides the task before the server confirms it',
      setUp: () =>
          when(() => repository.delete(any())).thenAnswer((_) => server.future),
      build: build,
      seed: () => loaded([pending, overdue]),
      act: (bloc) async {
        bloc.add(TaskDeleted(pending));
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.tasks, [overdue]);
        server.complete();
      },
      expect: () => [
        loaded([overdue]),
      ],
      verify: (_) {
        verify(() => repository.delete('p')).called(1);
        verifyNever(() => repository.getAll());
      },
    );

    blocTest<TasksBloc, TasksState>(
      'a failed completion puts the task back and reports once',
      setUp: () =>
          when(() => repository.update(any()))
              .thenAnswer((_) => fail(TaskFailureReason.network)),
      build: build,
      seed: () => loaded([pending]),
      act: (bloc) => bloc.add(TaskCompletionToggled(pending)),
      expect: () => [
        loaded([completed]),
        loaded([pending], failure: failureOf(TaskFailureReason.network)),
      ],
    );

    blocTest<TasksBloc, TasksState>(
      'a failed delete puts the task back',
      setUp: () =>
          when(() => repository.delete(any()))
              .thenAnswer((_) => fail(TaskFailureReason.network)),
      build: build,
      seed: () => loaded([pending, overdue]),
      act: (bloc) => bloc.add(TaskDeleted(pending)),
      expect: () => [
        loaded([overdue]),
        loaded([
          overdue,
          pending,
        ], failure: failureOf(TaskFailureReason.network)),
      ],
    );

    blocTest<TasksBloc, TasksState>(
      'completing a task deleted elsewhere removes it',
      setUp: () =>
          when(() => repository.update(any()))
              .thenAnswer((_) => fail(TaskFailureReason.notFound)),
      build: build,
      seed: () => loaded([pending]),
      act: (bloc) => bloc.add(TaskCompletionToggled(pending)),
      expect: () => [
        loaded([completed]),
        loaded([], failure: failureOf(TaskFailureReason.notFound)),
      ],
    );

    blocTest<TasksBloc, TasksState>(
      'a newer change to the task is kept when an older one fails',
      setUp: () =>
          when(() => repository.update(completed)).thenAnswer((_) async {
            await server.future;
            throw const TaskFailure(TaskFailureReason.network);
          }),
      build: build,
      seed: () => loaded([pending]),
      act: (bloc) async {
        bloc.add(TaskCompletionToggled(pending));
        await Future<void>.delayed(Duration.zero);
        bloc.add(TaskCompletionToggled(bloc.state.tasks.single));
        await Future<void>.delayed(Duration.zero);
        server.complete();
      },
      verify: (bloc) {
        expect(
          bloc.state,
          loaded([pending], failure: failureOf(TaskFailureReason.network)),
        );
        verifyInOrder([
          () => repository.update(completed),
          () => repository.update(pending),
        ]);
      },
    );

    blocTest<TasksBloc, TasksState>(
      'a change waits for the one before it to reach the server',
      setUp: () =>
          when(() => repository.update(any())).thenAnswer((_) => server.future),
      build: build,
      seed: () => loaded([pending, overdue]),
      act: (bloc) async {
        bloc
          ..add(TaskCompletionToggled(pending))
          ..add(TaskDeleted(overdue));
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.tasks, [completed]);
        verifyNever(() => repository.delete(any()));
        server.complete();
      },
      verify: (_) => verify(() => repository.delete('o')).called(1),
    );

    blocTest<TasksBloc, TasksState>(
      'a reload queued before a change does not undo it',
      setUp: () => stored([pending]),
      build: build,
      seed: () => loaded([pending]),
      act: (bloc) => bloc
        ..add(const TasksRequested())
        ..add(TaskCompletionToggled(pending)),
      verify: (bloc) => expect(bloc.state.tasks, [completed]),
    );

    blocTest<TasksBloc, TasksState>(
      'two equal failures in a row are two distinct messages',
      setUp: () =>
          when(() => repository.delete(any()))
              .thenAnswer((_) => fail(TaskFailureReason.network)),
      build: build,
      seed: () => loaded([pending]),
      act: (bloc) async {
        bloc.add(TaskDeleted(pending));
        await Future<void>.delayed(Duration.zero);
        bloc.add(TaskDeleted(pending));
      },
      verify: (bloc) => expect(
        bloc.state.actionFailure,
        failureOf(TaskFailureReason.network, 2),
      ),
    );
  });

  group('home screen widget', () {
    blocTest<TasksBloc, TasksState>(
      'loading publishes the stored tasks for today',
      setUp: () => stored([
        buildTask('today', dueDate: today),
        overdue,
        buildTask('undated'),
      ]),
      build: build,
      act: (bloc) => bloc.add(const TasksRequested()),
      verify: (_) {
        final snapshot =
            verify(() => widgetPublisher.publish(captureAny())).captured.single
                as WidgetTaskSnapshot;
        expect([for (final t in snapshot.tasks) t.id], ['today', 'o']);
        expect(snapshot.coversUntil, today.addDays(7));
      },
    );

    blocTest<TasksBloc, TasksState>(
      'each confirmed change publishes the list on screen',
      setUp: () {
        when(() => repository.add(any()))
            .thenAnswer((_) async => buildTask('new', dueDate: today));
        stored([pending]);
      },
      build: build,
      act: (bloc) async {
        bloc.add(const TasksRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const TaskAdded(AddTaskParams(title: 'Nova')));
        await Future<void>.delayed(Duration.zero);
        bloc.add(TaskDeleted(pending));
        await Future<void>.delayed(Duration.zero);
        bloc.add(TaskCompletionToggled(buildTask('new', dueDate: today)));
      },
      verify: (_) {
        final snapshots = verify(() => widgetPublisher.publish(captureAny()))
            .captured
            .cast<WidgetTaskSnapshot>();
        expect(
          [
            for (final s in snapshots) [for (final t in s.tasks) t.id],
          ],
          [
            ['p'],
            ['p', 'new'],
            ['new'],
            <String>[],
          ],
        );
      },
    );

    blocTest<TasksBloc, TasksState>(
      'a failed change publishes nothing',
      setUp: () =>
          when(() => repository.delete(any()))
              .thenAnswer((_) => fail(TaskFailureReason.network)),
      build: build,
      seed: () => loaded([pending]),
      act: (bloc) => bloc.add(TaskDeleted(pending)),
      verify: (_) => verifyNever(() => widgetPublisher.publish(any())),
    );

    blocTest<TasksBloc, TasksState>(
      'a failed reload publishes nothing',
      setUp: () =>
          when(() => repository.getAll())
              .thenAnswer((_) => fail(TaskFailureReason.network)),
      build: build,
      act: (bloc) => bloc.add(const TasksRequested()),
      verify: (_) => verifyNever(() => widgetPublisher.publish(any())),
    );

    blocTest<TasksBloc, TasksState>(
      'a failed publish changes nothing on screen',
      setUp: () {
        stored([pending]);
        when(() => widgetPublisher.publish(any()))
            .thenAnswer((_) async => throw StateError('storage'));
      },
      build: build,
      act: (bloc) => bloc.add(const TasksRequested()),
      expect: () => [
        loaded([pending]),
      ],
      errors: () => isEmpty,
    );
  });
}
