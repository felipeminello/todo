import 'package:flutter/material.dart';

/// Colors of the app icon's look (soft gradients, stacked cards and raised
/// edges) that the Material color scheme has no role for.
@immutable
class BrandColors extends ThemeExtension<BrandColors> {
  const BrandColors({
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.glow,
    required this.cardTop,
    required this.cardBottom,
    required this.cardEdge,
    required this.shadow,
    required this.stackBackTop,
    required this.stackBackBottom,
    required this.stackMiddleTop,
    required this.stackMiddleBottom,
    required this.accentTop,
    required this.accentBottom,
    required this.accentEdge,
    required this.dangerTop,
    required this.dangerBottom,
    required this.dangerEdge,
    required this.raisedTop,
    required this.raisedBottom,
    required this.raisedEdge,
    required this.divider,
    required this.rail,
    required this.placeholder,
    required this.placeholderSoft,
    required this.highlightTop,
    required this.highlightBottom,
    required this.onHighlight,
  });

  static const light = BrandColors(
    backgroundTop: Color(0xFFFFFFFF),
    backgroundBottom: Color(0xFFDCE4F2),
    glow: Color(0xE6FFFFFF),
    cardTop: Color(0xFFFFFFFF),
    cardBottom: Color(0xFFF1F4FA),
    cardEdge: Color(0xFFC9D3E6),
    shadow: Color(0x1A162C63),
    stackBackTop: Color(0xFFD3DDEE),
    stackBackBottom: Color(0xFFBAC8E2),
    stackMiddleTop: Color(0xFF9DB8F2),
    stackMiddleBottom: Color(0xFF6A8FE4),
    accentTop: Color(0xFF3D72EC),
    accentBottom: Color(0xFF1E4FD8),
    accentEdge: Color(0xFF163A9E),
    dangerTop: Color(0xFFD9434A),
    dangerBottom: Color(0xFFB3232A),
    dangerEdge: Color(0xFF8A1A20),
    raisedTop: Color(0xFFFFFFFF),
    raisedBottom: Color(0xFFE9EEF6),
    raisedEdge: Color(0xFFC3CEE3),
    divider: Color(0xFFE3E8F1),
    rail: Color(0xFFC3CEE3),
    placeholder: Color(0xFFD3DCEC),
    placeholderSoft: Color(0xFFE5EBF5),
    highlightTop: Color(0xFFEEF3FD),
    highlightBottom: Color(0xFFDDE7FA),
    onHighlight: Color(0xFF1A3FA8),
  );

  static const dark = BrandColors(
    backgroundTop: Color(0xFF141D2E),
    backgroundBottom: Color(0xFF0B1120),
    glow: Color(0x0FFFFFFF),
    cardTop: Color(0xFF1C2639),
    cardBottom: Color(0xFF172033),
    cardEdge: Color(0xFF0A0F1A),
    shadow: Color(0x66000000),
    stackBackTop: Color(0xFF2A3650),
    stackBackBottom: Color(0xFF222D44),
    stackMiddleTop: Color(0xFF3F63C2),
    stackMiddleBottom: Color(0xFF2F4FA6),
    accentTop: Color(0xFF4A7BF0),
    accentBottom: Color(0xFF2A5BDC),
    accentEdge: Color(0xFF17378F),
    dangerTop: Color(0xFFE0525A),
    dangerBottom: Color(0xFFB8303A),
    dangerEdge: Color(0xFF7A1A20),
    raisedTop: Color(0xFF263248),
    raisedBottom: Color(0xFF1E293D),
    raisedEdge: Color(0xFF0D1320),
    divider: Color(0xFF263248),
    rail: Color(0xFF2E3A55),
    placeholder: Color(0xFF2A3650),
    placeholderSoft: Color(0xFF222D44),
    highlightTop: Color(0xFF22355F),
    highlightBottom: Color(0xFF1C2C50),
    onHighlight: Color(0xFFC9D8FF),
  );

  final Color backgroundTop;
  final Color backgroundBottom;
  final Color glow;
  final Color cardTop;
  final Color cardBottom;
  final Color cardEdge;
  final Color shadow;
  final Color stackBackTop;
  final Color stackBackBottom;
  final Color stackMiddleTop;
  final Color stackMiddleBottom;
  final Color accentTop;
  final Color accentBottom;
  final Color accentEdge;
  final Color dangerTop;
  final Color dangerBottom;
  final Color dangerEdge;
  final Color raisedTop;
  final Color raisedBottom;
  final Color raisedEdge;
  final Color divider;
  final Color rail;
  final Color placeholder;
  final Color placeholderSoft;
  final Color highlightTop;
  final Color highlightBottom;
  final Color onHighlight;

  static BrandColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<BrandColors>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  // The palette is only ever swapped whole, between the light and dark sets.
  @override
  BrandColors copyWith() => this;

  // A theme switch snaps to the other palette halfway instead of blending
  // two dozen gradient stops.
  @override
  BrandColors lerp(BrandColors? other, double t) {
    if (other == null) return this;
    return t < 0.5 ? this : other;
  }
}
