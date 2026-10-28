import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:todo/core/time/clock.dart';
import 'package:todo/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:todo/features/auth/data/datasources/firebase_auth_data_source.dart';
import 'package:todo/features/auth/data/datasources/id_token_provider.dart';
import 'package:todo/features/auth/data/datasources/rest_auth_data_source.dart';
import 'package:todo/features/auth/data/datasources/secure_token_store.dart';
import 'package:todo/features/auth/data/repositories/auth_current_user_id_provider.dart';
import 'package:todo/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:todo/features/auth/domain/repositories/auth_repository.dart';
import 'package:todo/features/auth/domain/repositories/current_user_id_provider.dart';
import 'package:todo/features/auth/domain/usecases/restore_session.dart';
import 'package:todo/features/auth/domain/usecases/sign_in.dart';
import 'package:todo/features/auth/domain/usecases/sign_out.dart';
import 'package:todo/features/auth/domain/usecases/sign_up.dart';
import 'package:todo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:todo/features/tasks/data/datasources/firestore_task_data_source.dart';
import 'package:todo/features/tasks/data/datasources/rest_firestore_task_data_source.dart';
import 'package:todo/features/tasks/data/datasources/task_remote_data_source.dart';
import 'package:todo/features/tasks/data/repositories/task_repository_impl.dart';
import 'package:todo/features/tasks/domain/repositories/task_repository.dart';
import 'package:todo/features/tasks/domain/usecases/add_task.dart';
import 'package:todo/features/tasks/domain/usecases/build_task_timeline.dart';
import 'package:todo/features/tasks/domain/usecases/delete_task.dart';
import 'package:todo/features/tasks/domain/usecases/get_tasks.dart';
import 'package:todo/features/tasks/domain/usecases/toggle_task.dart';
import 'package:todo/features/tasks/domain/usecases/update_task.dart';
import 'package:todo/features/tasks/presentation/bloc/tasks_bloc.dart';

/// Whether the platform talks to Firebase over REST instead of FlutterFire,
/// which does not support Windows in production.
bool usesFirebaseRest(TargetPlatform platform) =>
    platform == TargetPlatform.windows;

/// Registers the whole object graph in [sl].
///
/// The Firebase SDK instances and platform services are parameters so tests
/// can compose the graph without native plugins.
void configureDependencies(
  GetIt sl, {
  required TargetPlatform platform,
  required FirebaseOptions options,
  FirebaseAuth Function()? firebaseAuth,
  FirebaseFirestore Function()? firestore,
  http.Client Function()? httpClient,
  FlutterSecureStorage Function()? secureStorage,
}) {
  sl.registerLazySingleton<Clock>(() => const SystemClock());

  if (usesFirebaseRest(platform)) {
    sl
      ..registerLazySingleton<http.Client>(httpClient ?? http.Client.new)
      ..registerLazySingleton<SecureTokenStore>(
        () => FlutterSecureTokenStore(
          (secureStorage ?? FlutterSecureStorage.new)(),
        ),
      )
      ..registerLazySingleton<RestAuthDataSource>(
        () => RestAuthDataSource(
          client: sl(),
          apiKey: options.apiKey,
          store: sl(),
          clock: sl(),
        ),
      )
      ..registerLazySingleton<AuthRemoteDataSource>(
        () => sl<RestAuthDataSource>(),
      )
      ..registerLazySingleton<IdTokenProvider>(() => sl<RestAuthDataSource>())
      ..registerLazySingleton<TaskRemoteDataSource>(
        () => RestFirestoreTaskDataSource(
          client: sl(),
          projectId: options.projectId,
          tokens: sl(),
          users: sl(),
        ),
      );
  } else {
    sl
      ..registerLazySingleton<AuthRemoteDataSource>(
        () => FirebaseAuthDataSource(
          (firebaseAuth ?? () => FirebaseAuth.instance)(),
        ),
      )
      ..registerLazySingleton<TaskRemoteDataSource>(
        () => FirestoreTaskDataSource(
          (firestore ?? _serverOnlyFirestore)(),
          sl(),
        ),
      );
  }

  sl
    ..registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(sl()))
    ..registerLazySingleton<CurrentUserIdProvider>(
      () => AuthCurrentUserIdProvider(sl()),
    )
    ..registerLazySingleton<TaskRepository>(() => TaskRepositoryImpl(sl()))
    ..registerFactory(
      () => AuthBloc(
        restoreSession: RestoreSession(sl()),
        signIn: SignIn(sl()),
        signUp: SignUp(sl()),
        signOut: SignOut(sl()),
      ),
    )
    ..registerFactory(
      () => TasksBloc(
        getTasks: GetTasks(sl()),
        addTask: AddTask(sl(), sl()),
        updateTask: UpdateTask(sl()),
        deleteTask: DeleteTask(sl()),
        toggleTask: ToggleTask(sl(), sl()),
        buildTimeline: const BuildTaskTimeline(),
        clock: sl(),
      ),
    );
}

// No offline cache, to behave like the REST client on Windows: what is shown
// always comes from the server.
FirebaseFirestore _serverOnlyFirestore() =>
    FirebaseFirestore.instance
      ..settings = const Settings(persistenceEnabled: false);
