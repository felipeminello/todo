import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:todo/core/error/failure.dart';
import 'package:todo/features/auth/domain/entities/app_user.dart';
import 'package:todo/features/auth/domain/repositories/auth_repository.dart';
import 'package:todo/features/auth/domain/usecases/restore_session.dart';
import 'package:todo/features/auth/domain/usecases/sign_in.dart';
import 'package:todo/features/auth/domain/usecases/sign_out.dart';
import 'package:todo/features/auth/domain/usecases/sign_up.dart';
import 'package:todo/features/auth/presentation/bloc/auth_bloc.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  const user = AppUser(id: 'u1', email: 'ana@example.com');
  late _MockAuthRepository repository;

  AuthBloc build() => AuthBloc(
    restoreSession: RestoreSession(repository),
    signIn: SignIn(repository),
    signUp: SignUp(repository),
    signOut: SignOut(repository),
  );

  void signInAnswers(Future<AppUser> Function() answer) => when(
    () => repository.signIn(
      email: any(named: 'email'),
      password: any(named: 'password'),
    ),
  ).thenAnswer((_) => answer());

  setUp(() {
    repository = _MockAuthRepository();
    when(() => repository.signOut()).thenAnswer((_) async {});
  });

  test('starts unknown, before the session is checked', () {
    expect(build().state, const AuthState());
  });

  group('session', () {
    blocTest<AuthBloc, AuthState>(
      'saved session opens authenticated',
      setUp: () =>
          when(() => repository.restoreSession()).thenAnswer((_) async => user),
      build: build,
      act: (bloc) => bloc.add(const AuthSessionRequested()),
      expect: () => [
        const AuthState(status: AuthStatus.authenticated, user: user),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'no saved session opens unauthenticated',
      setUp: () =>
          when(() => repository.restoreSession()).thenAnswer((_) async => null),
      build: build,
      act: (bloc) => bloc.add(const AuthSessionRequested()),
      expect: () => [const AuthState(status: AuthStatus.unauthenticated)],
    );

    blocTest<AuthBloc, AuthState>(
      'offline with a saved session still opens authenticated',
      // The data source keeps the session when renewal fails for network.
      setUp: () =>
          when(() => repository.restoreSession()).thenAnswer((_) async => user),
      build: build,
      act: (bloc) => bloc.add(const AuthSessionRequested()),
      expect: () => [
        const AuthState(status: AuthStatus.authenticated, user: user),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'a failure while restoring opens unauthenticated',
      setUp: () => when(() => repository.restoreSession()).thenAnswer(
        (_) async => throw const AuthFailure(AuthFailureReason.unknown),
      ),
      build: build,
      act: (bloc) => bloc.add(const AuthSessionRequested()),
      expect: () => [const AuthState(status: AuthStatus.unauthenticated)],
    );
  });

  group('sign in', () {
    blocTest<AuthBloc, AuthState>(
      'valid credentials authenticate',
      setUp: () => signInAnswers(() async => user),
      build: build,
      act: (bloc) => bloc.add(
        const AuthSignInRequested(email: 'ana@example.com', password: 'pw'),
      ),
      expect: () => [
        const AuthState(status: AuthStatus.unauthenticated, isSubmitting: true),
        const AuthState(status: AuthStatus.authenticated, user: user),
      ],
    );

    for (final reason in [
      AuthFailureReason.invalidCredentials,
      AuthFailureReason.network,
    ]) {
      blocTest<AuthBloc, AuthState>(
        '$reason is reported',
        setUp: () => signInAnswers(() async => throw AuthFailure(reason)),
        build: build,
        act: (bloc) => bloc.add(
          const AuthSignInRequested(email: 'ana@example.com', password: 'pw'),
        ),
        expect: () => [
          const AuthState(
            status: AuthStatus.unauthenticated,
            isSubmitting: true,
          ),
          AuthState(status: AuthStatus.unauthenticated, failure: reason),
        ],
      );
    }

    blocTest<AuthBloc, AuthState>(
      'unexpected errors become unknown failures',
      setUp: () => signInAnswers(() async => throw StateError('boom')),
      build: build,
      act: (bloc) => bloc.add(
        const AuthSignInRequested(email: 'ana@example.com', password: 'pw'),
      ),
      expect: () => [
        const AuthState(status: AuthStatus.unauthenticated, isSubmitting: true),
        const AuthState(
          status: AuthStatus.unauthenticated,
          failure: AuthFailureReason.unknown,
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'a malformed email fails without calling the provider',
      build: build,
      act: (bloc) =>
          bloc.add(const AuthSignInRequested(email: 'ana@', password: 'pw')),
      expect: () => [
        const AuthState(status: AuthStatus.unauthenticated, isSubmitting: true),
        const AuthState(
          status: AuthStatus.unauthenticated,
          failure: AuthFailureReason.invalidEmail,
        ),
      ],
      verify: (_) => verifyNever(
        () => repository.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ),
    );
  });

  group('sign up', () {
    blocTest<AuthBloc, AuthState>(
      'creates the account and authenticates',
      setUp: () => when(
        () => repository.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => user),
      build: build,
      act: (bloc) => bloc.add(
        const AuthSignUpRequested(email: 'ana@example.com', password: '123456'),
      ),
      expect: () => [
        const AuthState(status: AuthStatus.unauthenticated, isSubmitting: true),
        const AuthState(status: AuthStatus.authenticated, user: user),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'email in use is reported',
      setUp: () =>
          when(
            () => repository.signUp(
              email: any(named: 'email'),
              password: any(named: 'password'),
            ),
          ).thenAnswer(
            (_) async =>
                throw const AuthFailure(AuthFailureReason.emailAlreadyInUse),
          ),
      build: build,
      act: (bloc) => bloc.add(
        const AuthSignUpRequested(email: 'ana@example.com', password: '123456'),
      ),
      expect: () => [
        const AuthState(status: AuthStatus.unauthenticated, isSubmitting: true),
        const AuthState(
          status: AuthStatus.unauthenticated,
          failure: AuthFailureReason.emailAlreadyInUse,
        ),
      ],
    );
  });

  group('sign out', () {
    blocTest<AuthBloc, AuthState>(
      'returns to unauthenticated',
      build: build,
      seed: () => const AuthState(status: AuthStatus.authenticated, user: user),
      act: (bloc) => bloc.add(const AuthSignOutRequested()),
      expect: () => [const AuthState(status: AuthStatus.unauthenticated)],
      verify: (_) => verify(() => repository.signOut()).called(1),
    );

    blocTest<AuthBloc, AuthState>(
      'leaves the account even if signing out fails',
      setUp: () => when(() => repository.signOut()).thenAnswer(
        (_) async => throw const AuthFailure(AuthFailureReason.unknown),
      ),
      build: build,
      seed: () => const AuthState(status: AuthStatus.authenticated, user: user),
      act: (bloc) => bloc.add(const AuthSignOutRequested()),
      expect: () => [const AuthState(status: AuthStatus.unauthenticated)],
    );
  });
}
