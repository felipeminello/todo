import 'dart:convert';

import 'package:todo/features/tasks/data/widget/widget_strings.dart';
import 'package:todo/features/tasks/domain/entities/widget_task_snapshot.dart';

/// Writes the JSON the native widgets read. The iOS and Android readers
/// must change together with [version].
final class WidgetSnapshotCodec {
  const WidgetSnapshotCodec(this._strings);

  static const version = 1;

  final WidgetStrings _strings;

  /// The task order of [snapshot] is kept: the widgets rely on it.
  String encode(WidgetTaskSnapshot snapshot) => jsonEncode({
    'version': version,
    'signedIn': true,
    'generatedAt': snapshot.generatedAt.toUtc().toIso8601String(),
    'coversUntil': snapshot.coversUntil.toIso(),
    'tasks': [
      for (final task in snapshot.tasks)
        {
          'id': task.id,
          'title': task.title,
          'dueDate': task.dueDate?.toIso(),
          'createdAt': task.createdAt.toUtc().toIso8601String(),
        },
    ],
    'strings': _strings.toJson(),
  });

  /// No task data at all, only the texts the widget needs to ask the user
  /// to sign in.
  String encodeSignedOut() => jsonEncode({
    'version': version,
    'signedIn': false,
    'tasks': const <Object>[],
    'strings': _strings.toJson(),
  });
}
