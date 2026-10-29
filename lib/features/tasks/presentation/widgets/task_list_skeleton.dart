import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:todo/core/ui/brand_colors.dart';
import 'package:todo/core/ui/widgets/card_stack.dart';
import 'package:todo/core/ui/widgets/raised_card.dart';
import 'package:todo/features/tasks/presentation/widgets/task_timeline_view.dart';
import 'package:todo/l10n/app_localizations.dart';

/// The shape of the list in placeholder bars while it loads.
class TaskListSkeleton extends StatelessWidget {
  const TaskListSkeleton({super.key, this.horizontalPadding = 20});

  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final brand = BrandColors.of(context);

    return Semantics(
      label: AppLocalizations.of(context).loadingLabel,
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final side = math.max(
              horizontalPadding,
              (constraints.maxWidth - TaskTimelineView.maxContentWidth) / 2,
            );
            return ListView(
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(side, 4, side, 0),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: _Bar(width: 120, height: 12, color: brand.placeholder),
                ),
                const SizedBox(height: 12),
                const CardStack(child: _Rows(widths: [0.72, 0.58])),
                const SizedBox(height: 22),
                const _Day(widths: [0.62, 0.78], hasRail: true),
                const SizedBox(height: 22),
                const _Day(widths: [0.5], hasRail: false),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Day extends StatelessWidget {
  const _Day({required this.widths, required this.hasRail});

  final List<double> widths;
  final bool hasRail;

  @override
  Widget build(BuildContext context) {
    final brand = BrandColors.of(context);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                _Bar(width: 28, height: 20, color: brand.placeholder),
                const SizedBox(height: 6),
                _Bar(width: 24, height: 10, color: brand.placeholder),
                if (hasRail)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.only(top: 8),
                      color: brand.rail,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RaisedCard(child: _Rows(widths: widths)),
          ),
        ],
      ),
    );
  }
}

class _Rows extends StatelessWidget {
  const _Rows({required this.widths});

  /// Width of each title bar, as a fraction of the room left for it.
  final List<double> widths;

  @override
  Widget build(BuildContext context) {
    final brand = BrandColors.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          for (final width in widths)
            SizedBox(
              height: 62,
              child: Row(
                children: [
                  _Bar(width: 26, height: 26, color: brand.placeholderSoft),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: width,
                      child: _Bar(height: 12, color: brand.placeholder),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({this.width, required this.height, required this.color});

  final double? width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(math.min(height / 2, 8)),
        ),
      ),
    );
  }
}
