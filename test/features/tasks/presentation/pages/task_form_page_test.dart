import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/time/calendar_date.dart';
import 'package:todo/features/tasks/domain/entities/task.dart';
import 'package:todo/features/tasks/presentation/pages/task_form_page.dart';

import '../../../../helpers/localized_app.dart';

/// Opens the form from a button and records what it returns.
class _Host extends StatefulWidget {
  const _Host({this.initial, required this.onResult});

  final Task? initial;
  final ValueChanged<TaskFormResult?> onResult;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  @override
  Widget build(BuildContext context) => Scaffold(
    body: TextButton(
      onPressed: () async => widget.onResult(
        await TaskFormPage.open(context, initial: widget.initial),
      ),
      child: const Text('abrir'),
    ),
  );
}

void main() {
  late List<TaskFormResult?> results;

  setUp(() => results = []);

  Future<void> open(WidgetTester tester, {Task? initial}) async {
    await tester.pumpWidget(
      localizedApp(
        home: _Host(initial: initial, onResult: results.add),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  Finder titleField() => find.byKey(const Key('task-form-title'));
  Finder saveButton() => find.byKey(const Key('task-form-save'));

  testWidgets('a new task form is empty and without date', (tester) async {
    await open(tester);

    expect(find.text('Nova tarefa'), findsOneWidget);
    expect(find.text('Sem data'), findsOneWidget);
    expect(find.byTooltip('Remover data'), findsNothing);
  });

  for (final blank in ['', '   ']) {
    testWidgets('a blank title "$blank" is not saved', (tester) async {
      await open(tester);

      await tester.enterText(titleField(), blank);
      await tester.tap(saveButton());
      await tester.pumpAndSettle();

      expect(find.text('Informe o título'), findsOneWidget);
      expect(find.byType(TaskFormPage), findsOneWidget);
      expect(results, isEmpty);
    });
  }

  testWidgets('saves a task without a date', (tester) async {
    await open(tester);

    await tester.enterText(titleField(), 'Ligar');
    await tester.tap(saveButton());
    await tester.pumpAndSettle();

    expect(results, [
      const TaskFormResult(title: 'Ligar', description: '', dueDate: null),
    ]);
  });

  testWidgets('the date picker only asks for a day', (tester) async {
    await open(
      tester,
      initial: Task(
        id: '1',
        title: 't',
        dueDate: CalendarDate(2026, 10, 27),
        createdAt: DateTime.utc(2026),
      ),
    );

    await tester.tap(find.text('Escolher data'));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(find.byType(TimePickerDialog), findsNothing);

    await tester.tap(find.text('30'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(saveButton());
    await tester.pumpAndSettle();

    expect(results.single?.dueDate, CalendarDate(2026, 10, 30));
  });

  testWidgets('removes the date of a dated task', (tester) async {
    await open(
      tester,
      initial: Task(
        id: '1',
        title: 'Com data',
        description: 'd',
        dueDate: CalendarDate(2026, 10, 27),
        createdAt: DateTime.utc(2026),
      ),
    );

    expect(find.text('Editar tarefa'), findsOneWidget);
    expect(find.text('Com data'), findsOneWidget);
    expect(find.text('Sem data'), findsNothing);

    await tester.tap(find.byTooltip('Remover data'));
    await tester.pump();
    expect(find.text('Sem data'), findsOneWidget);

    await tester.tap(saveButton());
    await tester.pumpAndSettle();

    expect(results, [
      const TaskFormResult(title: 'Com data', description: 'd', dueDate: null),
    ]);
  });

  testWidgets('cancelling an edit returns nothing', (tester) async {
    await open(
      tester,
      initial: Task(id: '1', title: 'Original', createdAt: DateTime.utc(2026)),
    );

    await tester.enterText(titleField(), 'Mudado');
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();

    expect(results, [null]);
  });
}
