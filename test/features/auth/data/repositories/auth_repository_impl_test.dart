import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:todo/core/error/exceptions.dart';
import 'package:todo/core/error/failure.dart';
import 'package:todo/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:todo/features/auth/data/models/user_model.dart';
import 'package:todo/features/auth/data/repositories/auth_current_user_id_provider.dart';
import 'package:todo/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:todo/features/auth/domain/entities/app_user.dart';

class _MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}

void main() {
  late _MockAuthRemoteDataSource dataSource;
  late AuthRepositoryImpl repository;

  setUp(() {
    dataSource = _MockAuthRemoteDataSource();
    repository = AuthRepositoryImpl(dataSource);
  });

  const mapping = {
    AuthErrorKind.invalidCredentials: AuthFailureReason.invalidCredentials,
    AuthErrorKind.emailAlreadyInUse: AuthFailureReason.emailAlreadyInUse,
    AuthErrorKind.weakPassword: AuthFailureReason.weakPassword,
    AuthErrorKind.invalidEmail: AuthFailureReason.invalidEmail,
    AuthErrorKind.network: AuthFailureReason.network,
    AuthErrorKind.sessionRevoked: AuthFailureReason.unknown,
    AuthErrorKind.unknown: AuthFailureReason.unknown,
  };

  for (final MapEntry(key: kind, value: reason) in mapping.entries) {
    test('maps $kind to $reason on sign in, sign up and sign out', () async {
      Future<Never> fail(_) async => throw AuthRemoteException(kind);
      when(
        () => dataSource.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer(fail);
      when(
        () => dataSource.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer(fail);
      when(() => dataSource.signOut()).thenAnswer(fail);
      final failure = throwsA(AuthFailure(reason));

      await expectLater(repository.signIn(email: 'a', password: 'b'), failure);
      await expectLater(repository.signUp(email: 'a', password: 'b'), failure);
      await expectLater(repository.signOut(), failure);
    });
  }

  test('restore treats a revoked session as signed out', () async {
    when(() => dataSource.restoreSession()).thenAnswer(
      (_) async =>
          throw const AuthRemoteException(AuthErrorKind.sessionRevoked),
    );

    expect(await repository.restoreSession(), isNull);
  });

  test('restore maps other failures', () async {
    when(() => dataSource.restoreSession()).thenAnswer(
      (_) async => throw const AuthRemoteException(AuthErrorKind.network),
    );

    await expectLater(
      repository.restoreSession(),
      throwsA(const AuthFailure(AuthFailureReason.network)),
    );
  });

  test('current user and its id come from the data source', () {
    when(() => dataSource.currentUser)
        .thenReturn(const UserModel(id: 'u1', email: 'a@b.com'));

    expect(repository.currentUser, const AppUser(id: 'u1', email: 'a@b.com'));
    expect(AuthCurrentUserIdProvider(repository).currentUserId, 'u1');

    when(() => dataSource.currentUser).thenReturn(null);
    expect(AuthCurrentUserIdProvider(repository).currentUserId, isNull);
  });
}
