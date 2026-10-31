import 'dart:math';

import 'package:todo/core/time/calendar_date.dart';
import 'package:todo/features/tasks/data/models/task_model.dart';

/// Prefix of every seeded task id. Reseeding replaces only the ids with this
/// prefix, so the user's own tasks are never touched.
const seedIdPrefix = 'seed-';

typedef DueRule = CalendarDate Function(CalendarDate today);

/// A task described relative to when the seeder runs, so every scenario
/// stays meaningful whatever the day.
final class SeedTask {
  const SeedTask(
    this.key,
    this.title, {
    this.description = '',
    this.due,
    required this.createdAgo,
    this.completedAgo,
  });

  final String key;
  final String title;
  final String description;

  /// `null` means no due date.
  final DueRule? due;

  final Duration createdAgo;

  /// `null` means pending.
  final Duration? completedAgo;

  TaskModel toModel({required CalendarDate today, required DateTime now}) {
    final completedAgo = this.completedAgo;
    if (completedAgo != null && completedAgo > createdAgo) {
      throw StateError('Task $key is completed before it was created');
    }
    return TaskModel(
      id: '$seedIdPrefix$key',
      title: title,
      description: description,
      dueDate: due?.call(today).toIso(),
      createdAt: now.subtract(createdAgo).toUtc(),
      completedAt: completedAgo == null
          ? null
          : now.subtract(completedAgo).toUtc(),
    );
  }
}

final class Scenario {
  const Scenario(this.name, this.summary, this.build);

  final String name;

  /// What the scenario lets you check, shown by `--list`.
  final String summary;

  final List<SeedTask> Function() build;
}

final scenarios = <Scenario>[
  Scenario(
    'full',
    'Todos os casos: sem data, atrasadas (mês e ano anteriores), 7 de hoje, '
        'futuras (amanhã, limite de 7 dias do widget, fora dele, próximo mês '
        'e ano), concluídas e textos longos.',
    _full,
  ),
  Scenario(
    'today-fits',
    'Widget: 3 tarefas de hoje e nenhuma atrasada (todas cabem, sem '
        'agrupamento no widget de 3 linhas).',
    () => _today(3),
  ),
  Scenario(
    'today-overflow',
    'Widget: 12 tarefas de hoje e nenhuma atrasada ("{X} tarefas '
        'pendentes" em qualquer tamanho).',
    () => _today(12),
  ),
  Scenario(
    'overdue',
    'Widget: 2 atrasadas e 1 de hoje ("2 tarefas atrasadas" com a tarefa '
        'de hoje abaixo).',
    () => [
      ..._today(1),
      SeedTask(
        'overdue-1',
        'Renovar a CNH',
        due: _inDays(-1),
        createdAgo: _days(5),
      ),
      SeedTask(
        'overdue-2',
        'Pagar o IPVA',
        due: _inDays(-4),
        createdAgo: _days(10),
      ),
    ],
  ),
  Scenario(
    'singular',
    'Widget: 1 atrasada e 3 de hoje (singular "1 tarefa atrasada"; no '
        'widget de 3 linhas, também "2 tarefas pendentes").',
    () => [
      ..._today(3),
      SeedTask(
        'overdue-1',
        'Devolver o livro da biblioteca',
        due: _inDays(-2),
        createdAgo: _days(9),
      ),
    ],
  ),
  Scenario(
    'nothing-today',
    'Widget "Nada para hoje" com o app cheio: só sem data, futuras e '
        'uma concluída hoje.',
    () => [
      SeedTask('undated-1', 'Ler "O Nome do Vento"', createdAgo: _days(3)),
      SeedTask(
        'undated-2',
        'Trocar a lâmpada da garagem',
        createdAgo: _hours(6),
      ),
      SeedTask(
        'tomorrow-1',
        'Reunião de planejamento',
        due: _inDays(1),
        createdAgo: _days(2),
      ),
      SeedTask(
        'next-week-1',
        'Consulta no dentista',
        due: _inDays(6),
        createdAgo: _days(4),
      ),
      SeedTask(
        'done-today-1',
        'Enviar o relatório semanal',
        due: _inDays(0),
        createdAgo: _days(1),
        completedAgo: _minutes(40),
      ),
    ],
  ),
  Scenario(
    'bulk',
    '320 tarefas variadas entre -30 e +90 dias: rolagem, desempenho e '
        'paginação do REST no Windows (mais de 300 documentos).',
    _bulk,
  ),
];

List<SeedTask> _full() => [
  // Undated: shown on top, most recently created first.
  SeedTask(
    'undated-1',
    'Organizar fotos da viagem',
    description: 'Separar as melhores e montar um álbum.',
    createdAgo: _days(12),
  ),
  SeedTask(
    'undated-2',
    'Aprender a fazer pão de fermentação natural',
    createdAgo: _days(4),
  ),
  SeedTask(
    'undated-3',
    'Pesquisar preços de notebook para o trabalho remoto, comparando '
        'tela, bateria, peso e garantia nas lojas de sempre',
    description:
        'Título longo de propósito, para conferir quebra de linha e '
        'reticências.',
    createdAgo: _days(1),
  ),
  SeedTask(
    'undated-4',
    'Lista de compras 🛒',
    description: '- Café\n- Arroz\n- Feijão\n- Azeite\n- Pão de queijo',
    createdAgo: _hours(3),
  ),
  SeedTask('undated-5', 'Ligar para a vó', createdAgo: _minutes(20)),

  // Overdue, across a month and a year boundary.
  SeedTask(
    'overdue-last-year',
    'Declarar a doação de fim de ano',
    due: (today) => CalendarDate(today.year - 1, 12, 31),
    createdAgo: _days(400),
  ),
  SeedTask(
    'overdue-45d',
    'Agendar revisão do carro',
    description: 'Já passou da quilometragem.',
    due: _inDays(-45),
    createdAgo: _days(60),
  ),
  SeedTask(
    'overdue-last-month',
    'Pagar a fatura do cartão',
    due: (today) => CalendarDate(today.year, today.month, 1).addDays(-1),
    createdAgo: _days(70),
  ),
  SeedTask(
    'overdue-3d',
    'Responder o e-mail do condomínio',
    due: _inDays(-3),
    createdAgo: _days(6),
  ),
  SeedTask(
    'overdue-1d-a',
    'Levar o lixo reciclável',
    due: _inDays(-1),
    createdAgo: _days(3),
  ),
  SeedTask(
    'overdue-1d-b',
    'Buscar encomenda nos Correios',
    due: _inDays(-1),
    createdAgo: _days(2),
  ),

  // Today, more than any widget size fits; created in a known order.
  ..._today(7),

  // Upcoming.
  SeedTask(
    'tomorrow-a',
    'Reunião de alinhamento às 10h',
    due: _inDays(1),
    createdAgo: _days(5),
  ),
  SeedTask(
    'tomorrow-b',
    'Comprar presente de aniversário',
    due: _inDays(1),
    createdAgo: _hours(2),
  ),
  SeedTask(
    'in-2d',
    'Treino de corrida — 8 km',
    due: _inDays(2),
    createdAgo: _days(1),
  ),
  SeedTask(
    'in-5d',
    'Entregar a declaração do imposto',
    description: 'Juntar informes de rendimento do banco e da corretora.',
    due: _inDays(5),
    createdAgo: _days(15),
  ),
  SeedTask(
    'in-7d',
    'Último dia coberto pelo widget',
    description: 'Vence daqui a 7 dias, no limite do conteúdo gravado.',
    due: _inDays(7),
    createdAgo: _days(1),
  ),
  SeedTask(
    'in-8d',
    'Fora do horizonte do widget',
    description: 'Vence daqui a 8 dias e não entra no conteúdo gravado.',
    due: _inDays(8),
    createdAgo: _days(1),
  ),
  SeedTask(
    'next-month',
    'Renovar o seguro do apartamento',
    due: (today) {
      final first = DateTime.utc(today.year, today.month + 1, 1);
      return CalendarDate(first.year, first.month, first.day);
    },
    createdAgo: _days(20),
  ),
  SeedTask(
    'in-60d',
    'Planejar as férias',
    due: _inDays(60),
    createdAgo: _days(30),
  ),
  SeedTask(
    'next-year',
    'Feliz ano novo! 🎆',
    due: (today) => CalendarDate(today.year + 1, 1, 1),
    createdAgo: _days(8),
  ),

  // Completed: listed apart, most recently completed first, never in the
  // widget.
  SeedTask(
    'done-today',
    'Responder o cliente',
    description: 'Vencia hoje e já foi concluída: não aparece no widget.',
    due: _inDays(0),
    createdAgo: _days(2),
    completedAgo: _minutes(15),
  ),
  SeedTask(
    'done-overdue',
    'Pagar a conta de luz',
    due: _inDays(-2),
    createdAgo: _days(7),
    completedAgo: _hours(5),
  ),
  SeedTask(
    'done-undated',
    'Trocar a senha do Wi-Fi',
    createdAgo: _days(3),
    completedAgo: _days(1),
  ),
  SeedTask(
    'done-future',
    'Reservar o restaurante',
    due: _inDays(4),
    createdAgo: _days(2),
    completedAgo: _days(2),
  ),
  SeedTask(
    'done-old',
    'Montar a estante',
    createdAgo: _days(90),
    completedAgo: _days(80),
  ),
];

const _todayTitles = [
  'Responder mensagens pendentes',
  'Academia às 18h',
  'Revisar o pull request do time e deixar comentários sobre a nova tela '
      'de configurações',
  'Tomar o remédio',
  'Passear com o cachorro',
  'Preparar a apresentação de amanhã',
  'Regar as plantas',
  'Estudar Flutter por 30 minutos',
  'Lavar a louça',
  'Separar a roupa para lavar',
  'Conferir o extrato do banco',
  'Ler 20 páginas',
];

/// [count] tasks due today, the first one created earliest.
List<SeedTask> _today(int count) => [
  for (var i = 0; i < count; i++)
    SeedTask(
      'today-${(i + 1).toString().padLeft(2, '0')}',
      _todayTitles[i % _todayTitles.length],
      due: _inDays(0),
      createdAgo: _minutes((count - i) * 37),
    ),
];

const _bulkCount = 320;
const _bulkTitles = [
  'Revisar o relatório trimestral',
  'Agendar o dentista',
  'Pagar a conta de água',
  'Renovar o contrato de aluguel',
  'Atualizar a planilha de gastos',
  'Pedir o orçamento da reforma',
  'Ligar para a mãe',
  'Conferir os documentos do carro',
  'Priorizar o backlog do projeto',
  'Ensaiar a apresentação do cliente',
  'Fazer a lição do curso de inglês',
  'Selecionar as fotos do evento',
  'Comprar ração do gato',
  'Enviar a nota fiscal',
  'Marcar o corte de cabelo',
  'Estudar para a certificação',
];

/// Deterministic, so two runs give the same data.
List<SeedTask> _bulk() {
  final random = Random(42);
  return [for (var i = 1; i <= _bulkCount; i++) _bulkTask(i, random)];
}

SeedTask _bulkTask(int number, Random random) {
  final createdAgo = Duration(minutes: 30 + random.nextInt(60 * 24 * 60));
  final undated = random.nextDouble() < 0.2;
  final completed = random.nextDouble() < 0.25;
  return SeedTask(
    'bulk-${number.toString().padLeft(3, '0')}',
    _bulkTitles[random.nextInt(_bulkTitles.length)],
    description: random.nextBool() ? 'Tarefa gerada em massa nº $number.' : '',
    due: undated ? null : _inDays(random.nextInt(121) - 30),
    createdAgo: createdAgo,
    completedAgo: completed
        ? Duration(minutes: random.nextInt(createdAgo.inMinutes))
        : null,
  );
}

DueRule _inDays(int days) =>
    (today) => today.addDays(days);

Duration _minutes(int minutes) => Duration(minutes: minutes);

Duration _hours(int hours) => Duration(hours: hours);

Duration _days(int days) => Duration(days: days);
