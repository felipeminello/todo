# task-timeline Specification

## Purpose

Define como as tarefas do usuário são organizadas na tela principal: as pendentes sem data no topo, as pendentes com data numa linha do tempo agrupada por dia com destaque de atraso, e as concluídas numa lista separada.

## Requirements

### Requirement: Três blocos na tela de tarefas
A tela de tarefas SHALL exibir, nesta ordem: as tarefas pendentes sem data, a linha do tempo das tarefas pendentes com data e a lista de tarefas concluídas. Cada tarefa MUST aparecer em exatamente um bloco.

#### Scenario: Mistura de tarefas
- **WHEN** o usuário tem uma tarefa pendente sem data, uma pendente com data e uma concluída
- **THEN** a sem data aparece primeiro, a com data aparece na linha do tempo abaixo dela e a concluída aparece só na lista de concluídas

#### Scenario: Concluída com data não aparece na linha do tempo
- **WHEN** uma tarefa com vencimento em 27/10/2026 está concluída
- **THEN** ela aparece somente na lista de concluídas, e não no dia 27/10/2026 da linha do tempo

#### Scenario: Nenhuma tarefa
- **WHEN** o usuário não tem nenhuma tarefa
- **THEN** a tela mostra um estado vazio convidando a criar a primeira tarefa

#### Scenario: Bloco vazio não aparece
- **WHEN** o usuário só tem tarefas pendentes sem data
- **THEN** a tela não mostra cabeçalho nem espaço para a linha do tempo nem para as concluídas

### Requirement: Ordem das tarefas sem data
As tarefas pendentes sem data SHALL ser ordenadas da criada mais recentemente para a criada há mais tempo.

#### Scenario: Duas tarefas sem data
- **WHEN** o usuário cria a tarefa A e depois a tarefa B, ambas sem data
- **THEN** B aparece acima de A

### Requirement: Linha do tempo agrupada por dia
As tarefas pendentes com data SHALL ser agrupadas por dia de vencimento, com um cabeçalho que identifica o dia, e os grupos MUST aparecer em ordem cronológica crescente.

#### Scenario: Dias diferentes
- **WHEN** existem tarefas pendentes com vencimento em 02/11/2026, 27/10/2026 e 30/10/2026
- **THEN** os grupos aparecem na ordem 27/10/2026, 30/10/2026, 02/11/2026

#### Scenario: Mesmo dia vira um grupo só
- **WHEN** existem três tarefas pendentes com vencimento em 27/10/2026
- **THEN** elas aparecem sob um único cabeçalho de 27/10/2026

#### Scenario: Virada de mês
- **WHEN** existem tarefas pendentes com vencimento em 31/10/2026 e 01/11/2026
- **THEN** o grupo de 31/10/2026 aparece antes do de 01/11/2026

#### Scenario: Virada de ano
- **WHEN** existem tarefas pendentes com vencimento em 31/12/2026 e 01/01/2027
- **THEN** o grupo de 31/12/2026 aparece antes do de 01/01/2027

### Requirement: Desempate dentro do dia
Dentro de um mesmo dia da linha do tempo, as tarefas SHALL ser ordenadas da criada há mais tempo para a criada mais recentemente.

#### Scenario: Duas tarefas no mesmo dia
- **WHEN** o usuário cria a tarefa A e depois a tarefa B, ambas com vencimento em 27/10/2026
- **THEN** A aparece acima de B no grupo de 27/10/2026

#### Scenario: Ordem estável
- **WHEN** a lista é recarregada várias vezes sem alterações
- **THEN** as tarefas aparecem sempre na mesma ordem

### Requirement: Tarefa atrasada
Uma tarefa SHALL ser considerada atrasada quando está pendente e sua data de vencimento é anterior ao dia de hoje no calendário local do dispositivo. Tarefas com vencimento hoje MUST NOT ser consideradas atrasadas.

#### Scenario: Vencimento ontem
- **WHEN** hoje é 27/10/2026 e uma tarefa pendente vence em 26/10/2026
- **THEN** a tarefa é atrasada

#### Scenario: Vencimento hoje
- **WHEN** hoje é 27/10/2026 e uma tarefa pendente vence em 27/10/2026
- **THEN** a tarefa não é atrasada

#### Scenario: Concluída nunca é atrasada
- **WHEN** hoje é 27/10/2026 e uma tarefa concluída vence em 20/10/2026
- **THEN** a tarefa não é atrasada

#### Scenario: Passa a ser atrasada com a virada do dia
- **WHEN** uma tarefa pendente vence em 27/10/2026 e o app é usado em 28/10/2026
- **THEN** a tarefa é exibida como atrasada após o recarregamento da lista

### Requirement: Destaque visual de atraso
As tarefas atrasadas SHALL permanecer na linha do tempo, na posição do seu dia, destacadas em cor laranja e acompanhadas de um ícone e do rótulo "Atrasada". A cor MUST NOT ser o único sinal, o rótulo MUST ser anunciado por leitores de tela, e o texto em laranja MUST ter contraste mínimo de 4,5:1 nos temas claro e escuro.

#### Scenario: Atrasada continua na linha do tempo
- **WHEN** hoje é 27/10/2026 e existem tarefas pendentes que vencem em 25/10/2026 e em 28/10/2026
- **THEN** o grupo de 25/10/2026 aparece antes do de 28/10/2026 e só o de 25/10/2026 está destacado em laranja com ícone e rótulo "Atrasada"

#### Scenario: Leitor de tela
- **WHEN** um leitor de tela percorre um grupo atrasado
- **THEN** ele anuncia a data e que as tarefas estão atrasadas

### Requirement: Lista de concluídas
As tarefas concluídas SHALL aparecer numa lista separada, abaixo da linha do tempo, ordenadas da concluída mais recentemente para a concluída há mais tempo. A lista MUST exibir a quantidade de tarefas concluídas e MUST poder ser recolhida e expandida, começando recolhida.

#### Scenario: Ordem das concluídas
- **WHEN** o usuário conclui a tarefa A e depois a tarefa B
- **THEN** B aparece acima de A na lista de concluídas

#### Scenario: Recolhida por padrão
- **WHEN** o usuário abre a tela de tarefas e tem 3 tarefas concluídas
- **THEN** a lista de concluídas aparece recolhida, mostrando a quantidade 3

#### Scenario: Reabrir sai da lista
- **WHEN** o usuário reabre uma tarefa concluída
- **THEN** ela deixa de aparecer na lista de concluídas e a quantidade diminui em um

### Requirement: Layout responsivo
A tela de tarefas SHALL funcionar de larguras de celular a janelas de desktop, sem rolagem horizontal. Em larguras de desktop, o conteúdo MUST ficar limitado a uma largura máxima legível e centralizado.

#### Scenario: Celular
- **WHEN** a tela de tarefas é exibida com 360 px de largura
- **THEN** todo o conteúdo cabe na largura, sem rolagem horizontal

#### Scenario: Janela larga
- **WHEN** a tela de tarefas é exibida numa janela de 1600 px de largura
- **THEN** a lista fica centralizada com largura máxima limitada, e não esticada de borda a borda
