import 'package:flutter/material.dart';
import 'package:todo/core/ui/brand_colors.dart';

/// The icon's backdrop: a vertical wash with a soft glow at the top left.
class BrandBackground extends StatelessWidget {
  const BrandBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brand = BrandColors.of(context);

    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [brand.backgroundTop, brand.backgroundBottom],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.7, -1),
              radius: 1.2,
              colors: [brand.glow, brand.glow.withValues(alpha: 0)],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
