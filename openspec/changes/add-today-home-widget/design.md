# Design

## Context

A motivação está em `proposal.md` (seção Why) e os requisitos em `specs/home-screen-widget/spec.md`. Este documento cobre o como.

Estado atual que molda o desenho:

- **Não há armazenamento local de tarefas.** O Firestore roda com `persistenceEnabled: false` e o Windows usa REST. O `TasksBloc` recarrega a lista do servidor depois de cada alteração (`_reload`). Esse é o único ponto em que o app sabe "o que está armazenado agora".
- **O dia já é modelado sem fuso.** O `dueDate` é um `CalendarDate`, persistido como `YYYY-MM-DD`. "Hoje" é `CalendarDate.fromLocal(clock.now())`. A regra de atraso (pendente e vencimento antes de hoje) e as cores dela já existem: `TaskTimeline.isOverdue`, `TaskStatusColors.light/dark` (`0xFFA6400A` / `0xFFFFB77C`) e a chave `tasksOverdueLabel`.
- **O app é fixo em `pt_BR`.** `lookupAppLocalizations(Locale)` está disponível sem `BuildContext`.
- **Projetos nativos:** iOS com bundle `br.dev.minello.todo` e deployment target 15.0. Android com `applicationId br.dev.minello.todo`, Kotlin e Gradle KTS, e uma única `MainActivity`.
- Um widget de tela inicial é código nativo (WidgetKit e AppWidget) e não executa Dart.

## Goals / Non-Goals

**Goals:**
- Manter a regra (o que entra e em que ordem) **só em Dart**, testada por unidade. O código nativo só filtra pelo dia local, corta e desenha.
- Manter os textos com fonte única no ARB.
- Deixar domínio e presentation sem conhecer `home_widget`, seguindo a mesma estratégia de seleção por plataforma de `usesFirebaseRest`.
- Fazer a virada do dia funcionar sem abrir o app e sem rede.

**Non-Goals:**
- Ações interativas no widget (concluir, abrir uma tarefa específica por deep link).
- Widgets de tela de bloqueio (famílias `accessory*` no iOS), Live Activities, widgets no macOS e no Windows.
- Buscar dados no servidor a partir do widget ou de qualquer trabalho em background.
- Configuração do widget pelo usuário (escolher o que mostrar).

## Decisions

### D1. Snapshot JSON gravado pelo app, sem rede no widget

O app grava um JSON numa chave do armazenamento compartilhado. O widget só lê esse JSON.

- **Alternativa rejeitada:** o widget consulta o Firestore REST sozinho. Isso exigiria reimplementar login e renovação de token (`RestAuthDataSource`) em Swift e em Kotlin, além de compartilhar o refresh token pelo keychain e pelo App Group. É complexidade e superfície de segurança desproporcionais. O usuário aceitou o atraso entre dispositivos.
- **Alternativa rejeitada:** um engine Flutter headless em background (pacote `workmanager`) para recarregar do servidor. Seria mais uma dependência, a auth rodaria fora do app e não há equivalente confiável no iOS.

### D2. Formato do snapshot (versão 1)

Chave única `today_widget_snapshot` (string JSON):

```json
{
  "version": 1,
  "signedIn": true,
  "generatedAt": "2026-10-29T13:02:00Z",
  "coversUntil": "2026-11-05",
  "tasks": [
    { "id": "d4", "title": "Mercado",      "dueDate": "2026-10-29", "createdAt": "2026-10-29T14:00:00Z" },
    { "id": "b2", "title": "Reunião",      "dueDate": "2026-10-29", "createdAt": "2026-10-29T12:00:00Z" },
    { "id": "e5", "title": "Ligar banco",  "dueDate": "2026-10-28", "createdAt": "2026-10-20T10:00:00Z" }
  ],
  "strings": {
    "header": "Hoje",
    "empty": "Nada para hoje",
    "stale": "Abra o app para atualizar",
    "signedOut": "Entre no app para ver suas tarefas",
    "overdue": "Atrasada"
  }
}
```

- `tasks` contém só as **pendentes com `dueDate <= coversUntil`**, incluindo as futuras dentro do horizonte e todas as atrasadas, **já ordenadas** por `dueDate` decrescente e, no empate, por `createdAt` decrescente. Num empate exato, desempata pelo `id`, para a ordem ser determinística.
- O `dueDate` usa o mesmo formato `YYYY-MM-DD` do `TaskModel`, e o `createdAt` é UTC em ISO 8601. O widget não precisa ler o `createdAt`: ele está no JSON para depuração e para versões futuras.
- `coversUntil = hoje + 7 dias`.
- `version` permite evoluir o formato. Um widget que encontra uma versão maior do que conhece trata o snapshot como desatualizado (`stale`).
- **Por que a ordem é gravada pronta:** `dueDate DESC, createdAt DESC` não depende de "hoje". Depois da virada do dia continua valendo, e as de hoje continuam na frente das atrasadas porque têm o maior `dueDate` entre as visíveis. O nativo só precisa de três passos: `filter(dueDate <= hojeLocal)`, `prefix(N)` e desenhar invertido. A regra fica num lugar só.
- **Alternativa rejeitada:** gravar só os títulos de hoje. Isso quebra na virada do dia: mostraria as tarefas de ontem como de hoje.

### D3. Camadas no Dart

```
domain (Dart puro)
  entities/widget_task_snapshot.dart     WidgetTaskSnapshot { tasks, generatedAt, coversUntil }
  usecases/select_widget_tasks.dart      SelectWidgetTasks(tasks, today) -> WidgetTaskSnapshot (pura, como BuildTaskTimeline)
  repositories/task_widget_publisher.dart  interface: publish(WidgetTaskSnapshot), clearForSignOut()
  usecases/publish_widget_tasks.dart     Select + publish
  usecases/clear_widget_tasks.dart       clearForSignOut

data
  widget/widget_strings.dart             textos já localizados (value object)
  widget/widget_snapshot_codec.dart      WidgetTaskSnapshot + WidgetStrings -> JSON (v1)
  widget/widget_storage.dart             interface: save(key, json), refresh()
  widget/home_widget_storage.dart        implementação sobre home_widget (App Group, nomes dos widgets)
  widget/home_widget_task_publisher.dart TaskWidgetPublisher sobre codec + storage
  widget/noop_task_widget_publisher.dart Windows/macOS

presentation
  TasksBloc._reload (sucesso) -> PublishWidgetTasks, com falha engolida

app/
  injection.dart  usesHomeWidget(platform): android || iOS -> HomeWidget...; senão Noop
                  WidgetStrings a partir de lookupAppLocalizations(const Locale('pt', 'BR'))
  bootstrap/app   listener de AuthState.unauthenticated -> ClearWidgetTasks
```

- **`WidgetStorage` existe** porque a API do `home_widget` é estática. Com a interface, o publisher é testado com um fake, sem plugin.
- **Os textos entram pelo construtor do publisher na camada data**, montados em `app/`. O domínio não conhece l10n. O `Clock` e o "hoje" chegam do `TasksBloc`, que já os calcula.
- **Quem chama a publicação é o `TasksBloc`**, porque o BLoC orquestra casos de uso e já tem a lista e o `today` no momento certo. A chamada fica depois do `emit` do estado `loaded`, dentro de `try/catch` que ignora qualquer erro. Assim uma falha nunca chega à tela (spec: "Falha no widget não afeta o app"). A recarga que falha não publica, e o widget mantém o conteúdo anterior.
- **Alternativa rejeitada:** um `BlocListener` na página que publica a partir do estado. Ele precisaria da lista completa no estado (hoje só existe a `TaskTimeline`) e colocaria um efeito colateral de dados na árvore de widgets.

### D4. Logout e primeiro uso

- `clearForSignOut()` grava um snapshot com `signedIn: false`, `tasks: []` e os `strings`. Os títulos somem, mas o widget ainda tem o texto "Entre no app para ver suas tarefas" vindo do ARB. Isso cumpre o "apagar" combinado: nenhum dado de tarefa permanece.
- O gatilho é a transição do `AuthBloc` para `unauthenticated`. Ela cobre logout explícito, sessão revogada na restauração e troca de usuário. Fica num `BlocListener<AuthBloc>` em `app/`, a raiz de composição que conhece as duas features, para que `auth` não dependa de `tasks`. O listener recebe o `ClearWidgetTasks` por construtor, sem `get_it` na árvore.
- **Sem snapshot nenhum** (app nunca aberto ou dados apagados), o widget mostra só o ícone do app, sem texto. Não há string do ARB disponível nesse momento.

### D5. Textos nativos inevitáveis

O nome e a descrição do widget na galeria e no seletor aparecem antes de qualquer snapshot. Por isso são os únicos textos nativos: `configurationDisplayName`/`description` em `Localizable.strings` (pt-BR) na extensão, e `android:label`/`android:description` em `res/values/strings.xml`. Os textos que aparecem **dentro** do widget vêm todos do JSON.

### D6. Cores e acessibilidade

- O laranja de atraso fica duplicado como recurso nativo, com os mesmos valores do `TaskStatusColors`: Color Set `OverdueColor` com variante clara e escura no `Assets.xcassets` da extensão, e `res/values/colors.xml` mais `res/values-night/colors.xml` no Android. O modo escuro é resolvido pelo sistema sem depender do app. Um comentário em `TaskStatusColors` aponta para os recursos nativos, para não divergirem.
- O fundo do widget é o fundo padrão do sistema: `containerBackground(.fill.tertiary)` no iOS 17 ou superior e o tema do Glance no Android. O contraste de 4,5:1 é conferido contra esse fundo nos dois temas. Se não atingir, ajusta-se o fundo do widget, não a cor do app.
- O ícone de atraso é um SF Symbol `exclamationmark.circle` no iOS e um vetor equivalente no Android. O rótulo de acessibilidade é `"<overdue>: <título>"`, montado com `strings.overdue`.
- Cada linha tem uma linha de texto, truncada com reticências.

### D7. iOS: extensão WidgetKit

- Novo target `TodayWidget` (Widget Extension, SwiftUI), deployment target 15.0, igual ao Runner. O App Group `group.br.dev.minello.todo` fica nos entitlements do Runner e da extensão, e o Dart passa o App Group em cada gravação (`saveWidgetData(appGroupId:)`), sem o `HomeWidget.setAppGroupId`, que guarda estado estático.
- Famílias `systemSmall`, `systemMedium` e `systemLarge`. N (linhas que cabem) é uma constante por família, ajustada visualmente, por exemplo 3/3/8.
- `TimelineProvider`: lê o snapshot e gera **uma entrada por meia-noite local**, de agora até `coversUntil + 1`. A última entrada já é o estado `stale`. Política `.atEnd`. Cada entrada recalcula "hoje" pela própria data, com `Calendar.current`. Quando o app publica, o `home_widget` chama `WidgetCenter.reloadTimelines`. A atualização periódica de segurança é o orçamento do próprio WidgetKit sobre a política `.atEnd`.
- Tocar abre o app: o comportamento padrão do widget, sem `widgetURL` específico.

### D8. Android: Glance + WorkManager

- `TodayWidget : GlanceAppWidget` e `TodayWidgetReceiver`, usando o estado do `home_widget` (`HomeWidgetGlanceStateDefinition`). `SizeMode.Responsive` define N por tamanho. Tocar dispara `actionStartActivity<MainActivity>()`.
- O `appwidget-provider` tem `minWidth`/`minHeight` de 2x2, `resizeMode="horizontal|vertical"` e `updatePeriodMillis="0"`, porque o agendamento é próprio.
- **Virada do dia:** um `OneTimeWorkRequest` único (`REPLACE`) com `initialDelay` até 00:00:30 local. Ao rodar, ele chama `TodayWidget().updateAll(context)` e agenda o próximo. Um `PeriodicWorkRequest` único (`KEEP`) a cada 3 h só redesenha. Os dois são agendados no `onUpdate`/`onEnabled` do receiver e cancelados no `onDisabled`.
- **Fuso e hora:** o receiver também escuta `ACTION_TIMEZONE_CHANGED` e `ACTION_TIME_CHANGED`. Ambos estão na lista de broadcasts implícitos isentos, o que deve ser confirmado na implementação. Ao recebê-los, redesenha e reagenda a meia-noite.
- **Por que não alarme exato:** `SCHEDULE_EXACT_ALARM` é permissão restrita desde o Android 14. O WorkManager pode atrasar alguns minutos por causa do Doze, o que a spec aceita.
- **Gradle:** dependências `androidx.glance:glance-appwidget` e `androidx.work:work-runtime-ktx`, além do plugin do compilador Compose para Kotlin 2.x, se o `home_widget` não os trouxer.

### D9. Seleção por plataforma

`usesHomeWidget(TargetPlatform)` em `app/injection.dart`, verdadeira só para `android` e `iOS`, igual ao `usesFirebaseRest`. Sem `dart:io`. No Windows e no macOS o `NoopTaskWidgetPublisher` evita `MissingPluginException`, e o `home_widget` nem é chamado.

## Risks / Trade-offs

- [Alteração em outro aparelho não chega ao widget até abrir o app] → Limitação aceita pelo usuário e registrada na spec.
- [O app pode ficar mais de 7 dias fechado] → `coversUntil` e o estado `stale` impedem uma lista vazia enganosa.
- [Virada atrasada no Android por causa do Doze] → A spec aceita alguns minutos. O periódico de 3 h e os broadcasts de hora e fuso cobrem as falhas.
- [Extensão de app no Flutter iOS causa o erro "Cycle inside Runner" no build] → Mover a fase "Embed Foundation Extensions" para antes de "Thin Binary"/"Run Script" no target Runner. Verificar com `flutter build ios --debug --no-codesign`.
- [O App Group depende da conta Apple do usuário] → Tarefa explícita com o usuário antes do build assinado. O build sem assinatura não depende dela.
- [Os laranjas nativos divergem do `TaskStatusColors`] → Comentário cruzado e item no checklist de revisão. São só dois valores.
- [Snapshot grande se houver muitas atrasadas acumuladas] → Os títulos são curtos e o JSON fica em poucos KB mesmo com centenas de tarefas. Não há limite artificial.
- [O `home_widget` muda de API ou não suporta a versão do Flutter/Glance usada] → Conferir no pub.dev a versão atual e o suporte a Glance antes de adicionar (tarefa 1.1).
- [O `TasksBloc` ganha mais uma dependência] → É um caso de uso só, com a mesma forma das outras dependências. O `bloc_test` cobre o sucesso e a falha da publicação.

## Migration Plan

Não há dados a migrar: o snapshot nasce na primeira recarga após a atualização. Para pôr no ar, com o usuário: criar o App Group na conta Apple Developer e habilitá-lo nos dois App IDs (Runner e extensão). Rollback: reverter o código. O widget some com a remoção do target e do receiver, e a chave órfã nas preferências não tem efeito.
