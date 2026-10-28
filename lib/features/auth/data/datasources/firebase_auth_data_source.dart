import 'package:firebase_auth/firebase_auth.dart';
import 'package:todo/core/error/exceptions.dart';
import 'package:todo/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:todo/features/auth/data/models/user_model.dart';

/// Android, iOS and macOS, through the FlutterFire SDK.
final class FirebaseAuthDataSource implements AuthRemoteDataSource {
  const FirebaseAuthDataSource(this._auth);

  final FirebaseAuth _auth;

  @override
  UserModel? get currentUser => _toModel(_auth.currentUser);

  @override
  Future<UserModel> signUp({required String email, required String password}) =>
      _signedIn(
        () => _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        ),
      );

  @override
  Future<UserModel> signIn({required String email, required String password}) =>
      _signedIn(
        () =>
            _auth.signInWithEmailAndPassword(email: email, password: password),
      );

  @override
  Future<void> signOut() => _guard(_auth.signOut);

  @override
  Future<UserModel?> restoreSession() => _guard(() async {
    final user = await _auth.authStateChanges().first;
    if (user == null) return null;
    // The SDK restores the persisted user without asking the server; reload
    // so a revoked session is noticed now, as on Windows.
    try {
      await user.reload();
    } on FirebaseAuthException catch (e) {
      if (_mapCode(e.code) == AuthErrorKind.network) return _toModel(user);
      await _auth.signOut();
      return null;
    }
    return _toModel(_auth.currentUser);
  });

  Future<UserModel> _signedIn(Future<UserCredential> Function() action) =>
      _guard(() async {
        final user = _toModel((await action()).user);
        if (user == null) {
          throw const AuthRemoteException(AuthErrorKind.unknown, 'no user');
        }
        return user;
      });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseAuthException catch (e) {
      throw AuthRemoteException(_mapCode(e.code), e.code);
    } on FirebaseException catch (e) {
      throw AuthRemoteException(AuthErrorKind.unknown, e.code);
    }
  }

  static AuthErrorKind _mapCode(String code) => switch (code) {
    'email-already-in-use' => AuthErrorKind.emailAlreadyInUse,
    'weak-password' => AuthErrorKind.weakPassword,
    'invalid-email' => AuthErrorKind.invalidEmail,
    'invalid-credential' ||
    'INVALID_LOGIN_CREDENTIALS' ||
    'wrong-password' ||
    'user-not-found' ||
    'user-disabled' => AuthErrorKind.invalidCredentials,
    'network-request-failed' => AuthErrorKind.network,
    'user-token-expired' ||
    'invalid-user-token' ||
    'requires-recent-login' => AuthErrorKind.sessionRevoked,
    _ => AuthErrorKind.unknown,
  };

  static UserModel? _toModel(User? user) =>
      user == null ? null : UserModel(id: user.uid, email: user.email ?? '');
}
