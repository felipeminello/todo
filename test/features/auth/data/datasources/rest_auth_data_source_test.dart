import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:todo/core/error/exceptions.dart';
import 'package:todo/features/auth/data/datasources/rest_auth_data_source.dart';
import 'package:todo/features/auth/data/datasources/secure_token_store.dart';
import 'package:todo/features/auth/data/models/user_model.dart';

import '../../../../helpers/fake_firebase_rest_backend.dart';
import '../../../../helpers/fixed_clock.dart';
import '../../../../helpers/in_memory_secure_token_store.dart';

void main() {
  const email = 'ana@example.com';
  const password = 'segredo123';
  late FixedClock clock;
  late FakeFirebaseRestBackend backend;
  late InMemorySecureTokenStore store;

  RestAuthDataSource open({http.Client? client, Duration? timeout}) =>
      RestAuthDataSource(
        client: client ?? backend.client,
        apiKey: backend.apiKey,
        store: store,
        clock: clock,
        timeout: timeout ?? const Duration(seconds: 15),
      );

  int refreshCount() => backend.requestsTo('securetoken.googleapis.com').length;

  setUp(() {
    clock = FixedClock(DateTime.utc(2026, 10, 27, 12));
    backend = FakeFirebaseRestBackend(clock: clock);
    store = InMemorySecureTokenStore();
  });

  group('sign up and sign in', () {
    test('sign up returns the user and saves the session', () async {
      final user = await open().signUp(email: email, password: password);

      expect(user.email, email);
      expect(store.session?.uid, user.id);
      expect(store.session?.refreshToken, isNotEmpty);
      final request = backend.requests.single;
      expect(request.url.path, '/v1/accounts:signUp');
      expect(request.url.queryParameters['key'], backend.apiKey);
      expect(jsonDecode(request.body), containsPair('returnSecureToken', true));
    });

    test('sign in after sign up returns the same user', () async {
      final auth = open();
      final created = await auth.signUp(email: email, password: password);
      await auth.signOut();

      expect(await auth.signIn(email: email, password: password), created);
      expect(auth.currentUser, created);
    });

    test('sign out forgets the session on the device', () async {
      final auth = open();
      await auth.signUp(email: email, password: password);

      await auth.signOut();

      expect(auth.currentUser, isNull);
      expect(store.session, isNull);
    });
  });

  group('error mapping', () {
    const cases = {
      'EMAIL_EXISTS': AuthErrorKind.emailAlreadyInUse,
      'WEAK_PASSWORD : Password should be at least 6 characters':
          AuthErrorKind.weakPassword,
      'INVALID_EMAIL': AuthErrorKind.invalidEmail,
      'INVALID_LOGIN_CREDENTIALS': AuthErrorKind.invalidCredentials,
      'EMAIL_NOT_FOUND': AuthErrorKind.invalidCredentials,
      'INVALID_PASSWORD': AuthErrorKind.invalidCredentials,
      'USER_DISABLED': AuthErrorKind.invalidCredentials,
      'TOO_MANY_ATTEMPTS_TRY_LATER': AuthErrorKind.unknown,
    };

    for (final MapEntry(key: message, value: kind) in cases.entries) {
      test('$message -> $kind', () async {
        final client = MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': {'code': 400, 'message': message},
            }),
            400,
          ),
        );

        await expectLater(
          open(client: client).signIn(email: email, password: password),
          throwsA(
            isA<AuthRemoteException>().having((e) => e.kind, 'kind', kind),
          ),
        );
      });
    }

    test('server errors and garbage are unknown', () async {
      for (final response in [
        http.Response('{}', 500),
        http.Response('<html>', 502),
        http.Response('not json', 200),
      ]) {
        final client = MockClient((_) async => response);

        await expectLater(
          open(client: client).signIn(email: email, password: password),
          throwsA(
            isA<AuthRemoteException>().having(
              (e) => e.kind,
              'kind',
              AuthErrorKind.unknown,
            ),
          ),
        );
      }
    });

    test('no connection is a network error', () async {
      backend.offline = true;

      await expectLater(
        open().signIn(email: email, password: password),
        throwsA(
          isA<AuthRemoteException>().having(
            (e) => e.kind,
            'kind',
            AuthErrorKind.network,
          ),
        ),
      );
    });

    test('a request that never answers is a network error', () async {
      final client = MockClient((_) => Completer<http.Response>().future);

      await expectLater(
        open(
          client: client,
          timeout: const Duration(milliseconds: 10),
        ).signIn(email: email, password: password),
        throwsA(
          isA<AuthRemoteException>().having(
            (e) => e.kind,
            'kind',
            AuthErrorKind.network,
          ),
        ),
      );
    });
  });

  group('ID token', () {
    test('is reused while fresh', () async {
      final auth = open();
      await auth.signUp(email: email, password: password);

      final first = await auth.idToken();
      clock.advance(const Duration(minutes: 54));
      final second = await auth.idToken();

      expect(second, first);
      expect(refreshCount(), 0);
    });

    test('is renewed proactively within 5 minutes of expiry', () async {
      final auth = open();
      await auth.signUp(email: email, password: password);
      final first = await auth.idToken();

      clock.advance(const Duration(minutes: 56));
      final renewed = await auth.idToken();

      expect(renewed, isNot(first));
      expect(refreshCount(), 1);
    });

    test('is renewed on demand', () async {
      final auth = open();
      await auth.signUp(email: email, password: password);
      final first = await auth.idToken();

      expect(await auth.idToken(forceRefresh: true), isNot(first));
      expect(refreshCount(), 1);
    });

    test('concurrent renewals share one request', () async {
      final auth = open();
      await auth.signUp(email: email, password: password);

      final tokens = await Future.wait([
        auth.idToken(forceRefresh: true),
        auth.idToken(forceRefresh: true),
        auth.idToken(forceRefresh: true),
      ]);

      expect(tokens.toSet(), hasLength(1));
      expect(refreshCount(), 1);
    });

    test('without a session is unauthenticated', () async {
      await expectLater(
        open().idToken(),
        throwsA(
          isA<RemoteException>().having(
            (e) => e.kind,
            'kind',
            RemoteErrorKind.unauthenticated,
          ),
        ),
      );
    });

    test('a revoked refresh token ends the session', () async {
      final auth = open();
      await auth.signUp(email: email, password: password);
      backend.revokeRefreshTokens();

      await expectLater(
        auth.idToken(forceRefresh: true),
        throwsA(
          isA<RemoteException>().having(
            (e) => e.kind,
            'kind',
            RemoteErrorKind.unauthenticated,
          ),
        ),
      );
      expect(auth.currentUser, isNull);
      expect(store.session, isNull);
    });

    test(
      'renewal while offline is a network error and keeps the session',
      () async {
        final auth = open();
        await auth.signUp(email: email, password: password);
        backend.offline = true;

        await expectLater(
          auth.idToken(forceRefresh: true),
          throwsA(
            isA<RemoteException>().having(
              (e) => e.kind,
              'kind',
              RemoteErrorKind.network,
            ),
          ),
        );
        expect(auth.currentUser, isNotNull);
        expect(store.session, isNotNull);
      },
    );
  });

  group('restore session', () {
    test('returns null when nothing is saved', () async {
      expect(await open().restoreSession(), isNull);
      expect(backend.requests, isEmpty);
    });

    test('renews the saved session on reopening', () async {
      final user = await open().signUp(email: email, password: password);

      final reopened = open();

      expect(await reopened.restoreSession(), user);
      expect(reopened.currentUser, user);
      expect(refreshCount(), 1);
      expect(await reopened.idToken(), isNotEmpty);
      expect(refreshCount(), 1);
    });

    test('keeps the session when offline and renews later', () async {
      final user = await open().signUp(email: email, password: password);
      backend.offline = true;

      final reopened = open();

      expect(await reopened.restoreSession(), user);
      expect(reopened.currentUser, user);
      expect(store.session, isNotNull);

      backend.offline = false;
      expect(await reopened.idToken(), isNotEmpty);
    });

    test('keeps the session when the server fails', () async {
      await open().signUp(email: email, password: password);
      final failing = MockClient((_) async => http.Response('{}', 500));

      final reopened = open(client: failing);

      expect(await reopened.restoreSession(), isNotNull);
      expect(store.session, isNotNull);
    });

    test('discards a session the provider revoked', () async {
      await open().signUp(email: email, password: password);
      backend.revokeRefreshTokens();

      final reopened = open();

      expect(await reopened.restoreSession(), isNull);
      expect(reopened.currentUser, isNull);
      expect(store.session, isNull);
    });

    test('persists a rotated refresh token', () async {
      store.session = const StoredSession(
        uid: 'u1',
        email: email,
        refreshToken: 'old',
      );
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'id_token': 'id',
            'refresh_token': 'new',
            'expires_in': '3600',
            'user_id': 'u1',
          }),
          200,
        ),
      );

      final user = await open(client: client).restoreSession();

      expect(user, const UserModel(id: 'u1', email: email));
      expect(store.session?.refreshToken, 'new');
    });
  });
}
