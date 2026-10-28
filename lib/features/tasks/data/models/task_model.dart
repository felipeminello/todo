import 'package:equatable/equatable.dart';
import 'package:todo/core/time/calendar_date.dart';
import 'package:todo/features/tasks/domain/entities/new_task.dart';
import 'package:todo/features/tasks/domain/entities/task.dart';

/// Stored shape of a task, shared by the Firestore SDK and REST data sources.
///
/// Instants are UTC; the due date is a `YYYY-MM-DD` string so it never
/// shifts across time zones.
final class TaskModel extends Equatable {
  const TaskModel({
    required this.id,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.createdAt,
    required this.completedAt,
  });

  factory TaskModel.fromEntity(Task task) => TaskModel(
    id: task.id,
    title: task.title,
    description: task.description,
    dueDate: task.dueDate?.toIso(),
    createdAt: task.createdAt.toUtc(),
    completedAt: task.completedAt?.toUtc(),
  );

  /// A model not yet persisted. Its empty id is replaced by the one the
  /// backend assigns on creation.
  factory TaskModel.draft(NewTask task) => TaskModel(
    id: '',
    title: task.title,
    description: task.description,
    dueDate: task.dueDate?.toIso(),
    createdAt: task.createdAt.toUtc(),
    completedAt: null,
  );

  /// Reads the map stored through the Firestore SDK, with instants already
  /// converted to [DateTime]. Throws a [FormatException] on unexpected data.
  factory TaskModel.fromMap(String id, Map<String, Object?> map) {
    if (map case {
      'title': final String title,
      'createdAt': final DateTime createdAt,
    }) {
      return TaskModel(
        id: id,
        title: title,
        description: _optional<String>(map, 'description') ?? '',
        dueDate: _optional<String>(map, 'dueDate'),
        createdAt: createdAt.toUtc(),
        completedAt: _optional<DateTime>(map, 'completedAt')?.toUtc(),
      );
    }
    throw FormatException('Malformed task $id', map);
  }

  /// Reads a Firestore REST `Document` resource. Throws a [FormatException]
  /// on unexpected data.
  factory TaskModel.fromRestDocument(Map<String, Object?> document) {
    if (document case {
      'name': final String name,
      'fields': final Map<String, Object?> fields,
    }) {
      final createdAt = _restTimestamp(fields, 'createdAt');
      final title = _restString(fields, 'title');
      if (createdAt == null || title == null) {
        throw FormatException('Malformed task document $name', document);
      }
      return TaskModel(
        id: name.substring(name.lastIndexOf('/') + 1),
        title: title,
        description: _restString(fields, 'description') ?? '',
        dueDate: _restString(fields, 'dueDate'),
        createdAt: createdAt,
        completedAt: _restTimestamp(fields, 'completedAt'),
      );
    }
    throw FormatException('Malformed task document', document);
  }

  final String id;
  final String title;
  final String description;
  final String? dueDate;
  final DateTime createdAt;
  final DateTime? completedAt;

  /// Throws a [FormatException] if the stored due date is malformed.
  Task toEntity() => Task(
    id: id,
    title: title,
    description: description,
    dueDate: switch (dueDate) {
      final String iso => CalendarDate.fromIso(iso),
      null => null,
    },
    createdAt: createdAt,
    completedAt: completedAt,
  );

  TaskModel withId(String newId) => TaskModel(
    id: newId,
    title: title,
    description: description,
    dueDate: dueDate,
    createdAt: createdAt,
    completedAt: completedAt,
  );

  /// Fields for the Firestore SDK, which stores [DateTime] as a timestamp.
  Map<String, Object?> toMap() => {
    'title': title,
    'description': description,
    'dueDate': dueDate,
    'createdAt': createdAt,
    'completedAt': completedAt,
  };

  /// Typed `fields` of a Firestore REST `Document`.
  Map<String, Object?> toRestFields() => {
    'title': {'stringValue': title},
    'description': {'stringValue': description},
    'dueDate': _restValueOfString(dueDate),
    'createdAt': {'timestampValue': createdAt.toUtc().toIso8601String()},
    'completedAt': switch (completedAt) {
      final DateTime instant => {
        'timestampValue': instant.toUtc().toIso8601String(),
      },
      null => {'nullValue': null},
    },
  };

  static const restFieldPaths = [
    'title',
    'description',
    'dueDate',
    'createdAt',
    'completedAt',
  ];

  static Map<String, Object?> _restValueOfString(String? value) =>
      value == null ? {'nullValue': null} : {'stringValue': value};

  static T? _optional<T extends Object>(Map<String, Object?> map, String key) {
    return switch (map[key]) {
      null => null,
      final T value => value,
      final other => throw FormatException('Unexpected $key', other),
    };
  }

  static String? _restString(Map<String, Object?> fields, String key) {
    return switch (fields[key]) {
      null || {'nullValue': _} => null,
      {'stringValue': final String value} => value,
      final other => throw FormatException('Unexpected $key', other),
    };
  }

  static DateTime? _restTimestamp(Map<String, Object?> fields, String key) {
    return switch (fields[key]) {
      null || {'nullValue': _} => null,
      {'timestampValue': final String value} => DateTime.parse(value).toUtc(),
      final other => throw FormatException('Unexpected $key', other),
    };
  }

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    dueDate,
    createdAt,
    completedAt,
  ];
}
