/// One PNG rendered from an SVG source at its final size.
class Render {
  const Render(this.source, this.size, {this.opaque = false});

  /// SVG base name in `assets/icon/src/`.
  final String source;
  final int size;

  /// Opaque renders must have no alpha channel (iOS rejects it); the others
  /// must keep one, or the transparent background was lost.
  final bool opaque;

  String get svgName => '$source.svg';
  String get pngName => '${source}_$size.png';
}
