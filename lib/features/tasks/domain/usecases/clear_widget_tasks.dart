import 'package:todo/core/usecase/usecase.dart';
import 'package:todo/features/tasks/domain/repositories/task_widget_publisher.dart';

/// Removes the signed-out user's tasks from the home screen widget.
final class ClearWidgetTasks implements UseCase<void, NoParams> {
  const ClearWidgetTasks(this._publisher);

  final TaskWidgetPublisher _publisher;

  @override
  Future<void> call([NoParams params = const NoParams()]) =>
      _publisher.clearForSignOut();
}
