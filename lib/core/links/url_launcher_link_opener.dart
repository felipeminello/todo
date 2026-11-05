import 'package:todo/core/links/link_opener.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens web and e-mail links with the platform's default app.
final class UrlLauncherLinkOpener implements LinkOpener {
  const UrlLauncherLinkOpener();

  // Task text is user content: other schemes could start arbitrary apps or
  // reach local files.
  static const _allowedSchemes = {'http', 'https', 'mailto'};

  @override
  Future<bool> open(Uri uri) async {
    if (!_allowedSchemes.contains(uri.scheme.toLowerCase())) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Exception {
      return false;
    }
  }
}
