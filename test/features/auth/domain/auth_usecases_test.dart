import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:todo/core/error/failure.dart';
import 'package:todo/features/auth/domain/entities/app_user.dart';
import 'package:todo/features/auth/domain/entities/credentials.dart';
import 'package:todo/features/auth/domain/repositories/auth_repository.dart';
import 'package:todo/features/auth/domain/usecases/restore_session.dart';
import 'package:todo/features/auth/domain/usecases/sign_in.dart';
import 'package:todo/features/auth/domain/usecases/sign_out.dart';
import 'package:todo/features/auth/domain/usecases/sign_up.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  const user = AppUser(id: 'uid', email: 'ana@example.com');
  late _MockAuthRepository repository;

  setUp(() {
    repository = _MockAuthRepository();
    when(
      () => repository.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => user);
    when(
      () => repository.signUp(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => user);
  });

  group('Credentials', () {
    test('accepts well-formed emails', () {
      for (final email in ['ana@example.com', 'a.b+c@d.com.br']) {
        expect(Credentials.isValidEmail(email), isTrue, reason: email);
      }
    });

    test('rejects malformed emails', () {
      for (final email in ['', 'ana', 'ana@', 'ana@example', 'a b@c.com']) {
        expect(Credentials.isValidEmail(email), isFalse, reason: email);
      }
    });

    test('toString does not expose the password', () {
      expect(
        const Credentials(email: 'a@b.com', password: 'secret').toString(),
        isNot(contains('secret')),
      );
    });
  });

  for (final (name, run) in [
    ('SignIn', (Credentials c) => SignIn(repository)(c)),
    ('SignUp', (Credentials c) => SignUp(repository)(c)),
  ]) {
    group(name, () {
      test('trims the email and forwards the password untouched', () async {
        expect(
          await run(
            const Credentials(email: '  ana@example.com ', password: ' pw '),
          ),
          user,
        );
      });

      test('rejects an empty email', () {
        expect(
          run(const Credentials(email: '', password: 'pw')),
          throwsA(const AuthFailure(AuthFailureReason.invalidEmail)),
        );
      });

      test('rejects a malformed email', () {
        expect(
          run(const Credentials(email: 'ana@', password: 'pw')),
          throwsA(const AuthFailure(AuthFailureReason.invalidEmail)),
        );
      });

      test('rejects an empty password', () {
        expect(
          run(const Credentials(email: 'ana@example.com', password: '')),
          throwsA(const AuthFailure(AuthFailureReason.missingPassword)),
        );
      });
    });
  }

  test('SignIn sends trimmed email to the repository', () async {
    await SignIn(repository)(
      const Credentials(email: ' ana@example.com ', password: ' pw '),
    );

    verify(() => repository.signIn(email: 'ana@example.com', password: ' pw '))
        .called(1);
  });

  test('SignUp propagates provider failures', () {
    when(
      () => repository.signUp(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer(
      (_) async => throw const AuthFailure(AuthFailureReason.emailAlreadyInUse),
    );

    expect(
      SignUp(repository)(
        const Credentials(email: 'ana@example.com', password: 'pw1234'),
      ),
      throwsA(const AuthFailure(AuthFailureReason.emailAlreadyInUse)),
    );
  });

  test('SignOut delegates to the repository', () async {
    when(() => repository.signOut()).thenAnswer((_) async {});

    await SignOut(repository)();

    verify(() => repository.signOut()).called(1);
  });

  test('RestoreSession returns the saved user or null', () async {
    when(() => repository.restoreSession()).thenAnswer((_) async => user);
    expect(await RestoreSession(repository)(), user);

    when(() => repository.restoreSession()).thenAnswer((_) async => null);
    expect(await RestoreSession(repository)(), isNull);
  });
}
