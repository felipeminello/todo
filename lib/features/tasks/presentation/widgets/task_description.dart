import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

/// A task description with its line breaks, `-` lists and links, which open
/// through [onOpenLink]. Bare URLs become links too.
class TaskDescription extends StatelessWidget {
  const TaskDescription({
    super.key,
    required this.text,
    required this.onOpenLink,
  });

  final String text;
  final ValueChanged<Uri> onOpenLink;

  void _tapLink(String text, String? href, String title) {
    final uri = href == null ? null : Uri.tryParse(href);
    if (uri != null) onOpenLink(uri);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyLarge;

    return MarkdownBody(
      data: text,
      // Typed text breaks lines where the user did, unlike plain Markdown.
      softLineBreak: true,
      onTapLink: _tapLink,
      // Shows what an image points to instead of loading it from the web.
      imageBuilder: (uri, title, alt) =>
          Text(alt == null || alt.isEmpty ? uri.toString() : alt, style: body),
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: body,
        listBullet: body,
        a: body?.copyWith(
          color: theme.colorScheme.primary,
          decoration: TextDecoration.underline,
          decorationColor: theme.colorScheme.primary,
        ),
        blockSpacing: 10,
      ),
    );
  }
}
