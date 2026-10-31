# home-screen-widget Specification

## Purpose

Define o widget de tela inicial do iOS e do Android, que mostra de relance as tarefas pendentes de hoje e as atrasadas do usuário conectado, sem acesso à rede e mantendo-se correto na virada do dia.

## Requirements

### Requirement: Widget disponível no iOS e no Android
O app SHALL oferecer um widget de tela inicial no iOS e no Android. No iOS MUST haver os tamanhos pequeno, médio e grande. No Android o widget MUST ser redimensionável a partir de 2x2 células. No Windows e no macOS o app MUST se comportar como antes desta mudança.

#### Scenario: Galeria de widgets do iOS
- **WHEN** o usuário abre a galeria de widgets do iOS com o app instalado
- **THEN** o widget do app aparece nos tamanhos pequeno, médio e grande

#### Scenario: Seletor de widgets do Android
- **WHEN** o usuário adiciona o widget do app à tela inicial do Android
- **THEN** o widget ocupa inicialmente 2x2 células e pode ser redimensionado para tamanhos maiores

#### Scenario: Desktop sem efeito
- **WHEN** o usuário cria, edita ou conclui tarefas no Windows ou no macOS
- **THEN** o app se comporta como antes e não exibe erro relacionado ao widget

### Requirement: Tarefas exibidas no widget
O widget SHALL considerar apenas tarefas pendentes cujo vencimento é hoje ou anterior a hoje, no calendário local do dispositivo. Tarefas concluídas, sem data de vencimento ou com vencimento futuro MUST NOT aparecer nem ser contadas. Das tarefas de hoje, só o título é exibido. As atrasadas MUST NOT ser listadas uma a uma: elas aparecem só no agrupamento de atrasadas.

#### Scenario: Pendente de hoje
- **WHEN** existe uma tarefa pendente com vencimento hoje
- **THEN** o título dela aparece no widget

#### Scenario: Concluída some
- **WHEN** o usuário conclui uma tarefa que vencia hoje e o app recarrega a lista
- **THEN** o título dela deixa de aparecer no widget

#### Scenario: Sem data e futura não aparecem
- **WHEN** existem uma tarefa pendente sem data e uma com vencimento amanhã
- **THEN** nenhuma das duas aparece no widget

#### Scenario: Atrasada entra no agrupamento
- **WHEN** existe uma tarefa pendente com vencimento ontem
- **THEN** o título dela não aparece no widget, e ela é contada em "1 tarefa atrasada"

### Requirement: Ordem e agrupamentos
O widget SHALL empilhar as linhas de baixo para cima, da mais recente (embaixo) para a mais antiga (em cima). As tarefas de hoje MUST ser ordenadas pela data de criação. Acima delas ficam os agrupamentos, nesta ordem de cima para baixo: o de atrasadas ("{X} tarefas atrasadas"), quando há alguma atrasada, e o de pendentes ("{X} tarefas pendentes"), quando as tarefas de hoje não cabem todas. Cada agrupamento ocupa uma linha. O de pendentes MUST reunir as tarefas de hoje criadas há mais tempo, e as linhas restantes mostram as mais recentes. Com contagem 1, os textos MUST ficar no singular ("1 tarefa atrasada", "1 tarefa pendente").

#### Scenario: Atrasadas agrupadas
- **WHEN** há uma tarefa de hoje e duas atrasadas, e o widget comporta oito linhas
- **THEN** aparecem "2 tarefas atrasadas" e, abaixo, a tarefa de hoje

#### Scenario: Desempate por criação
- **WHEN** duas tarefas vencem hoje e uma foi criada depois da outra
- **THEN** a criada mais recentemente fica mais embaixo

#### Scenario: Tarefas de hoje que cabem
- **WHEN** o widget comporta três linhas e há três tarefas de hoje e nenhuma atrasada
- **THEN** aparecem as três, sem agrupamento

#### Scenario: Tarefas de hoje que não cabem
- **WHEN** o widget comporta três linhas e há quatro tarefas de hoje e nenhuma atrasada
- **THEN** aparecem "2 tarefas pendentes" e, abaixo, as duas criadas mais recentemente

#### Scenario: Atrasadas e pendentes juntas
- **WHEN** o widget comporta três linhas e há três tarefas de hoje e uma atrasada
- **THEN** aparecem, de cima para baixo, "1 tarefa atrasada", "2 tarefas pendentes" e a tarefa de hoje criada mais recentemente

### Requirement: Destaque do agrupamento de atrasadas
O agrupamento de atrasadas SHALL ser exibido em laranja e acompanhado de um ícone. O agrupamento de pendentes MUST usar a cor secundária do texto. O laranja MUST ter contraste mínimo de 4,5:1 sobre o fundo do widget nos temas claro e escuro.

#### Scenario: Identificação sem depender da cor
- **WHEN** há tarefas atrasadas
- **THEN** o texto "{X} tarefas atrasadas" é exibido em laranja e com um ícone de atraso, e as tarefas de hoje não têm esse ícone

#### Scenario: Leitor de tela
- **WHEN** o VoiceOver ou o TalkBack lê o agrupamento de atrasadas
- **THEN** a leitura é o próprio texto, que já diz que as tarefas estão atrasadas

#### Scenario: Tema escuro
- **WHEN** o sistema está no tema escuro
- **THEN** o laranja do agrupamento usa a variante escura, com contraste mínimo de 4,5:1 sobre o fundo

### Requirement: Layout e estado vazio
O widget SHALL exibir o cabeçalho "Hoje" no topo e a lista ancorada na parte de baixo. Quando não há tarefa para exibir, ele MUST mostrar a mensagem "Nada para hoje". Os textos do widget MUST estar em português do Brasil.

#### Scenario: Poucas tarefas
- **WHEN** há uma única tarefa para exibir num widget grande
- **THEN** o cabeçalho fica no topo, a tarefa fica junto à borda de baixo e o espaço vazio fica entre os dois

#### Scenario: Nenhuma tarefa
- **WHEN** não há tarefa pendente de hoje nem atrasada
- **THEN** o widget mostra "Nada para hoje"

### Requirement: Atualização ao usar o app
Sempre que o app carrega ou recarrega com sucesso a lista de tarefas, o que inclui a abertura e as recargas depois de criar, editar, excluir, concluir ou reabrir, o widget SHALL passar a refletir as tarefas armazenadas, sem que o usuário precise fazer mais nada.

#### Scenario: Tarefa criada para hoje
- **WHEN** o usuário cria uma tarefa com vencimento hoje
- **THEN** o widget passa a exibi-la em poucos segundos

#### Scenario: Tarefa excluída
- **WHEN** o usuário exclui uma tarefa exibida no widget
- **THEN** ela deixa de aparecer no widget

#### Scenario: Data alterada para o futuro
- **WHEN** o usuário edita uma tarefa de hoje e muda o vencimento para a semana seguinte
- **THEN** ela deixa de aparecer no widget

#### Scenario: Recarga falha
- **WHEN** a recarga da lista falha por erro de rede
- **THEN** o widget mantém o conteúdo anterior

### Requirement: Widget sem acesso à rede
O widget MUST NOT acessar a rede nem o serviço de dados. O conteúdo vem apenas do que o app gravou neste dispositivo. Uma alteração feita em outro dispositivo SHALL chegar ao widget só depois de o app ser aberto neste dispositivo e recarregar a lista.

#### Scenario: Alteração em outro dispositivo
- **WHEN** o usuário cria uma tarefa para hoje no desktop e não abre o app no celular
- **THEN** o widget do celular não a exibe

#### Scenario: App aberto depois
- **WHEN** o usuário em seguida abre o app no celular e a lista carrega
- **THEN** o widget do celular passa a exibir a tarefa

#### Scenario: Aparelho sem conexão
- **WHEN** o aparelho está sem conexão
- **THEN** o widget continua exibindo o último conteúdo gravado, sem mensagem de erro

### Requirement: Virada do dia sem abrir o app
O widget SHALL se manter correto na virada do dia sem que o app seja aberto: as tarefas do novo dia passam a aparecer e as do dia anterior que continuam pendentes passam a ser atrasadas. No iOS a troca MUST acontecer à meia-noite local. No Android ela MUST acontecer até alguns minutos depois da meia-noite local, conforme o sistema permitir.

#### Scenario: Tarefa de amanhã vira de hoje
- **WHEN** o app gravou o conteúdo ontem, com uma tarefa vencendo hoje, e não foi aberto desde então
- **THEN** depois da meia-noite o widget exibe essa tarefa como de hoje

#### Scenario: Tarefa de ontem vira atrasada
- **WHEN** uma tarefa de ontem continua pendente e o dia vira sem o app ser aberto
- **THEN** o widget a conta no agrupamento de atrasadas, e não a lista como de hoje

#### Scenario: Mudança de fuso ou de hora
- **WHEN** o usuário muda o fuso horário ou a hora do aparelho
- **THEN** o widget recalcula hoje e as atrasadas pelo novo dia local

### Requirement: Conteúdo desatualizado além do horizonte
O conteúdo gravado SHALL cobrir as tarefas com vencimento até 7 dias depois do dia em que foi gravado. Se hoje passar desse limite sem o app ser aberto, o widget MUST deixar de mostrar a lista e exibir "Abra o app para atualizar".

#### Scenario: Dentro do horizonte
- **WHEN** o app foi aberto há 6 dias
- **THEN** o widget exibe as tarefas de hoje e o agrupamento de atrasadas normalmente

#### Scenario: Além do horizonte
- **WHEN** o app não é aberto há 8 dias
- **THEN** o widget exibe "Abra o app para atualizar" e nenhuma tarefa

#### Scenario: Volta ao normal
- **WHEN** o usuário abre o app depois disso e a lista carrega
- **THEN** o widget volta a exibir as tarefas

### Requirement: Privacidade no logout
Quando o usuário sai da conta, ou quando a sessão é encerrada, o widget SHALL deixar de exibir qualquer título de tarefa e MUST mostrar "Entre no app para ver suas tarefas". Antes do primeiro uso do app no dispositivo, o widget MUST NOT exibir títulos de tarefa.

#### Scenario: Logout
- **WHEN** o usuário sai da conta
- **THEN** o widget deixa de exibir tarefas e mostra "Entre no app para ver suas tarefas"

#### Scenario: Troca de usuário
- **WHEN** um usuário sai e outro entra no mesmo aparelho
- **THEN** o widget exibe só as tarefas do novo usuário, sem nenhuma do anterior

#### Scenario: App nunca aberto
- **WHEN** o widget é adicionado antes de o app ser aberto pela primeira vez
- **THEN** ele não exibe nenhum título de tarefa

### Requirement: Toque abre o app
O widget SHALL ser só leitura. Tocar em qualquer ponto dele MUST abrir o app na tela principal. O widget MUST NOT oferecer ação de concluir, editar ou excluir.

#### Scenario: Toque numa tarefa
- **WHEN** o usuário toca no título de uma tarefa no widget
- **THEN** o app abre na tela principal, sem alterar a tarefa

### Requirement: Falha no widget não afeta o app
Uma falha ao gravar o conteúdo do widget MUST NOT mudar o que o app exibe nem gerar mensagem de erro para o usuário.

#### Scenario: Gravação falha
- **WHEN** a gravação do conteúdo do widget falha depois de uma recarga bem-sucedida
- **THEN** a lista de tarefas do app é exibida normalmente e nenhum erro aparece
