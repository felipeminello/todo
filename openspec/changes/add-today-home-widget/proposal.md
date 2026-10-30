# Proposal

## Why

Hoje, para ver o que vence no dia, o usuário precisa abrir o app. Um widget na tela inicial do iOS e do Android mostra de relance as tarefas de hoje e as atrasadas, que são as que pedem ação imediata.

## What Changes

- Novo widget de tela inicial para **iOS** (WidgetKit, SwiftUI) e **Android** (Glance), só leitura. O toque abre o app.
- Conteúdo: tarefas **pendentes** que vencem **hoje** e, se sobrar espaço, as **atrasadas** em laranja. Ficam de fora as concluídas, as sem data e as futuras.
- Ordem: empilhadas **de baixo para cima**. A mais recente fica embaixo: primeiro por data de vencimento, depois por data de criação. Quando falta espaço, saem as do topo. Não há indicador "+N".
- Dados: o app grava um **snapshot em JSON** num armazenamento compartilhado com o widget (App Group `group.br.dev.minello.todo` no iOS, SharedPreferences no Android). O snapshot já vem ordenado, cobre as pendentes com data até 7 dias à frente e traz os textos localizados. **O widget nunca acessa a rede.**
- Atualização:
  - O app publica o snapshot depois de cada recarga bem-sucedida da lista: abertura, criar, editar, excluir, concluir e reabrir.
  - Na virada do dia, o widget redesenha a partir do snapshot: timeline com uma entrada por meia-noite no iOS e trabalho agendado para perto da meia-noite no Android. Há também uma atualização periódica de segurança, que só redesenha.
  - Passado o horizonte de 7 dias, o widget mostra "Abra o app para atualizar".
- Logout: as tarefas saem do snapshot e o widget passa a pedir login.
- Nova dependência `home_widget` (só iOS e Android). Ela fica atrás de uma interface, com implementação vazia no Windows e no macOS.

## Capabilities

### New Capabilities

- `home-screen-widget`: o widget de tela inicial de iOS e Android. Cobre quais tarefas ele mostra, em que ordem, o destaque de atraso, os estados vazio, desatualizado e deslogado, quando o conteúdo se atualiza, a virada do dia sem abrir o app, os tamanhos e o toque.

### Modified Capabilities

Nenhuma. A regra de atraso já definida em `task-timeline` (change `add-task-management`) é reaproveitada sem alteração.

## Impact

- **Código Dart**: novos domínio e dados em `lib/features/tasks/` (seleção e ordenação das tarefas do widget, interface de publicação, serialização JSON), uma dependência nova no `TasksBloc`, composição em `lib/app/` (escolha por plataforma e limpeza no logout) e novas chaves em `lib/l10n/app_pt.arb`. Os testes espelham essa estrutura em `test/`.
- **Dependências**:
  - `home_widget` no `pubspec.yaml`, que precisa da confirmação do usuário.
  - No Android, Glance (Compose) e WorkManager no Gradle.
- **iOS**: novo target de extensão WidgetKit, App Group `group.br.dev.minello.todo` no Runner e na extensão (criado pelo usuário na conta Apple Developer), e ajustes no projeto Xcode.
- **Android**: receiver do widget, `appwidget-provider`, recursos de cor claro e escuro e o agendamento por WorkManager no `AndroidManifest.xml`/Gradle.
- **Windows e macOS**: nenhum comportamento muda. A publicação vira no-op.
- **Limitação aceita**: uma alteração feita em outro aparelho só chega ao widget quando o app é aberto neste.
