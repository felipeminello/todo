import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:todo/core/error/exceptions.dart';
import 'package:todo/features/auth/data/datasources/id_token_provider.dart';
import 'package:todo/features/tasks/data/datasources/api_task_attachment_data_source.dart';

import '../../../../helpers/fake_attachments_backend.dart';

/// Hands out `token-1`, then a new token on every forced renewal.
final class _Tokens implements IdTokenProvider {
  int renewals = 0;
  RemoteException? failure;

  @override
  Future<String> idToken({bool forceRefresh = false}) async {
    final failure = this.failure;
    if (failure != null) throw failure;
    if (forceRefresh) renewals++;
    return 'token-${renewals + 1}';
  }
}

/// Keeps the requests as they were sent, before the fake reads their body.
final class _RecordingClient extends http.BaseClient {
  _RecordingClient(this._inner);

  final http.Client _inner;
  final sent = <http.BaseRequest>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    sent.add(request);
    return _inner.send(request);
  }
}

void main() {
  late FakeAttachmentsBackend backend;
  late _Tokens tokens;

  ApiTaskAttachmentDataSource attachments({
    http.Client? client,
    Uri? baseUrl,
    Duration? timeout,
    Duration? transferTimeout,
  }) => ApiTaskAttachmentDataSource(
    client: client ?? backend.client,
    baseUrl: baseUrl ?? backend.baseUrl,
    tokens: tokens,
    timeout: timeout ?? const Duration(seconds: 15),
    transferTimeout: transferTimeout ?? const Duration(minutes: 5),
  );

  Stream<List<int>> Function() content(List<int> bytes) =>
      () => Stream.fromIterable([
        bytes.sublist(0, bytes.length ~/ 2),
        bytes.sublist(bytes.length ~/ 2),
      ]);

  Matcher remote(AttachmentErrorKind kind) => throwsA(
    isA<AttachmentRemoteException>().having((e) => e.kind, 'kind', kind),
  );

  Iterable<http.Request> apiRequests() =>
      backend.requestsTo(FakeAttachmentsBackend.apiHost);

  Iterable<http.Request> bucketRequests() =>
      backend.requestsTo(FakeAttachmentsBackend.bucketHost);

  setUp(() {
    backend = FakeAttachmentsBackend();
    tokens = _Tokens();
  });

  group('upload', () {
    test(
      'stores the file in the task folder as a uuid plus the extension',
      () async {
        final stored = await attachments().upload(
          'task-1',
          name: 'Relatório final.PDF',
          size: 4,
          openRead: content([1, 2, 3, 4]),
        );

        expect(backend.keys, ['task-1/${stored.id}']);
        expect(
          stored.id,
          matches(RegExp(r'^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}\.pdf$')),
        );
        expect(backend.content('task-1/${stored.id}'), [1, 2, 3, 4]);
      },
    );

    test('the attachment keeps the name of the uploaded file', () async {
      final stored = await attachments().upload(
        'task-1',
        name: 'Relatório final.PDF',
        size: 4,
        openRead: content([1, 2, 3, 4]),
      );

      expect(stored.name, 'Relatório final.PDF');
      expect(stored.size, 4);
      expect((await attachments().getAll('task-1')).single, stored);
    });

    test('asks the API with the name, the size and a bearer token', () async {
      await attachments().upload(
        'task-1',
        name: 'nota.txt',
        size: 2,
        openRead: content([1, 2]),
      );

      final request = apiRequests().single;
      expect(request.method, 'POST');
      expect(request.url.path, '/tasks/task-1/attachments');
      expect(request.headers['Authorization'], 'Bearer token-1');
      expect(jsonDecode(request.body), {'name': 'nota.txt', 'size': 2});
    });

    test('sends the file to the bucket with the signed headers and length, and '
        'without the ID token', () async {
      final client = _RecordingClient(backend.client);

      await attachments(
        client: client,
      ).upload('task-1', name: 'nota.txt', size: 2, openRead: content([1, 2]));

      final put = client.sent.last;
      expect(put.method, 'PUT');
      expect(put.url.host, FakeAttachmentsBackend.bucketHost);
      expect(put.contentLength, 2);
      expect(put.headers, {
        'Content-Type': 'application/octet-stream',
        'x-amz-meta-name': 'nota.txt',
        'x-amz-meta-owner': 'uid-1',
      });
    });

    test('an upload the bucket refuses fails and stores nothing', () async {
      backend.nextBucketStatus = 403;

      await expectLater(
        attachments().upload(
          'task-1',
          name: 'nota.txt',
          size: 2,
          openRead: content([1, 2]),
        ),
        remote(AttachmentErrorKind.unknown),
      );
      expect(backend.keys, isEmpty);
    });

    test('a file that ends up with another size is refused', () async {
      await expectLater(
        attachments().upload(
          'task-1',
          name: 'nota.txt',
          size: 5,
          openRead: content([1, 2]),
        ),
        remote(AttachmentErrorKind.unknown),
      );
      expect(backend.keys, isEmpty);
    });

    test('a file that cannot be read fails as unknown', () {
      expect(
        attachments().upload(
          'task-1',
          name: 'nota.txt',
          size: 2,
          openRead: () => Stream.error(const FormatException('unreadable')),
        ),
        remote(AttachmentErrorKind.unknown),
      );
    });

    test('a file over the server limit is refused before it is sent', () async {
      backend = FakeAttachmentsBackend(maxBytes: 3);

      await expectLater(
        attachments().upload(
          'task-1',
          name: 'nota.txt',
          size: 4,
          openRead: content([1, 2, 3, 4]),
        ),
        remote(AttachmentErrorKind.tooLarge),
      );
      expect(bucketRequests(), isEmpty);
    });

    test('a task full of attachments refuses another', () async {
      backend = FakeAttachmentsBackend(maxPerTask: 1);
      await attachments().upload(
        'task-1',
        name: 'a.txt',
        size: 1,
        openRead: content([1]),
      );

      expect(
        attachments().upload(
          'task-1',
          name: 'b.txt',
          size: 1,
          openRead: content([2]),
        ),
        remote(AttachmentErrorKind.limitReached),
      );
    });

    test('a task that does not exist refuses the upload', () {
      expect(
        attachments().upload(
          'gone',
          name: 'a.txt',
          size: 1,
          openRead: content([1]),
        ),
        remote(AttachmentErrorKind.notFound),
      );
    });
  });

  group('with stored attachments', () {
    late String first;
    late String second;

    setUp(() async {
      final source = attachments();
      first = (await source.upload(
        'task-1',
        name: 'a.txt',
        size: 2,
        openRead: content([1, 2]),
      )).id;
      second = (await source.upload(
        'task-1',
        name: 'b.pdf',
        size: 3,
        openRead: content([3, 4, 5]),
      )).id;
      backend.requests.clear();
    });

    test('lists the attachments of the task', () async {
      final listed = await attachments().getAll('task-1');

      expect(listed.map((a) => (a.id, a.name, a.size)), [
        (first, 'a.txt', 2),
        (second, 'b.pdf', 3),
      ]);
      expect(apiRequests().single.url.path, '/tasks/task-1/attachments');
      expect(await attachments().getAll('task-2'), isEmpty);
    });

    test('downloads from the bucket through a URL the API hands out', () async {
      final bytes = await attachments().download('task-1', second);

      expect(bytes, [3, 4, 5]);
      expect(
        apiRequests().single.url.path,
        '/tasks/task-1/attachments/$second',
      );
      final get = bucketRequests().single;
      expect(get.url.path, '/task-1/$second');
      expect(get.headers.containsKey('Authorization'), isFalse);
    });

    test('downloading an attachment that is gone reports not found', () async {
      await attachments().delete('task-1', first);

      expect(
        attachments().download('task-1', first),
        remote(AttachmentErrorKind.notFound),
      );
    });

    test('a file deleted after its URL was issued reports not found', () {
      backend.nextBucketStatus = 404;

      expect(
        attachments().download('task-1', first),
        remote(AttachmentErrorKind.notFound),
      );
    });

    test('a bucket failure while downloading is a network error', () {
      backend.nextBucketStatus = 503;

      expect(
        attachments().download('task-1', first),
        remote(AttachmentErrorKind.network),
      );
    });

    test('deletes one attachment', () async {
      await attachments().delete('task-1', first);

      expect(backend.keys, ['task-1/$second']);
      final request = apiRequests().single;
      expect(request.method, 'DELETE');
      expect(request.url.path, '/tasks/task-1/attachments/$first');
    });

    test('deleting an attachment that is gone reports not found', () async {
      await attachments().delete('task-1', first);

      expect(
        attachments().delete('task-1', first),
        remote(AttachmentErrorKind.notFound),
      );
    });

    test('deletes every attachment of the task', () async {
      await attachments().deleteAll('task-1');

      expect(backend.keys, isEmpty);
      final request = apiRequests().single;
      expect(request.method, 'DELETE');
      expect(request.url.path, '/tasks/task-1/attachments');
    });

    test('deleting all of a task without attachments succeeds', () {
      expect(attachments().deleteAll('task-2'), completes);
    });
  });

  group('API errors', () {
    const statuses = {
      403: AttachmentErrorKind.permissionDenied,
      404: AttachmentErrorKind.notFound,
      409: AttachmentErrorKind.limitReached,
      413: AttachmentErrorKind.tooLarge,
      429: AttachmentErrorKind.network,
      502: AttachmentErrorKind.network,
      503: AttachmentErrorKind.network,
      504: AttachmentErrorKind.network,
      400: AttachmentErrorKind.unknown,
      500: AttachmentErrorKind.unknown,
    };

    for (final MapEntry(key: status, value: kind) in statuses.entries) {
      test('HTTP $status is $kind', () {
        backend.nextApiStatus = status;

        expect(attachments().getAll('task-1'), remote(kind));
      });
    }

    test('a refused token is renewed once and the call repeated', () async {
      backend.validTokens
        ..clear()
        ..add('token-2');

      expect(await attachments().getAll('task-1'), isEmpty);
      expect(tokens.renewals, 1);
      expect(apiRequests().map((r) => r.headers['Authorization']), [
        'Bearer token-1',
        'Bearer token-2',
      ]);
    });

    test('a token refused even after renewal is unauthenticated', () async {
      backend.validTokens.clear();

      await expectLater(
        attachments().getAll('task-1'),
        remote(AttachmentErrorKind.unauthenticated),
      );
      expect(apiRequests(), hasLength(2));
    });

    test('nobody signed in is unauthenticated, without any request', () async {
      tokens.failure = const RemoteException(RemoteErrorKind.unauthenticated);

      await expectLater(
        attachments().getAll('task-1'),
        remote(AttachmentErrorKind.unauthenticated),
      );
      expect(backend.requests, isEmpty);
    });

    test('failing to renew the token offline is a network error', () {
      tokens.failure = const RemoteException(RemoteErrorKind.network);

      expect(
        attachments().getAll('task-1'),
        remote(AttachmentErrorKind.network),
      );
    });

    test('no connection is a network error', () {
      backend.offline = true;

      expect(
        attachments().getAll('task-1'),
        remote(AttachmentErrorKind.network),
      );
    });

    test('an API that does not answer in time is a network error', () {
      final never = MockClient((_) => Completer<http.Response>().future);

      expect(
        attachments(
          client: never,
          timeout: const Duration(milliseconds: 10),
        ).getAll('task-1'),
        remote(AttachmentErrorKind.network),
      );
    });

    test('a transfer that does not end in time is a network error', () {
      backend.bucketStalled = true;

      expect(
        attachments(transferTimeout: const Duration(milliseconds: 10))
            .upload('task-1', name: 'a.txt', size: 1, openRead: content([1])),
        remote(AttachmentErrorKind.network),
      );
    });

    test('an answer that is not the expected JSON is a format error', () {
      final odd = MockClient((_) async => http.Response('[]', 200));

      expect(attachments(client: odd).getAll('task-1'), throwsFormatException);
    });

    test('an answer without the expected fields is a format error', () {
      final odd = MockClient((_) async => http.Response('{}', 200));

      expect(attachments(client: odd).getAll('task-1'), throwsFormatException);
      expect(
        attachments(client: odd).download('task-1', 'x'),
        throwsFormatException,
      );
      expect(
        attachments(client: odd)
            .upload('task-1', name: 'a.txt', size: 1, openRead: content([1])),
        throwsFormatException,
      );
    });
  });

  test('a base URL with a path keeps it', () async {
    final seen = <Uri>[];
    final client = MockClient((request) async {
      seen.add(request.url);
      return http.Response('{"attachments":[]}', 200);
    });

    await attachments(
      client: client,
      baseUrl: Uri.parse('https://api.test/v1/'),
    ).getAll('task 1');

    expect(
      seen.single.toString(),
      'https://api.test/v1/tasks/task%201/attachments',
    );
  });
}
