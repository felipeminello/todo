import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:todo/core/error/failure.dart';
import 'package:todo/core/time/calendar_date.dart';
import 'package:todo/features/tasks/domain/entities/new_task.dart';
import 'package:todo/features/tasks/domain/entities/task.dart';
import 'package:todo/features/tasks/domain/entities/task_timeline.dart';
import 'package:todo/features/tasks/domain/repositories/task_repository.dart';
import 'package:todo/features/tasks/domain/usecases/add_task.dart';
import 'package:todo/features/tasks/domain/usecases/build_task_timeline.dart';
import 'package:todo/features/tasks/domain/usecases/delete_task.dart';
import 'package:todo/features/tasks/domain/usecases/get_tasks.dart';
import 'package:todo/features/tasks/domain/usecases/toggle_task.dart';
import 'package:todo/features/tasks/domain/usecases/update_task.dart';
import 'package:todo/features/tasks/presentation/bloc/tasks_bloc.dart';

import '../../../../helpers/fixed_clock.dart';
import '../../../../helpers/task_factory.dart';

class _MockTaskRepository extends Mock implements TaskRepository {}

void main() {
  final today = CalendarDate(2026, 10, 27);
  final pending = buildTask('p', dueDate: CalendarDate(2026, 10, 30));
  final overdue = buildTask('o', dueDate: CalendarDate(2026, 10, 25));
  late _MockTaskRepository repository;
  late FixedClock clock;

  TasksBloc build() => TasksBloc(
    getTasks: GetTasks(repository),
    addTask: AddTask(repository, clock),
    updateTask: UpdateTask(repository),
    deleteTask: DeleteTask(repository),
    toggleTask: ToggleTask(repository, clock),
    buildTimeline: const BuildTaskTimeline(),
    clock: clock,
  );

  TaskTimeline timelineOf(List<Task> tasks) =>
      const BuildTaskTimeline()(tasks, today: today);

  TasksState loaded(List<Task> tasks, {TaskActionFailure? failure}) =>
      TasksState(
        status: TasksStatus.loaded,
        timeline: timelineOf(tasks),
        actionFailure: failure,
      );

  void stored(List<Task> tasks) =>
      when(() => repository.getAll()).thenAnswer((_) async => tasks);

  Future<Never> fail(TaskFailureReason reason) async =>
      throw TaskFailure(reason);

  setUpAll(() {
    registerFallbackValue(NewTask(title: '', createdAt: baseInstant));
    registerFallbackValue(buildTask('fallback'));
  });

  setUp(() {
    repository = _MockTaskRepository();
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
      verify: (bloc) =>
          expect(bloc.state.timeline.days.first.isOverdue, isTrue),
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
        TasksState(
          status: TasksStatus.loaded,
          timeline: timelineOf([pending]),
          isRefreshing: true,
        ),
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

  group('changes', () {
    blocTest<TasksBloc, TasksState>(
      'adding saves the task and reloads the list',
      setUp: () {
        when(() => repository.add(any()))
            .thenAnswer((_) async => buildTask('new'));
        stored([pending, buildTask('new')]);
      },
      build: build,
      seed: () => loaded([pending]),
      act: (bloc) => bloc.add(const TaskAdded(AddTaskParams(title: 'Nova'))),
      skip: 1,
      expect: () => [
        loaded([pending, buildTask('new')]),
      ],
      verify: (_) => verify(() => repository.add(any())).called(1),
    );

    blocTest<TasksBloc, TasksState>(
      'updating saves the edited fields',
      setUp: () => stored([pending]),
      build: build,
      seed: () => loaded([pending]),
      act: (bloc) => bloc.add(
        TaskUpdated(
          UpdateTaskParams(
            original: pending,
            title: 'Editada',
            description: 'd',
            dueDate: null,
          ),
        ),
      ),
      verify: (_) => verify(
        () => repository.update(
          pending.copyWith(
            title: 'Editada',
            description: 'd',
            dueDate: () => null,
          ),
        ),
      ).called(1),
    );

    blocTest<TasksBloc, TasksState>(
      'deleting removes by id',
      setUp: () => stored([]),
      build: build,
      seed: () => loaded([pending]),
      act: (bloc) => bloc.add(TaskDeleted(pending)),
      verify: (bloc) {
        verify(() => repository.delete('p')).called(1);
        expect(bloc.state.timeline.isEmpty, isTrue);
      },
    );

    blocTest<TasksBloc, TasksState>(
      'completing stamps the completion and moves the task to completed',
      setUp: () => stored([
        pending.copyWith(completedAt: () => DateTime.utc(2026, 10, 27, 12)),
      ]),
      build: build,
      seed: () => loaded([pending]),
      act: (bloc) => bloc.add(TaskCompletionToggled(pending)),
      verify: (bloc) {
        verify(
          () => repository.update(
            pending.copyWith(completedAt: () => clock.now().toUtc()),
          ),
        ).called(1);
        expect(bloc.state.timeline.days, isEmpty);
        expect(bloc.state.timeline.completed.single.id, 'p');
      },
    );

    blocTest<TasksBloc, TasksState>(
      'a failed completion is reported once and the task stays pending',
      setUp: () {
        when(() => repository.update(any()))
            .thenAnswer((_) => fail(TaskFailureReason.network));
        when(() => repository.getAll())
            .thenAnswer((_) => fail(TaskFailureReason.network));
      },
      build: build,
      seed: () => loaded([pending]),
      act: (bloc) => bloc.add(TaskCompletionToggled(pending)),
      expect: () => [
        loaded([
          pending,
        ], failure: const TaskActionFailure(TaskFailureReason.network, 1)),
        TasksState(
          status: TasksStatus.loaded,
          timeline: timelineOf([pending]),
          isRefreshing: true,
          actionFailure: const TaskActionFailure(TaskFailureReason.network, 1),
        ),
        loaded([
          pending,
        ], failure: const TaskActionFailure(TaskFailureReason.network, 1)),
      ],
    );

    blocTest<TasksBloc, TasksState>(
      'two equal failures in a row are two distinct messages',
      setUp: () {
        when(() => repository.delete(any()))
            .thenAnswer((_) => fail(TaskFailureReason.notFound));
        stored([pending]);
      },
      build: build,
      seed: () => loaded([pending]),
      act: (bloc) async {
        bloc.add(TaskDeleted(pending));
        await Future<void>.delayed(Duration.zero);
        bloc.add(TaskDeleted(pending));
      },
      verify: (bloc) => expect(
        bloc.state.actionFailure,
        const TaskActionFailure(TaskFailureReason.notFound, 2),
      ),
    );
  });
}
