/// Opens a link outside the app, in the browser or the app that handles it.
abstract interface class LinkOpener {
  /// Completes with `false` when [uri] could not be opened.
  Future<bool> open(Uri uri);
}
