import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/error/failure.dart';
import 'package:todo/core/time/calendar_date.dart';
import 'package:todo/features/tasks/domain/entities/new_task.dart';
import 'package:todo/features/tasks/domain/repositories/task_repository.dart';

/// Behavior every [TaskRepository] must share, whatever its backend.
void taskRepositoryContract(Future<TaskRepository> Function() create) {
  final createdAt = DateTime.utc(2026, 10, 27, 15, 30, 12, 345);
  late TaskRepository repository;

  setUp(() async => repository = await create());

  test('starts empty', () async {
    expect(await repository.getAll(), isEmpty);
  });

  test('add assigns an id and the task is listed with its fields', () async {
    final added = await repository.add(
      NewTask(
        title: 'Comprar pão',
        description: 'Integral',
        dueDate: CalendarDate(2026, 10, 27),
        createdAt: createdAt,
      ),
    );

    expect(added.id, isNotEmpty);
    expect(added.isCompleted, isFalse);
    expect(await repository.getAll(), [added]);
    expect(added.dueDate, CalendarDate(2026, 10, 27));
    expect(added.createdAt, createdAt);
  });

  test('add without a due date stores none', () async {
    final added = await repository.add(
      NewTask(title: 'Ligar', createdAt: createdAt),
    );

    expect((await repository.getAll()).single.dueDate, isNull);
    expect(added.description, isEmpty);
  });

  test('each added task gets a distinct id', () async {
    final a = await repository.add(NewTask(title: 'a', createdAt: createdAt));
    final b = await repository.add(NewTask(title: 'b', createdAt: createdAt));

    expect(a.id, isNot(b.id));
    expect(await repository.getAll(), hasLength(2));
  });

  test('update replaces the stored task, including clearing fields', () async {
    final added = await repository.add(
      NewTask(
        title: 'a',
        dueDate: CalendarDate(2026, 10, 30),
        createdAt: createdAt,
      ),
    );
    final completed = added.copyWith(
      title: 'b',
      dueDate: () => null,
      completedAt: () => DateTime.utc(2026, 10, 28, 9),
    );

    await repository.update(completed);
    expect(await repository.getAll(), [completed]);

    final reopened = completed.copyWith(completedAt: () => null);
    await repository.update(reopened);
    expect(await repository.getAll(), [reopened]);
  });

  test('update of a missing task fails with notFound', () async {
    final added = await repository.add(
      NewTask(title: 'a', createdAt: createdAt),
    );
    await repository.delete(added.id);

    await expectLater(
      repository.update(added),
      throwsA(const TaskFailure(TaskFailureReason.notFound)),
    );
  });

  test('delete removes the task and is idempotent', () async {
    final added = await repository.add(
      NewTask(title: 'a', createdAt: createdAt),
    );

    await repository.delete(added.id);
    await repository.delete(added.id);

    expect(await repository.getAll(), isEmpty);
  });
}
