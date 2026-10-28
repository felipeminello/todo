// Regenerates every platform app icon from the SVG sources in assets/icon/src.
//
// Usage, from the project root:
//   dart run tool/app_icon/generate.dart                # render + generate (macOS)
//   dart run tool/app_icon/generate.dart --skip-render  # reuse assets/icon/png
//
// See tool/app_icon/README.md for which source feeds which platform file.
import 'dart:io';

import 'src/chrome_renderer.dart';
import 'src/ico_encoder.dart';
import 'src/icon_generation_exception.dart';
import 'src/png_info.dart';
import 'src/render.dart';

const _sourceDir = 'assets/icon/src';
const _masterDir = 'assets/icon/png';
const _launcherIconsConfig = 'flutter_launcher_icons.yaml';
const _macosIconSet = 'macos/Runner/Assets.xcassets/AppIcon.appiconset';
const _windowsIco = 'windows/runner/resources/app_icon.ico';

// Sizes of 32 px and below use the simplified artwork; the rest use the full tile.
const _smallMax = 32;
const _macosSizes = [16, 32, 64, 128, 256, 512, 1024];
const _windowsSizes = [16, 24, 32, 48, 64, 256];

final _renders = <Render>[
  const Render('full', 1024, opaque: true),
  const Render('adaptive_bg', 1024, opaque: true),
  const Render('adaptive_fg', 1024),
  const Render('monochrome', 1024),
  for (final size in {..._macosSizes, ..._windowsSizes})
    Render(size <= _smallMax ? 'small' : 'desktop', size),
];

Future<void> main(List<String> args) async {
  final skipRender = args.contains('--skip-render');
  try {
    _checkProjectRoot();
    if (skipRender) {
      stdout.writeln('Renderização pulada: usando os PNGs de $_masterDir.');
    } else {
      await _renderMasters();
    }
    _checkMasters();
    await _runLauncherIcons();
    _writeMacosIconSet();
    _writeWindowsIco();
    stdout.writeln('Ícones de Android, iOS, macOS e Windows gerados.');
  } on IconGenerationException catch (e) {
    stderr.writeln('Erro: ${e.message}');
    exitCode = 1;
  }
}

void _checkProjectRoot() {
  if (!File('pubspec.yaml').existsSync() ||
      !Directory(_sourceDir).existsSync()) {
    throw const IconGenerationException(
      'Rode o comando a partir da raiz do projeto.',
    );
  }
}

Future<void> _renderMasters() async {
  final renderer = ChromeRenderer.locate();
  Directory(_masterDir).createSync(recursive: true);
  for (final render in _renders) {
    stdout.writeln('Renderizando ${render.pngName}');
    await renderer.render(
      svg: File('$_sourceDir/${render.svgName}'),
      png: File('$_masterDir/${render.pngName}'),
      size: render.size,
    );
  }
}

void _checkMasters() {
  final problems = <String>[];
  for (final render in _renders) {
    final file = File('$_masterDir/${render.pngName}');
    if (!file.existsSync()) {
      problems.add('${render.pngName} não existe');
      continue;
    }
    final info = PngInfo.read(file.readAsBytesSync(), source: file.path);
    if (info.width != render.size || info.height != render.size) {
      problems.add(
        '${render.pngName} tem ${info.width}x${info.height}, '
        'esperado ${render.size}x${render.size}',
      );
    }
    if (info.hasAlpha == render.opaque) {
      problems.add(
        render.opaque
            ? '${render.pngName} deveria ser opaco e tem canal alfa'
            : '${render.pngName} deveria ter fundo transparente e não tem alfa',
      );
    }
  }
  if (problems.isNotEmpty) {
    throw IconGenerationException(
      'PNGs-mestre inválidos:\n  ${problems.join('\n  ')}',
    );
  }
}

Future<void> _runLauncherIcons() async {
  stdout.writeln('Gerando Android e iOS (flutter_launcher_icons)');
  final result = await Process.run('dart', [
    'run',
    'flutter_launcher_icons',
    '-f',
    _launcherIconsConfig,
  ], runInShell: Platform.isWindows);
  if (result.exitCode != 0) {
    throw IconGenerationException(
      'flutter_launcher_icons falhou:\n${result.stdout}${result.stderr}',
    );
  }
}

File _master(int size) =>
    File('$_masterDir/${size <= _smallMax ? 'small' : 'desktop'}_$size.png');

void _writeMacosIconSet() {
  stdout.writeln('Gerando macOS');
  // The file names match the existing Contents.json, which stays untouched.
  for (final size in _macosSizes) {
    _master(size).copySync('$_macosIconSet/app_icon_$size.png');
  }
}

void _writeWindowsIco() {
  stdout.writeln('Gerando Windows');
  final ico = encodeIco([
    for (final size in _windowsSizes) _master(size).readAsBytesSync(),
  ]);
  File(_windowsIco).writeAsBytesSync(ico);
}
