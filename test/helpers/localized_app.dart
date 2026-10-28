import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:todo/app/theme/app_theme.dart';
import 'package:todo/l10n/app_localizations.dart';

/// A [MaterialApp] configured like the real one: pt_BR and the app theme.
Widget localizedApp({required Widget home, ThemeData? theme}) {
  return MaterialApp(
    locale: const Locale('pt', 'BR'),
    supportedLocales: const [Locale('pt', 'BR')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: theme ?? AppTheme.light,
    home: home,
  );
}
