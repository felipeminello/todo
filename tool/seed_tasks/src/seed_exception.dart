/// A failure the seeder reports to the user and exits on.
class SeedException implements Exception {
  const SeedException(this.message);

  final String message;

  @override
  String toString() => message;
}
