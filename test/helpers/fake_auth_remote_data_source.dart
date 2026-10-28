import 'package:todo/core/error/exceptions.dart';
import 'package:todo/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:todo/features/auth/data/models/user_model.dart';

/// Accounts shared by every [FakeAuthRemoteDataSource] created from it, so a
/// test can "reopen the app" with a new data source over the same backend.
final class FakeAuthBackend {
  final Map<String, ({String id, String password})> accounts = {};

  /// Session persisted on the device, if any.
  UserModel? savedSession;

  /// When true, the saved session is rejected on the next restore.
  bool revokeSavedSession = false;
}

/// In-memory stand-in for the authentication provider, with Firebase rules:
/// passwords need at least 6 characters.
final class FakeAuthRemoteDataSource implements AuthRemoteDataSource {
  FakeAuthRemoteDataSource([FakeAuthBackend? backend])
    : backend = backend ?? FakeAuthBackend();

  final FakeAuthBackend backend;
  UserModel? _currentUser;

  /// When set, the next call throws it and clears it.
  AuthRemoteException? failNext;

  @override
  UserModel? get currentUser => _currentUser;

  @override
  Future<UserModel> signUp({
    required String email,
    required String password,
  }) async {
    _maybeFail();
    if (backend.accounts.containsKey(email)) {
      throw const AuthRemoteException(AuthErrorKind.emailAlreadyInUse);
    }
    if (password.length < 6) {
      throw const AuthRemoteException(AuthErrorKind.weakPassword);
    }
    final id = 'uid-${backend.accounts.length + 1}';
    backend.accounts[email] = (id: id, password: password);
    return _startSession(UserModel(id: id, email: email));
  }

  @override
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    _maybeFail();
    final account = backend.accounts[email];
    if (account == null || account.password != password) {
      throw const AuthRemoteException(AuthErrorKind.invalidCredentials);
    }
    return _startSession(UserModel(id: account.id, email: email));
  }

  @override
  Future<void> signOut() async {
    _maybeFail();
    _currentUser = null;
    backend.savedSession = null;
  }

  @override
  Future<UserModel?> restoreSession() async {
    _maybeFail();
    if (backend.revokeSavedSession) {
      backend
        ..savedSession = null
        ..revokeSavedSession = false;
    }
    return _currentUser = backend.savedSession;
  }

  UserModel _startSession(UserModel user) {
    backend.savedSession = user;
    return _currentUser = user;
  }

  void _maybeFail() {
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
  }
}
