part of 'task_attachments_bloc.dart';

sealed class TaskAttachmentsEvent extends Equatable {
  const TaskAttachmentsEvent();

  @override
  List<Object?> get props => [];
}

/// Load or reload the attachments from the server.
final class TaskAttachmentsRequested extends TaskAttachmentsEvent {
  const TaskAttachmentsRequested();
}

/// The user asked to attach a file, still to be chosen.
final class TaskAttachmentAddRequested extends TaskAttachmentsEvent {
  const TaskAttachmentAddRequested();
}

/// The user asked to save a copy of [attachment] on the device.
final class TaskAttachmentDownloadRequested extends TaskAttachmentsEvent {
  const TaskAttachmentDownloadRequested(this.attachment);

  final TaskAttachment attachment;

  @override
  List<Object?> get props => [attachment];
}

/// The user confirmed deleting [attachment].
final class TaskAttachmentDeleted extends TaskAttachmentsEvent {
  const TaskAttachmentDeleted(this.attachment);

  final TaskAttachment attachment;

  @override
  List<Object?> get props => [attachment];
}
