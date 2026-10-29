import 'package:flutter/material.dart';
import 'package:todo/core/ui/brand_colors.dart';
import 'package:todo/l10n/app_localizations.dart';

/// The floating create button, raised like the icon's checked box.
class AddTaskButton extends StatelessWidget {
  const AddTaskButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final brand = BrandColors.of(context);
    const shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(18)),
    );

    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [brand.accentTop, brand.accentBottom],
        ),
        shadows: [
          BoxShadow(color: brand.accentEdge, offset: const Offset(0, 3)),
          BoxShadow(
            color: brand.accentBottom.withValues(alpha: 0.32),
            offset: const Offset(0, 12),
            blurRadius: 24,
          ),
        ],
      ),
      child: FloatingActionButton(
        tooltip: AppLocalizations.of(context).addTaskTooltip,
        onPressed: onPressed,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: shape,
        child: const Icon(Icons.add),
      ),
    );
  }
}
