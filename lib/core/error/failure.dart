import 'package:equatable/equatable.dart';

/// Errors that cross from the data layer into domain and presentation.
///
/// Repositories throw only [Failure]s, so BLoCs can turn every error into a
/// state without knowing about Firebase, HTTP or storage exceptions.
sealed class Failure extends Equatable implements Exception {
  const Failure();
}

enum AuthFailureReason {
  invalidCredentials,
  emailAlreadyInUse,
  weakPassword,
  invalidEmail,
  missingPassword,
  network,
  unknown,
}

final class AuthFailure extends Failure {
  const AuthFailure(this.reason);

  final AuthFailureReason reason;

  @override
  List<Object> get props => [reason];

  @override
  String toString() => 'AuthFailure(${reason.name})';
}

enum TaskFailureReason {
  emptyTitle,
  network,
  permissionDenied,
  notFound,
  unknown,
}

final class TaskFailure extends Failure {
  const TaskFailure(this.reason);

  final TaskFailureReason reason;

  @override
  List<Object> get props => [reason];

  @override
  String toString() => 'TaskFailure(${reason.name})';
}
