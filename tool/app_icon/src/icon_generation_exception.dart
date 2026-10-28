/// A failure the generator reports to the user and exits on.
class IconGenerationException implements Exception {
  const IconGenerationException(this.message);

  final String message;

  @override
  String toString() => message;
}
