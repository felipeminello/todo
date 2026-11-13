import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:todo/core/error/failure.dart';
import 'package:todo/features/tasks/domain/entities/task_attachment.dart';
import 'package:todo/features/tasks/domain/usecases/add_task_attachment.dart';
import 'package:todo/features/tasks/domain/usecases/delete_task_attachment.dart';
import 'package:todo/features/tasks/domain/usecases/download_task_attachment.dart';
import 'package:todo/features/tasks/domain/usecases/get_task_attachments.dart';
import 'package:todo/features/tasks/domain/usecases/pick_attachment_file.dart';

part 'task_attachments_event.dart';
part 'task_attachments_state.dart';

/// Builds the bloc of the attachments of one task.
typedef TaskAttachmentsBlocFactory = TaskAttachmentsBloc Function(
  String taskId,
);

/// The attachments of the task [taskId], while its details are open.
///
/// Nothing shows before the server confirms it: an attachment appears once
/// its file is stored and disappears once it is deleted.
final class TaskAttachmentsBloc
    extends Bloc<TaskAttachmentsEvent, TaskAttachmentsState> {
  TaskAttachmentsBloc({
    required this.taskId,
    required this._getAttachments,
    required this._pickFile,
    required this._addAttachment,
    required this._downloadAttachment,
    required this._deleteAttachment,
  }) : super(const TaskAttachmentsState()) {
    on<TaskAttachmentsRequested>(_load);
    on<TaskAttachmentAddRequested>(_add);
    on<TaskAttachmentDownloadRequested>(_download);
    on<TaskAttachmentDeleted>(_delete);
  }

  final String taskId;
  final GetTaskAttachments _getAttachments;
  final PickAttachmentFile _pickFile;
  final AddTaskAttachment _addAttachment;
  final DownloadTaskAttachment _downloadAttachment;
  final DeleteTaskAttachment _deleteAttachment;

  /// From the request until the file is stored, including the time the user
  /// takes to choose it.
  bool _adding = false;

  Future<void> _load(
    TaskAttachmentsRequested event,
    Emitter<TaskAttachmentsState> emit,
  ) async {
    final pending = state.copyWith(
      status: TaskAttachmentsStatus.loading,
      loadFailure: () => null,
    );
    // Bloc emits the first state even when it equals the initial one.
    if (pending != state) emit(pending);
    try {
      final attachments = await _getAttachments(taskId);
      emit(
        state.copyWith(
          status: TaskAttachmentsStatus.loaded,
          attachments: List.unmodifiable(attachments),
        ),
      );
    } on Object catch (error) {
      emit(
        state.copyWith(
          status: TaskAttachmentsStatus.failure,
          loadFailure: () => _reasonOf(error),
        ),
      );
    }
  }

  Future<void> _add(
    TaskAttachmentAddRequested event,
    Emitter<TaskAttachmentsState> emit,
  ) async {
    if (state.status != TaskAttachmentsStatus.loaded || _adding) return;
    _adding = true;
    emit(state.copyWith(actionFailure: () => null));
    try {
      final file = await _pickFile();
      if (file == null) return;
      emit(state.copyWith(isUploading: true));
      final added = await _addAttachment(
        AddTaskAttachmentParams(taskId: taskId, file: file),
      );
      emit(
        state.copyWith(
          attachments: List.unmodifiable([...state.attachments, added]),
          isUploading: false,
        ),
      );
    } on Object catch (error) {
      emit(
        state.copyWith(
          isUploading: false,
          actionFailure: () => _reasonOf(error),
        ),
      );
    } finally {
      _adding = false;
    }
  }

  Future<void> _download(
    TaskAttachmentDownloadRequested event,
    Emitter<TaskAttachmentsState> emit,
  ) async {
    final attachment = event.attachment;
    if (state.busyIds.contains(attachment.id)) return;
    emit(
      state.copyWith(
        busyIds: {...state.busyIds, attachment.id},
        actionFailure: () => null,
      ),
    );
    try {
      await _downloadAttachment(
        DownloadTaskAttachmentParams(taskId: taskId, attachment: attachment),
      );
      emit(state.copyWith(busyIds: _without(attachment.id)));
    } on Object catch (error) {
      final reason = _reasonOf(error);
      emit(
        state.copyWith(
          // Deleted elsewhere: it leaves the list along with the message.
          attachments: reason == AttachmentFailureReason.notFound
              ? _removed(attachment.id)
              : null,
          busyIds: _without(attachment.id),
          actionFailure: () => reason,
        ),
      );
    }
  }

  Future<void> _delete(
    TaskAttachmentDeleted event,
    Emitter<TaskAttachmentsState> emit,
  ) async {
    final id = event.attachment.id;
    if (state.busyIds.contains(id)) return;
    emit(
      state.copyWith(
        busyIds: {...state.busyIds, id},
        actionFailure: () => null,
      ),
    );
    try {
      await _deleteAttachment(
        DeleteTaskAttachmentParams(taskId: taskId, attachmentId: id),
      );
      emit(state.copyWith(attachments: _removed(id), busyIds: _without(id)));
    } on Object catch (error) {
      final reason = _reasonOf(error);
      // One the server no longer has is already gone, which is what was
      // asked.
      final gone = reason == AttachmentFailureReason.notFound;
      emit(
        state.copyWith(
          attachments: gone ? _removed(id) : null,
          busyIds: _without(id),
          actionFailure: gone ? null : () => reason,
        ),
      );
    }
  }

  List<TaskAttachment> _removed(String id) => List.unmodifiable([
    for (final attachment in state.attachments)
      if (attachment.id != id) attachment,
  ]);

  Set<String> _without(String id) => {
    for (final busy in state.busyIds)
      if (busy != id) busy,
  };

  static AttachmentFailureReason _reasonOf(Object error) =>
      error is AttachmentFailure
      ? error.reason
      : AttachmentFailureReason.unknown;
}
