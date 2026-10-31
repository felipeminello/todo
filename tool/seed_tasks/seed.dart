// Fills the signed-in user's Firestore tasks with test data for the app and
// the home screen widget.
//
// Usage, from the project root:
//   dart run tool/seed_tasks/seed.dart --list            # list the scenarios
//   dart run tool/seed_tasks/seed.dart full --dry-run    # print, write nothing
//   dart run tool/seed_tasks/seed.dart full              # replace seeded tasks
//   dart run tool/seed_tasks/seed.dart --clear           # remove seeded tasks
//
// See tool/seed_tasks/README.md for credentials and what each scenario covers.
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:todo/core/time/calendar_date.dart';
import 'package:todo/features/tasks/data/models/task_model.dart';

import 'src/firebase_config.dart';
import 'src/firestore_seed_client.dart';
import 'src/scenarios.dart';
import 'src/seed_exception.dart';

const _defaultScenario = 'full';

Future<void> main(List<String> args) async {
  final flags = args.where((arg) => arg.startsWith('--')).toSet();
  final positional = args.where((arg) => !arg.startsWith('--')).toList();
  try {
    const known = {'--list', '--dry-run', '--clear', '--create-account'};
    if (flags.difference(known) case final unknown when unknown.isNotEmpty) {
      throw SeedException('Opção desconhecida: ${unknown.join(', ')}.');
    }
    if (flags.contains('--list')) {
      _printScenarios();
      return;
    }

    final clear = flags.contains('--clear');
    final tasks = clear
        ? const <TaskModel>[]
        : _build(_scenario(positional.firstOrNull ?? _defaultScenario));

    if (flags.contains('--dry-run')) {
      _printTasks(tasks);
      return;
    }

    final client = http.Client();
    try {
      await _seed(
        FirestoreSeedClient(client, FirebaseConfig.fromProject()),
        tasks,
        createAccount: flags.contains('--create-account'),
      );
    } finally {
      client.close();
    }
  } on SeedException catch (e) {
    stderr.writeln('Erro: ${e.message}');
    exitCode = 1;
  }
}

Scenario _scenario(String name) {
  for (final scenario in scenarios) {
    if (scenario.name == name) return scenario;
  }
  throw SeedException(
    'Cenário "$name" não existe. Use --list para ver os disponíveis.',
  );
}

List<TaskModel> _build(Scenario scenario) {
  final now = DateTime.now();
  final today = CalendarDate.fromLocal(now);
  return [
    for (final task in scenario.build()) task.toModel(today: today, now: now),
  ];
}

Future<void> _seed(
  FirestoreSeedClient firestore,
  List<TaskModel> tasks, {
  required bool createAccount,
}) async {
  final (email, password) = _credentials();
  await firestore.signIn(
    email: email,
    password: password,
    createAccount: createAccount,
  );
  stdout.writeln('Conectado como $email.');

  final previous = await firestore.listIds(prefix: seedIdPrefix);
  await firestore.deleteAll(previous);
  stdout.writeln('${previous.length} tarefas de teste anteriores removidas.');

  if (tasks.isEmpty) return;
  await firestore.writeAll(tasks);
  stdout
    ..writeln('${tasks.length} tarefas de teste gravadas.')
    ..writeln(
      'Abra o app (ou recarregue a lista) para ver os dados; o widget só '
      'se atualiza depois disso.',
    );
}

(String, String) _credentials() {
  final env = Platform.environment;
  final email = env['TODO_SEED_EMAIL'] ?? _prompt('E-mail: ');
  final password = env['TODO_SEED_PASSWORD'] ?? _prompt('Senha: ', hide: true);
  if (email.isEmpty || password.isEmpty) {
    throw const SeedException('Informe e-mail e senha.');
  }
  return (email, password);
}

String _prompt(String label, {bool hide = false}) {
  if (!stdin.hasTerminal) {
    throw const SeedException(
      'Defina TODO_SEED_EMAIL e TODO_SEED_PASSWORD para rodar sem terminal.',
    );
  }
  stdout.write(label);
  stdin.echoMode = !hide;
  try {
    return stdin.readLineSync()?.trim() ?? '';
  } finally {
    stdin.echoMode = true;
    if (hide) stdout.writeln();
  }
}

void _printScenarios() {
  for (final scenario in scenarios) {
    final mark = scenario.name == _defaultScenario ? ' (padrão)' : '';
    stdout
      ..writeln('${scenario.name}$mark')
      ..writeln('  ${scenario.summary}');
  }
}

void _printTasks(List<TaskModel> tasks) {
  for (final task in tasks) {
    final status = task.completedAt == null ? 'pendente ' : 'concluída';
    stdout.writeln(
      '${task.dueDate ?? 'sem data  '}  $status  ${task.id.padRight(24)}  '
      '${task.title}',
    );
  }
  stdout.writeln('${tasks.length} tarefas (nada foi gravado).');
}
