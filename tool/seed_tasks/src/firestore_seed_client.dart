import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:todo/features/tasks/data/models/task_model.dart';

import 'firebase_config.dart';
import 'seed_exception.dart';

/// Signs in with e-mail and password and writes to `users/{uid}/tasks`
/// through the REST APIs, as the Windows build does. Security rules apply,
/// so it can only touch the signed-in user's own tasks.
final class FirestoreSeedClient {
  FirestoreSeedClient(this._client, this._config);

  // Firestore's limit of writes per commit.
  static const _maxWritesPerCommit = 500;

  final http.Client _client;
  final FirebaseConfig _config;

  String? _uid;
  String? _idToken;

  Future<void> signIn({
    required String email,
    required String password,
    bool createAccount = false,
  }) async {
    final method = createAccount ? 'signUp' : 'signInWithPassword';
    final response = await _client.post(
      Uri.https('identitytoolkit.googleapis.com', '/v1/accounts:$method', {
        'key': _config.apiKey,
      }),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'returnSecureToken': true,
      }),
    );
    final body = _decode(response);
    if (body case {
      'localId': final String uid,
      'idToken': final String idToken,
    }) {
      _uid = uid;
      _idToken = idToken;
      return;
    }
    throw SeedException('Falha no login: ${_errorOf(body, response)}');
  }

  /// Ids of every task in the user's collection that starts with [prefix].
  Future<List<String>> listIds({required String prefix}) async {
    final ids = <String>[];
    String? pageToken;
    do {
      final response = await _client.get(
        _uri(
          [..._collectionPath()],
          query: {
            'pageSize': '300',
            'mask.fieldPaths': 'title',
            'pageToken': ?pageToken,
          },
        ),
        headers: _authHeaders(),
      );
      final body = _decode(response);
      if (response.statusCode != 200) {
        throw SeedException(
          'Falha ao listar tarefas: ${_errorOf(body, response)}',
        );
      }
      if (body['documents'] case final List<Object?> documents) {
        for (final document in documents) {
          if (document case {'name': final String name}) {
            final id = name.substring(name.lastIndexOf('/') + 1);
            if (id.startsWith(prefix)) ids.add(id);
          }
        }
      }
      pageToken = switch (body['nextPageToken']) {
        final String token when token.isNotEmpty => token,
        _ => null,
      };
    } while (pageToken != null);
    return ids;
  }

  Future<void> deleteAll(List<String> ids) => _commit([
    for (final id in ids) {'delete': _documentName(id)},
  ]);

  /// Writes each task under its own id, overwriting any document there.
  Future<void> writeAll(List<TaskModel> tasks) => _commit([
    for (final task in tasks)
      {
        'update': {
          'name': _documentName(task.id),
          'fields': task.toRestFields(),
        },
      },
  ]);

  Future<void> _commit(List<Map<String, Object?>> writes) async {
    for (var start = 0; start < writes.length; start += _maxWritesPerCommit) {
      final end = (start + _maxWritesPerCommit).clamp(0, writes.length);
      final response = await _client.post(
        _uri([..._databasePath(), 'documents:commit']),
        headers: {..._authHeaders(), 'Content-Type': 'application/json'},
        body: jsonEncode({'writes': writes.sublist(start, end)}),
      );
      if (response.statusCode != 200) {
        throw SeedException(
          'Falha ao gravar no Firestore: '
          '${_errorOf(_decode(response), response)}',
        );
      }
    }
  }

  Map<String, String> _authHeaders() {
    final token = _idToken;
    if (token == null) throw StateError('signIn must be called first');
    return {'Authorization': 'Bearer $token'};
  }

  List<String> _databasePath() => [
    'v1',
    'projects',
    _config.projectId,
    'databases',
    '(default)',
  ];

  List<String> _collectionPath() {
    final uid = _uid;
    if (uid == null) throw StateError('signIn must be called first');
    return [..._databasePath(), 'documents', 'users', uid, 'tasks'];
  }

  String _documentName(String id) =>
      [..._collectionPath().skip(1), id].join('/');

  Uri _uri(List<String> pathSegments, {Map<String, String>? query}) => Uri(
    scheme: 'https',
    host: 'firestore.googleapis.com',
    pathSegments: pathSegments,
    queryParameters: query,
  );

  static Map<String, Object?> _decode(http.Response response) {
    if (response.body.isEmpty) return const {};
    try {
      return switch (jsonDecode(response.body)) {
        final Map<String, Object?> map => map,
        _ => const {},
      };
    } on FormatException {
      return const {};
    }
  }

  static String _errorOf(Map<String, Object?> body, http.Response response) =>
      switch (body) {
        {'error': {'message': final String message}} => message,
        _ => 'HTTP ${response.statusCode}',
      };
}
