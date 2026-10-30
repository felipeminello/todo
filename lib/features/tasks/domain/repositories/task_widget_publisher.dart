import 'package:todo/features/tasks/domain/entities/widget_task_snapshot.dart';

/// Hands the tasks to the home screen widget, where the platform has one.
abstract interface class TaskWidgetPublisher {
  /// Replaces what the widget shows with [snapshot].
  Future<void> publish(WidgetTaskSnapshot snapshot);

  /// Removes every task from the widget, which then asks the user to sign
  /// in.
  Future<void> clearForSignOut();
}
