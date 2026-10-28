import 'package:flutter_test/flutter_test.dart';
import 'package:todo/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:todo/features/auth/domain/repositories/auth_repository.dart';

import '../../../../helpers/contracts/auth_repository_contract.dart';
import '../../../../helpers/fake_auth_remote_data_source.dart';

final class _FakeHarness implements AuthContractHarness {
  final _backend = FakeAuthBackend();

  @override
  Future<AuthRepository> open() async =>
      AuthRepositoryImpl(FakeAuthRemoteDataSource(_backend));

  @override
  Future<AuthRepository> reopen() => open();

  @override
  Future<void> revokeSavedSession() async => _backend.revokeSavedSession = true;
}

void main() {
  group('AuthRepositoryImpl over the in-memory data source', () {
    authRepositoryContract(_FakeHarness.new);
  });
}
