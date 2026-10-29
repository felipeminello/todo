import 'package:flutter/material.dart';
import 'package:todo/core/ui/brand_colors.dart';
import 'package:todo/features/tasks/presentation/widgets/task_card_list.dart';
import 'package:todo/l10n/app_localizations.dart';

/// Completed tasks behind a toggle, collapsed until opened. Give it a
/// [PageStorageKey] to keep it open while the list scrolls.
class CompletedSection extends StatefulWidget {
  const CompletedSection({super.key, required this.tiles});

  final List<Widget> tiles;

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
    final theme = Theme.of(context);
    final brand = BrandColors.of(context);
    final radius = BorderRadius.circular(16);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
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
              expanded: _expanded,
              child: InkWell(
                onTap: _toggle,
                borderRadius: radius,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.tasksCompletedHeader(widget.tiles.length),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontSize: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        AnimatedRotation(
                          turns: _expanded ? 0.5 : 0,
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
        ),
        if (_expanded) ...[
          const SizedBox(height: 12),
          TaskCardList(tiles: widget.tiles),
        ],
      ],
    );
  }
}
