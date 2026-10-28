# Tasks

## 1. Dependência

- [x] 1.1 Confirmar com o usuário a entrada do `flutter_launcher_icons` ^0.14.4 em `dev_dependencies` (justificativa no `design.md` D3). Concluída quando o usuário aprovar.
- [x] 1.2 Adicionar a dependência aprovada a `dev_dependencies` no `pubspec.yaml`. Verificar que `flutter pub get` e `flutter analyze` passam.

## 2. Fontes SVG (`assets/icon/src/`)

- [x] 2.1 Escrever `full.svg`: fundo lavanda com brilho, pilha de três cartões ampliada 1,32x, caixa marcada, linhas de texto e sombras, tudo opaco e na geometria da prévia aprovada. Verificar abrindo no Chrome ao lado da prévia: mesma composição e nada cortado pelo squircle do iOS.
- [x] 2.2 Escrever `adaptive_bg.svg` (só o gradiente e o brilho) e `adaptive_fg.svg` (pilha em escala 1x sobre transparente). Verificar abrindo o primeiro plano com um círculo de raio 313 px centrado sobreposto: nenhum cartão nem sombra o atravessa.
- [x] 2.3 Escrever `monochrome.svg`: cartão da frente cheio com o check vazado e os dois cartões de trás como faixas separadas por um vão, em branco sobre transparente. Verificar que a silhueta cabe no mesmo círculo de 313 px e que a leitura bate com a seção 3 da prévia.
- [x] 2.4 Escrever `desktop.svg` (tile de 824 px no grid do macOS, pilha 1,32x, sombra projetada embutida e transparente fora do tile) e `small.svg` (mesmo tile, dois cartões e a caixa grande com o check, fundo um tom mais escuro). Verificar abrindo os dois no Chrome em fundo claro e escuro: sem halo em volta do tile.

## 3. Geração (`tool/app_icon/` e `flutter_launcher_icons.yaml`)

- [x] 3.1 Criar o passo de renderização: cada SVG vira PNG em `assets/icon/png/` pelo Chrome headless, com fundo transparente. Os mestres saem em 1024, e o `small.svg` também em 16, 24 e 32 renderizados direto, assim como o `desktop.svg` nos tamanhos de desktop. O script confere as dimensões e o alfa esperados e falha se não baterem. Verificar com `sips -g pixelWidth -g pixelHeight -g hasAlpha assets/icon/png/*.png` (só `full.png` sem alfa) e `du -sh assets/icon` abaixo de 1 MB.
- [x] 3.2 Criar `flutter_launcher_icons.yaml` conforme o `design.md` D3 (`adaptive_icon_foreground_inset: 0`, monocromático, `remove_alpha_ios`, macOS e Windows desligados) e rodar a geração. Verificar que `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` declara fundo, primeiro plano e `<monochrome>`, que `sips -g hasAlpha` no 1024 do iOS responde `no` e que `flutter build apk --debug` passa. Se a ferramenta falhar com o Flutter atual, parar e discutir a alternativa do D3.
- [x] 3.3 Criar o passo do macOS: copia os PNGs para os sete nomes do appiconset existente, com 16 e 32 vindos de `small` e de 64 a 1024 vindos de `desktop`, sem alterar o `Contents.json`. Verificar com `sips -g pixelWidth macos/Runner/Assets.xcassets/AppIcon.appiconset/*.png` e abrindo os de 16 e 32 para confirmar que são a arte simplificada.
- [x] 3.4 Criar o escritor de `.ico` em Dart puro (`dart:io`), com cabeçalho, diretório e entradas PNG: 16, 24 e 32 de `small`; 48, 64 e 256 de `desktop`. Gravar em `windows/runner/resources/app_icon.ico`. Verificar com `file windows/runner/resources/app_icon.ico`, que deve listar 6 ícones de 16x16 a 256x256.
- [x] 3.5 Criar `tool/app_icon/generate.dart`, que encadeia renderização (pulável com `--skip-render`), `flutter_launcher_icons`, macOS e Windows, e o `tool/app_icon/README.md`, com o comando e a tabela de fonte para destino. Verificar que rodar o comando duas vezes seguidas produz os mesmos `shasum` em todos os arquivos de ícone de plataforma, que `--skip-render` funciona sem o Chrome e que `dart format .` e `flutter analyze` passam sem avisos.

## 4. Verificação nas plataformas

- [ ] 4.1 macOS: remover o app antigo, rodar `killall Dock` e `flutter run -d macos`. Verificar que Dock, Finder e Cmd+Tab mostram a pilha com check e que a Dock não põe moldura cinza em volta. Se puser, ajustar o tile do `desktop.svg` ao template do macOS, regenerar e verificar de novo.
- [ ] 4.2 iOS: desinstalar o app do simulador e rodar `flutter run` num iPhone e num iPad. Verificar a tela inicial, a busca e os Ajustes, e que a pilha e a sombra ficam inteiras dentro do recorte.
- [ ] 4.3 Android: desinstalar e rodar num emulador com API 33 ou superior. Verificar o ícone com a máscara padrão e, com os ícones temáticos ligados, a silhueta monocromática tingida. Se o `minSdk` efetivo for menor que 26, verificar também num emulador com API abaixo de 26 que aparece o ícone estático.
- [ ] 4.4 Windows (em máquina Windows, junto com o usuário): `flutter build windows` e `ie4uinit.exe -show`. Verificar a barra de tarefas, a barra de título e o Explorer em "Detalhes" (16 px, arte simplificada reconhecível) e em "Ícones extragrandes" (256 px, arte completa).
- [x] 4.5 Confirmar que nenhum arquivo de ícone de plataforma ficou com o logo do Flutter. Listar os arquivos de `mipmap-*`, dos dois appiconsets e o `.ico`, e verificar que todos foram regravados pela geração (`find ... -newer flutter_launcher_icons.yaml`) e conferem visualmente.
- [ ] 4.6 Mostrar ao usuário os ícones gerados e decidir as duas questões em aberto do `design.md` (tom do tile e conteúdo do 16 px). Se houver ajuste, ele fica só nos SVGs: regenerar e repetir a verificação da plataforma afetada.
- [x] 4.7 Rodar `dart format .`, `flutter analyze` e `flutter test`. Verificar que os três passam sem avisos nem falhas.

## Workflow follow-up

- O usuário faz o commit das alterações.
- Arquivar a change depois da verificação nas quatro plataformas.
