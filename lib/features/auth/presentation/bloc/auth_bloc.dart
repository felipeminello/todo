import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:todo/core/error/failure.dart';
import 'package:todo/features/auth/domain/entities/app_user.dart';
import 'package:todo/features/auth/domain/entities/credentials.dart';
import 'package:todo/features/auth/domain/usecases/restore_session.dart';
import 'package:todo/features/auth/domain/usecases/sign_in.dart';
import 'package:todo/features/auth/domain/usecases/sign_out.dart';
import 'package:todo/features/auth/domain/usecases/sign_up.dart';

part 'auth_event.dart';
part 'auth_state.dart';

final class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required this._restoreSession,
    required this._signIn,
    required this._signUp,
    required this._signOut,
  }) : super(const AuthState()) {
    on<AuthSessionRequested>(_onSessionRequested);
    on<AuthSignInRequested>(
      (event, emit) => _submit(
        emit,
        () =>
            _signIn(Credentials(email: event.email, password: event.password)),
      ),
    );
    on<AuthSignUpRequested>(
      (event, emit) => _submit(
        emit,
        () =>
            _signUp(Credentials(email: event.email, password: event.password)),
      ),
    );
    on<AuthSignOutRequested>(_onSignOutRequested);
  }

  final RestoreSession _restoreSession;
  final SignIn _signIn;
  final SignUp _signUp;
  final SignOut _signOut;

  Future<void> _onSessionRequested(
    AuthSessionRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (state != const AuthState()) emit(const AuthState());
    try {
      final user = await _restoreSession();
      emit(
        user == null
            ? const AuthState(status: AuthStatus.unauthenticated)
            : AuthState(status: AuthStatus.authenticated, user: user),
      );
    } on Object {
      emit(const AuthState(status: AuthStatus.unauthenticated));
    }
  }

  Future<void> _submit(
    Emitter<AuthState> emit,
    Future<AppUser> Function() action,
  ) async {
    if (state.isSubmitting) return;
    emit(
      const AuthState(status: AuthStatus.unauthenticated, isSubmitting: true),
    );
    try {
      final user = await action();
      emit(AuthState(status: AuthStatus.authenticated, user: user));
    } on AuthFailure catch (failure) {
      emit(
        AuthState(status: AuthStatus.unauthenticated, failure: failure.reason),
      );
    } on Object {
      emit(
        const AuthState(
          status: AuthStatus.unauthenticated,
          failure: AuthFailureReason.unknown,
        ),
      );
    }
  }

  Future<void> _onSignOutRequested(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await _signOut();
    } on Object {
      // Signing out only clears local state; leave the account either way.
    }
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }
}
