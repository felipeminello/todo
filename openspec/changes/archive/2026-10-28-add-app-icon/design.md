# Design

## Context

Os quatro conjuntos de ícone são os do template:

- `ios/Runner/Assets.xcassets/AppIcon.appiconset` com 15 tamanhos.
- `macos/Runner/Assets.xcassets/AppIcon.appiconset` com 7 PNGs. O de 32 px também serve como 16@2x, e o de 64 px como 32@2x.
- `android/app/src/main/res/mipmap-*dpi/ic_launcher.png`, sem ícone adaptativo.
- `windows/runner/resources/app_icon.ico`.

O `AndroidManifest.xml` (`@mipmap/ic_launcher`) e o `Runner.rc` (`IDI_APP_ICON`) já apontam para esses recursos.

A arte foi aprovada numa prévia renderizada no Chrome a partir de SVG. Ela já define a geometria das cinco artes num canvas de 1024 px, e a implementação reproduz essa prévia.

Restrições que moldam o desenho:

- O Mac de desenvolvimento não tem ImageMagick, Pillow, librsvg nem Inkscape. O Google Chrome está instalado.
- O `flutter_launcher_icons` (0.14.4) aceita uma imagem por plataforma. Ele não aceita uma arte diferente por faixa de tamanho, que é o que a spec exige no desktop.
- No macOS 26 ou superior, o sistema encolhe e põe sobre uma moldura cinza o ícone cujo formato não bate com o grid. Os relatos indicam que um tile dimensionado pelo template do macOS evita isso, mas não há documento oficial claro. Este Mac roda um macOS recente o bastante para conferir.

## Goals / Non-Goals

**Goals:**

- Um único comando regenera todos os ícones das quatro plataformas a partir das fontes.
- O app não ganha nenhuma dependência de runtime. A única dependência nova é de dev.
- O resultado reproduz a prévia aprovada.

**Non-Goals:**

- Gerar o procedimento no Windows ou no Linux. A renderização roda no Mac. Os PNGs-mestre ficam versionados, então só quem altera a arte precisa do Mac.
- Variantes escura e tingida do iOS, Icon Composer, assets de loja e nome do app (ver `proposal.md`).

## Decisions

### D1. Fonte: seis SVGs em camadas, escritos à mão

```
assets/icon/src/
  full.svg          1024, opaco: fundo + pilha ampliada 1,32x          -> iOS, Android legado
  adaptive_bg.svg   1024 = 108 dp: só o gradiente lavanda              -> Android, fundo
  adaptive_fg.svg   1024 = 108 dp, transparente: pilha no círculo 66dp -> Android, primeiro plano
  monochrome.svg    1024 = 108 dp, branco sobre transparente           -> Android 13+
  desktop.svg       1024, transparente: tile 824 + sombra embutida     -> macOS >= 64, Windows >= 48
  small.svg         1024, transparente: tile 824, dois cartões + caixa -> macOS 16/32, Windows 16/24/32
```

- As camadas da pilha (cartões, caixa, linhas) são as mesmas em todos os arquivos. A completa e a de desktop aplicam a escala de 1,32x da prévia. A adaptativa usa a escala 1x, que cabe no raio de 313 px (66 dp) a partir do centro.
- SVG estático, sem script. A prévia gerava o SVG por JavaScript, e a implementação congela essa geometria em arquivos.
- **Por quê**: as camadas separadas dão o primeiro plano, o fundo e a silhueta sem retrabalho, e trocar uma cor é editar um hex.
- **Alternativas**: imagem gerada por IA, que não separa camadas nem reproduz o resultado; ou desenhar no Figma e exportar, que tira a fonte do repositório.

### D2. Renderização: Chrome headless

Cada SVG é renderizado no tamanho final por `Google Chrome --headless --screenshot` com fundo transparente, numa página mínima que contém só o SVG ocupando a viewport.

- Os tamanhos pequenos (16, 24 e 32) são renderizados direto do `small.svg` naquele tamanho, e não reduzidos a partir de 1024. A rasterização vetorial no tamanho final sai mais nítida.
- O Chrome headless deixa sem pintar as ~30 linhas de baixo da janela, e a quantidade varia a cada execução. Por isso a janela é 128 px mais alta que o ícone, e o script recorta o quadrado de cima com um codec PNG mínimo em `dart:io`. O mesmo passo tira o canal alfa das artes opacas e regrava o PNG com compressão fixa, o que torna a saída determinística.
- **Por quê**: foi o Chrome que renderizou a prévia aprovada, então filtros de desfoque, máscaras e gradientes saem iguais. E ele já está instalado.
- **Alternativas**: `rsvg-convert`, que exige instalar o librsvg via Homebrew e renderiza filtros com pequenas diferenças; ou Inkscape, que é pesado para um passo de build.

### D3. Android e iOS pelo `flutter_launcher_icons`

A configuração fica em `flutter_launcher_icons.yaml` na raiz, para manter o `pubspec.yaml` enxuto. Os pontos que fogem do padrão:

- `adaptive_icon_foreground_inset: 0`. O padrão (16) encolheria o primeiro plano, que já foi desenhado com a zona segura.
- `adaptive_icon_monochrome` aponta para `monochrome.png`.
- `image_path_android` aponta para `full.png`, que vira o ícone estático dos Androids sem ícone adaptativo.
- `image_path_ios` aponta para `full.png`, com `remove_alpha_ios: true` por garantia.
- `macos` e `windows` ficam desligados (D4).

**Por quê**: ele gera as densidades do Android, o XML do `mipmap-anydpi-v26` e o `Contents.json` do iOS, que é a parte mais sujeita a erro quando escrita à mão. **Alternativa**: gerar tudo no script próprio, que dá mais código para manter em troca de evitar uma dependência de dev.

### D4. macOS e Windows por um script Dart próprio

O script fica em `tool/app_icon/` e usa só `dart:io`.

- **macOS**: copia os PNGs renderizados para os nomes do appiconset existente. `app_icon_16` e `app_icon_32` vêm do `small.svg`; de `app_icon_64` a `app_icon_1024`, do `desktop.svg`. O `Contents.json` não muda.
- **Windows**: monta o `app_icon.ico` com entradas PNG (formato aceito desde o Windows Vista). As entradas de 16, 24 e 32 vêm do `small.svg`; as de 48, 64 e 256, do `desktop.svg`. O formato ICO com PNG embutido é só um cabeçalho, um diretório e os blobs PNG, poucas dezenas de linhas.
- **Por quê**: é a única forma de pôr uma arte diferente por faixa de tamanho, que a spec exige, sem nova dependência.
- **Alternativas**: o pacote `image` (`IcoEncoder`), que seria mais uma dependência de dev para o que é concatenar bytes; ou Pillow/ImageMagick, que não estão instalados.

### D5. Um comando para tudo

`dart run tool/app_icon/generate.dart` executa, em ordem:

1. Renderiza os SVGs em `assets/icon/png/` (só no macOS; com `--skip-render`, usa os PNGs versionados).
2. Roda `dart run flutter_launcher_icons`.
3. Escreve o appiconset do macOS e o `.ico` do Windows.

O `tool/app_icon/README.md` documenta o comando e qual fonte alimenta cada arquivo de plataforma.

### D6. PNGs-mestre versionados

Os PNGs renderizados ficam versionados em `assets/icon/png/`. Assim, quem só regenera os ícones de plataforma, inclusive no Windows, não precisa do Chrome. O orçamento é abaixo de 1 MB no total. `assets/icon/` não é declarado em `flutter: assets:` e não entra no bundle.

## Risks / Trade-offs

- [O screenshot headless sai com tamanho ou fundo errado (viewport menor, fundo branco)] → O script confere as dimensões e a presença de alfa de cada PNG renderizado, e falha se não baterem.
- [O tile do desktop ganha a moldura cinza no macOS 26+] → Uma tarefa de verificação roda o app neste Mac e olha a Dock. Se a moldura aparecer, o tile do `desktop.svg` é reajustado ao template do macOS (canto e margem) antes de seguir.
- [O `flutter_launcher_icons` 0.14.4 é de mais de um ano atrás e pode não se dar bem com o Flutter 3.47 ou com o Gradle atual] → A primeira tarefa depois de adicioná-lo é rodar a geração e um `flutter build apk --debug`. Se falhar, o script próprio assume Android e iOS (alternativa de D3).
- [O tile lavanda tem pouco contraste sobre papéis de parede claros] → Aceito na prévia: a sombra segura a borda. Escurecer o gradiente é uma mudança só no SVG (ver Open Questions).
- [Cache de ícones do sistema mostra o ícone antigo durante a verificação] → Desinstalar o app antes de verificar no iOS e no Android, `killall Dock` no macOS e `ie4uinit.exe -show` no Windows.
- [Detalhe fino perdido em 48 px no Windows] → 48 px usa a arte completa, como a spec define. Se ficar ruim na verificação, a faixa da arte pequena passa a incluir 48, e a spec é atualizada.

## Migration Plan

Não há dados nem usuários afetados. A troca é só de arquivos de recurso. O rollback é restaurar os arquivos de ícone das plataformas e remover `assets/icon/`, `tool/app_icon/`, `flutter_launcher_icons.yaml` e a dependência de dev.

## Open Questions

Resolvidas na verificação (tarefa 4.6): o usuário aprovou os ícones como foram gerados.

- Tom do tile: fica o lavanda claro da prévia.
- Arte de 16 px: ficam os dois cartões com a caixa marcada.
