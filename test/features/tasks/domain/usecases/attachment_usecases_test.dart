import 'dart:typed_data';

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

import '../../../../helpers/fake_attachment_files.dart';

class _MockRepository extends Mock implements TaskAttachmentRepository {}

void main() {
  late _MockRepository repository;
  late FakeAttachmentFiles files;
  final attachment = TaskAttachment(
    id: 'a1b2.pdf',
    name: 'Contrato.pdf',
    size: 3,
    contentType: 'application/pdf',
    createdAt: DateTime.utc(2026, 11, 12),
  );

  AttachmentFile fileOf(int size) => AttachmentFile(
    name: 'Contrato.pdf',
    size: size,
    openRead: () => const Stream.empty(),
  );

  setUpAll(() => registerFallbackValue(fileOf(1)));

  setUp(() {
    repository = _MockRepository();
    files = FakeAttachmentFiles();
  });

  test('GetTaskAttachments returns the attachments of the task', () async {
    when(() => repository.getAll('t1')).thenAnswer((_) async => [attachment]);

    expect(await GetTaskAttachments(repository)('t1'), [attachment]);
  });

  group('PickAttachmentFile', () {
    test('returns the file the user chose', () async {
      final chosen = fileOf(3);
      files.nextPick = chosen;

      expect(await PickAttachmentFile(files)(), same(chosen));
    });

    test('returns nothing when the user gives up', () async {
      expect(await PickAttachmentFile(files)(), isNull);
    });
  });

  group('AddTaskAttachment', () {
    AddTaskAttachment useCase() => AddTaskAttachment(repository);

    test('stores the file in the task', () async {
      final file = fileOf(3);
      when(() => repository.add('t1', file))
          .thenAnswer((_) async => attachment);

      final added = await useCase()(
        AddTaskAttachmentParams(taskId: 't1', file: file),
      );

      expect(added, attachment);
    });

    test('accepts a file of exactly the limit', () async {
      final file = fileOf(AddTaskAttachment.maxBytes);
      when(() => repository.add('t1', file))
          .thenAnswer((_) async => attachment);

      await useCase()(AddTaskAttachmentParams(taskId: 't1', file: file));

      verify(() => repository.add('t1', file)).called(1);
    });

    test('the limit is 25 MB', () {
      expect(AddTaskAttachment.maxBytes, 25 * 1024 * 1024);
    });

    test('refuses a file over the limit without sending it', () {
      expect(
        () => useCase()(
          AddTaskAttachmentParams(
            taskId: 't1',
            file: fileOf(AddTaskAttachment.maxBytes + 1),
          ),
        ),
        throwsA(const AttachmentFailure(AttachmentFailureReason.tooLarge)),
      );
      verifyNever(() => repository.add(any(), any()));
    });

    test('refuses an empty file without sending it', () {
      expect(
        () => useCase()(AddTaskAttachmentParams(taskId: 't1', file: fileOf(0))),
        throwsA(const AttachmentFailure(AttachmentFailureReason.emptyFile)),
      );
      verifyNever(() => repository.add(any(), any()));
    });
  });

  group('DownloadTaskAttachment', () {
    final bytes = Uint8List.fromList([1, 2, 3]);
    DownloadTaskAttachment useCase() =>
        DownloadTaskAttachment(repository, files);
    final params = DownloadTaskAttachmentParams(
      taskId: 't1',
      attachment: attachment,
    );

    setUp(
      () =>
          when(() => repository.download('t1', 'a1b2.pdf'))
              .thenAnswer((_) async => bytes),
    );

    test('saves the content under the name it was uploaded with', () async {
      expect(await useCase()(params), isTrue);

      expect(files.saved, [
        (name: 'Contrato.pdf', contentType: 'application/pdf', bytes: bytes),
      ]);
    });

    test('reports when the user gives up saving', () async {
      files.acceptSave = false;

      expect(await useCase()(params), isFalse);
      expect(files.saved, isEmpty);
    });

    test('a failed download never opens the save dialog', () async {
      when(() => repository.download('t1', 'a1b2.pdf'))
          .thenThrow(const AttachmentFailure(AttachmentFailureReason.network));
      files.failNext = const AttachmentFailure(AttachmentFailureReason.unknown);

      await expectLater(
        useCase()(params),
        throwsA(const AttachmentFailure(AttachmentFailureReason.network)),
      );
    });
  });

  test('DeleteTaskAttachment deletes by task and attachment id', () async {
    when(() => repository.delete('t1', 'a1b2.pdf')).thenAnswer((_) async {});

    await DeleteTaskAttachment(repository)(
      const DeleteTaskAttachmentParams(taskId: 't1', attachmentId: 'a1b2.pdf'),
    );

    verify(() => repository.delete('t1', 'a1b2.pdf')).called(1);
  });
}
