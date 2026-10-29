import 'package:flutter/material.dart';
import 'package:todo/core/ui/brand_colors.dart';

/// The icon's front card: a light face over a solid bottom edge, so it reads
/// as a thick, raised sheet.
class RaisedCard extends StatelessWidget {
  const RaisedCard({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.radius = 22,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final brand = BrandColors.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [brand.cardTop, brand.cardBottom],
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(color: brand.cardEdge, offset: const Offset(0, 4)),
          BoxShadow(
            color: brand.shadow,
            offset: const Offset(0, 14),
            blurRadius: 28,
          ),
        ],
      ),
      // Lets ink splashes of the content paint on the card face.
      child: Material(
        type: MaterialType.transparency,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
