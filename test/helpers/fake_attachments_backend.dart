import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Simulates the attachments API and the bucket behind it (see
/// `infra/attachments`), with the same routes, status codes and signed
/// upload rules, so tests run without network.
final class FakeAttachmentsBackend {
  FakeAttachmentsBackend({
    this.maxBytes = 25 * 1024 * 1024,
    this.maxPerTask = 20,
  });

  static const apiHost = 'attachments.test';
  static const bucketHost = 'bucket.test';

  final Uri baseUrl = Uri.parse('https://$apiHost');
  final int maxBytes;
  final int maxPerTask;

  /// ID tokens the API accepts.
  final Set<String> validTokens = {'token-1'};

  /// Tasks that exist; uploads to any other answer 404.
  final Set<String> tasks = {'task-1'};

  /// Every request throws a connection error while set.
  bool offline = false;

  /// Bucket requests never get an answer while set.
  bool bucketStalled = false;

  /// Answers the next API request with this status, once.
  int? nextApiStatus;

  /// Answers the next bucket request with this status, once.
  int? nextBucketStatus;

  final List<http.Request> requests = [];

  final Map<String, _Object> _objects = {};
  final Map<String, _PendingUpload> _pending = {};
  int _sequence = 0;

  late final http.Client client = MockClient(_handle);

  Iterable<http.Request> requestsTo(String host) =>
      requests.where((r) => r.url.host == host);

  /// The keys in the bucket, as `<taskId>/<stored name>`.
  List<String> get keys => _objects.keys.toList();

  Uint8List? content(String key) => _objects[key]?.bytes;

  Future<http.Response> _handle(http.Request request) async {
    requests.add(request);
    if (offline) {
      throw http.ClientException('Connection failed', request.url);
    }
    return switch (request.url.host) {
      apiHost => _api(request),
      bucketHost when bucketStalled => Completer<http.Response>().future,
      bucketHost => _bucket(request),
      _ => http.Response('not found', 404),
    };
  }

  http.Response _api(http.Request request) {
    final forced = nextApiStatus;
    if (forced != null) {
      nextApiStatus = null;
      return _error(forced, 'forced');
    }
    final authorization = request.headers['Authorization'] ?? '';
    if (!authorization.startsWith('Bearer ') ||
        !validTokens.contains(authorization.substring(7))) {
      return http.Response('{"message":"Unauthorized"}', 401);
    }
    final segments = request.url.pathSegments;
    if (segments.length < 3 ||
        segments[0] != 'tasks' ||
        segments[2] != 'attachments') {
      return _error(404, 'not_found');
    }
    final taskId = segments[1];
    final attachmentId = segments.length > 3 ? segments[3] : null;
    final key = '$taskId/$attachmentId';

    switch ((request.method, attachmentId)) {
      case ('GET', null):
        return _json(200, {
          'attachments': [
            for (final MapEntry(:key, :value) in _objects.entries)
              if (key.startsWith('$taskId/')) value.toJson(key),
          ],
        });
      case ('POST', null):
        return _createUpload(request, taskId);
      case ('DELETE', null):
        _objects.removeWhere((key, _) => key.startsWith('$taskId/'));
        return http.Response('', 204);
      case ('GET', _):
        if (!_objects.containsKey(key)) {
          return _error(404, 'attachment_not_found');
        }
        return _json(200, {'url': 'https://$bucketHost/$key?signature=get'});
      case ('DELETE', _):
        if (_objects.remove(key) == null) {
          return _error(404, 'attachment_not_found');
        }
        return http.Response('', 204);
      default:
        return _error(404, 'not_found');
    }
  }

  http.Response _createUpload(http.Request request, String taskId) {
    final Object? body = jsonDecode(request.body);
    if (body case {'name': final String name, 'size': final int size}) {
      if (size <= 0) return _error(400, 'invalid_size');
      if (size > maxBytes) return _error(413, 'too_large');
      if (!tasks.contains(taskId)) return _error(404, 'task_not_found');
      final stored = _objects.keys.where((k) => k.startsWith('$taskId/'));
      if (stored.length >= maxPerTask) return _error(409, 'limit_reached');

      final dot = name.lastIndexOf('.');
      final extension = dot > 0 ? name.substring(dot).toLowerCase() : '';
      final number = (++_sequence).toString().padLeft(12, '0');
      final id = '00000000-0000-4000-8000-$number$extension';
      final headers = {
        'Content-Type': 'application/octet-stream',
        'x-amz-meta-name': Uri.encodeComponent(name),
        'x-amz-meta-owner': 'uid-1',
      };
      final signature = 'put-$_sequence';
      _pending[signature] = _PendingUpload(
        key: '$taskId/$id',
        name: name,
        size: size,
        headers: headers,
      );
      return _json(201, {
        'attachment': {
          'id': id,
          'name': name,
          'size': size,
          'contentType': 'application/octet-stream',
          'createdAt': '2026-11-12T12:00:00.000Z',
        },
        'upload': {
          'url': 'https://$bucketHost/$taskId/$id?signature=$signature',
          'headers': headers,
        },
      });
    }
    return _error(400, 'invalid_body');
  }

  http.Response _bucket(http.Request request) {
    final forced = nextBucketStatus;
    if (forced != null) {
      nextBucketStatus = null;
      return http.Response('<Error/>', forced);
    }
    final key = request.url.pathSegments.join('/');
    final signature = request.url.queryParameters['signature'];
    switch (request.method) {
      case 'PUT':
        // Like a presigned URL: only for that key, with exactly the signed
        // headers and length.
        final pending = _pending[signature];
        final matches =
            pending != null &&
            pending.key == key &&
            request.bodyBytes.length == pending.size &&
            pending.headers.entries.every(
              (header) => request.headers[header.key] == header.value,
            );
        if (!matches) return http.Response('<Error/>', 403);
        _objects[key] = _Object(pending.name, request.bodyBytes);
        return http.Response('', 200);
      case 'GET':
        final object = _objects[key];
        if (signature != 'get') return http.Response('<Error/>', 403);
        if (object == null) return http.Response('<Error/>', 404);
        return http.Response.bytes(object.bytes, 200);
      default:
        return http.Response('<Error/>', 405);
    }
  }

  static http.Response _json(int status, Map<String, Object?> body) =>
      http.Response.bytes(
        utf8.encode(jsonEncode(body)),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  static http.Response _error(int status, String code) =>
      _json(status, {'error': code});
}

final class _Object {
  _Object(this.name, this.bytes);

  final String name;
  final Uint8List bytes;

  Map<String, Object?> toJson(String key) => {
    'id': key.substring(key.indexOf('/') + 1),
    'name': name,
    'size': bytes.length,
    'contentType': 'application/octet-stream',
    'createdAt': '2026-11-12T12:00:00.000Z',
  };
}

final class _PendingUpload {
  _PendingUpload({
    required this.key,
    required this.name,
    required this.size,
    required this.headers,
  });

  final String key;
  final String name;
  final int size;
  final Map<String, String> headers;
}
