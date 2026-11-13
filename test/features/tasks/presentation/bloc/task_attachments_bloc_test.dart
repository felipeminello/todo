import 'dart:async';
import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:todo/core/error/failure.dart';
import 'package:todo/features/tasks/domain/entities/attachment_file.dart';
import 'package:todo/features/tasks/domain/entities/task_attachment.dart';
import 'package:todo/features/tasks/domain/repositories/task_attachment_repository.dart';
import 'package:todo/features/tasks/domain/usecases/add_task_attachment.dart';
import 'package:todo/features/tasks/domain/usecases/delete_task_attachment.dart';
import 'package:todo/features/tasks/domain/usecases/download_task_attachment.dart';
import 'package:todo/features/tasks/domain/usecases/get_task_attachments.dart';
import 'package:todo/features/tasks/domain/usecases/pick_attachment_file.dart';
import 'package:todo/features/tasks/presentation/bloc/task_attachments_bloc.dart';

import '../../../../helpers/fake_attachment_files.dart';

class _MockRepository extends Mock implements TaskAttachmentRepository {}

void main() {
  const loading = TaskAttachmentsState();
  const network = AttachmentFailure(AttachmentFailureReason.network);
  const gone = AttachmentFailure(AttachmentFailureReason.notFound);
  late _MockRepository repository;
  late FakeAttachmentFiles files;

  TaskAttachment attachment(String id) => TaskAttachment(
    id: '$id.pdf',
    name: 'Arquivo $id.pdf',
    size: 3,
    contentType: 'application/pdf',
    createdAt: DateTime.utc(2026, 11, 12),
  );
  final a = attachment('a');
  final b = attachment('b');
  final picked = attachmentFile('Arquivo b.pdf', [1, 2, 3]);

  TaskAttachmentsBloc build() => TaskAttachmentsBloc(
    taskId: 't1',
    getAttachments: GetTaskAttachments(repository),
    pickFile: PickAttachmentFile(files),
    addAttachment: AddTaskAttachment(repository),
    downloadAttachment: DownloadTaskAttachment(repository, files),
    deleteAttachment: DeleteTaskAttachment(repository),
  );

  TaskAttachmentsState loaded(
    List<TaskAttachment> attachments, {
    bool isUploading = false,
    Set<String> busyIds = const {},
    AttachmentFailureReason? failure,
  }) => TaskAttachmentsState(
    status: TaskAttachmentsStatus.loaded,
    attachments: attachments,
    isUploading: isUploading,
    busyIds: busyIds,
    actionFailure: failure,
  );

  setUpAll(() => registerFallbackValue(picked));

  setUp(() {
    repository = _MockRepository();
    files = FakeAttachmentFiles();
  });

  test('starts loading, with nothing to show', () {
    expect(build().state, loading);
  });

  group('loading', () {
    blocTest<TaskAttachmentsBloc, TaskAttachmentsState>(
      'shows the attachments of its task',
      setUp: () =>
          when(() => repository.getAll('t1')).thenAnswer((_) async => [a, b]),
      build: build,
      act: (bloc) => bloc.add(const TaskAttachmentsRequested()),
      expect: () => [
        loaded([a, b]),
      ],
    );

    blocTest<TaskAttachmentsBloc, TaskAttachmentsState>(
      'a failure says why',
      setUp: () => when(() => repository.getAll('t1')).thenThrow(network),
      build: build,
      act: (bloc) => bloc.add(const TaskAttachmentsRequested()),
      expect: () => const [
        TaskAttachmentsState(
          status: TaskAttachmentsStatus.failure,
          loadFailure: AttachmentFailureReason.network,
        ),
      ],
    );

    blocTest<TaskAttachmentsBloc, TaskAttachmentsState>(
      'an unexpected error is an unknown failure',
      setUp: () =>
          when(() => repository.getAll('t1')).thenThrow(StateError('boom')),
      build: build,
      act: (bloc) => bloc.add(const TaskAttachmentsRequested()),
      expect: () => const [
        TaskAttachmentsState(
          status: TaskAttachmentsStatus.failure,
          loadFailure: AttachmentFailureReason.unknown,
        ),
      ],
    );

    blocTest<TaskAttachmentsBloc, TaskAttachmentsState>(
      'retrying after a failure loads again',
      setUp: () =>
          when(() => repository.getAll('t1')).thenAnswer((_) async => [a]),
      build: build,
      seed: () => const TaskAttachmentsState(
        status: TaskAttachmentsStatus.failure,
        loadFailure: AttachmentFailureReason.network,
      ),
      act: (bloc) => bloc.add(const TaskAttachmentsRequested()),
      expect: () => [
        loading,
        loaded([a]),
      ],
    );
  });

  group('attaching', () {
    blocTest<TaskAttachmentsBloc, TaskAttachmentsState>(
      'sends the chosen file and shows it once stored',
      setUp: () {
        files.nextPick = picked;
        when(() => repository.add('t1', picked)).thenAnswer((_) async => b);
      },
      build: build,
      seed: () => loaded([a]),
      act: (bloc) => bloc.add(const TaskAttachmentAddRequested()),
      expect: () => [
        loaded([a], isUploading: true),
        loaded([a, b]),
      ],
    );

    blocTest<TaskAttachmentsBloc, TaskAttachmentsState>(
      'giving up choosing changes nothing',
      build: build,
      seed: () => loaded([a]),
      act: (bloc) => bloc.add(const TaskAttachmentAddRequested()),
      expect: () => const <TaskAttachmentsState>[],
      verify: (_) => verifyNever(() => repository.add(any(), any())),
    );

    blocTest<TaskAttachmentsBloc, TaskAttachmentsState>(
      'a file over the limit is refused without sending',
      setUp: () => files.nextPick = AttachmentFile(
        name: 'video.mp4',
        size: AddTaskAttachment.maxBytes + 1,
        openRead: () => const Stream.empty(),
      ),
      build: build,
      seed: () => loaded([a]),
      act: (bloc) => bloc.add(const TaskAttachmentAddRequested()),
      expect: () => [
        loaded([a], isUploading: true),
        loaded([a], failure: AttachmentFailureReason.tooLarge),
      ],
      verify: (_) => verifyNever(() => repository.add(any(), any())),
    );

    blocTest<TaskAttachmentsBloc, TaskAttachmentsState>(
      'a failed upload says why and adds nothing',
      setUp: () {
        files.nextPick = picked;
        when(() => repository.add('t1', picked)).thenThrow(network);
      },
      build: build,
      seed: () => loaded([a]),
      act: (bloc) => bloc.add(const TaskAttachmentAddRequested()),
      expect: () => [
        loaded([a], isUploading: true),
        loaded([a], failure: AttachmentFailureReason.network),
      ],
    );

    blocTest<TaskAttachmentsBloc, TaskAttachmentsState>(
      'a failing file dialog says so',
      setUp: () => files.failNext = const AttachmentFailure(
        AttachmentFailureReason.unknown,
      ),
      build: build,
      seed: () => loaded([a]),
      act: (bloc) => bloc.add(const TaskAttachmentAddRequested()),
      expect: () => [
        loaded([a], failure: AttachmentFailureReason.unknown),
      ],
    );

    blocTest<TaskAttachmentsBloc, TaskAttachmentsState>(
      'the next attempt clears the previous failure',
      setUp: () {
        files.nextPick = picked;
        when(() => repository.add('t1', picked)).thenAnswer((_) async => b);
      },
      build: build,
      seed: () => loaded([a], failure: AttachmentFailureReason.network),
      act: (bloc) => bloc.add(const TaskAttachmentAddRequested()),
      expect: () => [
        loaded([a]),
        loaded([a], isUploading: true),
        loaded([a, b]),
      ],
    );

    late Completer<TaskAttachment> upload;
    blocTest<TaskAttachmentsBloc, TaskAttachmentsState>(
      'asking again while a file is being sent opens no second dialog',
      setUp: () {
        upload = Completer();
        files.nextPick = picked;
        when(() => repository.add('t1', picked))
            .thenAnswer((_) => upload.future);
      },
      build: build,
      seed: () => loaded([a]),
      act: (bloc) async {
        bloc.add(const TaskAttachmentAddRequested());
        await pumpEventQueue();
        bloc.add(const TaskAttachmentAddRequested());
        await pumpEventQueue();
        upload.complete(b);
      },
      expect: () => [
        loaded([a], isUploading: true),
        loaded([a, b]),
      ],
      verify: (_) => expect(files.picks, 1),
    );

    blocTest<TaskAttachmentsBloc, TaskAttachmentsState>(
      'nothing can be attached before the list loads',
      setUp: () => files.nextPick = picked,
      build: build,
      act: (bloc) => bloc.add(const TaskAttachmentAddRequested()),
      expect: () => const <TaskAttachmentsState>[],
      verify: (_) => expect(files.picks, 0),
    );
  });

  group('downloading', () {
    final bytes = Uint8List.fromList([9, 8, 7]);

    blocTest<TaskAttachmentsBloc, TaskAttachmentsState>(
      'saves the file under the name it was uploaded with',
      setUp: () =>
          when(() => repository.download('t1', a.id))
              .thenAnswer((_) async => bytes),
      build: build,
      seed: () => loaded([a, b]),
      act: (bloc) => bloc.add(TaskAttachmentDownloadRequested(a)),
      expect: () => [
        loaded([a, b], busyIds: {a.id}),
        loaded([a, b]),
      ],
      verify: (_) => expect(files.saved, [
        (name: 'Arquivo a.pdf', contentType: 'application/pdf', bytes: bytes),
      ]),
    );

    blocTest<TaskAttachmentsBloc, TaskAttachmentsState>(
      'giving up saving is not a failure',
      setUp: () {
        files.acceptSave = false;
        when(() => repository.download('t1', a.id))
            .thenAnswer((_) async => bytes);
      },
      build: build,
      seed: () => loaded([a]),
      act: (bloc) => bloc.add(TaskAttachmentDownloadRequested(a)),
      expect: () => [
        loaded([a], busyIds: {a.id}),
        loaded([a]),
      ],
    );

    blocTest<TaskAttachmentsBloc, TaskAttachmentsState>(
      'a failed download says why and keeps the attachment',
      setUp: () =>
          when(() => repository.download('t1', a.id)).thenThrow(network),
      build: build,
      seed: () => loaded([a]),
      act: (bloc) => bloc.add(TaskAttachmentDownloadRequested(a)),
      expect: () => [
        loaded([a], busyIds: {a.id}),
        loaded([a], failure: AttachmentFailureReason.network),
      ],
      verify: (_) => expect(files.saved, isEmpty),
    );

    blocTest<TaskAttachmentsBloc, TaskAttachmentsState>(
      'an attachment deleted elsewhere leaves the list',
      setUp: () => when(() => repository.download('t1', a.id)).thenThrow(gone),
      build: build,
      seed: () => loaded([a, b]),
      act: (bloc) => bloc.add(TaskAttachmentDownloadRequested(a)),
      expect: () => [
        loaded([a, b], busyIds: {a.id}),
        loaded([b], failure: AttachmentFailureReason.notFound),
      ],
    );

    blocTest<TaskAttachmentsBloc, TaskAttachmentsState>(
      'asking twice downloads once',
      setUp: () =>
          when(() => repository.download('t1', a.id))
              .thenAnswer((_) async => bytes),
      build: build,
      seed: () => loaded([a]),
      act: (bloc) => bloc
        ..add(TaskAttachmentDownloadRequested(a))
        ..add(TaskAttachmentDownloadRequested(a)),
      verify: (_) => verify(() => repository.download('t1', a.id)).called(1),
    );
  });

  group('deleting', () {
    blocTest<TaskAttachmentsBloc, TaskAttachmentsState>(
      'removes the attachment once the server deleted it',
      setUp: () =>
          when(() => repository.delete('t1', a.id)).thenAnswer((_) async {}),
      build: build,
      seed: () => loaded([a, b]),
      act: (bloc) => bloc.add(TaskAttachmentDeleted(a)),
      expect: () => [
        loaded([a, b], busyIds: {a.id}),
        loaded([b]),
      ],
    );

    blocTest<TaskAttachmentsBloc, TaskAttachmentsState>(
      'a failed deletion says why and keeps the attachment',
      setUp: () => when(() => repository.delete('t1', a.id)).thenThrow(network),
      build: build,
      seed: () => loaded([a, b]),
      act: (bloc) => bloc.add(TaskAttachmentDeleted(a)),
      expect: () => [
        loaded([a, b], busyIds: {a.id}),
        loaded([a, b], failure: AttachmentFailureReason.network),
      ],
    );

    blocTest<TaskAttachmentsBloc, TaskAttachmentsState>(
      'one already gone on the server just leaves the list',
      setUp: () => when(() => repository.delete('t1', a.id)).thenThrow(gone),
      build: build,
      seed: () => loaded([a, b]),
      act: (bloc) => bloc.add(TaskAttachmentDeleted(a)),
      expect: () => [
        loaded([a, b], busyIds: {a.id}),
        loaded([b]),
      ],
    );

    blocTest<TaskAttachmentsBloc, TaskAttachmentsState>(
      'two attachments can be deleted at the same time',
      setUp: () =>
          when(() => repository.delete('t1', any())).thenAnswer((_) async {}),
      build: build,
      seed: () => loaded([a, b]),
      act: (bloc) => bloc
        ..add(TaskAttachmentDeleted(a))
        ..add(TaskAttachmentDeleted(b)),
      skip: 2,
      expect: () => [
        loaded([b], busyIds: {b.id}),
        loaded([]),
      ],
    );
  });

  test('closing while a file is being sent does not fail', () async {
    final upload = Completer<TaskAttachment>();
    files.nextPick = picked;
    when(() => repository.add('t1', picked)).thenAnswer((_) => upload.future);
    final bloc = build()..emit(loaded([a]));

    bloc.add(const TaskAttachmentAddRequested());
    await pumpEventQueue();
    final closing = bloc.close();
    upload.complete(b);

    await expectLater(closing, completes);
  });
}
