import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:todo/app/widget_sign_out_listener.dart';
import 'package:todo/features/auth/data/models/user_model.dart';
import 'package:todo/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:todo/features/auth/domain/usecases/restore_session.dart';
import 'package:todo/features/auth/domain/usecases/sign_in.dart';
import 'package:todo/features/auth/domain/usecases/sign_out.dart';
import 'package:todo/features/auth/domain/usecases/sign_up.dart';
import 'package:todo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:todo/features/tasks/domain/repositories/task_widget_publisher.dart';
import 'package:todo/features/tasks/domain/usecases/clear_widget_tasks.dart';

import '../helpers/fake_auth_remote_data_source.dart';

class _MockTaskWidgetPublisher extends Mock implements TaskWidgetPublisher {}

void main() {
  late FakeAuthBackend backend;
  late _MockTaskWidgetPublisher publisher;
  late AuthBloc authBloc;

  setUp(() {
    backend = FakeAuthBackend();
    publisher = _MockTaskWidgetPublisher();
    when(() => publisher.clearForSignOut()).thenAnswer((_) async {});
  });

  // The bloc is created inside the test so its events run in the test's
  // fake async zone.
  Future<void> pump(WidgetTester tester) async {
    final repository = AuthRepositoryImpl(FakeAuthRemoteDataSource(backend));
    authBloc = AuthBloc(
      restoreSession: RestoreSession(repository),
      signIn: SignIn(repository),
      signUp: SignUp(repository),
      signOut: SignOut(repository),
    );
    addTearDown(authBloc.close);
    await tester.pumpWidget(
      BlocProvider.value(
        value: authBloc,
        child: WidgetSignOutListener(
          clearWidgetTasks: ClearWidgetTasks(publisher),
          child: const SizedBox(),
        ),
      ),
    );
    authBloc.add(const AuthSessionRequested());
    await tester.pumpAndSettle();
  }

  testWidgets('restoring a signed-in session keeps the widget', (tester) async {
    backend.savedSession = const UserModel(id: 'u1', email: 'a@b.com');

    await pump(tester);

    expect(authBloc.state.status, AuthStatus.authenticated);
    verifyNever(() => publisher.clearForSignOut());
  });

  testWidgets('signing out clears the widget', (tester) async {
    backend.savedSession = const UserModel(id: 'u1', email: 'a@b.com');
    await pump(tester);

    authBloc.add(const AuthSignOutRequested());
    await tester.pumpAndSettle();

    expect(authBloc.state.status, AuthStatus.unauthenticated);
    verify(() => publisher.clearForSignOut()).called(1);
  });

  testWidgets('opening without a session clears what a previous user left', (
    tester,
  ) async {
    await pump(tester);

    expect(authBloc.state.status, AuthStatus.unauthenticated);
    verify(() => publisher.clearForSignOut()).called(1);
  });

  testWidgets('a failure to clear never reaches the screen', (tester) async {
    when(() => publisher.clearForSignOut())
        .thenAnswer((_) async => throw StateError('storage'));

    await pump(tester);

    expect(tester.takeException(), isNull);
    expect(authBloc.state.status, AuthStatus.unauthenticated);
  });
}
