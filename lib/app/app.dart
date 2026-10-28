import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:todo/app/auth_gate.dart';
import 'package:todo/app/theme/app_theme.dart';
import 'package:todo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:todo/features/tasks/presentation/bloc/tasks_bloc.dart';
import 'package:todo/l10n/app_localizations.dart';

class TodoApp extends StatelessWidget {
  const TodoApp({
    super.key,
    required this.createAuthBloc,
    required this.createTasksBloc,
  });

  final AuthBloc Function() createAuthBloc;
  final TasksBloc Function() createTasksBloc;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => createAuthBloc()..add(const AuthSessionRequested()),
      child: MaterialApp(
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: AuthGate(createTasksBloc: createTasksBloc),
      ),
    );
  }
}
