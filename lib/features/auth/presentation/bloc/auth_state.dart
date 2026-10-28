part of 'auth_bloc.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

final class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.isSubmitting = false,
    this.failure,
  });

  final AuthStatus status;

  /// Set only when [status] is [AuthStatus.authenticated].
  final AppUser? user;

  /// A sign in or sign up is in flight.
  final bool isSubmitting;

  /// Why the last sign in or sign up failed, until the next attempt.
  final AuthFailureReason? failure;

  @override
  List<Object?> get props => [status, user, isSubmitting, failure];
}
