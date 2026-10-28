/// Lets per-user storage find the signed-in user without depending on the
/// whole authentication API.
abstract interface class CurrentUserIdProvider {
  /// `null` when nobody is signed in.
  String? get currentUserId;
}
