import 'package:todo/core/error/exceptions.dart';
import 'package:todo/core/error/failure.dart';
import 'package:todo/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:todo/features/auth/domain/entities/app_user.dart';
import 'package:todo/features/auth/domain/repositories/auth_repository.dart';

final class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._dataSource);

  final AuthRemoteDataSource _dataSource;

  @override
  Future<AppUser> signUp({required String email, required String password}) =>
      _guard(() async {
        final user = await _dataSource.signUp(email: email, password: password);
        return user.toEntity();
      });

  @override
  Future<AppUser> signIn({required String email, required String password}) =>
      _guard(() async {
        final user = await _dataSource.signIn(email: email, password: password);
        return user.toEntity();
      });

  @override
  Future<void> signOut() => _guard(_dataSource.signOut);

  @override
  Future<AppUser?> restoreSession() => _guard(() async {
    try {
      return (await _dataSource.restoreSession())?.toEntity();
    } on AuthRemoteException catch (e) {
      if (e.kind == AuthErrorKind.sessionRevoked) return null;
      rethrow;
    }
  });

  @override
  AppUser? get currentUser => _dataSource.currentUser?.toEntity();

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AuthRemoteException catch (e) {
      throw AuthFailure(switch (e.kind) {
        AuthErrorKind.invalidCredentials =>
          AuthFailureReason.invalidCredentials,
        AuthErrorKind.emailAlreadyInUse => AuthFailureReason.emailAlreadyInUse,
        AuthErrorKind.weakPassword => AuthFailureReason.weakPassword,
        AuthErrorKind.invalidEmail => AuthFailureReason.invalidEmail,
        AuthErrorKind.network => AuthFailureReason.network,
        AuthErrorKind.sessionRevoked ||
        AuthErrorKind.unknown => AuthFailureReason.unknown,
      });
    }
  }
}
