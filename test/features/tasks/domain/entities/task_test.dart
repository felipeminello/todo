import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/time/calendar_date.dart';
import 'package:todo/features/tasks/domain/entities/new_task.dart';
import 'package:todo/features/tasks/domain/entities/task.dart';

void main() {
  final createdAt = DateTime.utc(2026, 10, 27, 12);
  final task = Task(
    id: '1',
    title: 'Comprar pão',
    description: 'Integral',
    dueDate: CalendarDate(2026, 10, 30),
    createdAt: createdAt,
  );

  test('compares by value', () {
    expect(
      task,
      Task(
        id: '1',
        title: 'Comprar pão',
        description: 'Integral',
        dueDate: CalendarDate(2026, 10, 30),
        createdAt: createdAt,
      ),
    );
    expect(task, isNot(task.copyWith(title: 'Outro')));
  });

  test('is pending without completedAt and completed with it', () {
    expect(task.isCompleted, isFalse);
    expect(task.copyWith(completedAt: () => createdAt).isCompleted, isTrue);
  });

  test('copyWith keeps unspecified fields', () {
    final copy = task.copyWith(title: 'Novo');

    expect(copy.id, task.id);
    expect(copy.title, 'Novo');
    expect(copy.description, task.description);
    expect(copy.dueDate, task.dueDate);
    expect(copy.createdAt, task.createdAt);
    expect(copy.completedAt, task.completedAt);
  });

  test('copyWith clears nullable fields explicitly', () {
    final completed = task.copyWith(completedAt: () => createdAt);

    expect(completed.copyWith(dueDate: () => null).dueDate, isNull);
    expect(completed.copyWith(completedAt: () => null).completedAt, isNull);
  });

  test('copyWith sets a due date on an undated task', () {
    final undated = task.copyWith(dueDate: () => null);

    expect(
      undated.copyWith(dueDate: () => CalendarDate(2026, 11, 2)).dueDate,
      CalendarDate(2026, 11, 2),
    );
  });

  test('NewTask compares by value', () {
    expect(
      NewTask(title: 'a', createdAt: createdAt),
      NewTask(title: 'a', createdAt: createdAt),
    );
  });
}
