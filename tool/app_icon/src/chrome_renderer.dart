import 'dart:io';

import 'icon_generation_exception.dart';
import 'png_image.dart';

/// Rasterises an SVG to a PNG of exact size with headless Google Chrome.
///
/// Chrome rendered the approved preview, so blur filters, masks and gradients
/// come out exactly as approved.
class ChromeRenderer {
  const ChromeRenderer(this.executable);

  static const _paintMargin = 128;

  static const _macosChrome =
      '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

  final String executable;

  /// Uses the CHROME environment variable, or the default macOS install.
  static ChromeRenderer locate() {
    final fromEnv = Platform.environment['CHROME'];
    if (fromEnv != null && fromEnv.isNotEmpty) return ChromeRenderer(fromEnv);
    if (Platform.isMacOS && File(_macosChrome).existsSync()) {
      return const ChromeRenderer(_macosChrome);
    }
    throw const IconGenerationException(
      'Google Chrome não encontrado. Defina a variável CHROME com o caminho '
      'do executável, ou rode com --skip-render para usar os PNGs versionados.',
    );
  }

  Future<void> render({
    required File svg,
    required File png,
    required int size,
  }) async {
    if (png.existsSync()) png.deleteSync();
    final temp = await Directory.systemTemp.createTemp('app_icon_');
    try {
      final page = File('${temp.path}/page.html');
      final shot = File('${temp.path}/shot.png');
      await page.writeAsString(
        '<!doctype html><html><body style="margin:0;background:transparent">'
        '<img src="${svg.absolute.uri}" '
        'style="display:block;width:${size}px;height:${size}px">'
        '</body></html>',
      );
      final result = await Process.run(executable, [
        '--headless=new',
        '--disable-gpu',
        '--hide-scrollbars',
        '--allow-file-access-from-files',
        '--force-device-scale-factor=1',
        '--default-background-color=00000000',
        // A throwaway profile keeps the user's running Chrome out of the way.
        '--user-data-dir=${temp.path}/profile',
        // Headless Chrome leaves the bottom ~30 rows of the window unpainted,
        // and how many varies per run. Render taller and keep the top square.
        '--window-size=$size,${size + _paintMargin}',
        '--screenshot=${shot.path}',
        page.uri.toString(),
      ]);
      if (result.exitCode != 0 || !shot.existsSync()) {
        throw IconGenerationException(
          'O Chrome não renderizou ${svg.path} em $size px.\n${result.stderr}',
        );
      }
      var image = PngImage.decode(shot.readAsBytesSync())
          .cropTopLeft(size, size);
      // Opaque art loses the alpha channel, which iOS rejects.
      if (image.isOpaque) image = image.withoutAlpha();
      png.writeAsBytesSync(image.encode());
    } finally {
      await temp.delete(recursive: true);
    }
  }
}
