import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:todo/core/time/clock.dart';

/// Simulates the Firebase Auth and Firestore REST endpoints the Windows data
/// sources call, with the same status codes and error payloads, so tests run
/// without network.
final class FakeFirebaseRestBackend {
  FakeFirebaseRestBackend({
    required this.clock,
    this.apiKey = 'test-api-key',
    this.projectId = 'test-project',
    this.maxPageSize = 2,
    this.tokenLifetime = const Duration(hours: 1),
  });

  final Clock clock;
  final String apiKey;
  final String projectId;

  /// Firestore may return fewer documents than requested; a small cap makes
  /// pagination happen in tests.
  final int maxPageSize;
  final Duration tokenLifetime;

  /// Every request throws a connection error while set.
  bool offline = false;

  /// Firestore rejects every ID token while set.
  bool rejectIdTokens = false;

  /// Answers the next Firestore request with this status, once.
  int? nextFirestoreStatus;

  final List<http.Request> requests = [];

  final Map<String, ({String uid, String password})> _accounts = {};
  final Map<String, ({String uid, DateTime expiresAt})> _idTokens = {};
  final Map<String, String> _refreshTokens = {};
  final Map<String, Map<String, Map<String, Object?>>> _documents = {};
  int _sequence = 0;

  late final http.Client client = MockClient(_handle);

  Iterable<http.Request> requestsTo(String host) =>
      requests.where((r) => r.url.host == host);

  /// Makes every saved refresh token invalid, as when the user is disabled
  /// or their password changes elsewhere.
  void revokeRefreshTokens() => _refreshTokens.clear();

  /// Drops every issued ID token, so Firestore answers 401 until renewal.
  void forgetIdTokens() => _idTokens.clear();

  Future<http.Response> _handle(http.Request request) async {
    requests.add(request);
    if (offline) {
      throw http.ClientException('Connection failed', request.url);
    }
    return switch (request.url.host) {
      'identitytoolkit.googleapis.com' => _identityToolkit(request),
      'securetoken.googleapis.com' => _secureToken(request),
      'firestore.googleapis.com' => _firestore(request),
      _ => http.Response('not found', 404),
    };
  }

  http.Response _identityToolkit(http.Request request) {
    if (request.url.queryParameters['key'] != apiKey) {
      return _authError('API_KEY_INVALID');
    }
    final Object? body = jsonDecode(request.body);
    if (body case {
      'email': final String email,
      'password': final String password,
    }) {
      switch (request.url.path) {
        case '/v1/accounts:signUp':
          if (!email.contains('@')) return _authError('INVALID_EMAIL');
          if (_accounts.containsKey(email)) return _authError('EMAIL_EXISTS');
          if (password.length < 6) {
            return _authError(
              'WEAK_PASSWORD : Password should be at least 6 characters',
            );
          }
          final uid = 'uid-${++_sequence}';
          _accounts[email] = (uid: uid, password: password);
          return _signedIn(uid, email);
        case '/v1/accounts:signInWithPassword':
          final account = _accounts[email];
          if (account == null || account.password != password) {
            return _authError('INVALID_LOGIN_CREDENTIALS');
          }
          return _signedIn(account.uid, email);
      }
    }
    return _authError('INVALID_REQUEST');
  }

  http.Response _secureToken(http.Request request) {
    final fields = request.bodyFields;
    final uid = _refreshTokens[fields['refresh_token']];
    if (fields['grant_type'] != 'refresh_token' || uid == null) {
      return _authError('INVALID_REFRESH_TOKEN');
    }
    return _json({
      'id_token': _issueIdToken(uid),
      'refresh_token': fields['refresh_token'],
      'expires_in': '${tokenLifetime.inSeconds}',
      'token_type': 'Bearer',
      'user_id': uid,
    });
  }

  http.Response _firestore(http.Request request) {
    final forced = nextFirestoreStatus;
    if (forced != null) {
      nextFirestoreStatus = null;
      return _json({
        'error': {'code': forced},
      }, forced);
    }

    final token = request.headers['Authorization']?.replaceFirst('Bearer ', '');
    final issued = _idTokens[token];
    if (rejectIdTokens ||
        issued == null ||
        !clock.now().isBefore(issued.expiresAt)) {
      return _json({
        'error': {'code': 401, 'status': 'UNAUTHENTICATED'},
      }, 401);
    }

    final segments = request.url.pathSegments;
    final prefix = [
      'v1',
      'projects',
      projectId,
      'databases',
      '(default)',
      'documents',
      'users',
    ];
    if (segments.length < 9 ||
        segments.length > 10 ||
        !_startsWith(segments, prefix) ||
        segments[8] != 'tasks') {
      return _json({
        'error': {'code': 404},
      }, 404);
    }
    final uid = segments[7];
    if (uid != issued.uid) {
      return _json({
        'error': {'code': 403, 'status': 'PERMISSION_DENIED'},
      }, 403);
    }
    final docs = _documents.putIfAbsent(uid, () => {});
    final docId = segments.length == 10 ? segments[9] : null;

    switch ((request.method, docId)) {
      case ('GET', null):
        final size = int.parse(request.url.queryParameters['pageSize'] ?? '20');
        final start = int.parse(
          request.url.queryParameters['pageToken'] ?? '0',
        );
        final end = (start + size.clamp(1, maxPageSize)).clamp(0, docs.length);
        final page = docs.entries.toList().sublist(start, end);
        return _json({
          if (page.isNotEmpty)
            'documents': [
              for (final MapEntry(:key, :value) in page)
                _document(uid, key, value),
            ],
          if (end < docs.length) 'nextPageToken': '$end',
        });
      case ('POST', null):
        final id = 'doc-${++_sequence}';
        docs[id] = _fieldsOf(request);
        return _json(_document(uid, id, docs[id] ?? const {}));
      case ('PATCH', final String id):
        final existing = docs[id];
        if (existing == null &&
            request.url.queryParameters['currentDocument.exists'] == 'true') {
          return _json({
            'error': {'code': 404, 'status': 'NOT_FOUND'},
          }, 404);
        }
        final updated = {...?existing};
        final incoming = _fieldsOf(request);
        final mask =
            request.url.queryParametersAll['updateMask.fieldPaths'] ??
            incoming.keys.toList();
        for (final path in mask) {
          if (incoming.containsKey(path)) {
            updated[path] = incoming[path];
          } else {
            updated.remove(path);
          }
        }
        docs[id] = updated;
        return _json(_document(uid, id, updated));
      case ('DELETE', final String id):
        docs.remove(id);
        return _json({});
      default:
        return _json({
          'error': {'code': 400},
        }, 400);
    }
  }

  http.Response _signedIn(String uid, String email) {
    final refreshToken = 'refresh-${++_sequence}';
    _refreshTokens[refreshToken] = uid;
    return _json({
      'localId': uid,
      'email': email,
      'idToken': _issueIdToken(uid),
      'refreshToken': refreshToken,
      'expiresIn': '${tokenLifetime.inSeconds}',
    });
  }

  String _issueIdToken(String uid) {
    final token = 'id-${++_sequence}';
    _idTokens[token] = (uid: uid, expiresAt: clock.now().add(tokenLifetime));
    return token;
  }

  Map<String, Object?> _document(
    String uid,
    String id,
    Map<String, Object?> fields,
  ) => {
    'name':
        'projects/$projectId/databases/(default)/documents/users/$uid/tasks/$id',
    'fields': fields,
    'createTime': '2026-10-27T00:00:00.000000Z',
    'updateTime': '2026-10-27T00:00:00.000000Z',
  };

  static Map<String, Object?> _fieldsOf(http.Request request) {
    final Object? body = jsonDecode(request.body);
    if (body case {'fields': final Map<String, Object?> fields}) {
      return {...fields};
    }
    return {};
  }

  static bool _startsWith(List<String> list, List<String> prefix) {
    for (var i = 0; i < prefix.length; i++) {
      if (list[i] != prefix[i]) return false;
    }
    return true;
  }

  static http.Response _authError(String message) => _json({
    'error': {'code': 400, 'message': message},
  }, 400);

  static http.Response _json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}
