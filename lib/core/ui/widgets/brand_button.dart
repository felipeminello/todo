import 'package:flutter/material.dart';
import 'package:todo/core/ui/brand_colors.dart';

enum BrandButtonVariant { primary, secondary, danger }

/// A [FilledButton] on a raised gradient, like the checked box in the icon.
class BrandButton extends StatelessWidget {
  const BrandButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
    this.variant = BrandButtonVariant.primary,
    this.foregroundColor,
    this.height = 54,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final Widget? icon;
  final BrandButtonVariant variant;

  /// Overrides the label color of the variant.
  final Color? foregroundColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final brand = BrandColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final (top, bottom, edge, foreground, glows) = switch (variant) {
      BrandButtonVariant.primary => (
        brand.accentTop,
        brand.accentBottom,
        brand.accentEdge,
        Colors.white,
        true,
      ),
      BrandButtonVariant.danger => (
        brand.dangerTop,
        brand.dangerBottom,
        brand.dangerEdge,
        Colors.white,
        true,
      ),
      BrandButtonVariant.secondary => (
        brand.raisedTop,
        brand.raisedBottom,
        brand.raisedEdge,
        scheme.onSurface,
        false,
      ),
    };
    final label = foregroundColor ?? foreground;
    final radius = BorderRadius.circular(16);
    final icon = this.icon;

    return Opacity(
      opacity: onPressed == null ? 0.6 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [top, bottom],
          ),
          boxShadow: [
            BoxShadow(color: edge, offset: const Offset(0, 3)),
            BoxShadow(
              color: glows
                  ? bottom.withValues(alpha: 0.28)
                  : brand.shadow.withValues(alpha: 0.08),
              offset: const Offset(0, 10),
              blurRadius: 20,
            ),
          ],
        ),
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: label,
            disabledForegroundColor: label,
            shadowColor: Colors.transparent,
            minimumSize: Size(0, height),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            shape: RoundedRectangleBorder(borderRadius: radius),
          ),
          child: icon == null
              ? child
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [icon, const SizedBox(width: 8), child],
                ),
        ),
      ),
    );
  }
}
