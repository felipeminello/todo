import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:todo/core/error/failure.dart';
import 'package:todo/features/auth/domain/entities/app_user.dart';
import 'package:todo/features/auth/domain/repositories/auth_repository.dart';
import 'package:todo/features/auth/domain/usecases/restore_session.dart';
import 'package:todo/features/auth/domain/usecases/sign_in.dart';
import 'package:todo/features/auth/domain/usecases/sign_out.dart';
import 'package:todo/features/auth/domain/usecases/sign_up.dart';
import 'package:todo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:todo/features/auth/presentation/pages/auth_page.dart';

import '../../../../helpers/localized_app.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository repository;
  late AuthBloc bloc;

  setUp(() => repository = _MockAuthRepository());

  // Created inside the test so its events run in the test's fake async zone.
  Future<void> pump(WidgetTester tester) {
    bloc = AuthBloc(
      restoreSession: RestoreSession(repository),
      signIn: SignIn(repository),
      signUp: SignUp(repository),
      signOut: SignOut(repository),
    );
    addTearDown(bloc.close);
    return tester.pumpWidget(
      localizedApp(
        home: BlocProvider.value(value: bloc, child: const AuthPage()),
      ),
    );
  }

  Finder emailField() => find.byKey(const Key('auth-email'));
  Finder passwordField() => find.byKey(const Key('auth-password'));

  void signInAnswers(Future<AppUser> Function() answer) => when(
    () => repository.signIn(
      email: any(named: 'email'),
      password: any(named: 'password'),
    ),
  ).thenAnswer((_) => answer());

  testWidgets('empty fields are not submitted', (tester) async {
    await pump(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pump();

    expect(find.text('Informe o e-mail'), findsOneWidget);
    expect(find.text('Informe a senha'), findsOneWidget);
    verifyZeroInteractions(repository);
  });

  testWidgets('a malformed email is not submitted', (tester) async {
    await pump(tester);

    await tester.enterText(emailField(), 'ana@');
    await tester.enterText(passwordField(), 'segredo');
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pump();

    expect(find.text('E-mail inválido'), findsOneWidget);
    verifyZeroInteractions(repository);
  });

  testWidgets('wrong credentials show one generic message', (tester) async {
    signInAnswers(
      () async => throw const AuthFailure(AuthFailureReason.invalidCredentials),
    );
    await pump(tester);

    await tester.enterText(emailField(), 'ana@example.com');
    await tester.enterText(passwordField(), 'errada');
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);
  });

  testWidgets('a network failure keeps what was typed', (tester) async {
    signInAnswers(
      () async => throw const AuthFailure(AuthFailureReason.network),
    );
    await pump(tester);

    await tester.enterText(emailField(), 'ana@example.com');
    await tester.enterText(passwordField(), 'segredo');
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pumpAndSettle();

    expect(
      find.text('Sem conexão. Verifique a internet e tente de novo.'),
      findsOneWidget,
    );
    expect(find.text('ana@example.com'), findsOneWidget);
  });

  testWidgets('shows progress and blocks the form while submitting', (
    tester,
  ) async {
    final pending = Completer<AppUser>();
    signInAnswers(() => pending.future);
    await pump(tester);

    await tester.enterText(emailField(), 'ana@example.com');
    await tester.enterText(passwordField(), 'segredo');
    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    pending.complete(const AppUser(id: 'u', email: 'ana@example.com'));
    await tester.pumpAndSettle();
  });

  testWidgets('the password starts hidden and the toggle shows and hides it', (
    tester,
  ) async {
    await pump(tester);
    bool isObscured() => tester
        .widget<EditableText>(
          find.descendant(
            of: passwordField(),
            matching: find.byType(EditableText),
          ),
        )
        .obscureText;

    await tester.enterText(passwordField(), 'segredo');
    expect(isObscured(), isTrue);
    expect(find.byTooltip('Mostrar senha'), findsOneWidget);

    await tester.tap(find.byTooltip('Mostrar senha'));
    await tester.pump();
    expect(isObscured(), isFalse);
    expect(find.byTooltip('Ocultar senha'), findsOneWidget);

    await tester.tap(find.byTooltip('Ocultar senha'));
    await tester.pump();
    expect(isObscured(), isTrue);
    expect(find.text('segredo'), findsOneWidget);
  });

  testWidgets('switches to sign up and submits a sign up', (tester) async {
    when(
      () => repository.signUp(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer(
      (_) async => throw const AuthFailure(AuthFailureReason.weakPassword),
    );
    await pump(tester);

    await tester.tap(find.text('Não tem conta? Criar conta'));
    await tester.pump();
    await tester.enterText(emailField(), 'ana@example.com');
    await tester.enterText(passwordField(), '123');
    await tester.tap(find.widgetWithText(FilledButton, 'Criar conta'));
    await tester.pumpAndSettle();

    expect(
      find.text('Senha fraca. Use pelo menos 6 caracteres.'),
      findsOneWidget,
    );
    verify(() => repository.signUp(email: 'ana@example.com', password: '123'))
        .called(1);
  });
}
