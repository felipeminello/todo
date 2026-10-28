import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:todo/core/error/exceptions.dart';
import 'package:todo/features/auth/data/datasources/id_token_provider.dart';
import 'package:todo/features/auth/domain/repositories/current_user_id_provider.dart';
import 'package:todo/features/tasks/data/datasources/task_remote_data_source.dart';
import 'package:todo/features/tasks/data/models/task_model.dart';

/// Windows, through the Firestore REST API, at `users/{uid}/tasks/{taskId}`.
/// Security rules apply exactly as for the SDK, since every call carries the
/// user's ID token.
final class RestFirestoreTaskDataSource implements TaskRemoteDataSource {
  RestFirestoreTaskDataSource({
    required this._client,
    required this._projectId,
    required this._tokens,
    required this._users,
    this.pageSize = 300,
    this.timeout = const Duration(seconds: 15),
  });

  final http.Client _client;
  final String _projectId;
  final IdTokenProvider _tokens;
  final CurrentUserIdProvider _users;
  final int pageSize;
  final Duration timeout;

  @override
  Future<List<TaskModel>> getAll() async {
    final tasks = <TaskModel>[];
    String? pageToken;
    do {
      final body = await _send(
        'GET',
        _collection(query: {'pageSize': '$pageSize', 'pageToken': ?pageToken}),
      );
      if (body['documents'] case final List<Object?> documents) {
        for (final document in documents) {
          if (document is! Map<String, Object?>) {
            throw FormatException('Malformed document', document);
          }
          tasks.add(TaskModel.fromRestDocument(document));
        }
      }
      pageToken = switch (body['nextPageToken']) {
        final String token when token.isNotEmpty => token,
        _ => null,
      };
    } while (pageToken != null);
    return tasks;
  }

  @override
  Future<TaskModel> create(TaskModel draft) async {
    final body = await _send(
      'POST',
      _collection(),
      body: {'fields': draft.toRestFields()},
    );
    return TaskModel.fromRestDocument(body);
  }

  @override
  Future<void> update(TaskModel task) => _send(
    'PATCH',
    _document(
      task.id,
      query: {
        'currentDocument.exists': 'true',
        'updateMask.fieldPaths': TaskModel.restFieldPaths,
      },
    ),
    body: {'fields': task.toRestFields()},
  );

  @override
  Future<void> delete(String id) => _send('DELETE', _document(id));

  Uri _collection({Map<String, Object>? query}) => Uri(
    scheme: 'https',
    host: 'firestore.googleapis.com',
    pathSegments: [..._collectionPath()],
    queryParameters: query,
  );

  Uri _document(String id, {Map<String, Object>? query}) => Uri(
    scheme: 'https',
    host: 'firestore.googleapis.com',
    pathSegments: [..._collectionPath(), id],
    queryParameters: query,
  );

  List<String> _collectionPath() {
    final uid = _users.currentUserId;
    if (uid == null) {
      throw const RemoteException(RemoteErrorKind.unauthenticated);
    }
    return [
      'v1',
      'projects',
      _projectId,
      'databases',
      '(default)',
      'documents',
      'users',
      uid,
      'tasks',
    ];
  }

  Future<Map<String, Object?>> _send(
    String method,
    Uri uri, {
    Map<String, Object?>? body,
  }) async {
    var response = await _request(method, uri, body, forceRefresh: false);
    // The token may have been revoked or expired early; renew it once.
    if (response.statusCode == 401) {
      response = await _request(method, uri, body, forceRefresh: true);
    }

    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      if (response.body.isEmpty) return const {};
      final Object? decoded = jsonDecode(response.body);
      if (decoded is Map<String, Object?>) return decoded;
      throw FormatException('Unexpected response', response.body);
    }
    throw RemoteException(switch (status) {
      401 => RemoteErrorKind.unauthenticated,
      403 => RemoteErrorKind.permissionDenied,
      404 => RemoteErrorKind.notFound,
      503 || 504 => RemoteErrorKind.network,
      _ => RemoteErrorKind.unknown,
    }, 'HTTP $status');
  }

  Future<http.Response> _request(
    String method,
    Uri uri,
    Map<String, Object?>? body, {
    required bool forceRefresh,
  }) async {
    final token = await _tokens.idToken(forceRefresh: forceRefresh);
    final request = http.Request(method, uri)
      ..headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode(body);
    }
    try {
      final streamed = await _client.send(request).timeout(timeout);
      return await http.Response.fromStream(streamed).timeout(timeout);
    } on http.ClientException catch (e) {
      throw RemoteException(RemoteErrorKind.network, e.message);
    } on TimeoutException {
      throw const RemoteException(RemoteErrorKind.network, 'timeout');
    }
  }
}
