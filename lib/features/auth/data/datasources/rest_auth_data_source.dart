import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:todo/core/error/exceptions.dart';
import 'package:todo/core/time/clock.dart';
import 'package:todo/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:todo/features/auth/data/datasources/id_token_provider.dart';
import 'package:todo/features/auth/data/datasources/secure_token_store.dart';
import 'package:todo/features/auth/data/models/user_model.dart';

/// Windows, through the Firebase Auth REST API (Identity Toolkit and Secure
/// Token), because FlutterFire does not support Windows in production.
final class RestAuthDataSource
    implements AuthRemoteDataSource, IdTokenProvider {
  RestAuthDataSource({
    required this._client,
    required this._apiKey,
    required this._store,
    required this._clock,
    this.timeout = const Duration(seconds: 15),
  });

  static const refreshMargin = Duration(minutes: 5);

  final http.Client _client;
  final String _apiKey;
  final SecureTokenStore _store;
  final Clock _clock;
  final Duration timeout;

  _Session? _session;
  Future<void>? _refreshing;

  @override
  UserModel? get currentUser => _session?.user;

  @override
  Future<UserModel> signUp({required String email, required String password}) =>
      _signInWith('accounts:signUp', email, password);

  @override
  Future<UserModel> signIn({required String email, required String password}) =>
      _signInWith('accounts:signInWithPassword', email, password);

  @override
  Future<void> signOut() async {
    _session = null;
    await _store.clear();
  }

  @override
  Future<UserModel?> restoreSession() async {
    final stored = await _store.read();
    if (stored == null) return null;
    final session = _session = _Session(
      user: UserModel(id: stored.uid, email: stored.email),
      refreshToken: stored.refreshToken,
    );
    try {
      await _refreshOnce();
    } on AuthRemoteException catch (e) {
      // Only an explicit refusal ends the session. When offline or the
      // server fails, keep it and renew on the next request.
      if (e.kind != AuthErrorKind.sessionRevoked) return session.user;
      await signOut();
      return null;
    }
    return _session?.user;
  }

  @override
  Future<String> idToken({bool forceRefresh = false}) async {
    final session = _session;
    if (session == null) {
      throw const RemoteException(RemoteErrorKind.unauthenticated);
    }
    final expiresAt = session.expiresAt;
    final stale =
        expiresAt == null ||
        !_clock.now().add(refreshMargin).isBefore(expiresAt);
    if (forceRefresh || stale) {
      try {
        await _refreshOnce();
      } on AuthRemoteException catch (e) {
        switch (e.kind) {
          case AuthErrorKind.network:
            throw const RemoteException(RemoteErrorKind.network);
          case AuthErrorKind.sessionRevoked:
            await signOut();
            throw const RemoteException(RemoteErrorKind.unauthenticated);
          default:
            throw RemoteException(RemoteErrorKind.unknown, e.detail);
        }
      }
    }
    final token = _session?.idToken;
    if (token == null) {
      throw const RemoteException(RemoteErrorKind.unauthenticated);
    }
    return token;
  }

  Future<UserModel> _signInWith(
    String method,
    String email,
    String password,
  ) async {
    final body = await _post(
      Uri.https('identitytoolkit.googleapis.com', '/v1/$method', {
        'key': _apiKey,
      }),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'returnSecureToken': true,
      }),
      mapError: _signInError,
    );
    if (body case {
      'localId': final String uid,
      'idToken': final String idToken,
      'refreshToken': final String refreshToken,
      'expiresIn': final String expiresIn,
    }) {
      final session = _session = _Session(
        user: UserModel(id: uid, email: _stringOr(body['email'], email)),
        refreshToken: refreshToken,
        idToken: idToken,
        expiresAt: _expiry(expiresIn),
      );
      await _persist(session);
      return session.user;
    }
    throw const AuthRemoteException(AuthErrorKind.unknown, 'bad response');
  }

  /// Joins concurrent callers onto a single renewal.
  Future<void> _refreshOnce() {
    return _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  }

  Future<void> _refresh() async {
    final session = _session;
    if (session == null) {
      throw const AuthRemoteException(AuthErrorKind.sessionRevoked);
    }
    final body = await _post(
      Uri.https('securetoken.googleapis.com', '/v1/token', {'key': _apiKey}),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': session.refreshToken,
      },
      // Every refusal of a refresh token means the session is gone.
      mapError: (_) => AuthErrorKind.sessionRevoked,
    );
    if (body case {
      'id_token': final String idToken,
      'refresh_token': final String refreshToken,
      'expires_in': final String expiresIn,
    }) {
      if (!identical(_session, session)) return;
      final renewed = _session = session.renewed(
        idToken: idToken,
        refreshToken: refreshToken,
        expiresAt: _expiry(expiresIn),
      );
      if (refreshToken != session.refreshToken) await _persist(renewed);
      return;
    }
    throw const AuthRemoteException(AuthErrorKind.unknown, 'bad response');
  }

  Future<Map<String, Object?>> _post(
    Uri uri, {
    required Map<String, String> headers,
    required Object body,
    required AuthErrorKind Function(String code) mapError,
  }) async {
    final http.Response response;
    try {
      response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(timeout);
    } on http.ClientException catch (e) {
      throw AuthRemoteException(AuthErrorKind.network, e.message);
    } on TimeoutException {
      throw const AuthRemoteException(AuthErrorKind.network, 'timeout');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw AuthRemoteException(
        AuthErrorKind.unknown,
        'HTTP ${response.statusCode}',
      );
    }

    if (response.statusCode == 200 && decoded is Map<String, Object?>) {
      return decoded;
    }
    if (decoded case {'error': {'message': final String message}}
        when response.statusCode == 400) {
      // Messages may carry details after the code: "WEAK_PASSWORD : ...".
      final code = message.split(' ').first;
      throw AuthRemoteException(mapError(code), code);
    }
    throw AuthRemoteException(
      AuthErrorKind.unknown,
      'HTTP ${response.statusCode}',
    );
  }

  static AuthErrorKind _signInError(String code) => switch (code) {
    'EMAIL_EXISTS' => AuthErrorKind.emailAlreadyInUse,
    'WEAK_PASSWORD' => AuthErrorKind.weakPassword,
    'INVALID_EMAIL' => AuthErrorKind.invalidEmail,
    'INVALID_LOGIN_CREDENTIALS' ||
    'EMAIL_NOT_FOUND' ||
    'INVALID_PASSWORD' ||
    'USER_DISABLED' => AuthErrorKind.invalidCredentials,
    _ => AuthErrorKind.unknown,
  };

  Future<void> _persist(_Session session) => _store.write(
    StoredSession(
      uid: session.user.id,
      email: session.user.email,
      refreshToken: session.refreshToken,
    ),
  );

  DateTime _expiry(String expiresInSeconds) =>
      _clock.now().add(Duration(seconds: int.tryParse(expiresInSeconds) ?? 0));

  static String _stringOr(Object? value, String fallback) =>
      value is String ? value : fallback;
}

final class _Session {
  const _Session({
    required this.user,
    required this.refreshToken,
    this.idToken,
    this.expiresAt,
  });

  final UserModel user;
  final String refreshToken;

  /// `null` until the first renewal after restoring from storage.
  final String? idToken;
  final DateTime? expiresAt;

  _Session renewed({
    required String idToken,
    required String refreshToken,
    required DateTime expiresAt,
  }) => _Session(
    user: user,
    refreshToken: refreshToken,
    idToken: idToken,
    expiresAt: expiresAt,
  );
}
