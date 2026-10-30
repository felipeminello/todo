import 'package:todo/core/time/calendar_date.dart';
import 'package:todo/core/time/clock.dart';
import 'package:todo/core/usecase/usecase.dart';
import 'package:todo/features/tasks/domain/entities/task.dart';
import 'package:todo/features/tasks/domain/repositories/task_widget_publisher.dart';
import 'package:todo/features/tasks/domain/usecases/select_widget_tasks.dart';

/// Updates the home screen widget from the full list of stored tasks.
final class PublishWidgetTasks implements UseCase<void, List<Task>> {
  const PublishWidgetTasks(
    this._publisher,
    this._clock, [
    this._select = const SelectWidgetTasks(),
  ]);

  final TaskWidgetPublisher _publisher;
  final Clock _clock;
  final SelectWidgetTasks _select;

  @override
  Future<void> call(List<Task> tasks) {
    final now = _clock.now();
    return _publisher.publish(
      _select(tasks, today: CalendarDate.fromLocal(now), generatedAt: now),
    );
  }
}
