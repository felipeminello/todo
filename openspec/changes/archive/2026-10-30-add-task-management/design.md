# Design

## Context

O repositório tem apenas o template do `flutter create`, com localização pt_BR já configurada, e as dependências de arquitetura já instaladas (`flutter_bloc`, `equatable`, `get_it`, `intl`, `bloc_test`, `mocktail`). A arquitetura alvo, as convenções e as regras de camada estão no `CLAUDE.md`. Este documento não as repete.

Restrição que molda o desenho: segundo o README do FlutterFire, `firebase_core`, `firebase_auth` e `cloud_firestore` no Windows são "for development only. Production on Windows is not supported". O macOS está em beta, sobre o mesmo SDK nativo do iOS. O app vai para produção no Windows (ver `proposal.md`).

## Goals / Non-Goals

**Goals:**

- O domínio e a apresentação são idênticos nas quatro plataformas. Só a camada `data` e a composição em `app/` variam.
- Implementações de repositório intercambiáveis (Liskov): FlutterFire, REST e fakes em memória obedecem ao mesmo contrato e passam pela mesma bateria de testes de contrato.
- Toda a regra de organização da lista (ordem, agrupamento, atraso) fica em Dart puro e é testável com um relógio controlado.

**Non-Goals:**

- Atualização em tempo real e modo offline. Nenhuma plataforma depende disso, para manter a paridade com o Windows.
- Recuperação de senha, verificação de e-mail, login social, exclusão de conta. Podem vir em changes futuras.
- Notificações e lembretes. Como a data não tem hora, não há horário para notificar.
- Web e Linux.

## Decisions

### D1. `dueDate` é um value object `CalendarDate`, não `DateTime`

`CalendarDate(year, month, day)` fica em `core/` ou no domínio de tasks. É imutável, `Equatable` e `Comparable`, com `fromIso('YYYY-MM-DD')`, `toIso()`, `isBefore` e um construtor a partir de um `DateTime` **local** (usado pelo formulário e pelo relógio). Persistido como string `YYYY-MM-DD`.

- **Por quê**: o formulário só coleta o dia. Guardar um instante criaria um fuso implícito, e `DateTime.utc(...)` exibido em UTC-3 cai no dia anterior. Com uma data de calendário não existe conversão, e o agrupamento por dia vira uma comparação direta.
- **Alternativas**: `DateTime` normalizado para meia-noite UTC, que depende de disciplina em todo ponto de conversão e falha em silêncio; ou `Timestamp` do Firestore, que traz o mesmo problema e ainda acopla ao Firebase.

### D2. Modelo `Task`

```
Task (Equatable, imutável)
  id           String
  title        String          obrigatório, não vazio após trim
  description  String          pode ser vazia
  dueDate      CalendarDate?   null = sem data
  createdAt    DateTime (UTC)  instante; só para ordenação
  completedAt  DateTime? (UTC) null = pendente
  isCompleted  => completedAt != null
```

- `completedAt` substitui um booleano porque a lista de concluídas é ordenada pela conclusão mais recente. `isCompleted` continua existindo como getter, conforme o `CLAUDE.md`.
- `createdAt` e `completedAt` são instantes legítimos. UTC na persistência, comparados como instantes, nunca agrupados por dia.
- Os instantes vêm do `Clock` injetado (D3), não de `serverTimestamp`, para que o fake em memória e as duas implementações remotas se comportem igual.

### D3. Relógio injetado

O domínio recebe uma interface `Clock { DateTime now(); }`, com implementação de sistema registrada no `get_it` e uma fixa nos testes. "Hoje" é `CalendarDate.fromLocal(clock.now())`: o dia do calendário local do dispositivo, que é o que o usuário entende como hoje.

### D4. Organização da lista: caso de uso puro `BuildTaskTimeline`

```
BuildTaskTimeline(List<Task> tasks, CalendarDate today) -> TaskTimeline

TaskTimeline
  undated:   List<Task>        pendentes sem data, createdAt desc
  days:      List<DayGroup>    date asc
  completed: List<Task>        completedAt desc

DayGroup
  date:      CalendarDate
  isOverdue: bool              date.isBefore(today)
  tasks:     List<Task>        createdAt asc
```

- Como `days` só contém pendentes, "atrasada" equivale a pertencer a um grupo cujo dia é anterior a hoje. A flag fica no `DayGroup`, e hoje não conta como atrasado.
- Uma tarefa concluída sai da linha do tempo e vai para `completed`, mesmo que tenha data. Reabrir zera `completedAt` e a devolve ao bloco certo.
- A ordenação é feita em memória, não em query. A lista de um usuário é pequena, e isso mantém a regra única e testável independente do backend.
- O empate em `createdAt`, improvável mas possível, é desfeito por `id` para garantir ordem determinística.

### D5. Contratos de domínio pequenos e baseados em `Future`

- `AuthRepository`: `signUp(email, password)`, `signIn(email, password)`, `signOut()`, `restoreSession() -> AppUser?`, `currentUser`.
- `TaskRepository`: `getAll()`, `add(NewTask)`, `update(Task)`, `delete(id)`. O `id` é atribuído pelo backend (auto-ID do Firestore) e devolvido no `Task` criado.
- Casos de uso: `SignUp`, `SignIn`, `SignOut`, `RestoreSession`, `GetTasks`, `AddTask`, `UpdateTask`, `DeleteTask`, `ToggleTask` (que define ou limpa `completedAt` usando o `Clock`) e `BuildTaskTimeline`.
- O `TaskRepository` não recebe `userId`. As implementações remotas recebem um `CurrentUserIdProvider` (implementado sobre o `AuthRepository`) pelo construtor, e o domínio de tarefas não conhece autenticação.
- **Por que `Future` e não `Stream`**: o REST não tem listener. Um contrato de stream obrigaria o Windows a simular tempo real com polling, ou quebraria a substituição de Liskov.

### D6. Erros como `Failure` tipadas

A camada `data` captura exceções do FlutterFire, do HTTP e de parsing, e as converte em subclasses seladas de `Failure` em `core/error/`:

- `AuthFailure`: `invalidCredentials`, `emailAlreadyInUse`, `weakPassword`, `invalidEmail`, `network`, `unknown`.
- `TaskFailure`: `network`, `permissionDenied`, `notFound`, `unknown`.

Os repositórios lançam apenas `Failure`, os BLoCs capturam e emitem estado de erro, e a UI traduz o tipo em mensagem via l10n. Considerei um `Result<T>` selado, mas descartei: ele exigiria desembrulhar em cada caso de uso sem ganho real aqui, e não vale uma dependência como `dartz`/`fpdart`.

### D7. Duas implementações remotas, escolhidas em `app/`

```
                       domain (interfaces)
             AuthRepository          TaskRepository
                   ^                        ^
         +---------+---------+    +---------+---------+
         |                   |    |                   |
 FirebaseAuth          RestAuth    Firestore       RestFirestore
 DataSource            DataSource  TaskDataSource  TaskDataSource
 (firebase_auth)       (http)      (cloud_firestore) (http)
         |                   |    |                   |
   Android/iOS/macOS    Windows   Android/iOS/macOS  Windows
```

- A seleção acontece uma vez, na injeção de dependências, com `defaultTargetPlatform == TargetPlatform.windows` (de `package:flutter/foundation.dart`). Nenhum `dart:io`. Nas demais plataformas o bootstrap chama `Firebase.initializeApp`. No Windows, **não** chama.
- Os repositórios concretos (`AuthRepositoryImpl`, `TaskRepositoryImpl`) são compartilhados e dependem de interfaces de datasource. Só os datasources têm duas versões. O mapeamento Model ↔ Entity e a conversão de erros ficam no repositório, sobre exceções de datasource normalizadas.
- **Alternativas**: (a) FlutterFire também no Windows, que é oficialmente não suportado em produção; (c) tirar o Windows do escopo, o que contraria o requisito. Ambas rejeitadas pelo usuário.

### D8. Auth REST no Windows

- Cadastro e login usam o Identity Toolkit (`accounts:signUp` e `accounts:signInWithPassword`, com `?key=<apiKey>`). Ambos devolvem `idToken` (1 h), `refreshToken` e `localId`, que é o uid.
- A renovação usa `securetoken.googleapis.com/v1/token` (`grant_type=refresh_token`). É feita de forma proativa quando faltam menos de 5 min para expirar, e reativa uma única vez se o Firestore responder 401.
- Para persistir a sessão, o `refreshToken` e o uid vão para um armazenamento seguro, atrás de uma interface `SecureTokenStore` (candidato: `flutter_secure_storage`, que usa o Credential Manager no Windows). `restoreSession` renova o token na abertura do app, e o logout apaga o store. Uma falha de **rede** na renovação mantém a sessão: o uid salvo continua valendo e a renovação é tentada na próxima requisição. Só uma recusa do provedor (`TOKEN_EXPIRED`, `USER_DISABLED`, `USER_NOT_FOUND`, `INVALID_REFRESH_TOKEN`) descarta a sessão, o que reproduz o comportamento offline do `firebase_auth`.
- Os códigos de erro do Identity Toolkit (`EMAIL_EXISTS`, `INVALID_LOGIN_CREDENTIALS`, `WEAK_PASSWORD`, etc.) são mapeados para os mesmos `AuthFailure` do FlutterFire.
- A configuração vem de `apiKey` e `projectId`, lidos de `DefaultFirebaseOptions` (gerado pelo `flutterfire configure`). Assim existe uma fonte única de configuração, sem `--dart-define`.

### D9. Firestore: modelo de dados e acesso REST

```
users/{uid}/tasks/{taskId}
  title        string
  description  string
  dueDate      string "YYYY-MM-DD" | null
  createdAt    timestamp
  completedAt  timestamp | null
```

- O REST usa `firestore.googleapis.com/v1/projects/{p}/databases/(default)/documents/users/{uid}/tasks`, com `Authorization: Bearer <idToken>`. O `getAll` pagina por `pageToken`, `add` faz POST sem `documentId` para obter o auto-ID, `update` usa PATCH com `updateMask` e `delete` usa DELETE.
- No SDK, as leituras usam `Source.server` e as escritas rodam em transações. Transações falham quando não há conexão, em vez de ficarem na fila do SDK, e isso mantém a mesma semântica do REST: uma alteração que falhou é informada e nunca é aplicada mais tarde sem o usuário saber.
- Um único `TaskModel` conhece os dois formatos: o `Map` do SDK e os valores tipados do REST (`stringValue`, `timestampValue`, `nullValue`). Ambos convertem para a mesma entidade.
- Regras de segurança, que valem igualmente para SDK e REST porque o REST autenticado as respeita:

```
match /users/{uid}/tasks/{taskId} {
  allow read, write: if request.auth != null && request.auth.uid == uid;
}
```

  Elas ficam versionadas no repo (`firestore.rules`) e são publicadas pelo usuário.

### D10. Apresentação

- `AuthBloc` decide a raiz: `unknown` mostra splash enquanto `restoreSession` roda, `unauthenticated` mostra `AuthPage` (login e cadastro alternáveis) e `authenticated` mostra `TasksPage`. O `TasksBloc` é criado dentro do ramo autenticado, então um logout descarta o estado do usuário anterior.
- `TasksBloc` tem os eventos `TasksRequested`, `TaskAdded`, `TaskUpdated`, `TaskDeleted` e `TaskCompletionToggled`, e os estados `loading`, `loaded(TaskTimeline)` e `failure`. Efeitos únicos, como o snackbar de erro numa ação, saem por `BlocListener`. Depois de cada mutação, o BLoC recarrega via `GetTasks` e recalcula com `BuildTaskTimeline`. Não há atualização otimista: menos estado divergente, e a latência é aceitável para uma lista pessoal.
- `TasksPage` desenha os três blocos numa única rolagem. As concluídas ficam numa seção recolhível "Concluídas (n)" no fim, recolhida por padrão. Em telas largas (breakpoint via `LayoutBuilder`) a lista fica centralizada com largura máxima legível.
- **Atraso**: uma `ThemeExtension` `TaskStatusColors` traz `overdue` (laranja) para tema claro e escuro, com contraste mínimo de 4.5:1 sobre a superfície. O `DayGroup` atrasado mostra o cabeçalho de data na cor `overdue`, com ícone (`Icons.schedule` ou `warning_amber`) e o rótulo localizado "Atrasada", que também vai no `Semantics`.
- O formulário de criação e edição tem título obrigatório (validação de vazio ou só espaços), descrição multilinha e um seletor de data opcional com ação de limpar. A data escolhida vira `CalendarDate` na própria borda da UI.

### D11. Estratégia de testes

- Domínio: `CalendarDate`, `Task` e `BuildTaskTimeline`, este com relógio fixo e os casos listados no `CLAUDE.md`, além de atraso exatamente em hoje e em ontem, concluída com data, reabertura e empate de `createdAt`.
- Uma suíte de contrato de `TaskRepository` e `AuthRepository` roda contra o fake em memória e contra os repositórios com datasources REST sobre `MockClient` (`package:http/testing`), sem rede.
- O datasource REST tem testes de serialização do formato tipado do Firestore, mapeamento de códigos de erro, renovação de token e reenvio após 401.
- Os datasources FlutterFire ficam finos e sem lógica. São cobertos pelos testes do repositório com datasource mockado, sem `fake_cloud_firestore`, para não adicionar dependência.
- BLoCs com `bloc_test` e `mocktail`. Widgets: formulário (título obrigatório, data opcional), `TasksPage` com os três blocos e o destaque de atraso, e `AuthPage`.

## Risks / Trade-offs

- [Os plugins FlutterFire declaram suporte a Windows e são compilados no build Windows mesmo sem uso, o que aumenta o tempo de build e o binário com o SDK C++] → Não inicializar o Firebase no Windows. Medir o tamanho do build. Se pesar, avaliar uma variante de pubspec ou um plugin de federação próprio numa change futura.
- [O REST diverge sem perceber do comportamento do SDK] → Suíte de contrato única para os dois caminhos e smoke test manual no Windows antes de cada release.
- [Sem tempo real, edições feitas em outro dispositivo só aparecem ao recarregar] → `TasksRequested` ao abrir o app e ao voltar ao foreground, além de "puxar para atualizar" no mobile e atalho F5/Ctrl+R no desktop.
- [O refresh token fica no dispositivo] → Armazenamento seguro do SO e nunca `shared_preferences`. O logout apaga.
- [Chave de API do Firebase no binário] → É pública por design. A proteção está nas regras do Firestore (D9), e o provedor e-mail/senha deve ter proteção contra enumeração ativada no console.
- [O macOS está em beta no FlutterFire] → Mesmo SDK do iOS. Se aparecer bloqueio, o macOS pode passar a usar o caminho REST trocando só a condição em `app/`.
- [O relógio do dispositivo está errado] → Afeta só `createdAt`/`completedAt` e o cálculo de "hoje". É aceitável para um app pessoal.

## Migration Plan

Não há dados nem usuários existentes. Para pôr no ar, junto com o usuário: criar o projeto Firebase, habilitar e-mail/senha, criar o Firestore, rodar `flutterfire configure` para Android, iOS, macOS e Windows, e publicar `firestore.rules`. Rollback: reverter o código. Os dados no Firestore ficam isolados por uid e não exigem limpeza.

## Open Questions

- Tom exato do laranja de atraso em cada tema. Definido na implementação, desde que respeite o contraste de D10.
- Região do Firestore. É escolhida pelo usuário ao criar o banco e não afeta o código.
