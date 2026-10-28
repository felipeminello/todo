# Como atualizar as chaves de API do Firebase

As chaves `AIza...` de `lib/firebase_options.dart`, `android/app/google-services.json` e
`ios|macos/Runner/GoogleService-Info.plist` são públicas por definição: vão dentro do app.
O que protege os dados são as regras do Firestore (`firestore.rules`) e o Auth. As
restrições abaixo limitam o que dá para fazer com uma chave fora do app.

Restrições aplicadas em 28/10/2026:

| Chave | ID (`uid`) | Prefixo | Restrição de app | APIs permitidas |
| --- | --- | --- | --- | --- |
| iOS key (iOS e macOS) | `dc409d12-e407-40be-9549-b3ef518a50f1` | `AIzaSyBwMnrb…` | bundle ID `br.dev.minello.todo` | identitytoolkit, securetoken, firestore, firebaseinstallations |
| Android key | `fd9b40eb-cb2d-4809-94cf-9a5df1828d41` | `AIzaSyC9i_a-…` | pacote `br.dev.minello.todo` + SHA-1 de debug | identitytoolkit, securetoken, firestore, firebaseinstallations |
| Browser key (Windows) | `2f674fdf-07a5-4794-af5b-c8758bb351d9` | `AIzaSyBCOYDH…` | nenhuma (app desktop não envia referrer) | identitytoolkit, securetoken, firestore |

O Windows usa o cliente REST (`rest_auth_data_source.dart` e
`rest_firestore_task_data_source.dart`), que só chama identitytoolkit, securetoken e firestore.

## Pré-requisitos

```bash
gcloud auth login
export PROJECT=todo-bomber
export IOS_KEY=dc409d12-e407-40be-9549-b3ef518a50f1
export ANDROID_KEY=fd9b40eb-cb2d-4809-94cf-9a5df1828d41
export BROWSER_KEY=2f674fdf-07a5-4794-af5b-c8758bb351d9
```

## 1. Ver o estado atual e fazer backup

```bash
gcloud services api-keys list --project $PROJECT \
  --format='table(displayName, uid, restrictions.apiTargets.service.list():label=APIS, restrictions.iosKeyRestrictions.allowedBundleIds.list():label=IOS, restrictions.androidKeyRestrictions.allowedApplications.list():label=ANDROID)'

# Backup fora do repositório
gcloud services api-keys list --project $PROJECT --format=json > ~/todo-bomber-api-keys-backup.json

# Descobrir qual ID corresponde a qual chave AIza...
gcloud services api-keys get-key-string $IOS_KEY --project $PROJECT
```

## 2. Obter os dados dos apps

```bash
# Pacote Android (applicationId)
grep applicationId android/app/build.gradle.kts

# Bundle ID iOS/macOS
grep PRODUCT_BUNDLE_IDENTIFIER macos/Runner/Configs/AppInfo.xcconfig

# SHA-1 do keystore de debug
keytool -list -v -keystore ~/.android/debug.keystore \
  -alias androiddebugkey -storepass android -keypass android | grep SHA1
```

## 3. Aplicar as restrições

Cada `update` **substitui** a lista inteira de APIs e de apps. Passe sempre todos os valores
desejados no mesmo comando, não só o que mudou.

```bash
APIS=(
  --api-target=service=identitytoolkit.googleapis.com
  --api-target=service=securetoken.googleapis.com
  --api-target=service=firestore.googleapis.com
  --api-target=service=firebaseinstallations.googleapis.com
)

# iOS e macOS (mesma chave, mesmo bundle ID)
gcloud services api-keys update $IOS_KEY --project $PROJECT "${APIS[@]}" \
  --allowed-bundle-ids=br.dev.minello.todo

# Android
gcloud services api-keys update $ANDROID_KEY --project $PROJECT "${APIS[@]}" \
  --allowed-application=sha1_fingerprint=B9:96:E1:CF:E6:42:C4:81:AD:81:AB:3C:BF:AD:ED:BC:6E:25:5C:AC,package_name=br.dev.minello.todo

# Windows (só restrição de API)
gcloud services api-keys update $BROWSER_KEY --project $PROJECT \
  --api-target=service=identitytoolkit.googleapis.com \
  --api-target=service=securetoken.googleapis.com \
  --api-target=service=firestore.googleapis.com
```

As mudanças podem levar alguns minutos para propagar.

## 4. Testar

`accounts:lookup` com um token falso não altera nada. `INVALID_ID_TOKEN` significa que a chave
foi aceita. `API_KEY_*_BLOCKED` significa que a restrição barrou a chamada.

```bash
URL='https://identitytoolkit.googleapis.com/v1/accounts:lookup'
BODY='{"idToken":"x"}'
IOS_STR=$(gcloud services api-keys get-key-string $IOS_KEY --project $PROJECT --format='value(keyString)')
ANDROID_STR=$(gcloud services api-keys get-key-string $ANDROID_KEY --project $PROJECT --format='value(keyString)')
BROWSER_STR=$(gcloud services api-keys get-key-string $BROWSER_KEY --project $PROJECT --format='value(keyString)')

# Esperado: API_KEY_IOS_APP_BLOCKED
curl -s "$URL?key=$IOS_STR" -H 'Content-Type: application/json' -d "$BODY"
# Esperado: INVALID_ID_TOKEN
curl -s "$URL?key=$IOS_STR" -H 'Content-Type: application/json' -d "$BODY" \
  -H 'X-Ios-Bundle-Identifier: br.dev.minello.todo'

# Esperado: API_KEY_ANDROID_APP_BLOCKED
curl -s "$URL?key=$ANDROID_STR" -H 'Content-Type: application/json' -d "$BODY"
# Esperado: INVALID_ID_TOKEN (SHA-1 sem os dois-pontos)
curl -s "$URL?key=$ANDROID_STR" -H 'Content-Type: application/json' -d "$BODY" \
  -H 'X-Android-Package: br.dev.minello.todo' \
  -H 'X-Android-Cert: B996E1CFE642C481AD81AB3CBFADEDBC6E255CAC'

# Esperado: INVALID_ID_TOKEN
curl -s "$URL?key=$BROWSER_STR" -H 'Content-Type: application/json' -d "$BODY"
# Esperado: API_KEY_SERVICE_BLOCKED (Remote Config está fora da lista)
curl -s -X POST "https://firebaseremoteconfig.googleapis.com/v1/projects/679707228997/namespaces/firebase:fetch?key=$BROWSER_STR" \
  -H 'Content-Type: application/json' \
  -d '{"appId":"1:679707228997:web:82429a743826a744b69c2c","appInstanceId":"test"}'
```

Depois, rode o app de verdade em cada plataforma (login e lista de tarefas).

## Quando atualizar de novo

### Novo certificado Android (release, Play App Signing, outra máquina)

Hoje o build de release assina com a chave de debug (`android/app/build.gradle.kts`). Quando
houver keystore de release, ou quando o app for para a Play Store com Play App Signing, adicione
os SHA-1 novos. O da Play Store fica em Play Console > Configuração > Integridade do app. Repita
`--allowed-application` para cada certificado:

```bash
gcloud services api-keys update $ANDROID_KEY --project $PROJECT "${APIS[@]}" \
  --allowed-application=sha1_fingerprint=<SHA1_DEBUG>,package_name=br.dev.minello.todo \
  --allowed-application=sha1_fingerprint=<SHA1_RELEASE>,package_name=br.dev.minello.todo \
  --allowed-application=sha1_fingerprint=<SHA1_PLAY>,package_name=br.dev.minello.todo
```

Cada máquina de desenvolvimento tem seu próprio `~/.android/debug.keystore`. Em outro
computador, o app Android em debug será bloqueado até o SHA-1 dele entrar na lista.

### Novo produto Firebase no app

Se o app passar a usar outro produto (Storage, Remote Config, Messaging...), inclua a API na
lista das chaves que precisam dela, senão as chamadas falham com `API_KEY_SERVICE_BLOCKED`.
Para ver as APIs ativas no projeto:

```bash
gcloud services list --enabled --project $PROJECT
```

### Trocar (rotacionar) uma chave

Só é necessário se houver sinal de abuso nas métricas das APIs.

```bash
# 1. Criar a chave nova já restrita
gcloud services api-keys create --project $PROJECT \
  --display-name="iOS key (rotated)" "${APIS[@]}" \
  --allowed-bundle-ids=br.dev.minello.todo

# 2. Pegar o valor e colocar em firebase_options.dart e GoogleService-Info.plist
#    (ou registrar a chave no app pelo console do Firebase e rodar `flutterfire configure`)
gcloud services api-keys get-key-string <NOVO_UID> --project $PROJECT

# 3. Depois que a versão nova do app estiver publicada, apagar a antiga
gcloud services api-keys delete $IOS_KEY --project $PROJECT
```

Apagar a chave antiga quebra as versões já instaladas que ainda a usam.

## Reverter

```bash
# Remove todas as restrições da chave (volta a aceitar qualquer app e API)
gcloud services api-keys update $ANDROID_KEY --project $PROJECT --clear-restrictions
```

Para voltar exatamente ao estado anterior, use o backup do passo 1 como referência e repita o
`update` com as mesmas `--api-target`.
