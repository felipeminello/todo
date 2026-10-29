import 'package:flutter/material.dart';
import 'package:todo/core/ui/brand_colors.dart';
import 'package:todo/core/ui/widgets/raised_card.dart';

/// A [RaisedCard] with two narrower cards peeking out behind it, like the
/// stack in the app icon.
class CardStack extends StatelessWidget {
  const CardStack({super.key, required this.child, this.inset = 18});

  final Widget child;

  /// How much narrower each card behind is, per side.
  final double inset;

  @override
  Widget build(BuildContext context) {
    final brand = BrandColors.of(context);

    return Stack(
      children: [
        Positioned(
          top: 0,
          left: inset * 2,
          right: inset * 2,
          height: 40,
          child: _Peek(
            radius: 16,
            colors: [brand.stackBackTop, brand.stackBackBottom],
          ),
        ),
        Positioned(
          top: 7,
          left: inset,
          right: inset,
          height: 40,
          child: _Peek(
            radius: 18,
            colors: [brand.stackMiddleTop, brand.stackMiddleBottom],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: RaisedCard(child: child),
        ),
      ],
    );
  }
}

class _Peek extends StatelessWidget {
  const _Peek({required this.radius, required this.colors});

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
