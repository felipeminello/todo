import 'package:equatable/equatable.dart';

/// A file attached to a task.
final class TaskAttachment extends Equatable {
  const TaskAttachment({
    required this.id,
    required this.name,
    required this.size,
    required this.contentType,
    required this.createdAt,
  });

  /// The name the file is stored under, assigned by the backend: a UUID plus
  /// the extension of [name].
  final String id;

  /// The name of the file as the user uploaded it; what the app shows.
  final String name;

  /// In bytes.
  final int size;

  final String contentType;

  /// UTC instant, used only for ordering.
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, name, size, contentType, createdAt];
}
