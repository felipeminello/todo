# Ícone do app

Todos os ícones de Android, iOS, macOS e Windows saem das fontes SVG em `assets/icon/src/`. Não edite à mão nenhum arquivo de ícone das pastas de plataforma. Altere o SVG e regenere.

## Regenerar

Na raiz do projeto:

```bash
dart run tool/app_icon/generate.dart                # renderiza os SVGs e gera tudo
dart run tool/app_icon/generate.dart --skip-render  # gera a partir dos PNGs versionados
```

- A renderização usa o Google Chrome em modo headless. No macOS o caminho padrão é detectado sozinho; em outro sistema, aponte a variável `CHROME` para o executável.
- Com `--skip-render`, o Chrome não é necessário. Use quando só precisar refazer os arquivos de plataforma, por exemplo no Windows.
- O script confere o tamanho e a transparência de cada PNG antes de gerar e para com erro se algo não bater.

## O que gera o quê

| Fonte (`assets/icon/src/`) | PNG-mestre (`assets/icon/png/`) | Destino |
|---|---|---|
| `full.svg` | `full_1024.png` (opaco) | iOS (todos os tamanhos) e ícone estático do Android abaixo da API 26 |
| `adaptive_bg.svg` | `adaptive_bg_1024.png` (opaco) | Android 8+, camada de fundo |
| `adaptive_fg.svg` | `adaptive_fg_1024.png` | Android 8+, primeiro plano |
| `monochrome.svg` | `monochrome_1024.png` | Android 13+, ícone temático |
| `desktop.svg` | `desktop_{48,64,128,256,512,1024}.png` | macOS 64 a 1024 px; Windows 48, 64 e 256 px |
| `small.svg` | `small_{16,24,32}.png` | macOS 16 e 32 px; Windows 16, 24 e 32 px |

Android e iOS são gerados pelo `flutter_launcher_icons` (configuração em `flutter_launcher_icons.yaml`, na raiz). macOS e Windows são gerados pelo próprio script, porque usam uma arte diferente por faixa de tamanho.

## Regras do desenho

- O canvas de todas as fontes tem 1024 px.
- Nas camadas do Android, 1024 px equivalem a 108 dp. Só o círculo central de 66 dp (raio de 313 px) aparece em qualquer launcher, então todo o desenho, incluindo a sombra, fica dentro dele.
- `full.svg` precisa ser totalmente opaco: o iOS rejeita ícone com transparência.
- `desktop.svg` e `small.svg` são um tile de 824 px centrado, com a sombra embutida e fundo transparente. O macOS e o Windows não recortam nem sombreiam o ícone.
- Até 32 px vale a arte simplificada (dois cartões e a caixa marcada). Detalhe fino vira ruído nesse tamanho.
