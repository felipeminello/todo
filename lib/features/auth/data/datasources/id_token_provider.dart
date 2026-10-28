/// Supplies the bearer token for REST calls made on behalf of the signed-in
/// user. Throws only `RemoteException`.
abstract interface class IdTokenProvider {
  /// A valid ID token, renewed first when it is about to expire or when
  /// [forceRefresh] is set (e.g. after the server answered 401).
  Future<String> idToken({bool forceRefresh = false});
}
