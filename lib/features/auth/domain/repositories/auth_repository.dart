import 'package:todo/features/auth/domain/entities/app_user.dart';

/// Email and password accounts. Every method throws only `AuthFailure`.
abstract interface class AuthRepository {
  Future<AppUser> signUp({required String email, required String password});

  Future<AppUser> signIn({required String email, required String password});

  Future<void> signOut();

  /// The user of the session saved on this device, or `null` if there is
  /// none or the provider revoked it. A network failure keeps the session.
  Future<AppUser?> restoreSession();

  AppUser? get currentUser;
}
