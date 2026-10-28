import 'package:flutter/material.dart';

/// Colors for task states that the Material color scheme has no role for.
@immutable
class TaskStatusColors extends ThemeExtension<TaskStatusColors> {
  const TaskStatusColors({required this.overdue});

  /// Orange tones chosen for at least 4.5:1 contrast on the app's surfaces.
  static const light = TaskStatusColors(overdue: Color(0xFFA6400A));
  static const dark = TaskStatusColors(overdue: Color(0xFFFFB77C));

  final Color overdue;

  static TaskStatusColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<TaskStatusColors>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  @override
  TaskStatusColors copyWith({Color? overdue}) =>
      TaskStatusColors(overdue: overdue ?? this.overdue);

  @override
  TaskStatusColors lerp(TaskStatusColors? other, double t) {
    if (other == null) return this;
    return TaskStatusColors(
      overdue: Color.lerp(overdue, other.overdue, t) ?? overdue,
    );
  }
}
