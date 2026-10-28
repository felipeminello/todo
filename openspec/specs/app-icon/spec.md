# app-icon Specification

## Purpose

Define como o app se apresenta no sistema operacional: qual ícone aparece em cada plataforma, como ele se comporta sob as máscaras, os temas e os tamanhos de cada sistema, e como os arquivos de ícone das plataformas são mantidos a partir de uma fonte única.

## Requirements

### Requirement: Ícone próprio em todas as plataformas-alvo
O app SHALL exibir o ícone "pilha com check" em Android, iOS, macOS e Windows, onde quer que o sistema mostre o ícone do app: tela inicial, gaveta de apps, Dock, Finder, barra de tarefas e Explorer. Nenhum recurso de ícone dessas plataformas MUST conter o logo do Flutter.

#### Scenario: App instalado no Android
- **WHEN** o app é instalado num aparelho Android
- **THEN** a tela inicial e a gaveta de apps mostram a pilha com check, e não o logo do Flutter

#### Scenario: App instalado no iOS
- **WHEN** o app é instalado num iPhone ou iPad
- **THEN** a tela inicial, a busca e os Ajustes mostram a pilha com check

#### Scenario: App aberto no macOS
- **WHEN** o app é aberto no macOS
- **THEN** a Dock, o Finder e o seletor de apps (Cmd+Tab) mostram a pilha com check

#### Scenario: App aberto no Windows
- **WHEN** o app é aberto no Windows
- **THEN** a barra de tarefas, a barra de título da janela e o Explorer mostram a pilha com check

#### Scenario: Nenhum resto do ícone padrão
- **WHEN** os arquivos de ícone das quatro plataformas são inspecionados
- **THEN** nenhum deles contém o logo do Flutter

### Requirement: Ícone do iOS opaco e sem forma própria
O ícone do iOS SHALL ser uma arte quadrada de 1024 px, totalmente opaca, sem cantos arredondados nem sombra fora do quadro, porque o sistema aplica a própria máscara. A pilha MUST ocupar o tile em proporção semelhante à dos ícones nativos, e não à escala reduzida da zona segura do Android.

#### Scenario: Arte sem transparência
- **WHEN** o ícone de 1024 px do iOS é inspecionado
- **THEN** ele não tem canal alfa nem pixels transparentes

#### Scenario: Recorte do sistema
- **WHEN** o iOS aplica a máscara de cantos contínuos
- **THEN** a pilha e a sombra projetada ficam inteiras dentro do recorte

### Requirement: Ícone adaptativo no Android
No Android 8 ou superior, o ícone SHALL ser adaptativo, com uma camada de fundo e uma de primeiro plano. Todo o desenho da pilha, incluindo a sombra, MUST caber no círculo central de 66 dp do canvas de 108 dp, para que nenhuma máscara de launcher o corte.

#### Scenario: Launcher com máscara circular
- **WHEN** o launcher recorta o ícone em círculo
- **THEN** os três cartões e a caixa de seleção aparecem inteiros, sem corte

#### Scenario: Launcher com outras máscaras
- **WHEN** o launcher usa squircle, quadrado arredondado ou gota
- **THEN** a pilha aparece inteira e centralizada, e só o fundo lavanda é recortado

#### Scenario: Android anterior ao 8
- **WHEN** o app roda num Android sem suporte a ícone adaptativo
- **THEN** o launcher mostra uma versão estática do mesmo ícone

### Requirement: Ícone temático no Android 13+
O ícone adaptativo SHALL incluir uma camada monocromática. Ela é uma silhueta de cor única: o cartão da frente cheio com o check vazado e os dois cartões de trás como faixas acima dele. Ela MUST ser reconhecível sem cor, sem volume e sem as linhas de texto da arte colorida.

#### Scenario: Ícones temáticos ligados
- **WHEN** o usuário ativa os ícones temáticos no Android 13 ou superior
- **THEN** o app mostra a silhueta monocromática tingida com as cores do tema do sistema

#### Scenario: Ícones temáticos desligados
- **WHEN** os ícones temáticos estão desligados
- **THEN** o app mostra o ícone colorido com volume e sombra

### Requirement: Ícone de desktop com forma e sombra próprias
No macOS e no Windows, que não recortam nem sombreiam o ícone, o ícone SHALL ser um tile de cantos arredondados no grid de ícones do macOS, com fundo transparente fora do tile e a sombra projetada embutida na arte.

#### Scenario: macOS 26 ou superior
- **WHEN** o app aparece na Dock do macOS 26 ou superior
- **THEN** o sistema mostra o tile do app sem a moldura cinza que aplica a ícones fora do padrão

#### Scenario: Fundo escuro
- **WHEN** o ícone é exibido sobre um fundo escuro no macOS ou no Windows
- **THEN** o tile continua com bordas definidas e não aparece halo claro em volta

### Requirement: Arte simplificada em tamanhos pequenos
Nos tamanhos de 32 px ou menos (macOS 16 e 32 px; Windows 16, 24 e 32 px), o ícone SHALL usar uma arte simplificada, com dois cartões e uma caixa de seleção grande marcada, sem as linhas de texto. Os tamanhos de 48 px ou mais MUST usar a arte completa.

#### Scenario: Windows Explorer em visualização de detalhes
- **WHEN** o Explorer mostra o executável do app em 16 px
- **THEN** a caixa roxa com o check é distinguível, e o ícone não vira uma mancha sem forma

#### Scenario: Ícone grande no Windows
- **WHEN** o Explorer mostra o executável em ícones extragrandes (256 px)
- **THEN** aparece a arte completa, com os três cartões e as linhas de texto

#### Scenario: Conjunto de tamanhos do Windows
- **WHEN** o arquivo de ícone do Windows é inspecionado
- **THEN** ele contém as resoluções 16, 24, 32, 48, 64 e 256 px

### Requirement: Geração a partir de fonte única
Todos os arquivos de ícone das plataformas SHALL ser gerados a partir das fontes versionadas no repositório, por um procedimento documentado. Nenhum arquivo de ícone de plataforma MUST ser editado à mão.

#### Scenario: Mudança de cor no ícone
- **WHEN** uma cor é alterada na fonte e o procedimento de geração é executado
- **THEN** os ícones das quatro plataformas são atualizados de forma consistente, sem nenhum passo manual por plataforma

#### Scenario: Regeneração sem mudança
- **WHEN** o procedimento é executado duas vezes sem alterar a fonte
- **THEN** o segundo resultado é visualmente idêntico ao primeiro
