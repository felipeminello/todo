import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:todo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:todo/features/tasks/domain/usecases/clear_widget_tasks.dart';

/// Removes the tasks from the home screen widget whenever no user is signed
/// in: after signing out, and when a saved session turns out to be gone.
///
/// Lives in `app/` so the auth feature does not depend on tasks.
class WidgetSignOutListener extends StatelessWidget {
  const WidgetSignOutListener({
    super.key,
    required this.clearWidgetTasks,
    required this.child,
  });

  final ClearWidgetTasks clearWidgetTasks;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          current.status == AuthStatus.unauthenticated,
      listener: (_, _) => _clear(),
      child: child,
    );
  }

  Future<void> _clear() async {
    try {
      await clearWidgetTasks();
    } on Object catch (_) {
      // The widget is secondary: a failure here must never reach the
      // screen.
    }
  }
}
