# Spec Delta

## Purpose

Define o ciclo de vida de uma tarefa do usuário (criar, editar, excluir, concluir e reabrir), as regras de validação do formulário e o significado da data de vencimento como uma data de calendário.

## ADDED Requirements

### Requirement: Criar tarefa
O sistema SHALL permitir que o usuário autenticado crie uma tarefa com título, descrição opcional e data de vencimento opcional. A tarefa criada MUST ficar pendente, ser salva na conta do usuário e registrar o momento da criação.

#### Scenario: Criar com título, descrição e data
- **WHEN** o usuário preenche título, descrição e data de vencimento e confirma
- **THEN** a tarefa aparece pendente na linha do tempo, no dia escolhido

#### Scenario: Criar só com título
- **WHEN** o usuário preenche apenas o título e confirma
- **THEN** a tarefa aparece pendente entre as tarefas sem data, com descrição vazia

#### Scenario: Tarefa persiste
- **WHEN** o usuário cria uma tarefa, fecha o app e entra de novo, em qualquer plataforma
- **THEN** a tarefa continua lá, com os mesmos título, descrição e data

### Requirement: Título obrigatório
O sistema MUST recusar salvar uma tarefa cujo título esteja vazio ou contenha apenas espaços. Espaços no início e no fim do título MUST ser descartados ao salvar.

#### Scenario: Título vazio
- **WHEN** o usuário tenta salvar uma tarefa com o título vazio
- **THEN** a tarefa não é salva e o campo de título mostra um erro de validação

#### Scenario: Título só com espaços
- **WHEN** o usuário tenta salvar uma tarefa com o título "   "
- **THEN** a tarefa não é salva e o campo de título mostra um erro de validação

#### Scenario: Espaços nas bordas
- **WHEN** o usuário salva uma tarefa com o título "  Comprar pão  "
- **THEN** a tarefa é salva com o título "Comprar pão"

### Requirement: Data de vencimento é uma data de calendário
A data de vencimento SHALL representar apenas um dia (dia, mês e ano), sem hora e sem fuso horário. O dia escolhido MUST ser o mesmo dia exibido e persistido em qualquer fuso e plataforma.

#### Scenario: Dia preservado em fuso negativo
- **WHEN** um usuário em UTC-3 escolhe o dia 27/10/2026 e a tarefa é salva e recarregada
- **THEN** a tarefa continua com vencimento em 27/10/2026, e não em 26/10/2026

#### Scenario: Dia preservado entre dispositivos em fusos diferentes
- **WHEN** a tarefa com vencimento em 27/10/2026 é criada num dispositivo em UTC-3 e aberta num dispositivo em UTC+9
- **THEN** os dois dispositivos mostram o vencimento em 27/10/2026

#### Scenario: Formulário pede só a data
- **WHEN** o usuário abre o seletor de data do formulário
- **THEN** só é possível escolher o dia, sem campo de hora

### Requirement: Data de vencimento opcional e removível
O sistema SHALL permitir criar tarefas sem data, adicionar uma data a uma tarefa que não tinha e remover a data de uma tarefa que tinha.

#### Scenario: Remover a data
- **WHEN** o usuário edita uma tarefa com vencimento em 27/10/2026, limpa a data e salva
- **THEN** a tarefa passa a aparecer entre as tarefas sem data

#### Scenario: Adicionar uma data
- **WHEN** o usuário edita uma tarefa sem data, escolhe 30/10/2026 e salva
- **THEN** a tarefa passa a aparecer na linha do tempo no dia 30/10/2026

#### Scenario: Data no passado é aceita
- **WHEN** o usuário cria uma tarefa com vencimento anterior a hoje
- **THEN** a tarefa é salva e aparece na linha do tempo marcada como atrasada

### Requirement: Editar tarefa
O sistema SHALL permitir alterar título, descrição e data de vencimento de uma tarefa existente, com as mesmas validações da criação. A edição MUST preservar o momento de criação e o estado de conclusão.

#### Scenario: Editar o título
- **WHEN** o usuário altera o título de uma tarefa e salva
- **THEN** a tarefa exibe o novo título e mantém sua posição relativa por ordem de criação

#### Scenario: Cancelar a edição
- **WHEN** o usuário altera campos de uma tarefa e cancela
- **THEN** a tarefa permanece como estava antes

### Requirement: Excluir tarefa
O sistema SHALL permitir excluir uma tarefa, pendente ou concluída. A exclusão MUST ser permanente e exigir confirmação do usuário.

#### Scenario: Excluir com confirmação
- **WHEN** o usuário pede para excluir uma tarefa e confirma
- **THEN** a tarefa some da lista e não volta ao recarregar

#### Scenario: Desistir da exclusão
- **WHEN** o usuário pede para excluir uma tarefa e cancela a confirmação
- **THEN** a tarefa continua na lista

### Requirement: Concluir e reabrir tarefa
O sistema SHALL permitir marcar uma tarefa pendente como concluída, registrando o momento da conclusão, e reabrir uma tarefa concluída, voltando-a a pendente. A data de vencimento, o título e a descrição MUST ser preservados nos dois sentidos.

#### Scenario: Concluir
- **WHEN** o usuário marca uma tarefa pendente como concluída
- **THEN** a tarefa sai da lista pendente e aparece na lista de concluídas

#### Scenario: Reabrir
- **WHEN** o usuário desmarca uma tarefa concluída que tem vencimento em 30/10/2026
- **THEN** a tarefa sai da lista de concluídas e volta à linha do tempo no dia 30/10/2026

### Requirement: Falha ao carregar ou alterar tarefas
O sistema SHALL informar ao usuário quando carregar, criar, editar, excluir, concluir ou reabrir uma tarefa falhar por erro de conexão ou do servidor. Uma alteração que falhou MUST deixar a lista exibida igual ao que está salvo.

#### Scenario: Falha ao carregar
- **WHEN** o carregamento das tarefas falha por falta de conexão
- **THEN** a tela informa a falha e oferece uma ação para tentar de novo

#### Scenario: Falha ao concluir
- **WHEN** o usuário marca uma tarefa como concluída e a operação falha
- **THEN** uma mensagem informa a falha e a tarefa continua pendente na lista

### Requirement: Atualizar a lista manualmente
O sistema SHALL recarregar as tarefas do servidor ao abrir a tela de tarefas, quando o app volta ao primeiro plano e quando o usuário pede atualização: puxando a lista para baixo em telas de toque, ou pelo atalho F5 ou Ctrl+R (Cmd+R no macOS) no desktop.

#### Scenario: Alteração feita em outro dispositivo
- **WHEN** o usuário cria uma tarefa no celular e depois pede atualização no Windows
- **THEN** a nova tarefa aparece no Windows

#### Scenario: Voltar ao app
- **WHEN** o app volta ao primeiro plano depois de ficar em segundo plano
- **THEN** as tarefas são recarregadas do servidor
