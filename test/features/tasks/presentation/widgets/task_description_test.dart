import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/features/tasks/presentation/widgets/task_description.dart';

import '../../../../helpers/localized_app.dart';

void main() {
  late List<Uri> opened;

  setUp(() => opened = []);

  Future<void> pump(WidgetTester tester, String text) => tester.pumpWidget(
    localizedApp(
      home: Scaffold(
        body: TaskDescription(text: text, onOpenLink: opened.add),
      ),
    ),
  );

  testWidgets('keeps the line breaks the user typed', (tester) async {
    await pump(tester, 'Primeira linha\nSegunda linha');

    expect(find.text('Primeira linha\nSegunda linha'), findsOneWidget);
  });

  testWidgets('shows "-" lines as a bulleted list', (tester) async {
    await pump(tester, 'Comprar:\n- pão\n- leite');

    expect(find.text('Comprar:'), findsOneWidget);
    expect(find.text('•'), findsNWidgets(2));
    expect(find.text('pão'), findsOneWidget);
    expect(find.text('leite'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('pão')).dy,
      lessThan(tester.getTopLeft(find.text('leite')).dy),
    );
  });

  testWidgets('a bare URL opens when tapped', (tester) async {
    await pump(tester, 'Veja https://example.com/doc?id=1 depois');

    await tester.tapOnText(
      find.textRange.ofSubstring('https://example.com/doc?id=1'),
    );

    expect(opened, [Uri.parse('https://example.com/doc?id=1')]);
  });

  testWidgets('a www address opens over the web', (tester) async {
    await pump(tester, 'Site: www.example.com');

    await tester.tapOnText(find.textRange.ofSubstring('www.example.com'));

    expect(opened.single.host, 'www.example.com');
    expect(opened.single.scheme, startsWith('http'));
  });

  testWidgets('a named link opens its address', (tester) async {
    await pump(tester, '[Manual](https://example.com/manual)');

    await tester.tapOnText(find.textRange.ofSubstring('Manual'));

    expect(opened, [Uri.parse('https://example.com/manual')]);
  });

  testWidgets('a link inside a list item opens', (tester) async {
    await pump(tester, '- item\n- https://example.com/a');

    await tester.tapOnText(find.textRange.ofSubstring('https://example.com/a'));

    expect(opened, [Uri.parse('https://example.com/a')]);
  });

  testWidgets('images are not loaded, their text is shown', (tester) async {
    await pump(tester, '![Diagrama](https://example.com/x.png)');

    expect(find.byType(Image), findsNothing);
    expect(find.text('Diagrama'), findsOneWidget);
  });
}
