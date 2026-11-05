import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/links/url_launcher_link_opener.dart';

void main() {
  for (final link in [
    'file:///etc/passwd',
    'javascript:alert(1)',
    'tel:+5511999999999',
    'ms-settings:privacy',
  ]) {
    test('refuses $link without asking the platform', () async {
      expect(
        await const UrlLauncherLinkOpener().open(Uri.parse(link)),
        isFalse,
      );
    });
  }
}
