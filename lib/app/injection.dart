import 'dart:ui' show Locale;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:todo/app/attachments_api_config.dart';
import 'package:todo/app/home_widget_strings.dart';
import 'package:todo/core/links/link_opener.dart';
import 'package:todo/core/links/url_launcher_link_opener.dart';
import 'package:todo/core/time/clock.dart';
import 'package:todo/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:todo/features/auth/data/datasources/firebase_auth_data_source.dart';
import 'package:todo/features/auth/data/datasources/firebase_id_token_provider.dart';
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
import 'package:todo/features/tasks/data/datasources/api_task_attachment_data_source.dart';
import 'package:todo/features/tasks/data/datasources/firestore_task_data_source.dart';
import 'package:todo/features/tasks/data/datasources/rest_firestore_task_data_source.dart';
import 'package:todo/features/tasks/data/datasources/task_attachment_remote_data_source.dart';
import 'package:todo/features/tasks/data/datasources/task_remote_data_source.dart';
import 'package:todo/features/tasks/data/files/file_picker_attachment_files.dart';
import 'package:todo/features/tasks/data/repositories/task_attachment_repository_impl.dart';
import 'package:todo/features/tasks/data/repositories/task_repository_impl.dart';
import 'package:todo/features/tasks/data/widget/home_widget_storage.dart';
import 'package:todo/features/tasks/data/widget/home_widget_task_publisher.dart';
import 'package:todo/features/tasks/data/widget/noop_task_widget_publisher.dart';
import 'package:todo/features/tasks/data/widget/widget_snapshot_codec.dart';
import 'package:todo/features/tasks/data/widget/widget_storage.dart';
import 'package:todo/features/tasks/domain/repositories/attachment_file_picker.dart';
import 'package:todo/features/tasks/domain/repositories/attachment_file_saver.dart';
import 'package:todo/features/tasks/domain/repositories/task_attachment_repository.dart';
import 'package:todo/features/tasks/domain/repositories/task_repository.dart';
import 'package:todo/features/tasks/domain/repositories/task_widget_publisher.dart';
import 'package:todo/features/tasks/domain/usecases/add_task.dart';
import 'package:todo/features/tasks/domain/usecases/add_task_attachment.dart';
import 'package:todo/features/tasks/domain/usecases/build_task_timeline.dart';
import 'package:todo/features/tasks/domain/usecases/clear_widget_tasks.dart';
import 'package:todo/features/tasks/domain/usecases/delete_task.dart';
import 'package:todo/features/tasks/domain/usecases/delete_task_attachment.dart';
import 'package:todo/features/tasks/domain/usecases/download_task_attachment.dart';
import 'package:todo/features/tasks/domain/usecases/get_task_attachments.dart';
import 'package:todo/features/tasks/domain/usecases/get_tasks.dart';
import 'package:todo/features/tasks/domain/usecases/pick_attachment_file.dart';
import 'package:todo/features/tasks/domain/usecases/publish_widget_tasks.dart';
import 'package:todo/features/tasks/domain/usecases/toggle_task.dart';
import 'package:todo/features/tasks/domain/usecases/update_task.dart';
import 'package:todo/features/tasks/presentation/bloc/task_attachments_bloc.dart';
import 'package:todo/features/tasks/presentation/bloc/tasks_bloc.dart';
import 'package:todo/l10n/app_localizations.dart';

/// Whether the platform talks to Firebase over REST instead of FlutterFire,
/// which does not support Windows in production.
bool usesFirebaseRest(TargetPlatform platform) =>
    platform == TargetPlatform.windows;

/// Whether the platform has the native home screen widget.
bool usesHomeWidget(TargetPlatform platform) =>
    platform == TargetPlatform.android || platform == TargetPlatform.iOS;

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
  Uri? attachmentsApi,
}) {
  sl
    ..registerLazySingleton<Clock>(() => const SystemClock())
    ..registerLazySingleton<LinkOpener>(() => const UrlLauncherLinkOpener())
    // Every platform reaches the attachments API over HTTP; Windows also
    // reaches Firebase this way.
    ..registerLazySingleton<http.Client>(httpClient ?? http.Client.new);

  if (usesFirebaseRest(platform)) {
    sl
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
      ..registerLazySingleton<IdTokenProvider>(
        () => FirebaseIdTokenProvider(
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

  if (usesHomeWidget(platform)) {
    sl
      ..registerLazySingleton<WidgetStorage>(
        () => HomeWidgetStorage(
          appGroupId: platform == TargetPlatform.iOS
              ? HomeWidgetStorage.iOSAppGroupId
              : null,
        ),
      )
      ..registerLazySingleton<TaskWidgetPublisher>(
        () => HomeWidgetTaskPublisher(
          sl(),
          // Same fixed locale as the MaterialApp; there is no BuildContext
          // here.
          WidgetSnapshotCodec(
            homeWidgetStrings(lookupAppLocalizations(const Locale('pt', 'BR'))),
          ),
        ),
      );
  } else {
    sl.registerLazySingleton<TaskWidgetPublisher>(
      () => const NoopTaskWidgetPublisher(),
    );
  }

  sl
    ..registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(sl()))
    ..registerLazySingleton<CurrentUserIdProvider>(
      () => AuthCurrentUserIdProvider(sl()),
    )
    ..registerLazySingleton<TaskRepository>(() => TaskRepositoryImpl(sl()))
    ..registerLazySingleton<TaskAttachmentRemoteDataSource>(
      () => ApiTaskAttachmentDataSource(
        client: sl(),
        baseUrl: attachmentsApi ?? attachmentsApiUrl,
        tokens: sl(),
      ),
    )
    ..registerLazySingleton<TaskAttachmentRepository>(
      () => TaskAttachmentRepositoryImpl(sl()),
    )
    ..registerLazySingleton(() => const FilePickerAttachmentFiles())
    ..registerLazySingleton<AttachmentFilePicker>(
      () => sl<FilePickerAttachmentFiles>(),
    )
    ..registerLazySingleton<AttachmentFileSaver>(
      () => sl<FilePickerAttachmentFiles>(),
    )
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
        deleteTask: DeleteTask(sl(), sl()),
        toggleTask: ToggleTask(sl(), sl()),
        buildTimeline: const BuildTaskTimeline(),
        publishWidgetTasks: PublishWidgetTasks(sl(), sl()),
        clock: sl(),
      ),
    )
    ..registerFactoryParam<TaskAttachmentsBloc, String, void>(
      (taskId, _) => TaskAttachmentsBloc(
        taskId: taskId,
        getAttachments: GetTaskAttachments(sl()),
        pickFile: PickAttachmentFile(sl()),
        addAttachment: AddTaskAttachment(sl()),
        downloadAttachment: DownloadTaskAttachment(sl(), sl()),
        deleteAttachment: DeleteTaskAttachment(sl()),
      ),
    )
    ..registerLazySingleton(() => ClearWidgetTasks(sl()));
}

// No offline cache, to behave like the REST client on Windows: what is shown
// always comes from the server.
FirebaseFirestore _serverOnlyFirestore() =>
    FirebaseFirestore.instance
      ..settings = const Settings(persistenceEnabled: false);
