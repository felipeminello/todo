import 'package:equatable/equatable.dart';
import 'package:todo/core/time/calendar_date.dart';

final class Task extends Equatable {
  const Task({
    required this.id,
    required this.title,
    this.description = '',
    this.dueDate,
    required this.createdAt,
    this.completedAt,
  });

  final String id;
  final String title;
  final String description;

  /// `null` means the task has no due date.
  final CalendarDate? dueDate;

  /// UTC instant, used only for ordering.
  final DateTime createdAt;

  /// UTC instant; `null` means the task is pending.
  final DateTime? completedAt;

  bool get isCompleted => completedAt != null;

  /// Nullable fields take a function so they can be explicitly cleared,
  /// e.g. `copyWith(dueDate: () => null)`.
  Task copyWith({
    String? title,
    String? description,
    CalendarDate? Function()? dueDate,
    DateTime? Function()? completedAt,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate != null ? dueDate() : this.dueDate,
      createdAt: createdAt,
      completedAt: completedAt != null ? completedAt() : this.completedAt,
    );
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
