# Spec Delta

## Purpose

Identifica o usuário por e-mail e senha em todas as plataformas-alvo, para que cada pessoa acesse apenas as próprias tarefas, com uma sessão que sobrevive ao fechamento do app.

## ADDED Requirements

### Requirement: Cadastro com e-mail e senha
O sistema SHALL permitir criar uma conta informando e-mail e senha. Com o cadastro aceito, o usuário MUST ficar autenticado sem precisar fazer login em seguida.

#### Scenario: Cadastro válido
- **WHEN** o usuário informa um e-mail ainda não cadastrado e uma senha aceita pelo provedor e confirma o cadastro
- **THEN** a conta é criada e o usuário é levado à tela de tarefas, autenticado e com a lista vazia

#### Scenario: E-mail já cadastrado
- **WHEN** o usuário tenta se cadastrar com um e-mail que já possui conta
- **THEN** o cadastro é recusado e uma mensagem informa que o e-mail já está em uso

#### Scenario: Senha fraca
- **WHEN** o usuário tenta se cadastrar com uma senha que o provedor considera fraca (menos de 6 caracteres)
- **THEN** o cadastro é recusado e uma mensagem informa que a senha é fraca

#### Scenario: E-mail malformado
- **WHEN** o usuário informa um e-mail sem formato válido
- **THEN** o formulário não é enviado e o campo de e-mail mostra um erro de validação

### Requirement: Login com e-mail e senha
O sistema SHALL autenticar um usuário existente por e-mail e senha. Credenciais inválidas MUST produzir uma mensagem genérica que não revele se o e-mail existe.

#### Scenario: Credenciais corretas
- **WHEN** o usuário informa e-mail e senha de uma conta existente
- **THEN** o usuário é autenticado e levado à tela de tarefas

#### Scenario: Credenciais incorretas
- **WHEN** o usuário informa uma senha errada ou um e-mail sem conta
- **THEN** o login é recusado com a mesma mensagem nos dois casos, informando que e-mail ou senha estão incorretos

#### Scenario: Campos vazios
- **WHEN** o usuário tenta entrar com e-mail ou senha vazios
- **THEN** o formulário não é enviado e os campos vazios mostram erro de validação

### Requirement: Sessão persistente
O sistema SHALL manter o usuário autenticado entre aberturas do app até que ele saia explicitamente ou a sessão seja revogada pelo provedor.

#### Scenario: Reabrir o app autenticado
- **WHEN** um usuário autenticado fecha o app e o abre de novo
- **THEN** o app abre direto na tela de tarefas, sem pedir login

#### Scenario: Sessão revogada
- **WHEN** o app é aberto e o provedor recusa a renovação da sessão salva
- **THEN** a sessão local é descartada e o app mostra a tela de login

#### Scenario: Abrir o app sem conexão com sessão salva
- **WHEN** um usuário com sessão salva abre o app sem conexão com a internet
- **THEN** a sessão é mantida, o app abre na tela de tarefas, e o carregamento das tarefas informa falha de conexão

#### Scenario: Verificação da sessão em andamento
- **WHEN** o app está verificando a sessão salva na abertura
- **THEN** o app mostra um indicador de carregamento e não exibe nem a tela de login nem a de tarefas

### Requirement: Logout
O sistema SHALL permitir sair da conta. Ao sair, MUST remover do dispositivo as credenciais da sessão e descartar as tarefas do usuário em memória.

#### Scenario: Sair
- **WHEN** o usuário autenticado escolhe sair
- **THEN** o app mostra a tela de login, e reabrir o app também mostra a tela de login

#### Scenario: Troca de usuário
- **WHEN** o usuário A sai e o usuário B entra no mesmo dispositivo
- **THEN** a tela de tarefas exibe apenas as tarefas de B, sem nenhuma tarefa de A visível em momento algum

### Requirement: Isolamento de dados por usuário
O sistema MUST garantir, inclusive no servidor, que um usuário só leia e altere as próprias tarefas. Requisições não autenticadas MUST ser recusadas.

#### Scenario: Acesso às próprias tarefas
- **WHEN** um usuário autenticado lê ou altera tarefas da própria conta
- **THEN** a operação é permitida

#### Scenario: Acesso a tarefas de outro usuário
- **WHEN** uma requisição autenticada como usuário A tenta ler ou alterar tarefas do usuário B
- **THEN** o servidor recusa a operação

#### Scenario: Requisição sem autenticação
- **WHEN** uma requisição sem credenciais tenta ler ou alterar qualquer tarefa
- **THEN** o servidor recusa a operação

### Requirement: Paridade entre plataformas
O cadastro, o login, a sessão persistente e o logout SHALL ter o mesmo comportamento observável em Windows, macOS, iOS e Android, incluindo as mensagens de erro. Uma conta criada numa plataforma MUST funcionar nas demais.

#### Scenario: Mesma conta em plataformas diferentes
- **WHEN** o usuário cria a conta no Android e depois entra com o mesmo e-mail e senha no Windows
- **THEN** o login é aceito e a tela de tarefas mostra as mesmas tarefas

#### Scenario: Mesmo erro em plataformas diferentes
- **WHEN** o usuário erra a senha no Windows e no iOS
- **THEN** as duas plataformas exibem a mesma mensagem de credenciais incorretas

### Requirement: Falha de rede na autenticação
O sistema SHALL informar quando cadastro, login ou renovação de sessão falharem por falta de conexão. O formulário MUST permanecer preenchido, e o usuário MUST poder tentar de novo.

#### Scenario: Login sem conexão
- **WHEN** o usuário tenta entrar sem conexão com a internet
- **THEN** uma mensagem informa falha de conexão e o e-mail digitado continua no formulário
