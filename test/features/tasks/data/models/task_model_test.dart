import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/time/calendar_date.dart';
import 'package:todo/features/tasks/data/models/task_model.dart';
import 'package:todo/features/tasks/domain/entities/new_task.dart';
import 'package:todo/features/tasks/domain/entities/task.dart';

void main() {
  final full = Task(
    id: 'abc',
    title: 'Comprar pão',
    description: 'Integral',
    dueDate: CalendarDate(2026, 10, 27),
    createdAt: DateTime.utc(2026, 10, 27, 2, 30),
    completedAt: DateTime.utc(2026, 10, 28, 9, 15, 0, 123),
  );
  final minimal = Task(
    id: 'xyz',
    title: 'Ligar',
    createdAt: DateTime.utc(2026, 10, 27),
  );

  group('entity', () {
    test('round-trips with every field set', () {
      expect(TaskModel.fromEntity(full).toEntity(), full);
    });

    test('round-trips with optional fields empty', () {
      expect(TaskModel.fromEntity(minimal).toEntity(), minimal);
    });

    test('stores the due date as YYYY-MM-DD', () {
      expect(TaskModel.fromEntity(full).dueDate, '2026-10-27');
    });

    test('normalizes instants to UTC', () {
      final local = DateTime(2026, 10, 27, 23, 30);
      final model = TaskModel.fromEntity(
        Task(id: '1', title: 't', createdAt: local),
      );

      expect(model.createdAt.isUtc, isTrue);
      expect(model.createdAt, local.toUtc());
    });

    test('a draft has no id and is pending', () {
      final draft = TaskModel.draft(
        NewTask(title: 't', createdAt: DateTime.utc(2026)),
      );

      expect(draft.id, isEmpty);
      expect(draft.completedAt, isNull);
      expect(draft.withId('n').id, 'n');
    });

    test('a malformed stored due date is a FormatException', () {
      final model = TaskModel(
        id: '1',
        title: 't',
        description: '',
        dueDate: '27/10/2026',
        createdAt: DateTime.utc(2026),
        completedAt: null,
      );

      expect(model.toEntity, throwsFormatException);
    });
  });

  group('SDK map', () {
    test('round-trips with every field set', () {
      final model = TaskModel.fromEntity(full);

      expect(TaskModel.fromMap(model.id, model.toMap()), model);
    });

    test('round-trips with null fields', () {
      final model = TaskModel.fromEntity(minimal);
      final map = model.toMap();

      expect(map['dueDate'], isNull);
      expect(map['completedAt'], isNull);
      expect(TaskModel.fromMap(model.id, map), model);
    });

    test('tolerates a missing description', () {
      final model = TaskModel.fromMap('1', {
        'title': 't',
        'createdAt': DateTime.utc(2026),
      });

      expect(model.description, isEmpty);
    });

    test('rejects missing or mistyped fields', () {
      expect(
        () => TaskModel.fromMap('1', {'createdAt': DateTime.utc(2026)}),
        throwsFormatException,
      );
      expect(
        () => TaskModel.fromMap('1', {'title': 't', 'createdAt': '2026'}),
        throwsFormatException,
      );
      expect(
        () => TaskModel.fromMap('1', {
          'title': 't',
          'createdAt': DateTime.utc(2026),
          'dueDate': 20261027,
        }),
        throwsFormatException,
      );
    });
  });

  group('REST document', () {
    Map<String, Object?> document(TaskModel model) => {
      'name': 'projects/p/databases/(default)/documents/users/u/tasks/abc',
      'fields': model.toRestFields(),
      'createTime': '2026-10-27T02:30:00.000001Z',
    };

    test('round-trips with every field set', () {
      final model = TaskModel.fromEntity(full);

      expect(TaskModel.fromRestDocument(document(model)), model);
    });

    test('round-trips with null fields', () {
      final model = TaskModel.fromEntity(minimal.copyWithId('abc'));

      expect(TaskModel.fromRestDocument(document(model)), model);
    });

    test('uses typed values', () {
      final fields = TaskModel.fromEntity(full).toRestFields();

      expect(fields['title'], {'stringValue': 'Comprar pão'});
      expect(fields['dueDate'], {'stringValue': '2026-10-27'});
      expect(fields['createdAt'], {
        'timestampValue': '2026-10-27T02:30:00.000Z',
      });
      expect(TaskModel.fromEntity(minimal).toRestFields()['completedAt'], {
        'nullValue': null,
      });
    });

    test('takes the id from the last segment of the name', () {
      final model = TaskModel.fromRestDocument(
        document(TaskModel.fromEntity(full)),
      );

      expect(model.id, 'abc');
    });

    test('parses nanosecond timestamps sent by Firestore', () {
      final model = TaskModel.fromRestDocument({
        'name': 'x/tasks/1',
        'fields': {
          'title': {'stringValue': 't'},
          'createdAt': {'timestampValue': '2026-10-27T02:30:00.123456789Z'},
        },
      });

      expect(model.createdAt, DateTime.utc(2026, 10, 27, 2, 30, 0, 123, 456));
      expect(model.description, isEmpty);
      expect(model.dueDate, isNull);
    });

    test('the day survives a REST round trip in any time zone', () {
      final model = TaskModel.fromRestDocument(
        document(TaskModel.fromEntity(full)),
      );

      expect(model.toEntity().dueDate, CalendarDate(2026, 10, 27));
    });

    test('rejects malformed documents', () {
      expect(() => TaskModel.fromRestDocument({}), throwsFormatException);
      expect(
        () => TaskModel.fromRestDocument({
          'name': 'x/tasks/1',
          'fields': {
            'title': {'integerValue': '1'},
            'createdAt': {'timestampValue': '2026-10-27T00:00:00Z'},
          },
        }),
        throwsFormatException,
      );
      expect(
        () => TaskModel.fromRestDocument({
          'name': 'x/tasks/1',
          'fields': {
            'title': {'stringValue': 't'},
          },
        }),
        throwsFormatException,
      );
    });
  });
}

extension on Task {
  Task copyWithId(String id) => Task(
    id: id,
    title: title,
    description: description,
    dueDate: dueDate,
    createdAt: createdAt,
    completedAt: completedAt,
  );
}
