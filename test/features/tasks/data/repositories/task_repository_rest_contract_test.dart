import 'package:flutter_test/flutter_test.dart';
import 'package:todo/features/auth/data/datasources/rest_auth_data_source.dart';
import 'package:todo/features/auth/data/repositories/auth_current_user_id_provider.dart';
import 'package:todo/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:todo/features/tasks/data/datasources/rest_firestore_task_data_source.dart';
import 'package:todo/features/tasks/data/repositories/task_repository_impl.dart';
import 'package:todo/features/tasks/domain/repositories/task_repository.dart';

import '../../../../helpers/contracts/task_repository_contract.dart';
import '../../../../helpers/fake_firebase_rest_backend.dart';
import '../../../../helpers/fixed_clock.dart';
import '../../../../helpers/in_memory_secure_token_store.dart';

Future<TaskRepository> _signedInRestRepository() async {
  final clock = FixedClock(DateTime.utc(2026, 10, 27, 12));
  final backend = FakeFirebaseRestBackend(clock: clock);
  final auth = RestAuthDataSource(
    client: backend.client,
    apiKey: backend.apiKey,
    store: InMemorySecureTokenStore(),
    clock: clock,
  );
  final authRepository = AuthRepositoryImpl(auth);
  await authRepository.signUp(email: 'ana@example.com', password: 'segredo1');
  return TaskRepositoryImpl(
    RestFirestoreTaskDataSource(
      client: backend.client,
      projectId: backend.projectId,
      tokens: auth,
      users: AuthCurrentUserIdProvider(authRepository),
    ),
  );
}

void main() {
  group('TaskRepositoryImpl over the REST data source', () {
    taskRepositoryContract(_signedInRestRepository);
  });
}
