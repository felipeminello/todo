# Tasks

## 1. Dependência e pré-requisitos

- [x] 1.1 Conferir no pub.dev a versão atual do `home_widget`, o suporte a Glance e a compatibilidade com o SDK Flutter do projeto, e confirmar com o usuário a entrada do pacote (justificativa no `design.md` D1/D9). Concluída quando o usuário aprovar.
- [x] 1.2 Adicionar `home_widget` ao `pubspec.yaml`. Verificar que `flutter pub get` e `flutter analyze` passam e que `flutter build windows --debug` e `flutter build macos --debug` continuam compilando.
- [x] 1.3 Junto com o usuário: criar o App Group `group.br.dev.minello.todo` na conta Apple Developer e associá-lo aos App IDs `br.dev.minello.todo` e da extensão (`br.dev.minello.todo.TodayWidget`). Concluída quando o usuário confirmar a criação.

## 2. Domínio do widget (`lib/features/tasks/domain/`)

- [x] 2.1 Criar a entidade `WidgetTaskSnapshot` (tarefas, `generatedAt`, `coversUntil`) e o caso de uso puro `SelectWidgetTasks(tasks, today)`: pendentes com data até `today + 7`, ordenadas por `dueDate` desc, `createdAt` desc e `id`. Verificar com testes unitários cobrindo lista vazia, só concluídas, só sem data, futura dentro e fora do horizonte, atrasadas antigas incluídas, empate de data com desempate por criação e por `id`, e virada de mês e de ano no cálculo de `coversUntil`.
- [x] 2.2 Criar a interface `TaskWidgetPublisher` (`publish`, `clearForSignOut`) e os casos de uso `PublishWidgetTasks` e `ClearWidgetTasks`. Verificar com testes usando publisher mockado (`mocktail`) e conferindo que a pasta `domain` não importa Flutter nem `home_widget`.

## 3. Camada data do widget (`lib/features/tasks/data/widget/`)

- [x] 3.1 Criar `WidgetStrings` e o codec JSON v1 do `design.md` D2 (`version`, `signedIn`, `generatedAt`, `coversUntil`, `tasks`, `strings`). Verificar com testes de serialização cobrindo snapshot com tarefas, snapshot de logout (`signedIn: false`, sem tarefas), `dueDate` `YYYY-MM-DD` sem deslocamento de fuso, `createdAt` em UTC e preservação da ordem.
- [x] 3.2 Criar a interface `WidgetStorage`, a implementação `HomeWidgetStorage` (App Group, `saveWidgetData` e `updateWidget` com os nomes do widget iOS e do receiver Android), o `HomeWidgetTaskPublisher` e o `NoopTaskWidgetPublisher`. Verificar com testes do publisher sobre um `WidgetStorage` fake: grava a chave `today_widget_snapshot` e pede atualização, tanto ao publicar quanto no logout.

## 4. Localização

- [x] 4.1 Adicionar ao `lib/l10n/app_pt.arb` as chaves `widgetHeader` ("Hoje"), `widgetEmpty` ("Nada para hoje"), `widgetStale` ("Abra o app para atualizar") e `widgetSignedOut` ("Entre no app para ver suas tarefas"), com descrições, reaproveitando `tasksOverdueLabel` para "Atrasada". Rodar `flutter gen-l10n`. Verificar com teste que monta `WidgetStrings` a partir de `lookupAppLocalizations(const Locale('pt', 'BR'))`.

## 5. Integração no app (presentation e `lib/app/`)

- [x] 5.1 Injetar `PublishWidgetTasks` no `TasksBloc` e chamá-lo depois de cada recarga bem-sucedida, engolindo qualquer erro. Verificar com `bloc_test`: publica após `TasksRequested` e após cada mutação, com a lista e o `today` corretos; não publica quando a recarga falha; uma falha de publicação não altera os estados emitidos.
- [x] 5.2 Em `app/injection.dart`, criar `usesHomeWidget(TargetPlatform)` e registrar o publisher real em Android e iOS e o no-op nas demais plataformas, com `WidgetStrings` vindas do l10n. No iOS, o `HomeWidgetStorage` recebe o App Group e o passa em cada gravação (sem `HomeWidget.setAppGroupId`, que guarda estado estático). Verificar com o teste de `injection` checando o tipo registrado para Android, iOS, Windows e macOS.
- [x] 5.3 Adicionar o `BlocListener<AuthBloc>` em `app/`, recebendo `ClearWidgetTasks` pelo construtor e chamando-o na transição para `unauthenticated`. Verificar com teste de widget: o logout chama o clear, e a restauração de sessão autenticada não chama.
- [x] 5.4 Rodar `dart format .`, `flutter analyze` e `flutter test`. Verificar que os três passam sem avisos.

## 6. Widget iOS (WidgetKit)

- [x] 6.1 Criar o target `TodayWidget` (Widget Extension SwiftUI, iOS 15.0) no `ios/Runner.xcodeproj`, com o App Group nos entitlements do Runner e da extensão, `Localizable.strings` pt-BR com nome e descrição para a galeria, e o Color Set `OverdueColor` com os valores claro e escuro de `TaskStatusColors`. Ajustar a ordem da fase "Embed Foundation Extensions" se aparecer o erro de ciclo. Verificar com `flutter build ios --debug --no-codesign` sem erros.
- [x] 6.2 Implementar a leitura do snapshot v1 do App Group e o `TimelineProvider` com uma entrada por meia-noite local até `coversUntil + 1` e política `.atEnd`. Cada entrada filtra `dueDate <= dia da entrada`, corta em N por família e classifica as atrasadas. Versão desconhecida ou dia além do horizonte viram `stale`. Verificar com testes XCTest da lógica pura (filtro, corte, atraso, `stale`, `signedIn: false`, ausência de snapshot) ou, se o target de teste não for viável, com previews SwiftUI cobrindo esses estados.
- [x] 6.3 Implementar as views SwiftUI das famílias small, medium e large: cabeçalho no topo, lista ancorada embaixo e invertida, atrasadas em `OverdueColor` com `exclamationmark.circle` e rótulo de acessibilidade, uma linha por título, estados vazio, `stale` e deslogado, e só o ícone do app quando não há snapshot. Verificar no simulador, nos temas claro e escuro, que o layout bate com a spec e que o VoiceOver anuncia "Atrasada".
- [x] 6.4 Smoke test no simulador ou no aparelho: criar, concluir e excluir uma tarefa de hoje e conferir o widget; mudar a data do sistema para o dia seguinte e conferir que a tarefa pendente vira atrasada; sair da conta e conferir a mensagem de login. Registrar o resultado para o usuário.

## 7. Widget Android (Glance)

- [x] 7.1 Adicionar as dependências Glance e WorkManager (e o plugin Compose, se necessário) no Gradle, o `TodayWidgetReceiver` no `AndroidManifest.xml` com o `appwidget-provider` (2x2, redimensionável, `updatePeriodMillis="0"`), `strings.xml` com nome e descrição, e `colors.xml`/`values-night/colors.xml` com os laranjas. Verificar com `flutter build apk --debug` sem erros.
- [x] 7.2 Implementar a leitura do snapshot v1 e a seleção (filtro pelo dia local, corte em N, atraso, `stale`, deslogado, sem snapshot) como funções Kotlin puras. Verificar com testes JUnit em `android/app/src/test` rodando `./gradlew :app:testDebugUnitTest`.
- [x] 7.3 Implementar o `TodayWidget` (`GlanceAppWidget`, `SizeMode.Responsive`): cabeçalho no topo, lista ancorada embaixo e invertida, atrasadas em laranja com ícone e `contentDescription`, toque abrindo a `MainActivity`, e só o ícone do app sem snapshot. Verificar no emulador, nos temas claro e escuro, em 2x2 e em tamanho maior, e com o TalkBack anunciando "Atrasada".
- [x] 7.4 Implementar o agendamento: trabalho único perto de 00:00:30 local que se reagenda, periódico de 3 h que só redesenha, e redesenho em `ACTION_TIMEZONE_CHANGED`/`ACTION_TIME_CHANGED` (confirmando que estão na lista de broadcasts implícitos isentos). Agendar em `onEnabled`/`onUpdate` e cancelar em `onDisabled`. Verificar com teste do cálculo do atraso até a meia-noite (inclusive na mudança de horário de verão) e, no emulador, com `adb shell cmd jobscheduler run` ou avançando o relógio.
- [x] 7.5 Smoke test no emulador ou no aparelho com os mesmos passos de 6.4. Registrar o resultado para o usuário.

## 8. Verificação integrada

- [x] 8.1 Rodar `dart format .`, `flutter analyze` e `flutter test`, e buildar Android, iOS (`--no-codesign`), macOS e Windows em debug. Verificar que tudo passa e que nada mudou no comportamento do Windows e do macOS.
- [x] 8.2 Percorrer os cenários da spec `home-screen-widget` com o usuário num aparelho iOS e num Android, incluindo a alteração feita no desktop que só aparece depois de abrir o app no celular. Concluída quando o usuário aprovar.
