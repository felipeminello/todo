# Proposal

## Why

O projeto ainda é o template do `flutter create`: não existe nenhuma funcionalidade de tarefas. Esta change entrega o produto descrito no `CLAUDE.md`, ou seja, tarefas pessoais com data opcional, exibidas em uma linha do tempo e sincronizadas por conta de usuário no Firebase, funcionando em produção nas quatro plataformas-alvo (Windows, macOS, iOS e Android).

## What Changes

- Login e cadastro por **e-mail e senha** no Firebase Authentication. É o único método que funciona nas quatro plataformas: o `google_sign_in` não suporta Windows. Cada usuário vê apenas as próprias tarefas.
- Criar, editar, excluir, concluir e reabrir tarefas com título (obrigatório), descrição e data de vencimento opcional.
- A data de vencimento é uma **data de calendário** (dia, mês e ano, sem hora e sem fuso). Ela é persistida como `YYYY-MM-DD`, o que elimina a troca de dia por conversão de fuso.
- Tela principal com três blocos:
  1. Pendentes **sem data** no topo, da mais recente para a mais antiga (por criação).
  2. Pendentes **com data** em uma linha do tempo crescente, agrupadas por dia. No mesmo dia, ficam na ordem de criação, da mais antiga para a mais recente.
  3. Lista de **concluídas**, separada, da concluída mais recentemente para a mais antiga. Reabrir uma tarefa a devolve para a lista pendente.
- Tarefas **atrasadas** (pendentes com vencimento antes de hoje) continuam na linha do tempo, destacadas em laranja **e** com ícone e rótulo "Atrasada". A cor nunca é o único sinal. "Atrasada" é regra de domínio, calculada a partir de um relógio injetado.
- Persistência no Cloud Firestore, por usuário. Em **Android, iOS e macOS** ela usa os plugins FlutterFire. Em **Windows** usa as APIs REST do Firebase Auth e do Firestore, porque o FlutterFire declara o Windows "apenas para desenvolvimento" e o app vai para produção nessa plataforma. As duas implementações ficam atrás das mesmas interfaces de domínio.
- Substitui o `lib/main.dart` e o `test/widget_test.dart` do template.

## Capabilities

### New Capabilities

- `user-auth`: cadastro, login, logout e sessão persistente por e-mail e senha, além do isolamento de dados por usuário.
- `task-management`: ciclo de vida de uma tarefa (criar, editar, excluir, concluir, reabrir), validação do formulário e o modelo de data de vencimento como data de calendário.
- `task-timeline`: como as tarefas são organizadas para exibição. Inclui a ordem das sem data, o agrupamento por dia da linha do tempo, os desempates, a regra e o destaque de atraso e a lista de concluídas.

### Modified Capabilities

Nenhuma. Ainda não existem specs no projeto.

## Impact

- **Código**: cria `lib/app/`, `lib/core/`, `lib/features/auth/` e `lib/features/tasks/`, seguindo a Clean Architecture do `CLAUDE.md`, e os testes espelhados em `test/`. Novas chaves em `lib/l10n/app_pt.arb`.
- **Dependências novas** (cada uma precisa da confirmação do usuário antes de entrar no `pubspec.yaml`):
  - `firebase_core`, `firebase_auth`, `cloud_firestore` (Android, iOS e macOS).
  - `http`, para as chamadas REST no Windows.
  - Um armazenamento seguro do refresh token no Windows (candidato: `flutter_secure_storage`).
- **Firebase**: exige criar o projeto, habilitar o provedor e-mail/senha, rodar `flutterfire configure` e publicar regras de segurança do Firestore. Tudo isso depende da conta do usuário e será feito em conjunto com ele.
- **Plataformas**: o macOS precisa da capability de rede (client) e de keychain sharing nos entitlements, e o iOS precisa de deployment target compatível com o FlutterFire atual. Não há código específico de plataforma fora da camada `data` e do `app/`.
- **Diferenças aceitas no Windows**: sem atualização em tempo real e sem cache offline nativo. Ver `design.md`.
