#!/usr/bin/env bash
# Gera o AAB de release e envia para o Google Play.
#
#   tool/playstore_publish.sh [opções]
#
#   -t, --track TRILHA   internal (padrão), alpha, beta, production ou o nome
#                        de uma trilha de teste fechado
#   -n, --notes ARQUIVO  notas da versão no formato do Play Console, um bloco
#                        <pt-BR>…</pt-BR> por idioma (padrão:
#                        tool/release_notes_android.txt, se existir)
#   -p, --priority N     prioridade da atualização in-app do Play, de 0 a 5
#                        (padrão: 0). Só tem efeito se o app consultar a API de
#                        In-App Updates, o que o ToDo Bomber ainda não faz.
#                        Não muda depois.
#       --draft          cria a versão como rascunho, para lançar pelo Console
#       --skip-build     envia o AAB que já está em build/, sem gerar de novo
#   -y, --yes            não pede confirmação antes de gerar e enviar
#   -h, --help           mostra esta ajuda
#
# A versão vem do pubspec.yaml (version: NOME+CÓDIGO). O Play recusa um código
# que já foi enviado, então suba o número depois do + antes de cada envio.
#
# Precisa de android/key.properties com a chave de upload e de uma conta de
# serviço com acesso ao app no Play Console. A chave JSON dela fica em
# ~/play-service-account-todo-bomber.json ou no caminho que estiver em
# PLAY_SERVICE_ACCOUNT_JSON.
#
# Atenção: hoje android/app/build.gradle.kts assina o release com a chave de
# debug (signingConfigs.getByName("debug")), e o Play recusa esse AAB. Antes do
# primeiro envio, crie a chave de upload, o android/key.properties (fora do
# git) e uma signingConfig "release" que leia esse arquivo.

# Como gerar ~/play-service-account-todo-bomber.json
# É uma chave que você gera no Google Cloud para uma conta de serviço
# (um "usuário robô" que o script usa para acessar o Play).

# 1. No terminal, crie a conta de serviço e baixe a chave:
# gcloud services enable androidpublisher.googleapis.com --project todo-bomber

# gcloud iam service-accounts create play-publisher \
#   --display-name="Envio para o Google Play" --project todo-bomber

# gcloud iam service-accounts keys create ~/play-service-account-todo-bomber.json \
#   --iam-account play-publisher@todo-bomber.iam.gserviceaccount.com

# chmod 600 ~/play-service-account-todo-bomber.json

# 2. No Play Console, dê acesso ao app:

# 1. Abra Usuários e permissões e clique em Convidar novos usuários.
# 2. No e-mail, coloque play-publisher@todo-bomber.iam.gserviceaccount.com.
# 3. Na aba Permissões do app, adicione o ToDo Bomber. Marque a permissão de lançar em faixas de teste (Release to testing tracks), e também a de produção se for usar --track production.
# 4. Envie o convite. Conta de serviço não precisa aceitar.

# 3. Teste com tool/playstore_publish.sh. Se aparecer "The caller does not have permission", a permissão do passo 2 ainda não começou a valer, o que pode levar algumas horas.

set -euo pipefail

PACKAGE_NAME=br.dev.minello.todo
API=https://androidpublisher.googleapis.com/androidpublisher/v3/applications/$PACKAGE_NAME
UPLOAD_API=https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/$PACKAGE_NAME

ROOT=$(cd "$(dirname "$0")/.." && pwd)
AAB=$ROOT/build/app/outputs/bundle/release/app-release.aab
SERVICE_ACCOUNT=${PLAY_SERVICE_ACCOUNT_JSON:-$HOME/play-service-account-todo-bomber.json}

track=internal
notes_file=$ROOT/tool/release_notes_android.txt
notes_given=false
release_status=completed
priority=0
build=true
assume_yes=false

token=
edit_id=
committed=false

die() { printf '\nerro: %s\n' "$*" >&2; exit 1; }
step() { printf '\n==> %s\n' "$*"; }
usage() { awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"; }

# Base64 sem padding e com o alfabeto de URL, como o JWT pede.
b64url() { openssl base64 -e -A | tr '+/' '-_' | tr -d '='; }

# Troca a chave da conta de serviço por um access token de uma hora.
authenticate() {
  local email now header claims signature response
  email=$(jq -r '.client_email // empty' "$SERVICE_ACCOUNT" 2>/dev/null || true)
  [ -n "$email" ] || die "$SERVICE_ACCOUNT não é uma chave JSON de conta de serviço"

  now=$(date +%s)
  header=$(printf '{"alg":"RS256","typ":"JWT"}' | b64url)
  claims=$(jq -ncj --arg iss "$email" --argjson now "$now" '{
    iss: $iss,
    scope: "https://www.googleapis.com/auth/androidpublisher",
    aud: "https://oauth2.googleapis.com/token",
    iat: $now,
    exp: ($now + 3600)
  }' | b64url)
  signature=$(printf '%s.%s' "$header" "$claims" |
    openssl dgst -sha256 -sign <(jq -r .private_key "$SERVICE_ACCOUNT") | b64url)

  response=$(curl -sS https://oauth2.googleapis.com/token \
    --data-urlencode grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer \
    --data-urlencode "assertion=$header.$claims.$signature") ||
    die "sem resposta de oauth2.googleapis.com"
  token=$(jq -r '.access_token // empty' <<<"$response")
  [ -n "$token" ] ||
    die "o Google recusou a conta de serviço $email: $(jq -r '.error_description // .error // .' <<<"$response")"
}

# Chama a API do Play e imprime a resposta; se ela responder com erro, sai com
# a mensagem que veio.
api() {
  local method=$1 url=$2 response status body message
  shift 2
  response=$(curl -sS -X "$method" -H "Authorization: Bearer $token" -w '\n%{http_code}' "$@" "$url") ||
    die "sem resposta de $url"
  status=${response##*$'\n'}
  body=${response%$'\n'*}
  if [ "$status" -ge 400 ]; then
    message=$(jq -r '.error.message // empty' <<<"$body" 2>/dev/null || true)
    case $message in
      *'draft app'*) message="$message — o app ainda é rascunho no Play Console; rode de novo com --draft" ;;
    esac
    die "$method ${url#*"$PACKAGE_NAME"} → HTTP $status: ${message:-$body}"
  fi
  printf '%s\n' "$body"
}

# Uma edição que não chegou ao commit é descartada, para não ficar pendurada
# no Play.
cleanup() {
  if [ -n "$edit_id" ] && [ "$committed" = false ]; then
    curl -sS -o /dev/null -X DELETE -H "Authorization: Bearer $token" "$API/edits/$edit_id" || true
  fi
}
trap cleanup EXIT

while [ $# -gt 0 ]; do
  case $1 in
    -t | --track)
      [ $# -ge 2 ] || die "$1 precisa de um valor"
      track=$2
      shift 2
      ;;
    -n | --notes)
      [ $# -ge 2 ] || die "$1 precisa de um valor"
      notes_file=$2
      notes_given=true
      shift 2
      ;;
    -p | --priority)
      [ $# -ge 2 ] || die "$1 precisa de um valor"
      priority=$2
      shift 2
      ;;
    --draft) release_status=draft; shift ;;
    --skip-build) build=false; shift ;;
    -y | --yes) assume_yes=true; shift ;;
    -h | --help) usage; exit 0 ;;
    *) die "opção desconhecida: $1 (veja --help)" ;;
  esac
done
case $priority in
  [0-5]) ;;
  *) die "a prioridade vai de 0 a 5 (veio '$priority')" ;;
esac

# --- Pré-requisitos --------------------------------------------------------

for cmd in curl jq openssl; do
  command -v "$cmd" >/dev/null || die "$cmd não está instalado"
done
if [ "$build" = true ]; then
  command -v flutter >/dev/null || die "flutter não está no PATH"
  [ -f "$ROOT/android/key.properties" ] ||
    die "android/key.properties não existe: o AAB sairia com a chave de debug e o Play recusaria (veja android/key.properties.example)"
else
  [ -f "$AAB" ] || die "não há AAB em ${AAB#"$ROOT"/} para enviar com --skip-build"
fi
[ -f "$SERVICE_ACCOUNT" ] ||
  die "chave da conta de serviço não encontrada em $SERVICE_ACCOUNT (ou aponte PLAY_SERVICE_ACCOUNT_JSON para ela)"

version=$(sed -n 's/^version:[[:space:]]*//p' "$ROOT/pubspec.yaml" | tr -d "[:space:]\"'")
version_name=${version%%+*}
version_code=${version#*+}
case $version_code in
  '' | *[!0-9]*) die "o pubspec.yaml precisa de version: NOME+CÓDIGO (está '$version')" ;;
esac

release_notes='[]'
if [ -f "$notes_file" ]; then
  release_notes=$(jq -Rs '[
    scan("<(?<lang>[A-Za-z]{2,3}(-[A-Za-z0-9]+)*)>\\s*(?<text>[\\s\\S]*?)\\s*</\\k<lang>>")
    | {language: .[0], text: .[2]}
  ]' "$notes_file")
  [ "$release_notes" != '[]' ] ||
    die "nenhum idioma em $notes_file — use um bloco <pt-BR>…</pt-BR> por idioma"
  too_long=$(jq -r '.[] | select(.text | length > 500) | "\(.language) (\(.text | length))"' <<<"$release_notes")
  [ -z "$too_long" ] || die "o Play aceita até 500 caracteres por idioma: $too_long"
elif [ "$notes_given" = true ]; then
  die "$notes_file não existe"
fi

# --- Play: conferir antes de gastar tempo com o build ------------------------

step "Conectando ao Google Play"
authenticate
edit_id=$(api POST "$API/edits" -H 'Content-Type: application/json' --data '{}' | jq -r .id)
api GET "$API/edits/$edit_id/tracks/$track" >/dev/null
last_code=$(api GET "$API/edits/$edit_id/bundles" | jq '[.bundles[]?.versionCode] | max // 0')
[ "$version_code" -gt "$last_code" ] ||
  die "o código $version_code já foi usado (o último enviado é $last_code) — suba o número depois do + no pubspec.yaml"

printf '\n  App:        %s\n  Versão:     %s (%s) — a última no Play é a (%s)\n  Trilha:     %s, %s\n  Prioridade: %s\n' \
  "$PACKAGE_NAME" "$version_name" "$version_code" "$last_code" "$track" \
  "$([ "$release_status" = draft ] && echo 'como rascunho' || echo 'lançada na hora')" \
  "$priority$([ "$priority" -ge 4 ] && echo ' — atualização obrigatória')"
if [ "$release_notes" = '[]' ]; then
  printf '  Notas:      nenhuma\n'
else
  jq -r '.[] | "\n  [\(.language)]\n\(.text | split("\n") | map("  " + .) | join("\n"))"' <<<"$release_notes"
fi

if [ "$assume_yes" = false ]; then
  [ -t 0 ] || die "sem terminal para confirmar — rode com --yes"
  printf '\nContinuar? [s/N] '
  read -r answer
  case $answer in
    s | S | sim | y | Y | yes) ;;
    *) echo "Cancelado."; exit 0 ;;
  esac
fi

# --- Build e envio ---------------------------------------------------------

if [ "$build" = true ]; then
  step "Gerando o AAB"
  build_args=(appbundle --release)
  [ -f "$ROOT/config.json" ] && build_args+=(--dart-define-from-file=config.json)
  (cd "$ROOT" && flutter build "${build_args[@]}")
  [ -f "$AAB" ] || die "o build terminou sem gerar ${AAB#"$ROOT"/}"
fi

step "Enviando ${AAB#"$ROOT"/} ($(du -h "$AAB" | cut -f1 | tr -d ' '))"
uploaded_code=$(api POST "$UPLOAD_API/edits/$edit_id/bundles?uploadType=media" \
  -H 'Content-Type: application/octet-stream' --data-binary "@$AAB" | jq -r .versionCode)
[ "$uploaded_code" = "$version_code" ] ||
  die "o AAB enviado tem código $uploaded_code, mas o pubspec.yaml diz $version_code — gere de novo sem --skip-build"

step "Criando a versão na trilha $track"
track_body=$(jq -n \
  --arg track "$track" \
  --arg name "$version_name ($version_code)" \
  --arg code "$version_code" \
  --arg status "$release_status" \
  --argjson priority "$priority" \
  --argjson notes "$release_notes" \
  '{track: $track, releases: [
    {name: $name, versionCodes: [$code], status: $status, inAppUpdatePriority: $priority}
    + (if $notes == [] then {} else {releaseNotes: $notes} end)
  ]}')
api PUT "$API/edits/$edit_id/tracks/$track" -H 'Content-Type: application/json' --data "$track_body" >/dev/null

step "Publicando"
# Apps com revisão pendente não aceitam envio automático para revisão: aí a
# edição entra assim mesmo, e o envio fica para o botão no Console.
review_note=
if ! commit_error=$(api POST "$API/edits/$edit_id:commit" --data '' 2>&1 >/dev/null); then
  case $commit_error in
    *changesNotSentForReview*)
      api POST "$API/edits/$edit_id:commit?changesNotSentForReview=true" --data '' >/dev/null
      review_note="O Play não enviou as mudanças para revisão sozinho: envie em Visão geral da publicação, no Play Console."
      ;;
    *) printf '%s\n' "$commit_error" >&2; exit 1 ;;
  esac
fi
committed=true

if [ "$release_status" = draft ]; then
  printf '\n%s (%s) criada como rascunho na trilha %s: lance pelo Play Console.\n' "$version_name" "$version_code" "$track"
else
  printf '\n%s (%s) enviada para a trilha %s.\n' "$version_name" "$version_code" "$track"
fi
[ -z "$review_note" ] || printf '%s\n' "$review_note"
