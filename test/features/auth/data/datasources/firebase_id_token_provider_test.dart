import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:todo/core/error/exceptions.dart';
import 'package:todo/features/auth/data/datasources/firebase_id_token_provider.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockUser extends Mock implements User {}

void main() {
  late _MockFirebaseAuth auth;
  late _MockUser user;
  late FirebaseIdTokenProvider tokens;

  Matcher remote(RemoteErrorKind kind) =>
      throwsA(isA<RemoteException>().having((e) => e.kind, 'kind', kind));

  setUp(() {
    auth = _MockFirebaseAuth();
    user = _MockUser();
    tokens = FirebaseIdTokenProvider(auth);
    when(() => auth.currentUser).thenReturn(user);
  });

  test('returns the token of the signed-in user', () async {
    when(() => user.getIdToken(false)).thenAnswer((_) async => 'abc');

    expect(await tokens.idToken(), 'abc');
  });

  test('forces a renewal when asked', () async {
    when(() => user.getIdToken(true)).thenAnswer((_) async => 'new');

    expect(await tokens.idToken(forceRefresh: true), 'new');
    verify(() => user.getIdToken(true)).called(1);
  });

  test('nobody signed in is unauthenticated', () {
    when(() => auth.currentUser).thenReturn(null);

    expect(tokens.idToken(), remote(RemoteErrorKind.unauthenticated));
  });

  test('no token is unauthenticated', () {
    when(() => user.getIdToken(false)).thenAnswer((_) async => null);

    expect(tokens.idToken(), remote(RemoteErrorKind.unauthenticated));
  });

  test('failing to renew offline is a network error', () {
    when(() => user.getIdToken(false))
        .thenThrow(FirebaseAuthException(code: 'network-request-failed'));

    expect(tokens.idToken(), remote(RemoteErrorKind.network));
  });

  test('a revoked session is unauthenticated', () {
    when(() => user.getIdToken(false))
        .thenThrow(FirebaseAuthException(code: 'user-token-expired'));

    expect(tokens.idToken(), remote(RemoteErrorKind.unauthenticated));
  });

  test('any other Firebase failure is unknown', () {
    when(() => user.getIdToken(false))
        .thenThrow(FirebaseException(plugin: 'core', code: 'internal'));

    expect(tokens.idToken(), remote(RemoteErrorKind.unknown));
  });
}
