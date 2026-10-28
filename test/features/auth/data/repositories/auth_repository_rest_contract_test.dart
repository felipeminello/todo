import 'package:flutter_test/flutter_test.dart';
import 'package:todo/features/auth/data/datasources/rest_auth_data_source.dart';
import 'package:todo/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:todo/features/auth/domain/repositories/auth_repository.dart';

import '../../../../helpers/contracts/auth_repository_contract.dart';
import '../../../../helpers/fake_firebase_rest_backend.dart';
import '../../../../helpers/fixed_clock.dart';
import '../../../../helpers/in_memory_secure_token_store.dart';

final class _RestHarness implements AuthContractHarness {
  final _clock = FixedClock(DateTime.utc(2026, 10, 27, 12));
  late final _backend = FakeFirebaseRestBackend(clock: _clock);
  final _deviceStore = InMemorySecureTokenStore();

  @override
  Future<AuthRepository> open() async => AuthRepositoryImpl(
    RestAuthDataSource(
      client: _backend.client,
      apiKey: _backend.apiKey,
      store: _deviceStore,
      clock: _clock,
    ),
  );

  @override
  Future<AuthRepository> reopen() => open();

  @override
  Future<void> revokeSavedSession() async => _backend.revokeRefreshTokens();
}

void main() {
  group('AuthRepositoryImpl over the REST data source', () {
    authRepositoryContract(_RestHarness.new);
  });
}
