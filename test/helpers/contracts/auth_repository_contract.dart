import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/error/failure.dart';
import 'package:todo/features/auth/domain/repositories/auth_repository.dart';

/// Builds repositories over one backend. [reopen] simulates closing and
/// reopening the app: a fresh repository over the same backend and the same
/// device storage.
abstract interface class AuthContractHarness {
  Future<AuthRepository> open();

  Future<AuthRepository> reopen();

  /// Makes the provider reject the session saved on the device.
  Future<void> revokeSavedSession();
}

/// Behavior every [AuthRepository] must share, whatever its backend.
void authRepositoryContract(AuthContractHarness Function() createHarness) {
  const email = 'ana@example.com';
  const password = 'segredo123';
  late AuthContractHarness harness;
  late AuthRepository repository;

  setUp(() async {
    harness = createHarness();
    repository = await harness.open();
  });

  test('nobody is signed in initially', () async {
    expect(repository.currentUser, isNull);
    expect(await repository.restoreSession(), isNull);
  });

  test('sign up signs the new user in', () async {
    final user = await repository.signUp(email: email, password: password);

    expect(user.email, email);
    expect(user.id, isNotEmpty);
    expect(repository.currentUser, user);
  });

  test('sign up with an email in use fails', () async {
    await repository.signUp(email: email, password: password);

    await expectLater(
      repository.signUp(email: email, password: password),
      throwsA(const AuthFailure(AuthFailureReason.emailAlreadyInUse)),
    );
  });

  test('sign up with a weak password fails', () async {
    await expectLater(
      repository.signUp(email: email, password: '12345'),
      throwsA(const AuthFailure(AuthFailureReason.weakPassword)),
    );
  });

  test('sign in with the right password returns the same user', () async {
    final created = await repository.signUp(email: email, password: password);
    await repository.signOut();

    expect(await repository.signIn(email: email, password: password), created);
  });

  test('wrong password and unknown email fail the same way', () async {
    await repository.signUp(email: email, password: password);
    await repository.signOut();

    await expectLater(
      repository.signIn(email: email, password: 'errada'),
      throwsA(const AuthFailure(AuthFailureReason.invalidCredentials)),
    );
    await expectLater(
      repository.signIn(email: 'ninguem@example.com', password: password),
      throwsA(const AuthFailure(AuthFailureReason.invalidCredentials)),
    );
  });

  test('the session survives reopening the app', () async {
    final user = await repository.signUp(email: email, password: password);

    final reopened = await harness.reopen();

    expect(await reopened.restoreSession(), user);
    expect(reopened.currentUser, user);
  });

  test('sign out ends the session, also after reopening', () async {
    await repository.signUp(email: email, password: password);

    await repository.signOut();
    expect(repository.currentUser, isNull);

    final reopened = await harness.reopen();
    expect(await reopened.restoreSession(), isNull);
  });

  test('a revoked session is discarded on restore', () async {
    await repository.signUp(email: email, password: password);
    await harness.revokeSavedSession();

    final reopened = await harness.reopen();

    expect(await reopened.restoreSession(), isNull);
    expect(reopened.currentUser, isNull);
  });
}
