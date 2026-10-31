# Massa de dados de teste

Grava tarefas de teste no Firestore da conta informada, para conferir a linha do tempo, a lista de concluídas e o widget de tela inicial sem cadastrar nada à mão.

## Rodar

Na raiz do projeto:

```bash
dart run tool/seed_tasks/seed.dart --list            # lista os cenários
dart run tool/seed_tasks/seed.dart full --dry-run    # mostra as tarefas sem gravar nada
dart run tool/seed_tasks/seed.dart full              # grava o cenário (o padrão é full)
dart run tool/seed_tasks/seed.dart --clear           # remove só as tarefas de teste
dart run tool/seed_tasks/seed.dart full --create-account   # cria a conta antes de gravar
```

- O e-mail e a senha vêm de `TODO_SEED_EMAIL` e `TODO_SEED_PASSWORD`. Sem essas variáveis, o script pergunta no terminal, sem mostrar a senha.
- Prefira uma conta só para testes: o script grava no projeto Firebase de produção (`todo-bomber`), lido de `lib/firebase_options.dart`.
- Toda tarefa de teste tem id começando por `seed-`. Cada execução apaga as `seed-` anteriores e grava o cenário escolhido, então dá para trocar de cenário à vontade. Tarefas criadas no app nunca são apagadas, mas continuam aparecendo junto com as de teste.
- As datas são relativas ao dia em que o script roda, no calendário local da máquina. Rode no mesmo fuso do aparelho.
- O widget só lê o que o app gravou no aparelho. Depois de rodar o script, abra o app (ou recarregue a lista) para o widget se atualizar.

## Cenários

| Cenário | Para conferir |
|---|---|
| `full` | Tudo de uma vez: 5 sem data (título longo, descrição em várias linhas, emoji), atrasadas de ontem, de 3 e 45 dias, do fim do mês anterior e de 31/12 do ano anterior, 7 de hoje (mais do que cabe em qualquer tamanho de widget), duas para amanhã, uma em 7 dias (último dia coberto pelo widget), uma em 8 dias (fora dele), dia 1º do mês seguinte, 1º/01 do ano seguinte e 5 concluídas, uma delas vencendo hoje. |
| `today-fits` | 3 de hoje e nenhuma atrasada: no widget de 3 linhas, todas aparecem sem agrupamento. |
| `today-overflow` | 12 de hoje e nenhuma atrasada: "{X} tarefas pendentes" em qualquer tamanho. |
| `overdue` | 2 atrasadas e 1 de hoje: "2 tarefas atrasadas" em laranja, com ícone, e a de hoje abaixo. |
| `singular` | 1 atrasada e 3 de hoje: "1 tarefa atrasada" e, no widget de 3 linhas, "2 tarefas pendentes". |
| `nothing-today` | Sem data, futuras e uma concluída hoje: o app tem conteúdo e o widget mostra "Nada para hoje". |
| `bulk` | 320 tarefas entre -30 e +90 dias, 20% sem data e 25% concluídas, sempre as mesmas: rolagem, desempenho e paginação do cliente REST do Windows, que lê 300 documentos por página. |

Para os casos que dependem do relógio (virada do dia, conteúdo além do horizonte de 7 dias), grave o `full`, abra o app e depois adiante a data do aparelho.

Os estados "Entre no app para ver suas tarefas" e "Abra o app para atualizar" não dependem de dados: saia da conta no app, ou adiante a data do aparelho em mais de 7 dias.
