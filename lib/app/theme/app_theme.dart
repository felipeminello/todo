import 'package:flutter/material.dart';
import 'package:todo/app/theme/app_typography.dart';
import 'package:todo/core/ui/brand_colors.dart';
import 'package:todo/features/tasks/presentation/theme/task_status_colors.dart';

/// Blue and silver, in the look of the app icon.
abstract final class AppTheme {
  static const _seed = Color(0xFF1E4FD8);

  static ThemeData light([
    AppTypography typography = const PlatformTypography(),
  ]) => _build(
    scheme: ColorScheme.fromSeed(seedColor: _seed).copyWith(
      primary: _seed,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFE3EBFB),
      onPrimaryContainer: const Color(0xFF1A3FA8),
      surface: Colors.white,
      onSurface: const Color(0xFF0E1726),
      onSurfaceVariant: const Color(0xFF556071),
      outline: const Color(0xFF7F93B5),
      outlineVariant: const Color(0xFFD5DBE3),
      error: const Color(0xFFB3232A),
      onError: Colors.white,
      errorContainer: const Color(0xFFFCE5E6),
      onErrorContainer: const Color(0xFF8E1A20),
      inverseSurface: const Color(0xFF0E1726),
      onInverseSurface: const Color(0xFFEEF1F5),
    ),
    brand: BrandColors.light,
    status: TaskStatusColors.light,
    typography: typography,
  );

  static ThemeData dark([
    AppTypography typography = const PlatformTypography(),
  ]) => _build(
    scheme: ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark)
        .copyWith(
          primary: const Color(0xFF8CADFF),
          onPrimary: const Color(0xFF0B1A44),
          primaryContainer: const Color(0xFF22355F),
          onPrimaryContainer: const Color(0xFFC9D8FF),
          surface: const Color(0xFF1C2639),
          onSurface: const Color(0xFFE6EBF3),
          onSurfaceVariant: const Color(0xFFA9B4C5),
          outline: const Color(0xFF7F93B5),
          outlineVariant: const Color(0xFF2E3A55),
          error: const Color(0xFFFF8A8F),
          onError: const Color(0xFF4A0A0E),
          errorContainer: const Color(0xFF4A1C20),
          onErrorContainer: const Color(0xFFFFD9DB),
          inverseSurface: const Color(0xFFE6EBF3),
          onInverseSurface: const Color(0xFF0E1726),
        ),
    brand: BrandColors.dark,
    status: TaskStatusColors.dark,
    typography: typography,
  );

  static ThemeData _build({
    required ColorScheme scheme,
    required BrandColors brand,
    required TaskStatusColors status,
    required AppTypography typography,
  }) {
    final textTheme = typography.apply(
      _sized(ThemeData(colorScheme: scheme).textTheme),
    );
    final fieldRadius = BorderRadius.circular(16);
    OutlineInputBorder field(Color color, double width) => OutlineInputBorder(
      borderRadius: fieldRadius,
      borderSide: BorderSide(color: color, width: width),
    );

    return ThemeData(
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: brand.backgroundBottom,
      extensions: [brand, status],
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brand.cardTop,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: field(scheme.outline, 1.5),
        enabledBorder: field(scheme.outline, 1.5),
        focusedBorder: field(scheme.primary, 2),
        errorBorder: field(scheme.error, 1.5),
        focusedErrorBorder: field(scheme.error, 2),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: WidgetStateBorderSide.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? BorderSide.none
              : BorderSide(color: scheme.outline, width: 2),
        ),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(scheme.onPrimary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: brand.cardTop,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: const Color(0x660E1726),
        showDragHandle: true,
        dragHandleColor: brand.rail,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(color: brand.divider, space: 1),
    );
  }

  /// The type scale of the design. Weights are set here, before the
  /// typefaces, so the right font files are loaded.
  static TextTheme _sized(TextTheme base) => base.copyWith(
    headlineLarge: base.headlineLarge?.copyWith(
      fontSize: 32,
      height: 38 / 32,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.6,
    ),
    headlineMedium: base.headlineMedium?.copyWith(
      fontSize: 30,
      height: 36 / 30,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
    ),
    titleLarge: base.titleLarge?.copyWith(
      fontSize: 22,
      height: 28 / 22,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.2,
    ),
    titleMedium: base.titleMedium?.copyWith(
      fontSize: 15,
      height: 22 / 15,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
    titleSmall: base.titleSmall?.copyWith(
      fontSize: 13,
      height: 18 / 13,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
    ),
    bodyLarge: base.bodyLarge?.copyWith(
      fontSize: 16,
      height: 24 / 16,
      letterSpacing: 0,
    ),
    bodyMedium: base.bodyMedium?.copyWith(
      fontSize: 15,
      height: 22 / 15,
      letterSpacing: 0,
    ),
    bodySmall: base.bodySmall?.copyWith(
      fontSize: 13,
      height: 18 / 13,
      letterSpacing: 0,
    ),
    labelLarge: base.labelLarge?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
    labelMedium: base.labelMedium?.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
    ),
    labelSmall: base.labelSmall?.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
    ),
  );
}
