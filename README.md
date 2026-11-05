# todo

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Releases no GitHub (macOS e Windows)

Um push de tag `v*.*.*` roda [.github/workflows/release.yml](.github/workflows/release.yml),
que gera as duas plataformas e anexa `todo-macos.zip` e `todo-windows.zip` a uma
Release do GitHub. Em **Actions › Release › Run workflow** dá para rodar à mão:
os dois builds saem como artefatos da execução, sem criar Release. É o jeito de
testar os secrets. A versão continua vindo do `pubspec.yaml`; a tag só dispara
o workflow.

### macOS: Developer ID + notarização

O runner não tem o certificado "Apple Development" que o target usa, então o
workflow compila **sem assinar** e reassina o `.app` com o **Developer ID
Application** (Hardened Runtime). Depois notariza com `notarytool` e grampeia o
ticket (`stapler`), e o Gatekeeper abre o app baixado sem o aviso *"A Apple não
pôde verificar…"*.

O `firebase_auth` exige `keychain-access-groups` em
`macos/Runner/Release.entitlements`. Esse entitlement é restrito, então o app
também precisa de um **provisioning profile Developer ID**, senão o macOS mata o
app ao abrir. O workflow embute o profile e expande o `Release.entitlements` com
o Team ID e o bundle ID que vêm do próprio profile.

Secrets do repositório (*Settings › Secrets and variables › Actions*):

| Secret | Valor |
| --- | --- |
| `MACOS_CERTIFICATE_P12` | Base64 do certificado Developer ID Application + chave privada, exportados como `.p12` |
| `MACOS_CERTIFICATE_PASSWORD` | Senha escolhida ao exportar o `.p12` |
| `MACOS_PROVISIONING_PROFILE` | Base64 do profile Developer ID de `br.dev.minello.todo` |
| `APPLE_API_KEY_P8` | Conteúdo da chave da API do App Store Connect (`AuthKey_<ID>.p8`) |
| `APPLE_API_KEY_ID` | ID dessa chave |
| `APPLE_API_ISSUER_ID` | Issuer ID da página de chaves da API do App Store Connect |

O certificado e a chave da API podem ser os mesmos de outros apps da conta, mas
secrets são por repositório e precisam ser cadastrados aqui. O profile é por app.

**1. Certificado Developer ID Application.** Confira se ele está no Mac:

```bash
security find-identity -v -p codesigning | grep "Developer ID Application"
```

Exporte-o com a chave privada: *Acesso às Chaves › Meus Certificados ›
Developer ID Application: … › botão direito › Exportar*, no formato `.p12`, com
uma senha.

**2. Provisioning profile.** Em [developer.apple.com › Profiles](https://developer.apple.com/account/resources/profiles/list),
clique em **+**, escolha **Developer ID** (em *Distribution*), o App ID
`br.dev.minello.todo` e o certificado do passo 1. Baixe o `.provisionprofile`.
Ele vale até o certificado vencer; ao renovar o certificado, gere o profile de
novo.

**3. Chave da API do App Store Connect.** Qualquer chave com acesso *Developer*
ou superior serve para o `notarytool`.

**4. Gravar os secrets** com a GitHub CLI, de dentro do repositório:

```bash
base64 -i devid.p12 | gh secret set MACOS_CERTIFICATE_P12
gh secret set MACOS_CERTIFICATE_PASSWORD        # pede a senha do .p12
base64 -i ~/Downloads/<nome>.provisionprofile | gh secret set MACOS_PROVISIONING_PROFILE
gh secret set APPLE_API_KEY_P8 < ~/.appstoreconnect/private_keys/AuthKey_<ID>.p8
gh secret set APPLE_API_KEY_ID --body "<ID>"
gh secret set APPLE_API_ISSUER_ID --body "<issuer-id>"
rm devid.p12
gh secret list                                  # confere os seis
```

O `.p12` e o `.p8` nunca entram no repositório.

### Windows

Não precisa de secret. O workflow roda `flutter build windows --release`, copia
o runtime do Visual C++ para o lado do `todo.exe` (para abrir em máquinas sem o
VC++ Redistributable) e compacta a pasta `Release`. O executável **não é
assinado**, então o SmartScreen avisa na primeira execução (*Mais informações ›
Executar assim mesmo*).
