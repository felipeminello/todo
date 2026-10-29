import 'package:flutter/material.dart';
import 'package:todo/core/ui/brand_colors.dart';

/// A round [IconButton] on a raised face.
class RaisedIconButton extends StatelessWidget {
  const RaisedIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final brand = BrandColors.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [brand.raisedTop, brand.raisedBottom],
        ),
        boxShadow: [
          BoxShadow(color: brand.raisedEdge, offset: const Offset(0, 2)),
          BoxShadow(
            color: brand.shadow,
            offset: const Offset(0, 6),
            blurRadius: 14,
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 20),
        tooltip: tooltip,
        onPressed: onPressed,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
