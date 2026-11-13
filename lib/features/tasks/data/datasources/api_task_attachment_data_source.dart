import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:todo/core/error/exceptions.dart';
import 'package:todo/features/auth/data/datasources/id_token_provider.dart';
import 'package:todo/features/tasks/data/datasources/task_attachment_remote_data_source.dart';
import 'package:todo/features/tasks/data/models/task_attachment_model.dart';

/// Every platform, through the attachments API (see `infra/attachments`).
///
/// The API checks the user's ID token and hands out short-lived URLs; the
/// file itself goes straight to and from the S3 bucket, where it is stored
/// as `<taskId>/<uuid>.<extension>`.
final class ApiTaskAttachmentDataSource
    implements TaskAttachmentRemoteDataSource {
  ApiTaskAttachmentDataSource({
    required this._client,
    required this._baseUrl,
    required this._tokens,
    this.timeout = const Duration(seconds: 15),
    this.transferTimeout = const Duration(minutes: 10),
  });

  final http.Client _client;
  final Uri _baseUrl;
  final IdTokenProvider _tokens;

  /// For calls to the API.
  final Duration timeout;

  /// For sending or receiving a whole file; long enough for the largest one
  /// on a slow mobile connection.
  final Duration transferTimeout;

  @override
  Future<List<TaskAttachmentModel>> getAll(String taskId) async {
    final body = await _call('GET', _uri(taskId));
    if (body case {'attachments': final List<Object?> attachments}) {
      return [
        for (final attachment in attachments)
          TaskAttachmentModel.fromJson(attachment),
      ];
    }
    throw FormatException('Unexpected attachment list', body);
  }

  @override
  Future<TaskAttachmentModel> upload(
    String taskId, {
    required String name,
    required int size,
    required Stream<List<int>> Function() openRead,
  }) async {
    final body = await _call(
      'POST',
      _uri(taskId),
      body: {'name': name, 'size': size},
    );
    if (body case {
      'attachment': final Object? attachment,
      'upload': {
        'url': final String url,
        'headers': final Map<String, Object?> headers,
      },
    }) {
      final model = TaskAttachmentModel.fromJson(attachment);
      // The URL is signed for exactly these headers and this length.
      final request = _FileUpload(Uri.parse(url), openRead())
        ..contentLength = size
        ..headers.addAll({
          for (final MapEntry(:key, :value) in headers.entries)
            if (value is String) key: value,
        });
      final response = await _transfer(
        () async => http.Response.fromStream(await _client.send(request)),
      );
      _checkStorage(response);
      return model;
    }
    throw FormatException('Unexpected upload answer', body);
  }

  @override
  Future<Uint8List> download(String taskId, String attachmentId) async {
    final body = await _call('GET', _uri(taskId, attachmentId));
    if (body case {'url': final String url}) {
      final response = await _transfer(() => _client.get(Uri.parse(url)));
      _checkStorage(response);
      return response.bodyBytes;
    }
    throw FormatException('Unexpected download answer', body);
  }

  @override
  Future<void> delete(String taskId, String attachmentId) =>
      _call('DELETE', _uri(taskId, attachmentId));

  @override
  Future<void> deleteAll(String taskId) => _call('DELETE', _uri(taskId));

  Uri _uri(String taskId, [String? attachmentId]) => _baseUrl.replace(
    pathSegments: [
      ..._baseUrl.pathSegments.where((segment) => segment.isNotEmpty),
      'tasks',
      taskId,
      'attachments',
      ?attachmentId,
    ],
  );

  Future<Map<String, Object?>> _call(
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
    throw AttachmentRemoteException(switch (status) {
      401 => AttachmentErrorKind.unauthenticated,
      403 => AttachmentErrorKind.permissionDenied,
      404 => AttachmentErrorKind.notFound,
      409 => AttachmentErrorKind.limitReached,
      413 => AttachmentErrorKind.tooLarge,
      429 || 502 || 503 || 504 => AttachmentErrorKind.network,
      _ => AttachmentErrorKind.unknown,
    }, 'HTTP $status');
  }

  Future<http.Response> _request(
    String method,
    Uri uri,
    Map<String, Object?>? body, {
    required bool forceRefresh,
  }) async {
    final String token;
    try {
      token = await _tokens.idToken(forceRefresh: forceRefresh);
    } on RemoteException catch (e) {
      throw AttachmentRemoteException(switch (e.kind) {
        RemoteErrorKind.network => AttachmentErrorKind.network,
        RemoteErrorKind.unauthenticated => AttachmentErrorKind.unauthenticated,
        RemoteErrorKind.permissionDenied =>
          AttachmentErrorKind.permissionDenied,
        RemoteErrorKind.notFound ||
        RemoteErrorKind.unknown => AttachmentErrorKind.unknown,
      }, e.detail);
    }
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
      throw AttachmentRemoteException(AttachmentErrorKind.network, e.message);
    } on TimeoutException {
      throw const AttachmentRemoteException(
        AttachmentErrorKind.network,
        'timeout',
      );
    }
  }

  /// Sends or receives a file, straight to or from the bucket.
  Future<http.Response> _transfer(
    Future<http.Response> Function() action,
  ) async {
    try {
      return await action().timeout(transferTimeout);
    } on http.ClientException catch (e) {
      throw AttachmentRemoteException(AttachmentErrorKind.network, e.message);
    } on TimeoutException {
      throw const AttachmentRemoteException(
        AttachmentErrorKind.network,
        'timeout',
      );
    } on Exception catch (e) {
      // Reading the local file failed halfway.
      throw AttachmentRemoteException(AttachmentErrorKind.unknown, '$e');
    }
  }

  static void _checkStorage(http.Response response) {
    final status = response.statusCode;
    if (status >= 200 && status < 300) return;
    throw AttachmentRemoteException(switch (status) {
      404 => AttachmentErrorKind.notFound,
      >= 500 => AttachmentErrorKind.network,
      // 403 is an expired or mismatched signature, not a user without
      // permission.
      _ => AttachmentErrorKind.unknown,
    }, 'storage HTTP $status');
  }
}

/// A PUT whose body is read from the file as it is sent, so a large file is
/// never held in memory.
final class _FileUpload extends http.BaseRequest {
  _FileUpload(Uri url, this._content) : super('PUT', url);

  final Stream<List<int>> _content;

  @override
  http.ByteStream finalize() {
    super.finalize();
    return http.ByteStream(_content);
  }
}
