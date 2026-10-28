/// Exceptions thrown by data sources, normalized across backends (FlutterFire
/// SDK and REST) so repositories map a single vocabulary to `Failure`s.
library;

enum RemoteErrorKind {
  network,
  unauthenticated,
  permissionDenied,
  notFound,
  unknown,
}

final class RemoteException implements Exception {
  const RemoteException(this.kind, [this.detail]);

  final RemoteErrorKind kind;
  final String? detail;

  @override
  String toString() => 'RemoteException(${kind.name}, $detail)';
}

enum AuthErrorKind {
  invalidCredentials,
  emailAlreadyInUse,
  weakPassword,
  invalidEmail,
  network,

  /// The provider refused to renew the saved session.
  sessionRevoked,
  unknown,
}

final class AuthRemoteException implements Exception {
  const AuthRemoteException(this.kind, [this.detail]);

  final AuthErrorKind kind;
  final String? detail;

  @override
  String toString() => 'AuthRemoteException(${kind.name}, $detail)';
}
