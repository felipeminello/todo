import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:todo/app/theme/app_typography.dart';

/// Manrope for headings and Inter for everything else, downloaded on first
/// use and cached by `google_fonts`. Until then the platform font shows.
final class GoogleFontsTypography implements AppTypography {
  const GoogleFontsTypography();

  // Styles go one by one: the package's TextTheme helpers return the type
  // from `material_ui`, not the one from `flutter/material`.
  @override
  TextTheme apply(TextTheme base) {
    TextStyle? heading(TextStyle? style) =>
        style == null ? null : GoogleFonts.manrope(textStyle: style);
    TextStyle? body(TextStyle? style) =>
        style == null ? null : GoogleFonts.inter(textStyle: style);

    return base.copyWith(
      displayLarge: heading(base.displayLarge),
      displayMedium: heading(base.displayMedium),
      displaySmall: heading(base.displaySmall),
      headlineLarge: heading(base.headlineLarge),
      headlineMedium: heading(base.headlineMedium),
      headlineSmall: heading(base.headlineSmall),
      titleLarge: heading(base.titleLarge),
      titleMedium: body(base.titleMedium),
      titleSmall: body(base.titleSmall),
      bodyLarge: body(base.bodyLarge),
      bodyMedium: body(base.bodyMedium),
      bodySmall: body(base.bodySmall),
      labelLarge: body(base.labelLarge),
      labelMedium: body(base.labelMedium),
      labelSmall: body(base.labelSmall),
    );
  }
}
