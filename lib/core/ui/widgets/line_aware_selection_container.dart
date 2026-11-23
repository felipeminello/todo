import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Makes text copied from [child] keep the layout's line breaks.
///
/// Flutter joins the text of separate widgets (a title and a description,
/// paragraphs, list items) with nothing in between, so everything copied
/// lands on a single line. This container joins pieces on the same line
/// (a bullet and its item) with a space, consecutive list items with a line
/// break, and blocks with space between them (paragraphs, sections) with a
/// blank line.
///
/// Place it inside a [SelectionArea], around the selectable content.
class LineAwareSelectionContainer extends StatefulWidget {
  const LineAwareSelectionContainer({super.key, required this.child});

  final Widget child;

  @override
  State<LineAwareSelectionContainer> createState() =>
      _LineAwareSelectionContainerState();
}

class _LineAwareSelectionContainerState
    extends State<LineAwareSelectionContainer> {
  final _delegate = LineAwareSelectionContainerDelegate();

  @override
  void dispose() {
    _delegate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SelectionContainer(delegate: _delegate, child: widget.child);
}

/// The [SelectionContainerDelegate] behind [LineAwareSelectionContainer].
class LineAwareSelectionContainerDelegate
    extends StaticSelectionContainerDelegate {
  @override
  SelectedContent? getSelectedContent() {
    final lines = <_Line>[];
    for (final selectable in selectables) {
      final content = selectable.getSelectedContent();
      if (content == null || content.plainText.isEmpty) continue;
      final rect = MatrixUtils.transformRect(
        selectable.getTransformTo(null),
        Offset.zero & selectable.size,
      );
      final last = lines.isEmpty ? null : lines.last;
      // Pieces that overlap vertically, like a bullet and its text, share a
      // line.
      if (last != null && rect.top < last.rect.bottom - 1) {
        last.add(content.plainText, rect);
      } else {
        lines.add(_Line(content.plainText, rect));
      }
    }
    if (lines.isEmpty) return null;

    final buffer = StringBuffer(lines.first.text);
    for (var i = 1; i < lines.length; i++) {
      buffer
        ..write(_lineBreak(lines[i - 1], lines[i]))
        ..write(lines[i].text);
    }
    return SelectedContent(plainText: buffer.toString());
  }

  static String _lineBreak(_Line previous, _Line next) {
    // List items are spaced like paragraphs, but read as consecutive lines.
    if (previous.hasMarker && next.hasMarker) return '\n';
    return next.rect.top - previous.rect.bottom > 4 ? '\n\n' : '\n';
  }
}

class _Line {
  _Line(String text, this.rect) : _buffer = StringBuffer(text);

  final StringBuffer _buffer;
  Rect rect;
  int _pieces = 1;

  String get text => _buffer.toString();

  /// Whether the line starts with a separate piece, such as a list bullet.
  bool get hasMarker => _pieces > 1;

  void add(String text, Rect pieceRect) {
    _buffer
      ..write(' ')
      ..write(text);
    rect = rect.expandToInclude(pieceRect);
    _pieces++;
  }
}
