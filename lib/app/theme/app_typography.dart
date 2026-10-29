import 'package:flutter/material.dart';

/// Puts the brand typefaces on a text theme whose sizes and weights are
/// already final: some font sources bake the weight into the loaded family.
abstract interface class AppTypography {
  TextTheme apply(TextTheme base);
}

/// Keeps the platform font. Used where fonts cannot be downloaded, as in
/// tests.
final class PlatformTypography implements AppTypography {
  const PlatformTypography();

  @override
  TextTheme apply(TextTheme base) => base;
}
