import 'package:todo/features/auth/data/models/user_model.dart';

/// Email and password authentication backend. Throws only
/// `AuthRemoteException`.
abstract interface class AuthRemoteDataSource {
  Future<UserModel> signUp({required String email, required String password});

  Future<UserModel> signIn({required String email, required String password});

  Future<void> signOut();

  /// The user of the session persisted on this device. Returns `null` when
  /// there is none or the provider revoked it; keeps the session when the
  /// renewal fails only for lack of network.
  Future<UserModel?> restoreSession();

  UserModel? get currentUser;
}
