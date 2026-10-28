import 'package:todo/features/auth/data/datasources/secure_token_store.dart';

final class InMemorySecureTokenStore implements SecureTokenStore {
  StoredSession? session;

  @override
  Future<StoredSession?> read() async => session;

  @override
  Future<void> write(StoredSession value) async => session = value;

  @override
  Future<void> clear() async => session = null;
}
