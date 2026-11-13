part of 'task_attachments_bloc.dart';

enum TaskAttachmentsStatus { loading, loaded, failure }

final class TaskAttachmentsState extends Equatable {
  const TaskAttachmentsState({
    this.status = TaskAttachmentsStatus.loading,
    this.attachments = const [],
    this.loadFailure,
    this.isUploading = false,
    this.busyIds = const {},
    this.actionFailure,
  });

  final TaskAttachmentsStatus status;

  /// What the server has, oldest first.
  final List<TaskAttachment> attachments;

  /// Why loading failed; set only when [status] is
  /// [TaskAttachmentsStatus.failure].
  final AttachmentFailureReason? loadFailure;

  /// A chosen file is being sent.
  final bool isUploading;

  /// Attachments being downloaded or deleted.
  final Set<String> busyIds;

  /// Why the last attach, download or delete failed, until the next one
  /// starts.
  final AttachmentFailureReason? actionFailure;

  TaskAttachmentsState copyWith({
    TaskAttachmentsStatus? status,
    List<TaskAttachment>? attachments,
    AttachmentFailureReason? Function()? loadFailure,
    bool? isUploading,
    Set<String>? busyIds,
    AttachmentFailureReason? Function()? actionFailure,
  }) {
    return TaskAttachmentsState(
      status: status ?? this.status,
      attachments: attachments ?? this.attachments,
      loadFailure: loadFailure != null ? loadFailure() : this.loadFailure,
      isUploading: isUploading ?? this.isUploading,
      busyIds: busyIds ?? this.busyIds,
      actionFailure: actionFailure != null
          ? actionFailure()
          : this.actionFailure,
    );
  }

  @override
  List<Object?> get props => [
    status,
    attachments,
    loadFailure,
    isUploading,
    busyIds,
    actionFailure,
  ];
}
