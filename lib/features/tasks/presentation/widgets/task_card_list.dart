import 'package:flutter/material.dart';
import 'package:todo/core/ui/widgets/card_stack.dart';
import 'package:todo/core/ui/widgets/raised_card.dart';

/// Task tiles on one raised card, separated by hairlines.
class TaskCardList extends StatelessWidget {
  const TaskCardList({super.key, required this.tiles, this.stacked = false});

  final List<Widget> tiles;

  /// Shows cards peeking out behind, as in the app icon.
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        children: [
          for (final (index, tile) in tiles.indexed) ...[
            if (index > 0) const Divider(indent: 52, endIndent: 16),
            tile,
          ],
        ],
      ),
    );

    return stacked ? CardStack(child: content) : RaisedCard(child: content);
  }
}
