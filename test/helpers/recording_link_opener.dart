import 'package:todo/core/links/link_opener.dart';

/// Records the links it is asked to open instead of leaving the app.
final class RecordingLinkOpener implements LinkOpener {
  final opened = <Uri>[];

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return true;
  }
}
