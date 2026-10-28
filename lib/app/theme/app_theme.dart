import 'package:flutter/material.dart';
import 'package:todo/features/tasks/presentation/theme/task_status_colors.dart';

abstract final class AppTheme {
  static const _seed = Colors.deepPurple;

  static ThemeData get light => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: _seed),
    extensions: const [TaskStatusColors.light],
  );

  static ThemeData get dark => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    ),
    extensions: const [TaskStatusColors.dark],
  );
}
