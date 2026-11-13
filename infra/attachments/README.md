# Anexos das tarefas (AWS)

Infraestrutura dos anexos do ToDo Bomber, na conta AWS do projeto, em `us-east-1`.

O app nunca usa credenciais da AWS. Ele chama uma API com o ID token do Firebase do usuário e recebe URLs pré-assinadas, válidas por 5 minutos, para enviar ou baixar um arquivo direto do bucket.

```
app ──ID token──▶ API Gateway (HTTP, autorizador JWT do Firebase) ──▶ Lambda
app ──URL pré-assinada──▶ bucket S3 privado
```

## Recursos

Tudo pertence à stack CloudFormation `todo-bomber-attachments` ([template.yaml](template.yaml)).

| Recurso | Nome |
| --- | --- |
| Bucket S3 | `todo-bomber-attachments-<conta>`: privado, criptografado, só HTTPS |
| Lambda | `todo-bomber-attachments` (Python 3.13), código em [lambda/handler.py](lambda/handler.py) |
| API HTTP | `todo-bomber-attachments`, com autorizador JWT `firebase` |
| Role da Lambda | `todo-bomber-attachments-lambda`: lê, grava e apaga só nesse bucket |
| Logs | `/aws/lambda/todo-bomber-attachments`, 30 dias |

A URL da API é o output `ApiUrl` da stack e fica em `lib/app/attachments_api_config.dart`.

## Como os arquivos ficam no bucket

- Chave: `<id da tarefa>/<uuid>.<extensão>`. A pasta é o id da tarefa; o nome físico é um UUID gerado pela Lambda mais a extensão do arquivo enviado, em minúsculas (sem extensão, só o UUID).
- O nome que o app mostra é o nome do arquivo enviado, guardado no metadado `name` do objeto (codificado em URL).
- O dono fica no metadado `owner` (uid do Firebase). Listar, baixar e apagar só enxergam objetos cujo `owner` é o usuário do token.
- Tamanho, tipo, nome e dono entram na assinatura da URL de upload. O S3 recusa o envio se qualquer um deles for diferente do que a Lambda autorizou.

## API

Toda rota exige `Authorization: Bearer <ID token do Firebase>`.

| Rota | O que faz |
| --- | --- |
| `GET /tasks/{taskId}/attachments` | Lista os anexos da tarefa, do mais antigo ao mais novo |
| `POST /tasks/{taskId}/attachments` | Corpo `{"name", "size"}`. Devolve o anexo e a URL de upload com os cabeçalhos a enviar no `PUT` |
| `GET /tasks/{taskId}/attachments/{id}` | Devolve a URL de download |
| `DELETE /tasks/{taskId}/attachments/{id}` | Apaga um anexo |
| `DELETE /tasks/{taskId}/attachments` | Apaga todos os anexos da tarefa (usado ao excluir a tarefa) |

Limites, parâmetros da stack: 25 MB por arquivo (`MaxBytes`) e 20 anexos por tarefa (`MaxPerTask`). O limite de tamanho também existe no app, em `AddTaskAttachment.maxBytes`; mude os dois juntos.

O upload só é aceito para uma tarefa que existe e é do usuário: a Lambda consulta `users/{uid}/tasks/{taskId}` no Firestore com o próprio token do usuário, então quem decide são as regras do Firestore.

Erros: `400` pedido inválido, `401` token recusado, `403` sem acesso à tarefa, `404` tarefa ou anexo inexistente, `409` limite de anexos, `413` arquivo grande demais, `502` S3 ou Firestore indisponível.

## Publicar mudanças

A stack cria a função com um código provisório. O código de verdade é publicado à parte, então atualizar a stack não mexe nele.

**Código da Lambda** (depois de editar `lambda/handler.py`):

```bash
cd infra/attachments/lambda
zip -j /tmp/handler.zip handler.py
aws lambda update-function-code --region us-east-1 \
  --function-name todo-bomber-attachments --zip-file fileb:///tmp/handler.zip
```

**Infraestrutura** (depois de editar `template.yaml`):

```bash
aws cloudformation deploy --region us-east-1 \
  --stack-name todo-bomber-attachments \
  --template-file infra/attachments/template.yaml \
  --capabilities CAPABILITY_NAMED_IAM
```

Apagar a stack **não** apaga o bucket (`DeletionPolicy: Retain`), porque os anexos são dados dos usuários.
