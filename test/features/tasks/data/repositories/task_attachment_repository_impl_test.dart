import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/error/exceptions.dart';
import 'package:todo/core/error/failure.dart';
import 'package:todo/features/tasks/data/repositories/task_attachment_repository_impl.dart';

import '../../../../helpers/fake_attachment_files.dart';
import '../../../../helpers/fake_task_attachment_remote_data_source.dart';

final class _MalformedAnswers extends FakeTaskAttachmentRemoteDataSource {
  @override
  Future<Never> getAll(String taskId) async =>
      throw const FormatException('malformed');
}

void main() {
  late FakeTaskAttachmentRemoteDataSource dataSource;
  late TaskAttachmentRepositoryImpl repository;

  setUp(() {
    dataSource = FakeTaskAttachmentRemoteDataSource();
    repository = TaskAttachmentRepositoryImpl(dataSource);
  });

  test('a stored file comes back as an attachment of that task only', () async {
    final added = await repository.add(
      't1',
      attachmentFile('Contrato.PDF', [1, 2, 3]),
    );

    expect(added.name, 'Contrato.PDF');
    expect(added.size, 3);
    expect(await repository.getAll('t1'), [added]);
    expect(await repository.getAll('t2'), isEmpty);
  });

  test('the stored name is not the name of the uploaded file', () async {
    final added = await repository.add(
      't1',
      attachmentFile('Contrato.PDF', [1, 2, 3]),
    );

    expect(dataSource.storedNames('t1'), [added.id]);
    expect(added.id, isNot('Contrato.PDF'));
    expect(added.id, endsWith('.pdf'));
  });

  test('downloads the content that was stored', () async {
    final added = await repository.add('t1', attachmentFile('a.txt', [7, 8]));

    expect(await repository.download('t1', added.id), [7, 8]);
  });

  test('deleting removes only that attachment', () async {
    final first = await repository.add('t1', attachmentFile('a.txt', [1]));
    final second = await repository.add('t1', attachmentFile('b.txt', [2]));

    await repository.delete('t1', first.id);

    expect(await repository.getAll('t1'), [second]);
  });

  test('deleting all empties the folder of that task only', () async {
    await repository.add('t1', attachmentFile('a.txt', [1]));
    final other = await repository.add('t2', attachmentFile('b.txt', [2]));

    await repository.deleteAll('t1');

    expect(await repository.getAll('t1'), isEmpty);
    expect(await repository.getAll('t2'), [other]);
  });

  const mapping = {
    AttachmentErrorKind.network: AttachmentFailureReason.network,
    AttachmentErrorKind.unauthenticated:
        AttachmentFailureReason.permissionDenied,
    AttachmentErrorKind.permissionDenied:
        AttachmentFailureReason.permissionDenied,
    AttachmentErrorKind.notFound: AttachmentFailureReason.notFound,
    AttachmentErrorKind.tooLarge: AttachmentFailureReason.tooLarge,
    AttachmentErrorKind.limitReached: AttachmentFailureReason.limitReached,
    AttachmentErrorKind.unknown: AttachmentFailureReason.unknown,
  };

  test('every remote error kind is mapped', () {
    expect(mapping.keys, AttachmentErrorKind.values);
  });

  for (final MapEntry(key: kind, value: reason) in mapping.entries) {
    test('maps $kind to $reason on every operation', () async {
      final failure = throwsA(AttachmentFailure(reason));
      final operations = <Future<Object?> Function()>[
        () => repository.getAll('t1'),
        () => repository.add('t1', attachmentFile('a.txt', [1])),
        () => repository.download('t1', 'x'),
        () => repository.delete('t1', 'x'),
        () => repository.deleteAll('t1'),
      ];

      for (final operation in operations) {
        dataSource.failNext = AttachmentRemoteException(kind);
        await expectLater(operation(), failure);
      }
    });
  }

  test('a malformed answer becomes an unknown failure', () {
    expect(
      TaskAttachmentRepositoryImpl(_MalformedAnswers()).getAll('t1'),
      throwsA(const AttachmentFailure(AttachmentFailureReason.unknown)),
    );
  });
}
