import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:todo/features/auth/data/datasources/secure_token_store.dart';

class _MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  const session = StoredSession(
    uid: 'u1',
    email: 'ana@example.com',
    refreshToken: 'r1',
  );
  late _MockFlutterSecureStorage storage;
  late FlutterSecureTokenStore store;
  String? saved;

  setUp(() {
    saved = null;
    storage = _MockFlutterSecureStorage();
    store = FlutterSecureTokenStore(storage);
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((invocation) async {
      saved = invocation.namedArguments[#value] as String?;
    });
    when(() => storage.read(key: any(named: 'key')))
        .thenAnswer((_) async => saved);
    when(() => storage.delete(key: any(named: 'key'))).thenAnswer((_) async {
      saved = null;
    });
  });

  test('round-trips a session', () async {
    await store.write(session);

    expect(await store.read(), session);
  });

  test('reads nothing when empty', () async {
    expect(await store.read(), isNull);
  });

  test('clear removes the session', () async {
    await store.write(session);
    await store.clear();

    expect(await store.read(), isNull);
  });

  for (final corrupted in ['not json', '{"uid": 1}', '[]']) {
    test('discards an unreadable value: $corrupted', () async {
      saved = corrupted;

      expect(await store.read(), isNull);
      verify(() => storage.delete(key: any(named: 'key'))).called(1);
    });
  }

  test('toString does not expose the refresh token', () {
    expect(session.toString(), isNot(contains('r1')));
  });
}
