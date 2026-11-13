import 'package:todo/features/tasks/data/datasources/task_attachment_remote_data_source.dart';
import 'package:todo/features/tasks/data/repositories/task_attachment_repository_impl.dart';
import 'package:todo/features/tasks/domain/usecases/add_task_attachment.dart';
import 'package:todo/features/tasks/domain/usecases/delete_task_attachment.dart';
import 'package:todo/features/tasks/domain/usecases/download_task_attachment.dart';
import 'package:todo/features/tasks/domain/usecases/get_task_attachments.dart';
import 'package:todo/features/tasks/domain/usecases/pick_attachment_file.dart';
import 'package:todo/features/tasks/presentation/bloc/task_attachments_bloc.dart';

import 'fake_attachment_files.dart';

/// Builds attachment blocs like the app does, over a fake backend and fake
/// file dialogs.
TaskAttachmentsBlocFactory taskAttachmentsBlocFactory(
  TaskAttachmentRemoteDataSource dataSource,
  FakeAttachmentFiles files,
) {
  final repository = TaskAttachmentRepositoryImpl(dataSource);
  return (taskId) => TaskAttachmentsBloc(
    taskId: taskId,
    getAttachments: GetTaskAttachments(repository),
    pickFile: PickAttachmentFile(files),
    addAttachment: AddTaskAttachment(repository),
    downloadAttachment: DownloadTaskAttachment(repository, files),
    deleteAttachment: DeleteTaskAttachment(repository),
  );
}
