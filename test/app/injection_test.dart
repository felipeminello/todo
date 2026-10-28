import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:todo/app/injection.dart';
import 'package:todo/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:todo/features/auth/data/datasources/firebase_auth_data_source.dart';
import 'package:todo/features/auth/data/datasources/id_token_provider.dart';
import 'package:todo/features/auth/data/datasources/rest_auth_data_source.dart';
import 'package:todo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:todo/features/tasks/data/datasources/firestore_task_data_source.dart';
import 'package:todo/features/tasks/data/datasources/rest_firestore_task_data_source.dart';
import 'package:todo/features/tasks/data/datasources/task_remote_data_source.dart';
import 'package:todo/features/tasks/presentation/bloc/tasks_bloc.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  const options = FirebaseOptions(
    apiKey: 'key',
    appId: 'app',
    messagingSenderId: 'sender',
    projectId: 'project',
  );
  late GetIt sl;

  setUp(() => sl = GetIt.asNewInstance());
  tearDown(() => sl.reset());

  void configure(TargetPlatform platform) => configureDependencies(
    sl,
    platform: platform,
    options: options,
    firebaseAuth: _MockFirebaseAuth.new,
    firestore: _MockFirestore.new,
    httpClient: () => MockClient((_) async => http.Response('{}', 200)),
    secureStorage: _MockSecureStorage.new,
  );

  test('only Windows uses the REST data sources', () {
    expect(usesFirebaseRest(TargetPlatform.windows), isTrue);
    for (final platform in [
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
    ]) {
      expect(usesFirebaseRest(platform), isFalse, reason: '$platform');
    }
  });

  test('Windows composes the REST data sources', () {
    configure(TargetPlatform.windows);

    expect(sl<AuthRemoteDataSource>(), isA<RestAuthDataSource>());
    expect(sl<TaskRemoteDataSource>(), isA<RestFirestoreTaskDataSource>());
    expect(sl<IdTokenProvider>(), same(sl<AuthRemoteDataSource>()));
  });

  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
  ]) {
    test('$platform composes the FlutterFire data sources', () {
      configure(platform);

      expect(sl<AuthRemoteDataSource>(), isA<FirebaseAuthDataSource>());
      expect(sl<TaskRemoteDataSource>(), isA<FirestoreTaskDataSource>());
      expect(sl.isRegistered<IdTokenProvider>(), isFalse);
    });
  }

  test('each bloc request builds a new bloc', () async {
    configure(TargetPlatform.windows);

    final first = sl<TasksBloc>();
    final second = sl<TasksBloc>();
    final auth = sl<AuthBloc>();

    expect(first, isNot(same(second)));
    await Future.wait([first.close(), second.close(), auth.close()]);
  });
}
