import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/app/home_widget_strings.dart';
import 'package:todo/features/tasks/data/widget/widget_strings.dart';
import 'package:todo/l10n/app_localizations.dart';

void main() {
  test('widget texts come from the pt_BR localization', () {
    final strings = homeWidgetStrings(
      lookupAppLocalizations(const Locale('pt', 'BR')),
    );

    expect(
      strings,
      const WidgetStrings(
        header: 'Hoje',
        empty: 'Nada para hoje',
        stale: 'Abra o app para atualizar',
        signedOut: 'Entre no app para ver suas tarefas',
        overdue: 'Atrasada',
      ),
    );
  });
}
