# Tasks

## 1. Dependências e configuração de plataforma

- [x] 1.1 Confirmar com o usuário a entrada de `firebase_core`, `firebase_auth`, `cloud_firestore`, `http` e `flutter_secure_storage` (justificativas no `design.md` D7/D8) e conferir no pub.dev o suporte das versões escolhidas a Android, iOS, macOS e Windows. Concluída quando o usuário aprovar a lista.
- [x] 1.2 Adicionar as dependências aprovadas ao `pubspec.yaml`. Verificar que `flutter pub get` e `flutter analyze` passam.
- [x] 1.3 Ajustar a configuração nativa exigida pelos plugins: entitlements do macOS (rede client e keychain sharing, em Debug e Release), deployment target do iOS e do macOS e `minSdk` do Android. Verificar com `flutter build macos --debug` e `flutter build apk --debug` sem erros.

## 2. Núcleo compartilhado (`lib/core/`)

- [x] 2.1 Criar `CalendarDate` (value object com `fromIso`, `toIso`, `fromLocal`, `compareTo` e `isBefore`) com testes de parse e formatação, rejeição de string inválida, igualdade, ordenação e virada de mês e ano. Verificar com `flutter test test/core`.
- [x] 2.2 Criar a interface `Clock`, a implementação de sistema e um relógio fixo para testes. Verificar que `fromLocal(clock.now())` devolve o dia local num teste com relógio fixo.
- [x] 2.3 Criar a hierarquia selada de `Failure` (`AuthFailure` e `TaskFailure` com os tipos do `design.md` D6) e o contrato base de caso de uso. Verificar com `flutter analyze` sem avisos.

## 3. Domínio de tarefas (`lib/features/tasks/domain/`)

- [x] 3.1 Criar a entidade `Task` (com `createdAt`, `completedAt` e o getter `isCompleted`) e `NewTask`, com testes de igualdade por valor e `copyWith`, incluindo limpar `dueDate` e `completedAt`.
- [x] 3.2 Criar a interface `TaskRepository` e os casos de uso `GetTasks`, `AddTask` (com trim e validação de título), `UpdateTask` (preserva `createdAt` e `completedAt`), `DeleteTask` e `ToggleTask` (define ou limpa `completedAt` pelo `Clock`). Verificar com testes unitários usando repositório mockado (`mocktail`), cobrindo título vazio e só com espaços.
- [x] 3.3 Criar `BuildTaskTimeline`, `TaskTimeline` e `DayGroup`. Verificar com testes cobrindo todos os cenários da spec `task-timeline`: lista vazia, só sem data, só com data, mistura, mesmo dia, desempate por criação e por `id`, virada de mês e de ano, atrasada ontem e não atrasada hoje, concluída com data fora da linha do tempo, ordem das concluídas e reabertura.

## 4. Domínio de autenticação (`lib/features/auth/domain/`)

- [x] 4.1 Criar a entidade `AppUser`, a interface `AuthRepository` e a interface `CurrentUserIdProvider`. Verificar com `flutter analyze` sem avisos e sem imports de Flutter na pasta `domain`.
- [x] 4.2 Criar os casos de uso `SignUp`, `SignIn` (com validação de e-mail e senha vazios ou malformados), `SignOut` e `RestoreSession`. Verificar com testes unitários usando repositório mockado.

## 5. Camada data: modelos, repositórios e contrato

- [x] 5.1 Criar `TaskModel` com conversão de e para entidade, o `Map` do SDK do Firestore e o formato tipado do REST (`stringValue`, `timestampValue`, `nullValue`), com `dueDate` como string `YYYY-MM-DD`. Verificar com testes de ida e volta para os dois formatos, incluindo campos nulos e o dia 27/10/2026 sem deslocamento.
- [x] 5.2 Definir as interfaces `TaskRemoteDataSource` e `AuthRemoteDataSource` e as exceções de datasource normalizadas. Implementar `TaskRepositoryImpl` e `AuthRepositoryImpl`, convertendo exceções em `Failure`. Verificar com testes de repositório que usam datasources mockados, cobrindo cada mapeamento de erro.
- [x] 5.3 Criar fakes em memória dos dois datasources e uma suíte de contrato reutilizável para `TaskRepository` e `AuthRepository`. Verificar que a suíte passa contra os fakes.

## 6. Camada data: FlutterFire (Android, iOS, macOS)

- [x] 6.1 Implementar `FirebaseAuthDataSource` sobre `firebase_auth`, mapeando os códigos de erro para as exceções normalizadas, e `FirestoreTaskDataSource` em `users/{uid}/tasks` usando `CurrentUserIdProvider`. Ambos sem lógica além da tradução. Verificar com `flutter analyze` sem avisos e com os testes do repositório (5.2) ainda passando.

## 7. Camada data: REST (Windows)

- [x] 7.1 Criar a interface `SecureTokenStore` e a implementação sobre `flutter_secure_storage`. Verificar com teste usando um fake do store.
- [x] 7.2 Implementar `RestAuthDataSource`: cadastro e login no Identity Toolkit, renovação proativa e reativa, `restoreSession` que mantém a sessão em falha de rede e a descarta em recusa do provedor, e logout que apaga o store. Verificar com testes sobre `MockClient` cobrindo sucesso, cada código de erro mapeado, renovação, abertura offline e sessão revogada.
- [x] 7.3 Implementar `RestFirestoreTaskDataSource`: listagem paginada por `pageToken`, criação com auto-ID, PATCH com `updateMask`, exclusão e uma nova tentativa após 401 com renovação de token. Verificar com testes sobre `MockClient`.
- [x] 7.4 Rodar a suíte de contrato (5.3) contra os repositórios montados com os datasources REST sobre `MockClient`. Verificar que passa com o mesmo resultado dos fakes.

## 8. Projeto Firebase (com o usuário)

- [x] 8.1 Criar `firestore.rules` na raiz com a regra de `design.md` D9 e `firebase.json` apontando para ele. Verificar a sintaxe das regras com o emulador ou o simulador de regras do console, junto com o usuário.
- [x] 8.2 Junto com o usuário: criar o projeto Firebase, habilitar e-mail/senha com proteção contra enumeração, criar o Firestore, rodar `flutterfire configure` para Android, iOS, macOS e Windows e publicar as regras. Verificar que `lib/firebase_options.dart` foi gerado com as quatro plataformas.

## 9. Composição do app (`lib/app/`)

- [x] 9.1 Configurar a injeção de dependências com `get_it`, escolhendo os datasources FlutterFire ou REST por `defaultTargetPlatform`, sem `dart:io`. Verificar com teste da função de composição para Windows e para outra plataforma, checando o tipo de datasource registrado.
- [x] 9.2 Criar o bootstrap (`Firebase.initializeApp` fora do Windows; no Windows, configuração REST vinda de `DefaultFirebaseOptions`), o tema claro e escuro com a `ThemeExtension` `TaskStatusColors` e o `MaterialApp` pt_BR. Reduzir `lib/main.dart` a chamar o bootstrap. Verificar com teste unitário de contraste mínimo de 4,5:1 do laranja de atraso sobre a superfície nos dois temas e com `flutter run -d macos` abrindo o app.

## 10. Apresentação: autenticação

- [x] 10.1 Criar `AuthBloc` (estados `unknown`, `unauthenticated`, `authenticated` e falha de ação; eventos de restaurar, cadastrar, entrar e sair). Verificar com `bloc_test` cobrindo os cenários da spec `user-auth`, incluindo a abertura offline.
- [x] 10.2 Criar o roteamento raiz por estado de autenticação (splash, `AuthPage` ou tarefas), com o `TasksBloc` dentro do ramo autenticado, e a `AuthPage` com login e cadastro alternáveis, validação e mensagens via l10n. Verificar com testes de widget: campos vazios, e-mail malformado, erro de credenciais exibido, e-mail preservado após falha de rede e troca de usuário sem tarefas residuais.

## 11. Apresentação: tarefas

- [x] 11.1 Criar `TasksBloc` com os eventos do `design.md` D10, recarga após cada mutação e falhas como estado ou efeito, sem deixar exceção vazar. Verificar com `bloc_test` e casos de uso mockados, incluindo a falha ao concluir que mantém a tarefa pendente.
- [x] 11.2 Criar o formulário de criação e edição (título obrigatório com trim, descrição multilinha, seletor só de data com ação de limpar, cancelar). Verificar com testes de widget: título vazio e só com espaços, criar sem data, adicionar e remover data e cancelar a edição.
- [x] 11.3 Criar a `TasksPage` com os três blocos, o estado vazio, os blocos vazios ocultos, os cabeçalhos de dia, o destaque de atraso (cor, ícone, rótulo "Atrasada" e `Semantics`), as concluídas recolhíveis com contagem, a exclusão com confirmação e o layout responsivo com largura máxima. Verificar com testes de widget dos cenários da spec `task-timeline`, incluindo 360 px sem overflow e 1600 px centralizado.
- [x] 11.4 Adicionar a atualização: carregar ao abrir, recarregar ao voltar ao primeiro plano, puxar para atualizar e atalhos F5, Ctrl+R e Cmd+R. Verificar com testes de widget que cada gatilho dispara `TasksRequested`.
- [x] 11.5 Remover o `test/widget_test.dart` do template e conferir que todos os textos visíveis vêm de `app_pt.arb`. Verificar que `flutter gen-l10n` roda e que não há string literal visível nos widgets.

## 12. Verificação integrada

- [x] 12.1 Rodar `dart format .`, `flutter analyze` e `flutter test`. Verificar que os três passam sem avisos nem falhas.
- [ ] 12.2 Junto com o usuário, fazer o smoke test contra o Firebase real em macOS, iOS, Android e Windows (este último em máquina Windows): cadastro, login, criar, editar, concluir, reabrir e excluir, tarefa atrasada, logout, reabrir o app autenticado, conta criada numa plataforma e usada em outra e atualização após alteração em outro dispositivo. Verificar que o comportamento bate com as specs nas quatro plataformas.
- [ ] 12.3 Medir o tamanho e o tempo do build release no Windows com os plugins FlutterFire compilados e não usados (risco do `design.md`). Verificar registrando o resultado para o usuário decidir se vale uma change de mitigação.

## Workflow follow-up

- Arquivar a change (`/opsx:archive`) depois que o usuário revisar e aprovar a implementação.
