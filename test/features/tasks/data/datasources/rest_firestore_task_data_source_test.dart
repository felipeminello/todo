import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:todo/core/error/exceptions.dart';
import 'package:todo/core/time/calendar_date.dart';
import 'package:todo/features/auth/data/datasources/rest_auth_data_source.dart';
import 'package:todo/features/auth/domain/repositories/current_user_id_provider.dart';
import 'package:todo/features/tasks/data/datasources/rest_firestore_task_data_source.dart';
import 'package:todo/features/tasks/data/models/task_model.dart';
import 'package:todo/features/tasks/domain/entities/new_task.dart';

import '../../../../helpers/fake_firebase_rest_backend.dart';
import '../../../../helpers/fixed_clock.dart';
import '../../../../helpers/in_memory_secure_token_store.dart';

final class _FixedUser implements CurrentUserIdProvider {
  _FixedUser(this.currentUserId);

  @override
  String? currentUserId;
}

void main() {
  late FixedClock clock;
  late FakeFirebaseRestBackend backend;
  late RestAuthDataSource auth;
  late _FixedUser user;

  RestFirestoreTaskDataSource tasks({http.Client? client, Duration? timeout}) =>
      RestFirestoreTaskDataSource(
        client: client ?? backend.client,
        projectId: backend.projectId,
        tokens: auth,
        users: user,
        timeout: timeout ?? const Duration(seconds: 15),
      );

  TaskModel draft(String title, {CalendarDate? dueDate}) => TaskModel.draft(
    NewTask(title: title, dueDate: dueDate, createdAt: clock.now()),
  );

  Matcher remote(RemoteErrorKind kind) =>
      throwsA(isA<RemoteException>().having((e) => e.kind, 'kind', kind));

  Iterable<http.Request> firestoreRequests() =>
      backend.requestsTo('firestore.googleapis.com');

  setUp(() async {
    clock = FixedClock(DateTime.utc(2026, 10, 27, 12));
    backend = FakeFirebaseRestBackend(clock: clock);
    auth = RestAuthDataSource(
      client: backend.client,
      apiKey: backend.apiKey,
      store: InMemorySecureTokenStore(),
      clock: clock,
    );
    final signedIn = await auth.signUp(
      email: 'ana@example.com',
      password: 'segredo123',
    );
    user = _FixedUser(signedIn.id);
  });

  test(
    'creates under users/{uid}/tasks with typed fields and a bearer token',
    () async {
      final created = await tasks().create(
        draft('Comprar pão', dueDate: CalendarDate(2026, 10, 27)),
      );

      expect(created.id, isNotEmpty);
      expect(created.dueDate, '2026-10-27');
      final request = firestoreRequests().single;
      expect(request.method, 'POST');
      expect(
        request.url.path,
        '/v1/projects/${backend.projectId}/databases/(default)/documents'
        '/users/${user.currentUserId}/tasks',
      );
      expect(request.headers['Authorization'], startsWith('Bearer id-'));
      final Object? body = jsonDecode(request.body);
      expect(body, {
        'fields': containsPair('dueDate', {'stringValue': '2026-10-27'}),
      });
    },
  );

  test('lists every page', () async {
    final source = tasks();
    for (var i = 0; i < 5; i++) {
      await source.create(draft('t$i'));
    }
    backend.requests.clear();

    final all = await source.getAll();

    expect([for (final t in all) t.title], ['t0', 't1', 't2', 't3', 't4']);
    expect(firestoreRequests(), hasLength(3));
  });

  test('an empty collection lists nothing', () async {
    expect(await tasks().getAll(), isEmpty);
  });

  test(
    'update patches the mask of every field and requires the document',
    () async {
      final source = tasks();
      final created = await source.create(draft('a'));
      backend.requests.clear();

      await source.update(
        TaskModel(
          id: created.id,
          title: 'b',
          description: '',
          dueDate: null,
          createdAt: created.createdAt,
          completedAt: clock.now(),
        ),
      );

      final request = firestoreRequests().single;
      expect(request.method, 'PATCH');
      expect(request.url.queryParameters['currentDocument.exists'], 'true');
      expect(
        request.url.queryParametersAll['updateMask.fieldPaths'],
        TaskModel.restFieldPaths,
      );
      final stored = (await source.getAll()).single;
      expect(stored.title, 'b');
      expect(stored.completedAt, clock.now());
    },
  );

  test('update of a missing document is notFound', () async {
    final missing = draft('x').withId('nope');

    await expectLater(
      tasks().update(missing),
      remote(RemoteErrorKind.notFound),
    );
  });

  test('renews the token and retries once after 401', () async {
    final source = tasks();
    await source.create(draft('a'));
    backend.forgetIdTokens();
    backend.requests.clear();

    expect(await source.getAll(), hasLength(1));
    expect(firestoreRequests(), hasLength(2));
    expect(backend.requestsTo('securetoken.googleapis.com'), hasLength(1));
  });

  test('a second 401 is unauthenticated', () async {
    backend.rejectIdTokens = true;

    await expectLater(
      tasks().getAll(),
      remote(RemoteErrorKind.unauthenticated),
    );
    expect(firestoreRequests(), hasLength(2));
  });

  test("another user's tasks are permissionDenied", () async {
    user.currentUserId = 'someone-else';

    await expectLater(
      tasks().getAll(),
      remote(RemoteErrorKind.permissionDenied),
    );
  });

  test('without a signed-in user nothing is sent', () async {
    user.currentUserId = null;
    backend.requests.clear();

    await expectLater(
      tasks().getAll(),
      remote(RemoteErrorKind.unauthenticated),
    );
    expect(backend.requests, isEmpty);
  });

  test('no connection is a network error', () async {
    backend.offline = true;

    await expectLater(
      tasks().create(draft('a')),
      remote(RemoteErrorKind.network),
    );
  });

  test(
    'unavailable is a network error, other server errors are unknown',
    () async {
      backend.nextFirestoreStatus = 503;
      await expectLater(tasks().getAll(), remote(RemoteErrorKind.network));

      backend.nextFirestoreStatus = 500;
      await expectLater(tasks().getAll(), remote(RemoteErrorKind.unknown));
    },
  );

  test('a request that never answers is a network error', () async {
    final hanging = MockClient((_) => Completer<http.Response>().future);

    await expectLater(
      tasks(
        client: hanging,
        timeout: const Duration(milliseconds: 10),
      ).getAll(),
      remote(RemoteErrorKind.network),
    );
  });

  test('delete removes the document and tolerates a missing one', () async {
    final source = tasks();
    final created = await source.create(draft('a'));

    await source.delete(created.id);
    await source.delete(created.id);

    expect(await source.getAll(), isEmpty);
  });
}
