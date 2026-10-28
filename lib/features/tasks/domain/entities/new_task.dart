import 'package:equatable/equatable.dart';
import 'package:todo/core/time/calendar_date.dart';

/// A task not yet persisted; the backend assigns its id.
final class NewTask extends Equatable {
  const NewTask({
    required this.title,
    this.description = '',
    this.dueDate,
    required this.createdAt,
  });

  final String title;
  final String description;
  final CalendarDate? dueDate;
  final DateTime createdAt;

  @override
  List<Object?> get props => [title, description, dueDate, createdAt];
}
