import 'package:equatable/equatable.dart';
import 'package:todo/features/tasks/domain/entities/task_attachment.dart';

/// An attachment as the attachments API describes it.
final class TaskAttachmentModel extends Equatable {
  const TaskAttachmentModel({
    required this.id,
    required this.name,
    required this.size,
    required this.contentType,
    required this.createdAt,
  });

  /// Throws a [FormatException] on unexpected data.
  factory TaskAttachmentModel.fromJson(Object? json) {
    if (json case {
      'id': final String id,
      'name': final String name,
      'size': final int size,
      'createdAt': final String createdAt,
    }) {
      return TaskAttachmentModel(
        id: id,
        name: name,
        size: size,
        contentType: switch (json['contentType']) {
          final String type => type,
          _ => 'application/octet-stream',
        },
        createdAt: DateTime.parse(createdAt).toUtc(),
      );
    }
    throw FormatException('Malformed attachment', json);
  }

  final String id;
  final String name;
  final int size;
  final String contentType;
  final DateTime createdAt;

  TaskAttachment toEntity() => TaskAttachment(
    id: id,
    name: name,
    size: size,
    contentType: contentType,
    createdAt: createdAt,
  );

  @override
  List<Object?> get props => [id, name, size, contentType, createdAt];
}
