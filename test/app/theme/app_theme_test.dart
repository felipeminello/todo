import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/app/theme/app_theme.dart';
import 'package:todo/features/tasks/presentation/theme/task_status_colors.dart';

/// WCAG 2.x contrast ratio between two opaque colors.
double contrastRatio(Color a, Color b) {
  double luminance(Color c) {
    double channel(double v) => v <= 0.04045
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * channel(c.r) +
        0.7152 * channel(c.g) +
        0.0722 * channel(c.b);
  }

  final la = luminance(a);
  final lb = luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  for (final (name, theme) in [
    ('light', AppTheme.light),
    ('dark', AppTheme.dark),
  ]) {
    group('$name theme', () {
      final overdue = theme.extension<TaskStatusColors>()?.overdue;

      test('registers the overdue color', () {
        expect(overdue, isNotNull);
      });

      test('overdue text has at least 4.5:1 contrast on its surfaces', () {
        final color = overdue ?? Colors.transparent;
        for (final surface in [
          theme.colorScheme.surface,
          theme.scaffoldBackgroundColor,
        ]) {
          expect(
            contrastRatio(color, surface),
            greaterThanOrEqualTo(4.5),
            reason: 'on $surface',
          );
        }
      });
    });
  }
}
