# CLAUDE.md

Guia para o Claude Code trabalhar neste repositório.

## Visão geral

App Flutter de **Todo List**. O usuário cria tarefas com **título** e **descrição**, e a data é opcional.

Regras de exibição (regra de negócio central):

- Tarefas **sem data** aparecem **no topo** da lista.
- Tarefas **com data** aparecem **abaixo**, organizadas em uma **linha do tempo** (ordem cronológica, agrupadas por dia).

## Plataformas-alvo

Windows, macOS, iOS e Android. Todo código e toda dependência nova precisam funcionar nessas quatro.

- Antes de adicionar um pacote, confira no pub.dev se ele suporta as quatro plataformas. Exemplo: `sqflite` puro não suporta Windows.
- Não use `dart:io` direto em código de UI nem `dart:html`. Isole código específico de plataforma atrás de uma interface.
- O projeto também tem as pastas `web/` e `linux/` geradas pelo `flutter create`. Elas **não são alvo**. Não invista tempo nelas.
- A UI deve ser responsiva, de celular a janela de desktop. Use `LayoutBuilder` ou breakpoints, sem larguras fixas.
- Em desktop, considere mouse, teclado e atalhos. Em mobile, considere toque e áreas seguras.

## Comandos

```bash
flutter pub get                 # instalar dependências
flutter run -d windows          # ou: macos | ios | android | <device id>
flutter analyze                 # lint (flutter_lints); deve passar sem avisos
dart format .                   # formatação
flutter test                    # todos os testes
flutter test test/caminho/x_test.dart   # um arquivo
flutter test --coverage         # cobertura
dart run build_runner build --delete-conflicting-outputs   # só se houver geração de código
```

Builds para iOS e macOS só funcionam em um Mac.

Antes de dar uma tarefa por concluída: `dart format .`, `flutter analyze` e `flutter test` precisam passar.

## Arquitetura

Clean Architecture em camadas, organizada **por feature**, com **BLoC** para gerenciamento de estado. A regra de dependência aponta sempre para dentro: `presentation → domain ← data`.

```
lib/
├── main.dart                  # só inicializa e chama o bootstrap
├── app/                       # MaterialApp, rotas, tema, injeção de dependências
├── core/                      # código compartilhado e sem regra de negócio
│   ├── error/                 # Failure, exceptions
│   ├── usecase/               # contrato base de UseCase
│   └── utils/                 # extensões, formatadores de data
└── features/
    └── tasks/
        ├── domain/            # Dart puro, sem import de flutter
        │   ├── entities/      # Task
        │   ├── repositories/  # TaskRepository (abstract)
        │   └── usecases/      # AddTask, UpdateTask, DeleteTask, ToggleTask, GetTasks
        ├── data/
        │   ├── models/        # TaskModel (serialização)
        │   ├── datasources/   # acesso a armazenamento local
        │   └── repositories/  # TaskRepositoryImpl
        └── presentation/
            ├── bloc/          # TasksBloc, events, states
            ├── pages/
            └── widgets/
```

Os testes espelham a estrutura de `lib/` dentro de `test/`.

### Camadas

- **domain**: entidades, interfaces de repositório e casos de uso. Dart puro, sem Flutter, sem pacotes de armazenamento. É aqui que mora a regra de ordenação (sem data no topo, depois por data).
- **data**: implementa os repositórios do domínio. Converte entre `Model` e `Entity`. Nenhuma outra camada conhece o pacote de persistência.
- **presentation**: widgets e BLoCs. O BLoC chama **casos de uso**, nunca datasources nem repositórios concretos.

### Modelo da tarefa

`Task` é imutável, com `id`, `title` (obrigatório), `description`, `dueDate` (`DateTime?`, nulo significa sem data) e `isCompleted`. Use `Equatable` ou equivalente para igualdade por valor.

### Ordenação e linha do tempo

- A ordenação e o agrupamento por dia ficam em um caso de uso ou serviço de domínio puro, **não** no widget e **não** no `build`.
- Ordem: primeiro as tarefas sem data (ordem de criação, mais recente primeiro), depois as com data em ordem crescente, agrupadas por dia.
- Compare datas pelo dia, ignorando a hora, onde o agrupamento for por dia. Cuidado com fuso horário: persista em UTC ou em formato bem definido e converta só na apresentação.
- Cubra esta regra com testes unitários, incluindo lista vazia, só sem data, só com data, mistura, datas iguais e virada de mês e ano.

## BLoC

- Use `flutter_bloc`. Prefira `Bloc` (eventos explícitos) em vez de `Cubit` para o fluxo principal de tarefas.
- **Eventos** descrevem o que o usuário fez (`TaskAdded`, `TaskDeleted`, `TasksRequested`). **Estados** descrevem a tela (`loading`, `loaded`, `failure`). Ambos imutáveis, com igualdade por valor.
- O BLoC não importa `package:flutter/...` e não conhece `BuildContext`.
- Efeitos únicos (snackbar, navegação) usam `BlocListener`. Reconstrução de UI usa `BlocBuilder`, com `buildWhen` quando fizer sentido.
- Nada de `setState` para estado de domínio. `StatefulWidget` só para estado puramente local de UI (controllers de texto, animação).
- Falhas viram estados de erro. O BLoC nunca deixa uma exceção vazar sem tratamento.
- Todo BLoC tem teste com `bloc_test` e repositório/casos de uso mockados.

## SOLID, aplicado aqui

- **S**: uma responsabilidade por classe. Um caso de uso faz uma coisa. Widget só desenha. BLoC só orquestra. Repositório só persiste.
- **O**: novas formas de exibir ou ordenar tarefas entram por extensão (nova estratégia, novo caso de uso), sem alterar código estável.
- **L**: qualquer implementação de `TaskRepository` (SQLite, memória, fake de teste) deve ser intercambiável sem quebrar os chamadores.
- **I**: interfaces pequenas e focadas. Não crie um repositório "faz tudo".
- **D**: dependa de abstrações. Use e mocke a interface `TaskRepository`, e injete tudo pelo construtor. Sem singletons globais nem `static` com estado dentro das camadas.

Dependências já instaladas para esta arquitetura: `flutter_bloc`, `equatable`, `get_it`, `intl`, `flutter_localizations` e, em dev, `bloc_test` e `mocktail`.

Injeção de dependências: use `get_it`, configurada em `app/`. Os BLoCs são fornecidos via `BlocProvider` e recebem seus casos de uso pelo construtor.

## Convenções de código

- Siga `flutter_lints` (já configurado em `analysis_options.yaml`). Não desative regras para silenciar aviso. Corrija a causa.
- Null safety estrita. Evite `!` e `dynamic`. Prefira `final` e `const` (construtores `const` sempre que possível).
- Nomes de arquivo em `snake_case`, classes em `PascalCase`. Um arquivo por classe pública principal.
- Widgets pequenos e extraídos como classes (`StatelessWidget`), não como métodos que retornam `Widget`.
- Imports com `package:todo/...`. Sem imports relativos que subam com `../..`.
- Textos visíveis ao usuário em português do Brasil, **sempre via localização**, nunca como string solta no widget. Adicione a chave em `lib/l10n/app_pt.arb`, rode `flutter gen-l10n` e use `AppLocalizations.of(context)`. A configuração está em `l10n.yaml`, e o `MaterialApp` está fixado em `pt_BR`.
- Código e identificadores em inglês. Comentários só para o "porquê", não para o "o quê".
- Acessibilidade: `Semantics`/`tooltip` em ícones, contraste adequado, alvos de toque de pelo menos 48x48.

## Persistência

A persistência é feita no **Firebase** (decisão do usuário), provavelmente com Cloud Firestore. Ela fica **atrás de um datasource** na camada `data` (`TaskRemoteDataSource` ou similar), então domínio e presentation não importam nenhum pacote `firebase_*`.

- Os pacotes Firebase ainda **não foram adicionados** ao `pubspec.yaml`, e o projeto Firebase ainda não foi configurado.
- A configuração (`flutterfire configure`, login, geração de `firebase_options.dart`) depende de conta e projeto do usuário. Não rode sem combinar antes.
- Antes de escolher pacotes, confirme o suporte de cada plugin Firebase em **Windows** e **macOS**, que costuma ser mais limitado que o de Android e iOS.
- `Firebase.initializeApp` é chamado no bootstrap (`app/`), nunca dentro de BLoC ou widget.
- Nos testes, use um fake em memória do datasource. Testes não podem depender de rede nem do Firebase real.

## Testes

- **Unitários**: entidades, casos de uso (incluindo a regra de ordenação), repositórios, BLoCs (`bloc_test` + `mocktail`).
- **Widget**: páginas principais e formulário de criação de tarefa (título obrigatório, data opcional).
- Use `mocktail` para mocks. Prefira fakes em memória quando simplificarem o teste.
- Um teste novo para cada bug corrigido e cada regra nova.
- `test/widget_test.dart` é o template do `flutter create` e deve ser substituído por testes reais.

## Fluxo de trabalho

- Mudanças pequenas e focadas. Não misture refatoração com funcionalidade nova.
- Antes de adicionar dependência, justifique e confirme com o usuário. Mantenha `pubspec.yaml` enxuto.
- Respeite a regra de dependência entre camadas. Se uma mudança exigir quebrá-la, pare e discuta.
- Não edite arquivos gerados (`*.g.dart`, `*.freezed.dart`) nem as pastas de plataforma (`android/`, `ios/`, `macos/`, `windows/`) sem necessidade real, como permissões ou configuração de build.

## Git

**Nunca rode comandos do git.** O usuário faz todo o controle de versão. Não execute `git` de nenhuma forma, e não sugira commits, branches, `git init`, PRs ou qualquer outra operação relacionada.
