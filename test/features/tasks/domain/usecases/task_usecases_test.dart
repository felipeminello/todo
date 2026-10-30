import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:todo/core/error/failure.dart';
import 'package:todo/core/time/calendar_date.dart';
import 'package:todo/features/tasks/domain/entities/new_task.dart';
import 'package:todo/features/tasks/domain/entities/task.dart';
import 'package:todo/features/tasks/domain/repositories/task_repository.dart';
import 'package:todo/features/tasks/domain/usecases/add_task.dart';
import 'package:todo/features/tasks/domain/usecases/delete_task.dart';
import 'package:todo/features/tasks/domain/usecases/get_tasks.dart';
import 'package:todo/features/tasks/domain/usecases/toggle_task.dart';
import 'package:todo/features/tasks/domain/usecases/update_task.dart';

import '../../../../helpers/fixed_clock.dart';
import '../../../../helpers/task_factory.dart';

class _MockTaskRepository extends Mock implements TaskRepository {}

void main() {
  late _MockTaskRepository repository;
  late FixedClock clock;

  setUpAll(() {
    registerFallbackValue(NewTask(title: '', createdAt: baseInstant));
    registerFallbackValue(buildTask('fallback'));
  });

  setUp(() {
    repository = _MockTaskRepository();
    clock = FixedClock(DateTime.utc(2026, 10, 27, 15, 30));
    when(() => repository.update(any())).thenAnswer((_) async {});
  });

  group('GetTasks', () {
    test('returns the repository tasks', () async {
      final tasks = [buildTask('1')];
      when(() => repository.getAll()).thenAnswer((_) async => tasks);

      expect(await GetTasks(repository)(), tasks);
    });

    test('propagates failures', () {
      when(() => repository.getAll()).thenAnswer(
        (_) async => throw const TaskFailure(TaskFailureReason.network),
      );

      expect(
        GetTasks(repository)(),
        throwsA(const TaskFailure(TaskFailureReason.network)),
      );
    });
  });

  group('AddTask', () {
    setUp(() {
      when(() => repository.add(any())).thenAnswer((invocation) async {
        final draft = invocation.positionalArguments.single as NewTask;
        return Task(
          id: 'new',
          title: draft.title,
          description: draft.description,
          dueDate: draft.dueDate,
          createdAt: draft.createdAt,
        );
      });
    });

    test('trims the title and stamps the creation instant in UTC', () async {
      final task = await AddTask(repository, clock)(
        AddTaskParams(
          title: '  Comprar pão  ',
          description: 'Integral',
          dueDate: CalendarDate(2026, 10, 30),
        ),
      );

      expect(task.title, 'Comprar pão');
      verify(
        () => repository.add(
          NewTask(
            title: 'Comprar pão',
            description: 'Integral',
            dueDate: CalendarDate(2026, 10, 30),
            createdAt: DateTime.utc(2026, 10, 27, 15, 30),
          ),
        ),
      ).called(1);
    });

    test('creates a task without a due date', () async {
      final task = await AddTask(repository, clock)(
        const AddTaskParams(title: 'Ligar'),
      );

      expect(task.dueDate, isNull);
      expect(task.description, isEmpty);
      expect(task.isCompleted, isFalse);
    });

    for (final title in ['', '   ', '\n\t']) {
      test('rejects the blank title ${title.codeUnits}', () {
        expect(
          () => AddTask(repository, clock)(AddTaskParams(title: title)),
          throwsA(const TaskFailure(TaskFailureReason.emptyTitle)),
        );
        verifyNever(() => repository.add(any()));
      });
    }
  });

  group('UpdateTask', () {
    final original = buildTask(
      '1',
      title: 'Antigo',
      dueDate: CalendarDate(2026, 10, 30),
      createdMinute: 5,
      completedMinute: 10,
    );

    test('changes editable fields and keeps creation and completion', () async {
      final updated = await UpdateTask(repository)(
        UpdateTaskParams(
          original: original,
          title: ' Novo ',
          description: 'Detalhe',
          dueDate: null,
        ),
      );

      expect(updated.title, 'Novo');
      expect(updated.description, 'Detalhe');
      expect(updated.dueDate, isNull);
      expect(updated.createdAt, original.createdAt);
      expect(updated.completedAt, original.completedAt);
      verify(() => repository.update(updated)).called(1);
    });

    test('adds a due date to an undated task', () async {
      final updated = await UpdateTask(repository)(
        UpdateTaskParams(
          original: original.copyWith(dueDate: () => null),
          title: original.title,
          description: original.description,
          dueDate: CalendarDate(2026, 10, 30),
        ),
      );

      expect(updated.dueDate, CalendarDate(2026, 10, 30));
    });

    test('rejects a blank title', () {
      expect(
        () => UpdateTask(repository)(
          UpdateTaskParams(
            original: original,
            title: '  ',
            description: '',
            dueDate: null,
          ),
        ),
        throwsA(const TaskFailure(TaskFailureReason.emptyTitle)),
      );
      verifyNever(() => repository.update(any()));
    });
  });

  group('DeleteTask', () {
    test('deletes by id', () async {
      when(() => repository.delete('1')).thenAnswer((_) async {});

      await DeleteTask(repository)('1');

      verify(() => repository.delete('1')).called(1);
    });
  });

  group('ToggleTask', () {
    test('completes a pending task at the current UTC instant', () {
      final pending = buildTask('1', dueDate: CalendarDate(2026, 10, 30));

      final toggled = ToggleTask(repository, clock).toggled(pending);

      expect(toggled.completedAt, DateTime.utc(2026, 10, 27, 15, 30));
      expect(toggled.dueDate, pending.dueDate);
    });

    test('reopens a completed task keeping its due date', () {
      final completed = buildTask(
        '1',
        dueDate: CalendarDate(2026, 10, 30),
        completedMinute: 3,
      );

      final toggled = ToggleTask(repository, clock).toggled(completed);

      expect(toggled.isCompleted, isFalse);
      expect(toggled.dueDate, CalendarDate(2026, 10, 30));
      expect(toggled.title, completed.title);
    });

    test('toggling alone stores nothing', () {
      ToggleTask(repository, clock).toggled(buildTask('1'));

      verifyNever(() => repository.update(any()));
    });

    test('stores the toggled task as it is', () async {
      final toggleTask = ToggleTask(repository, clock);
      final toggled = toggleTask.toggled(buildTask('1'));

      await toggleTask(toggled);

      verify(() => repository.update(toggled)).called(1);
    });

    test('propagates failures from the repository', () {
      when(() => repository.update(any()))
          .thenThrow(const TaskFailure(TaskFailureReason.network));

      expect(
        ToggleTask(repository, clock)(buildTask('1')),
        throwsA(const TaskFailure(TaskFailureReason.network)),
      );
    });
  });
}
