import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:todo/app/app.dart';
import 'package:todo/app/injection.dart';
import 'package:todo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:todo/features/tasks/presentation/bloc/tasks_bloc.dart';
import 'package:todo/firebase_options.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final platform = defaultTargetPlatform;
  final options = DefaultFirebaseOptions.currentPlatform;
  // On Windows the REST data sources only need the API key and project id;
  // the FlutterFire SDK there is not meant for production.
  if (!usesFirebaseRest(platform)) {
    await Firebase.initializeApp(options: options);
  }

  final sl = GetIt.instance;
  configureDependencies(sl, platform: platform, options: options);

  runApp(
    TodoApp(
      createAuthBloc: sl.call<AuthBloc>,
      createTasksBloc: sl.call<TasksBloc>,
    ),
  );
}
