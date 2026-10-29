import 'package:flutter/material.dart';

/// Colors for task states that the Material color scheme has no role for.
@immutable
class TaskStatusColors extends ThemeExtension<TaskStatusColors> {
  const TaskStatusColors({
    required this.overdue,
    required this.overdueContainer,
  });

  /// Orange tones chosen for at least 4.5:1 contrast on the app's surfaces
  /// and on their own container.
  static const light = TaskStatusColors(
    overdue: Color(0xFFA6400A),
    overdueContainer: Color(0xFFFDF0E3),
  );
  static const dark = TaskStatusColors(
    overdue: Color(0xFFFFB77C),
    overdueContainer: Color(0xFF3A2412),
  );

  final Color overdue;
  final Color overdueContainer;

  static TaskStatusColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<TaskStatusColors>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  @override
  TaskStatusColors copyWith({Color? overdue, Color? overdueContainer}) =>
      TaskStatusColors(
        overdue: overdue ?? this.overdue,
        overdueContainer: overdueContainer ?? this.overdueContainer,
      );

  @override
  TaskStatusColors lerp(TaskStatusColors? other, double t) {
    if (other == null) return this;
    return TaskStatusColors(
      overdue: Color.lerp(overdue, other.overdue, t) ?? overdue,
      overdueContainer:
          Color.lerp(overdueContainer, other.overdueContainer, t) ??
          overdueContainer,
    );
  }
}
