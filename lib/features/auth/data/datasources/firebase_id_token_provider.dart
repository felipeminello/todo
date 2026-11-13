import 'package:firebase_auth/firebase_auth.dart';
import 'package:todo/core/error/exceptions.dart';
import 'package:todo/features/auth/data/datasources/id_token_provider.dart';

/// Android, iOS and macOS: the ID token kept and renewed by the FlutterFire
/// SDK.
final class FirebaseIdTokenProvider implements IdTokenProvider {
  const FirebaseIdTokenProvider(this._auth);

  final FirebaseAuth _auth;

  @override
  Future<String> idToken({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const RemoteException(RemoteErrorKind.unauthenticated);
    }
    try {
      final token = await user.getIdToken(forceRefresh);
      if (token == null) {
        throw const RemoteException(RemoteErrorKind.unauthenticated);
      }
      return token;
    } on FirebaseAuthException catch (e) {
      throw RemoteException(
        e.code == 'network-request-failed'
            ? RemoteErrorKind.network
            : RemoteErrorKind.unauthenticated,
        e.code,
      );
    } on FirebaseException catch (e) {
      throw RemoteException(RemoteErrorKind.unknown, e.code);
    }
  }
}
