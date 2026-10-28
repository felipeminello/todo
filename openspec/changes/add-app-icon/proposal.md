# Proposal

## Why

Os ícones do app ainda são os do `flutter create`, o logo do Flutter, nas quatro plataformas. O app vai para produção, e o ícone é a primeira coisa que o usuário vê na tela inicial, na Dock e na barra de tarefas. O conceito visual já foi escolhido e validado numa prévia: a **pilha com check**, com volume e sombra.

## What Changes

- Substitui o ícone padrão do Flutter em **Android, iOS, macOS e Windows** pelo conceito "pilha com check": três cartões empilhados em profundidade, e o da frente traz uma caixa de seleção roxa marcada. Fundo lavanda claro e roxo do tema do app.
- O ícone deixa de ser um único PNG e passa a ser **cinco artes-mestre**, cada uma desenhada para o que a plataforma faz com ela:
  1. **Completa**: arte sangrada e opaca de 1024 px, para iOS e App Store.
  2. **Adaptativa**: camadas de fundo e de primeiro plano do Android 8+, com a pilha inteira dentro da zona segura de 66 dp.
  3. **Monocromática**: silhueta para o ícone temático do Android 13+.
  4. **Desktop**: tile no grid do macOS com a sombra embutida, também usado nos tamanhos grandes do Windows.
  5. **Pequena**: versão simplificada para 32 px ou menos (macOS 16/32 e Windows 16/24/32).
- As artes passam a ter uma **fonte versionada em SVG** e um **procedimento único de geração** que produz todos os arquivos de plataforma. Nenhum ícone de plataforma é editado à mão.
- Fora do escopo, cada item para uma change futura: variantes escura e tingida do iOS 18+, ícone em camadas do Icon Composer (Liquid Glass), o ícone de 512 px e as imagens da Play Store, e a padronização do nome exibido do app (hoje "todo", "Todo" e "Minhas Tarefas" convivem).

## Capabilities

### New Capabilities

- `app-icon`: a identidade do app no sistema operacional. Cobre qual ícone aparece em cada plataforma, como ele se comporta sob as máscaras e os temas do sistema, quais artes servem cada faixa de tamanho e como os arquivos de plataforma são gerados a partir da fonte.

### Modified Capabilities

Nenhuma.

## Impact

- **Arquivos de plataforma** (necessidade real, conforme o `CLAUDE.md`):
  - Android: `android/app/src/main/res/mipmap-*`, além de `mipmap-anydpi-v26/` e dos drawables de fundo, primeiro plano e monocromático, todos novos.
  - iOS: `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
  - macOS: `macos/Runner/Assets.xcassets/AppIcon.appiconset/`.
  - Windows: `windows/runner/resources/app_icon.ico`.
  - O `AndroidManifest.xml` e o `Runner.rc` já apontam para esses recursos e não mudam.
- **Novos arquivos no repositório**: fontes SVG e PNGs-mestre em `assets/icon/`, o script de geração em `tool/app_icon/` e o arquivo de configuração `flutter_launcher_icons.yaml`. Nada disso entra no bundle do app.
- **Dependência nova (dev)**: `flutter_launcher_icons`, só em `dev_dependencies`. Precisa da confirmação do usuário antes de entrar no `pubspec.yaml`.
- **Ferramenta de máquina**: o Google Chrome em modo headless, já instalado no Mac de desenvolvimento, renderiza o SVG em PNG. Não é dependência do app nem do build.
- **Código Dart do app**: nenhum. Domínio, dados e apresentação não mudam.
