import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:todo/core/error/exceptions.dart';
import 'package:todo/core/error/failure.dart';
import 'package:todo/features/tasks/data/datasources/task_remote_data_source.dart';
import 'package:todo/features/tasks/data/models/task_model.dart';
import 'package:todo/features/tasks/data/repositories/task_repository_impl.dart';
import 'package:todo/features/tasks/domain/entities/new_task.dart';

import '../../../../helpers/task_factory.dart';

class _MockTaskRemoteDataSource extends Mock implements TaskRemoteDataSource {}

void main() {
  late _MockTaskRemoteDataSource dataSource;
  late TaskRepositoryImpl repository;

  setUpAll(() => registerFallbackValue(TaskModel.fromEntity(buildTask('f'))));

  setUp(() {
    dataSource = _MockTaskRemoteDataSource();
    repository = TaskRepositoryImpl(dataSource);
  });

  const mapping = {
    RemoteErrorKind.network: TaskFailureReason.network,
    RemoteErrorKind.unauthenticated: TaskFailureReason.permissionDenied,
    RemoteErrorKind.permissionDenied: TaskFailureReason.permissionDenied,
    RemoteErrorKind.notFound: TaskFailureReason.notFound,
    RemoteErrorKind.unknown: TaskFailureReason.unknown,
  };

  for (final MapEntry(key: kind, value: reason) in mapping.entries) {
    test('maps $kind to $reason on every operation', () async {
      Future<Never> fail(_) async => throw RemoteException(kind);
      when(() => dataSource.getAll()).thenAnswer(fail);
      when(() => dataSource.create(any())).thenAnswer(fail);
      when(() => dataSource.update(any())).thenAnswer(fail);
      when(() => dataSource.delete(any())).thenAnswer(fail);
      final failure = throwsA(TaskFailure(reason));

      await expectLater(repository.getAll(), failure);
      await expectLater(
        repository.add(NewTask(title: 't', createdAt: baseInstant)),
        failure,
      );
      await expectLater(repository.update(buildTask('1')), failure);
      await expectLater(repository.delete('1'), failure);
    });
  }

  test('maps malformed stored data to unknown', () async {
    when(() => dataSource.getAll()).thenAnswer(
      (_) async => [
        TaskModel(
          id: '1',
          title: 't',
          description: '',
          dueDate: 'bad',
          createdAt: baseInstant,
          completedAt: null,
        ),
      ],
    );

    await expectLater(
      repository.getAll(),
      throwsA(const TaskFailure(TaskFailureReason.unknown)),
    );
  });

  test('converts models to entities', () async {
    final task = buildTask('1', completedMinute: 3);
    when(() => dataSource.getAll())
        .thenAnswer((_) async => [TaskModel.fromEntity(task)]);

    expect(await repository.getAll(), [task]);
  });
}
