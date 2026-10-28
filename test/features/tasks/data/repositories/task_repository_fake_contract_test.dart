import 'package:flutter_test/flutter_test.dart';
import 'package:todo/features/tasks/data/repositories/task_repository_impl.dart';

import '../../../../helpers/contracts/task_repository_contract.dart';
import '../../../../helpers/fake_task_remote_data_source.dart';

void main() {
  group('TaskRepositoryImpl over the in-memory data source', () {
    taskRepositoryContract(
      () async => TaskRepositoryImpl(FakeTaskRemoteDataSource()),
    );
  });
}
