import 'package:flutter/material.dart';
import 'package:todo/core/ui/brand_colors.dart';

/// The app icon drawn with widgets: a stack of cards whose front card holds
/// task rows, or a [badge] instead of them.
class TaskStackIllustration extends StatelessWidget {
  const TaskStackIllustration({
    super.key,
    this.width = 150,
    this.rows = const [true, false],
    this.muted = false,
    this.badge,
  });

  /// Drawn at [_baseSize] and scaled, so proportions stay those of the icon.
  final double width;

  /// One row per entry; `true` draws a checked box.
  final List<bool> rows;

  /// Silver cards only, for states where nothing is going well.
  final bool muted;
  final Widget? badge;

  static const _baseSize = Size(150, 122);

  @override
  Widget build(BuildContext context) {
    final brand = BrandColors.of(context);
    final badge = this.badge;
    final middle = muted
        ? [brand.stackBackTop, brand.stackBackBottom]
        : [brand.stackMiddleTop, brand.stackMiddleBottom];

    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: width * _baseSize.height / _baseSize.width,
        child: FittedBox(
          child: SizedBox.fromSize(
            size: _baseSize,
            child: Stack(
              children: [
                Positioned(
                  left: 26,
                  top: 0,
                  width: 98,
                  height: 50,
                  child: _Layer(
                    radius: 16,
                    colors: [brand.placeholderSoft, brand.placeholder],
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 15,
                  width: 126,
                  height: 60,
                  child: _Layer(radius: 18, colors: middle),
                ),
                Positioned(
                  left: 0,
                  top: 34,
                  width: 150,
                  height: 84,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [brand.cardTop, brand.cardBottom],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: brand.cardEdge,
                          offset: const Offset(0, 5),
                        ),
                        BoxShadow(
                          color: brand.shadow,
                          offset: const Offset(0, 16),
                          blurRadius: 28,
                        ),
                      ],
                    ),
                    child: badge != null
                        ? Center(child: badge)
                        : Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                for (final checked in rows.take(2))
                                  _Row(checked: checked),
                              ],
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Layer extends StatelessWidget {
  const _Layer({required this.radius, required this.colors});

  final double radius;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    final brand = BrandColors.of(context);

    return Row(
      children: [
        SizedBox.square(
          dimension: 24,
          child: DecoratedBox(
            decoration: checked
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(7),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [brand.accentTop, brand.accentBottom],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: brand.accentEdge,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  )
                : BoxDecoration(
                    borderRadius: BorderRadius.circular(7),
                    color: brand.cardTop,
                    border: Border.all(color: brand.rail, width: 3),
                  ),
            child: checked
                ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Bar(width: 62, height: 7, color: brand.placeholder),
            const SizedBox(height: 5),
            _Bar(width: 40, height: 6, color: brand.placeholderSoft),
          ],
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.width, required this.height, required this.color});

  final double width;
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
          borderRadius: BorderRadius.circular(height / 2),
        ),
      ),
    );
  }
}
