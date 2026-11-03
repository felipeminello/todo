import 'package:flutter/material.dart';
import 'package:todo/core/ui/brand_colors.dart';
import 'package:todo/core/ui/widgets/raised_icon_button.dart';
import 'package:todo/features/tasks/presentation/widgets/task_card_list.dart';
import 'package:todo/l10n/app_localizations.dart';

/// Completed tasks behind a toggle, collapsed until opened, with a button
/// beside it to delete them all. Give it a [PageStorageKey] to keep it open
/// while the list scrolls.
class CompletedSection extends StatefulWidget {
  const CompletedSection({
    super.key,
    required this.tiles,
    required this.onDeleteAll,
  });

  final List<Widget> tiles;
  final VoidCallback onDeleteAll;

  @override
  State<CompletedSection> createState() => _CompletedSectionState();
}

class _CompletedSectionState extends State<CompletedSection> {
  late bool _expanded =
      PageStorage.maybeOf(context)?.readState(context) as bool? ?? false;

  void _toggle() {
    setState(() => _expanded = !_expanded);
    PageStorage.maybeOf(context)?.writeState(context, _expanded);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _CompletedToggle(
                count: widget.tiles.length,
                expanded: _expanded,
                onTap: _toggle,
              ),
            ),
            const SizedBox(width: 10),
            RaisedIconButton(
              icon: Icons.delete_sweep_outlined,
              tooltip: l10n.completedDeleteTooltip,
              onPressed: widget.onDeleteAll,
            ),
          ],
        ),
        if (_expanded) ...[
          const SizedBox(height: 12),
          TaskCardList(tiles: widget.tiles),
        ],
      ],
    );
  }
}

class _CompletedToggle extends StatelessWidget {
  const _CompletedToggle({
    required this.count,
    required this.expanded,
    required this.onTap,
  });

  final int count;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final brand = BrandColors.of(context);
    final radius = BorderRadius.circular(16);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [brand.raisedTop, brand.raisedBottom],
        ),
        boxShadow: [
          BoxShadow(color: brand.raisedEdge, offset: const Offset(0, 3)),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Semantics(
          button: true,
          expanded: expanded,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.tasksCompletedHeader(count),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontSize: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.expand_more,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
