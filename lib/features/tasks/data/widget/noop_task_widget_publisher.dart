import 'package:todo/features/tasks/domain/entities/widget_task_snapshot.dart';
import 'package:todo/features/tasks/domain/repositories/task_widget_publisher.dart';

/// For platforms without a home screen widget (Windows, macOS).
final class NoopTaskWidgetPublisher implements TaskWidgetPublisher {
  const NoopTaskWidgetPublisher();

  @override
  Future<void> publish(WidgetTaskSnapshot snapshot) async {}

  @override
  Future<void> clearForSignOut() async {}
}
