import 'dart:io';

import 'seed_exception.dart';

const _optionsPath = 'lib/firebase_options.dart';

/// Web API key and project of the Firebase app.
final class FirebaseConfig {
  const FirebaseConfig({required this.apiKey, required this.projectId});

  /// Reads the Windows options from `lib/firebase_options.dart`, so the seeder
  /// never drifts from `flutterfire configure`. That file imports
  /// `firebase_core`, which needs Flutter, so it is parsed instead of
  /// imported. The Windows key is the web one, the only kind the REST APIs
  /// accept from outside an Android or iOS app.
  factory FirebaseConfig.fromProject() {
    final file = File(_optionsPath);
    if (!file.existsSync()) {
      throw const SeedException('Rode o comando a partir da raiz do projeto.');
    }
    final block = RegExp(
      r'FirebaseOptions windows = FirebaseOptions\(([^)]*)\)',
    ).firstMatch(file.readAsStringSync())?.group(1);
    final apiKey = block == null ? null : _field(block, 'apiKey');
    final projectId = block == null ? null : _field(block, 'projectId');
    if (apiKey == null || projectId == null) {
      throw const SeedException(
        'Não encontrei apiKey e projectId das opções do Windows em '
        '$_optionsPath.',
      );
    }
    return FirebaseConfig(apiKey: apiKey, projectId: projectId);
  }

  final String apiKey;
  final String projectId;

  static String? _field(String block, String name) =>
      RegExp("$name: '([^']+)'").firstMatch(block)?.group(1);
}
