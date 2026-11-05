import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/time/calendar_date.dart';
import 'package:todo/features/tasks/domain/entities/task.dart';
import 'package:todo/features/tasks/presentation/widgets/task_details.dart';

import '../../../../helpers/localized_app.dart';

void main() {
  late List<Uri> opened;
  String? clipboard;

  setUp(() {
    opened = [];
    clipboard = null;
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String?;
          }
          return null;
        });
  });

  tearDown(
    () => TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );

  Task task({String description = '', CalendarDate? dueDate}) => Task(
    id: '1',
    title: 'Pagar conta',
    description: description,
    dueDate: dueDate,
    createdAt: DateTime.utc(2026, 11, 5),
  );

  Future<void> pump(WidgetTester tester, Task task) => tester.pumpWidget(
    localizedApp(
      home: Scaffold(
        body: TaskDetails(task: task, onOpenLink: opened.add),
      ),
    ),
  );

  Future<void> selectAllAndCopy(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('task-details-title')));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
  }

  testWidgets('title and description can be selected and copied', (
    tester,
  ) async {
    await pump(
      tester,
      task(description: 'Boleto da luz', dueDate: CalendarDate(2026, 11, 10)),
    );

    await selectAllAndCopy(tester);

    expect(clipboard, contains('Pagar conta'));
    expect(clipboard, contains('Boleto da luz'));
    expect(clipboard, isNot(contains('2026')));
  });

  testWidgets('dragging over the title copies part of it', (tester) async {
    await pump(tester, task(description: 'Boleto da luz'));

    final title = find.byKey(const Key('task-details-title'));
    final gesture = await tester.startGesture(
      tester.getTopLeft(title) + const Offset(1, 8),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveTo(tester.getCenter(title));
    await gesture.up();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(clipboard, isNotEmpty);
    expect('Pagar conta', startsWith(clipboard!));
  });

  testWidgets('the "no description" placeholder is not copied', (tester) async {
    await pump(tester, task());

    await selectAllAndCopy(tester);

    expect(clipboard, 'Pagar conta');
  });

  testWidgets('links in a selectable description still open', (tester) async {
    await pump(tester, task(description: 'Veja https://example.com/a'));

    await tester.tapOnText(find.textRange.ofSubstring('https://example.com/a'));

    expect(opened, [Uri.parse('https://example.com/a')]);
  });
}
