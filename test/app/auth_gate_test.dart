import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/app/auth_gate.dart';
import 'package:todo/core/time/calendar_date.dart';
import 'package:todo/features/auth/data/repositories/auth_current_user_id_provider.dart';
import 'package:todo/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:todo/features/auth/domain/repositories/current_user_id_provider.dart';
import 'package:todo/features/auth/domain/usecases/restore_session.dart';
import 'package:todo/features/auth/domain/usecases/sign_in.dart';
import 'package:todo/features/auth/domain/usecases/sign_out.dart';
import 'package:todo/features/auth/domain/usecases/sign_up.dart';
import 'package:todo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:todo/features/auth/presentation/pages/auth_page.dart';
import 'package:todo/features/tasks/data/widget/noop_task_widget_publisher.dart';
import 'package:todo/features/tasks/domain/entities/new_task.dart';
import 'package:todo/features/tasks/domain/entities/task.dart';
import 'package:todo/features/tasks/domain/repositories/task_repository.dart';
import 'package:todo/features/tasks/domain/usecases/add_task.dart';
import 'package:todo/features/tasks/domain/usecases/build_task_timeline.dart';
import 'package:todo/features/tasks/domain/usecases/delete_task.dart';
import 'package:todo/features/tasks/domain/usecases/get_tasks.dart';
import 'package:todo/features/tasks/domain/usecases/publish_widget_tasks.dart';
import 'package:todo/features/tasks/domain/usecases/toggle_task.dart';
import 'package:todo/features/tasks/domain/usecases/update_task.dart';
import 'package:todo/features/tasks/presentation/bloc/tasks_bloc.dart';
import 'package:todo/features/tasks/presentation/pages/tasks_page.dart';

import '../helpers/fake_auth_remote_data_source.dart';
import '../helpers/fixed_clock.dart';
import '../helpers/localized_app.dart';

/// Tasks stored per user, served to whoever is signed in.
final class _PerUserTasks implements TaskRepository {
  _PerUserTasks(this._users);

  final CurrentUserIdProvider _users;
  final Map<String, List<Task>> byUser = {};

  List<Task> get _mine => byUser[_users.currentUserId] ?? const [];

  @override
  Future<List<Task>> getAll() async => _mine;

  @override
  Future<Task> add(NewTask task) => throw UnimplementedError();

  @override
  Future<void> update(Task task) => throw UnimplementedError();

  @override
  Future<void> delete(String id) => throw UnimplementedError();
}

void main() {
  late FakeAuthBackend backend;
  late FakeAuthRemoteDataSource authSource;
  late AuthRepositoryImpl authRepository;
  late AuthBloc authBloc;
  late _PerUserTasks tasks;
  final clock = FixedClock(DateTime(2026, 10, 27, 10));

  setUp(() {
    backend = FakeAuthBackend();
    authSource = FakeAuthRemoteDataSource(backend);
    authRepository = AuthRepositoryImpl(authSource);
    tasks = _PerUserTasks(AuthCurrentUserIdProvider(authRepository));
  });

  // Blocs are created inside the test so their events run in its fake async
  // zone.
  Future<void> pump(WidgetTester tester) {
    authBloc = AuthBloc(
      restoreSession: RestoreSession(authRepository),
      signIn: SignIn(authRepository),
      signUp: SignUp(authRepository),
      signOut: SignOut(authRepository),
    );
    addTearDown(authBloc.close);
    return tester.pumpWidget(
      localizedApp(
        home: BlocProvider.value(
          value: authBloc,
          child: AuthGate(
            createTasksBloc: () => TasksBloc(
              getTasks: GetTasks(tasks),
              addTask: AddTask(tasks, clock),
              updateTask: UpdateTask(tasks),
              deleteTask: DeleteTask(tasks),
              toggleTask: ToggleTask(tasks, clock),
              buildTimeline: const BuildTaskTimeline(),
              publishWidgetTasks: PublishWidgetTasks(
                const NoopTaskWidgetPublisher(),
                clock,
              ),
              clock: clock,
            ),
          ),
        ),
      ),
    );
  }

  Task taskTitled(String title) => Task(
    id: title,
    title: title,
    dueDate: CalendarDate(2026, 10, 30),
    createdAt: DateTime.utc(2026),
  );

  testWidgets('shows a loading indicator while the session is checked', (
    tester,
  ) async {
    await pump(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(AuthPage), findsNothing);
    expect(find.byType(TasksPage), findsNothing);
  });

  testWidgets('without a saved session shows the login', (tester) async {
    await pump(tester);
    authBloc.add(const AuthSessionRequested());
    await tester.pumpAndSettle();

    expect(find.byType(AuthPage), findsOneWidget);
  });

  testWidgets('with a saved session opens the tasks directly', (tester) async {
    await authSource.signUp(email: 'ana@example.com', password: '123456');
    tasks.byUser['uid-1'] = [taskTitled('Tarefa da Ana')];

    await pump(tester);
    authBloc.add(const AuthSessionRequested());
    await tester.pumpAndSettle();

    expect(find.byType(TasksPage), findsOneWidget);
    expect(find.text('Tarefa da Ana'), findsOneWidget);
  });

  testWidgets('switching users never shows the previous user tasks', (
    tester,
  ) async {
    await authSource.signUp(email: 'ana@example.com', password: '123456');
    await authSource.signUp(email: 'bia@example.com', password: '123456');
    tasks.byUser['uid-1'] = [taskTitled('Tarefa da Ana')];
    tasks.byUser['uid-2'] = [taskTitled('Tarefa da Bia')];
    await pump(tester);

    authBloc.add(
      const AuthSignInRequested(email: 'ana@example.com', password: '123456'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tarefa da Ana'), findsOneWidget);

    await tester.tap(find.byTooltip('Sair'));
    await tester.pumpAndSettle();
    expect(find.byType(AuthPage), findsOneWidget);

    authBloc.add(
      const AuthSignInRequested(email: 'bia@example.com', password: '123456'),
    );
    await tester.pump();
    expect(find.text('Tarefa da Ana'), findsNothing);
    await tester.pump();
    expect(find.text('Tarefa da Ana'), findsNothing);
    await tester.pumpAndSettle();

    expect(find.text('Tarefa da Bia'), findsOneWidget);
    expect(find.text('Tarefa da Ana'), findsNothing);
  });

  testWidgets('signing out shows the login, also after reopening', (
    tester,
  ) async {
    await authSource.signUp(email: 'ana@example.com', password: '123456');
    await pump(tester);
    authBloc.add(const AuthSessionRequested());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Sair'));
    await tester.pumpAndSettle();

    expect(find.byType(AuthPage), findsOneWidget);
    expect(backend.savedSession, isNull);
  });
}
