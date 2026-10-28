import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// What the REST authentication keeps on the device between app launches.
final class StoredSession extends Equatable {
  const StoredSession({
    required this.uid,
    required this.email,
    required this.refreshToken,
  });

  final String uid;
  final String email;
  final String refreshToken;

  @override
  List<Object> get props => [uid, email, refreshToken];

  @override
  String toString() => 'StoredSession($uid, $email)';
}

/// Device storage for the session's refresh token. Implementations must use
/// the OS secure store, never plain preferences.
abstract interface class SecureTokenStore {
  Future<StoredSession?> read();

  Future<void> write(StoredSession session);

  Future<void> clear();
}

/// Backed by the OS credential store (Credential Manager on Windows).
final class FlutterSecureTokenStore implements SecureTokenStore {
  const FlutterSecureTokenStore(this._storage);

  static const _key = 'auth_session';

  final FlutterSecureStorage _storage;

  @override
  Future<StoredSession?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded case {
        'uid': final String uid,
        'email': final String email,
        'refreshToken': final String refreshToken,
      }) {
        return StoredSession(
          uid: uid,
          email: email,
          refreshToken: refreshToken,
        );
      }
    } on FormatException {
      // Falls through to discard the unreadable value.
    }
    await clear();
    return null;
  }

  @override
  Future<void> write(StoredSession session) => _storage.write(
    key: _key,
    value: jsonEncode({
      'uid': session.uid,
      'email': session.email,
      'refreshToken': session.refreshToken,
    }),
  );

  @override
  Future<void> clear() => _storage.delete(key: _key);
}
