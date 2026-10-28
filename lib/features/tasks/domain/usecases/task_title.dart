import 'package:todo/core/error/failure.dart';

/// Returns [title] without surrounding whitespace, or throws
/// [TaskFailureReason.emptyTitle] if nothing is left.
String normalizeTaskTitle(String title) {
  final trimmed = title.trim();
  if (trimmed.isEmpty) {
    throw const TaskFailure(TaskFailureReason.emptyTitle);
  }
  return trimmed;
}
