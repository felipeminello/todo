import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:todo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:todo/features/auth/presentation/pages/auth_page.dart';
import 'package:todo/features/tasks/presentation/bloc/tasks_bloc.dart';
import 'package:todo/features/tasks/presentation/pages/tasks_page.dart';
import 'package:todo/l10n/app_localizations.dart';

/// Shows the screen that matches the authentication state.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.createTasksBloc});

  /// Called once per signed-in user, so signing out discards the previous
  /// user's tasks together with their bloc.
  final TasksBloc Function() createTasksBloc;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (previous, current) =>
          previous.status != current.status || previous.user != current.user,
      builder: (context, state) => switch (state) {
        AuthState(status: AuthStatus.authenticated, :final user?) =>
          BlocProvider(
            key: ValueKey(user.id),
            create: (_) => createTasksBloc()..add(const TasksRequested()),
            child: TasksPage(
              onSignOut: () =>
                  context.read<AuthBloc>().add(const AuthSignOutRequested()),
            ),
          ),
        AuthState(status: AuthStatus.unauthenticated) => const AuthPage(),
        _ => const _Splash(),
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(
          semanticsLabel: AppLocalizations.of(context).loadingLabel,
        ),
      ),
    );
  }
}
