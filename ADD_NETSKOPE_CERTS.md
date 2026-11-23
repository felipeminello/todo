# Adicionar as CAs do Netskope ao ToDo Bomber (Firestore / gRPC)

## 1. Problema

O Netskope intercepta o TLS e reemite o certificado de `firestore.googleapis.com`, assinado pela CA da GCB.
O Firestore (gRPC) **não usa o Keychain do macOS**: ele passa ao gRPC uma lista de CAs embutida no próprio SDK
(`Firestore/core/src/remote/grpc_root_certificates_generated.cc`, carregada por `LoadGrpcRootCertificate()`).
Como a CA do Netskope não está nessa lista, o handshake falha:

```
CERTIFICATE_VERIFY_FAILED: self signed certificate in certificate chain
```

Por isso a variável `GRPC_DEFAULT_SSL_ROOTS_FILE_PATH` não resolve: com `pem_root_certs` explícito, o gRPC a ignora.

## 2. Certificados exportados

Arquivo pronto: `~/Documents/netskope-certs.pem` (extraído de `/Library/Keychains/System.keychain`).

| # | Subject (CN) | Papel | Validade | SHA-256 |
|---|---|---|---|---|
| 1 | `*.dfw3.goskope.com` | Raiz (autoassinada) | até 25/07/2032 | `25:78:B9:0F:6F:BE:AC:74:FA:C4:C0:57:8F:E3:78:3F:35:D7:98:AD:95:F4:5C:E3:CD:97:50:FD:59:86:A1:C2` |
| 2 | `ca.gcb-br.goskope.com` | Intermediária da GCB (emite os certs interceptados) | até 04/02/2036 | `11:6D:6A:71:C9:CA:B3:6B:19:55:11:31:B6:FC:C5:3C:40:AC:6F:2F:B2:16:07:67:A1:16:99:1C:0A:DF:91:22` |

Conferir a cadeia que o Netskope entrega (deve terminar nessa raiz):

```bash
echo | openssl s_client -connect firestore.googleapis.com:443 -servername firestore.googleapis.com -showcerts 2>/dev/null | grep -E " s:| i:"
openssl s_client -connect firestore.googleapis.com:443 -servername firestore.googleapis.com -CAfile ~/Documents/netskope-certs.pem </dev/null 2>&1 | grep "Verif"   # Verification: OK
```

> Importante: **acrescente** essas CAs à lista do Google, não substitua. Assim o app continua funcionando em máquinas
> sem Netskope (o cert do Google é validado pelas CAs originais) e passa a funcionar nas máquinas com Netskope da GCB.
> Máquinas de outras empresas com Netskope usam outra CA e continuariam falhando.

## 3. Alternativa sem código (considere primeiro)

Pedir à TI um **bypass de TLS/SSL** no Netskope para `firestore.googleapis.com` (ou `*.googleapis.com`).
Resolve para todos os usuários da empresa sem alterar o app. Se isso for aprovado, não é preciso seguir os passos abaixo.

## 4. Passo a passo: fork do Firebase iOS SDK com as CAs extras

O SDK não expõe API pública para CAs customizadas, então o caminho é um fork de `firebase/firebase-ios-sdk`
com uma alteração de ~10 linhas em um único arquivo.

### 4.1 Descobrir qual versão e qual gerenciador o projeto usa

```bash
cd <projeto-flutter>
grep -n -i -E "firebase_core|cloud_firestore" pubspec.lock | head
ls macos/Podfile macos/Runner.xcodeproj 2>/dev/null
ls macos/Flutter/ephemeral/Packages 2>/dev/null   # existe => Flutter está usando Swift Package Manager
```

O build atual tem `FirebaseFirestoreInternal.framework` (binário pré-compilado) e Firestore **13.1.1**.
Use no fork a **mesma tag** (`13.1.1`, ou a que o `cloud_firestore` instalado exigir) para não mudar versões.

### 4.2 Criar o fork

```bash
gh repo fork firebase/firebase-ios-sdk --clone --remote=false   # ou fork pela interface do GitHub
cd firebase-ios-sdk
git checkout -b netskope-certs 13.1.1        # troque pela tag que o app usa
```

### 4.3 Alterar `Firestore/core/src/remote/grpc_root_certificate_finder_generated.cc`

Substitua o conteúdo da função `LoadGrpcRootCertificate()` para devolver as CAs originais **mais** as do Netskope.
Não mexa no `grpc_root_certificates_generated.cc` (arquivo gigante, gerado).

```cpp
#include "Firestore/core/src/remote/grpc_root_certificate_finder.h"

#include "Firestore/core/src/remote/grpc_root_certificates_generated.h"

namespace firebase {
namespace firestore {
namespace remote {

namespace {

// CAs do Netskope (GCB): raiz *.dfw3.goskope.com + intermediária ca.gcb-br.goskope.com.
// Acrescentadas à lista original; sem efeito em redes sem interceptação TLS.
const char kNetskopeRootCertificates[] = R"PEM(
-----BEGIN CERTIFICATE-----
MIIEDTCCAvWgAwIBAgICATgwDQYJKoZIhvcNAQELBQAwgZ4xJTAjBgkqhkiG9w0B
CQEMFmNlcnRhZG1pbkBuZXRza29wZS5jb20xGzAZBgNVBAMMEiouZGZ3My5nb3Nr
b3BlLmNvbTESMBAGA1UECwwJY2VydGFkbWluMRYwFAYDVQQKDA1OZXRza29wZSBJ
bmMuMRIwEAYDVQQHDAlMb3MgQWx0b3MxCzAJBgNVBAgMAkNBMQswCQYDVQQGDAJV
UzAeFw0yMjA3MjgwOTI4MDJaFw0zMjA3MjUwOTI4MDJaMIGeMSUwIwYJKoZIhvcN
AQkBDBZjZXJ0YWRtaW5AbmV0c2tvcGUuY29tMRswGQYDVQQDDBIqLmRmdzMuZ29z
a29wZS5jb20xEjAQBgNVBAsMCWNlcnRhZG1pbjEWMBQGA1UECgwNTmV0c2tvcGUg
SW5jLjESMBAGA1UEBwwJTG9zIEFsdG9zMQswCQYDVQQIDAJDQTELMAkGA1UEBgwC
VVMwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCvGMbm3aAzs3IWjiw/
1k9ktMyFAODw3ed4qVJrsiG7P2zGg+AiiThMRV6UU3VB+as8vvzhg+4EsDTv0NpZ
NWesJRK7ZXroSZobyj0FBGU6Qi149HHEd29ChZzhaW+D3DXUW5X8sfpIrdSwj0PZ
gzQTVcWFk1QNfr294TbD9ro5l1pXE6IIuhh/d23eL2iHJK/zgckzOi9kqqRrsWqt
KUPco5vIewT+rhTjzwa6E6BYWsV7Vn9tM08bol+igTjoFb1Ml8Wi7OEQXEYprJmj
oMuwXCaaIfKY5HmfGaOm4lg6PIsbj9MZ/U2NVymwiMq9rmRrN3I6XbCCcvjH3fJ+
E1mzAgMBAAGjUzBRMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFMEr7yYqpq8Z
w77pQbJ7vOi/ioQwMB8GA1UdIwQYMBaAFMEr7yYqpq8Zw77pQbJ7vOi/ioQwMA0G
CSqGSIb3DQEBCwUAA4IBAQBlh8uN8dW6XAE2x7NUECI/6KhHSQRDyfXl/n65m/+g
m53Q7fU67gw0gx6Tb1yuNDiqfkxELya01mXnWL6jwKUaE22BSAdbKnEZe4EPPloE
WFvvBYhER5qJvOolyMwBBc2OneIw+URVGFpsP1VXNTy6E2T8K+VQN1zIcvvIV0g/
Ig7ZndaphTbGi+VCYuCCMQk5157vaREfjYS5zOVLnpTx7+54OUcjiNYLZ6wQMhfx
8ujs6pUGf7EDrnW1AjLeM59xsiX6GfxVUslKFxEvZUFqJ6k7E2aVrYmhOH6pdT/T
odGNrA0BUBig1ShrAcSyhAKPC97twY24v6bYoejHha8V
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
MIIEgzCCA2ugAwIBAgIUXwD2DB8uaAVq+cFfgjFDzpOeVFgwDQYJKoZIhvcNAQEL
BQAwgZ4xJTAjBgkqhkiG9w0BCQEMFmNlcnRhZG1pbkBuZXRza29wZS5jb20xGzAZ
BgNVBAMMEiouZGZ3My5nb3Nrb3BlLmNvbTESMBAGA1UECwwJY2VydGFkbWluMRYw
FAYDVQQKDA1OZXRza29wZSBJbmMuMRIwEAYDVQQHDAlMb3MgQWx0b3MxCzAJBgNV
BAgMAkNBMQswCQYDVQQGDAJVUzAeFw0yNjAyMDYwMTI5MDNaFw0zNjAyMDQwMTI5
MDNaMIHRMSUwIwYJKoZIhvcNAQkBDBZjZXJ0YWRtaW5AbmV0c2tvcGUuY29tMR4w
HAYDVQQDDBVjYS5nY2ItYnIuZ29za29wZS5jb20xKTAnBgNVBAsMIGRlNjJiMTgx
MGVmODkyMTQ1ZTcwYWE2ZTVmMWE2NGM4MSYwJAYDVQQKDB1HcnVwbyBDYXNhcyBC
YWhpYSBHQ0IgIEV4IFZJQTEbMBkGA1UEBwwSU2FvIENhZXRhbm8gZG8gU3VsMQsw
CQYDVQQIDAJCUjELMAkGA1UEBgwCQlIwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAw
ggEKAoIBAQChdcGzOhwRI+yOp3sJNl5O296yTT8gZSNl4wIR4afMyBVO/6Oo+oZy
IC/UbGxo5vQHAXz7U/jElrkofGDIPOgDn8V0vVsGlXIpTAhfMBsZS6ih5xK19Z7S
4/xLMHALJqocSlU0vvSf44eQMcFtCrFGoFX0tPrc3tEIbUw3xKtcpZ4SUUjRQcgS
C9bHz/Nb1glmdh0d/O4pswygYADVoRspB2FjadsK1dPCEDMNXj4u3WzLzlCW/TlL
gQMjsOMDem7tweDA7RZRx8CA4yxTtxQ37wFY/yZ5Zg9Olq0rsTSrLITMM3zWmpUs
Iy8zqtN6c8c95V7r9aaWCjRDqRoxDe3NAgMBAAGjgYMwgYAwEgYDVR0TAQH/BAgw
BgEB/wIBATALBgNVHQ8EBAMCAaYwHQYDVR0lBBYwFAYIKwYBBQUHAwEGCCsGAQUF
BwMCMB0GA1UdDgQWBBQ4tQ/F5LWxUMH77xTX5NHFikd0UDAfBgNVHSMEGDAWgBTB
K+8mKqavGcO+6UGye7zov4qEMDANBgkqhkiG9w0BAQsFAAOCAQEAByyu2Ap4L+Jb
VZJkS9e4Le8WmL9GKAX1AiY9+16OOOcTQx1F60E566GIyncSBl7a0TXCj7+KTgIf
BRP34AA6/4pLnzXvFJFvN3brLvvIGRyQW+5YqBkIQp6TABCNJWMA7KFDkKI3h7Fq
uzY9IV7EGN2cKfKTG1EzMfe+ZSvP36hnqqIn4/7JcSAo50v9eo5GLCYAv1casNVg
ySzbF+uECU0aqxrKl5XtBvnQtPmUOpibBGGafJufsygi547qITZQ715f6m6nKrub
Ooac4bL0VQFbqviUPTk3rSKvOJmtv5nQYgDOVmSycmBmH/TGhZ117a13i33q4STO
XglDyvrVrg==
-----END CERTIFICATE-----
)PEM";

}  // namespace

std::string LoadGrpcRootCertificate() {
  std::string roots(
      reinterpret_cast<const char*>(grpc_root_certificates_generated_data),
      grpc_root_certificates_generated_size);
  roots += "\n";
  roots += kNetskopeRootCertificates;
  return roots;
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
```

Valide e publique o fork:

```bash
git add Firestore/core/src/remote/grpc_root_certificate_finder_generated.cc
git commit -m "Firestore: add Netskope (GCB) root CAs to gRPC roots"
git tag 13.1.1-netskope && git push origin netskope-certs --tags
```

### 4.4 Apontar o app para o fork

O build atual usa o Firestore **pré-compilado** (`FirebaseFirestoreInternal.xcframework`), que não enxerga o fork.
É preciso compilar o Firestore **a partir do código-fonte**. Escolha conforme o gerenciador do projeto (passo 4.1).

**A) CocoaPods** (`macos/Podfile` existe e o Flutter não usa SwiftPM)

No `macos/Podfile`, dentro do `target 'Runner'`, antes do `flutter_install_all_macos_pods`:

```ruby
pod 'FirebaseFirestore', :git => 'https://github.com/<SEU_USUARIO>/firebase-ios-sdk.git', :tag => '13.1.1-netskope'
```

Depois:

```bash
cd macos && pod repo update && pod install && cd ..
```

**B) Swift Package Manager** (Flutter com SwiftPM habilitado; `firebase_core`/`cloud_firestore` puxam o `firebase-ios-sdk`)

1. No Xcode, abra `macos/Runner.xcworkspace` → projeto **Runner** → aba **Package Dependencies**.
2. Remova/override o pacote `firebase-ios-sdk` e adicione o fork (`https://github.com/<SEU_USUARIO>/firebase-ios-sdk`, tag `13.1.1-netskope`),
   ou clone o fork localmente e use **Add Local...** apontando para a pasta (um pacote local sobrescreve o remoto de mesmo nome).
3. Para compilar o Firestore do fonte (e não o binário), exporte a variável antes de abrir o Xcode/rodar o build:

```bash
export FIREBASE_SOURCE_FIRESTORE=1
open macos/Runner.xcworkspace          # ou: flutter build macos --release
```

> Se o seu Flutter resolver o SwiftPM sozinho e o override do passo 2 for difícil, desative o SwiftPM e use CocoaPods
> (`flutter config --no-enable-swift-package-manager`) e siga a opção A.

### 4.5 Rebuild limpo

```bash
flutter clean
flutter pub get
flutter build macos --release
```

## 5. Validação

Em uma máquina **com Netskope**, rode o binário com trace do gRPC:

```bash
GRPC_VERBOSITY=DEBUG GRPC_TRACE=tsi,handshaker \
  "build/macos/Build/Products/Release/ToDo Bomber.app/Contents/MacOS/ToDo Bomber" 2>&1 | grep -a -E "CERTIFICATE_VERIFY_FAILED|Handshake failed"
```

- **Sem nenhuma linha** `CERTIFICATE_VERIFY_FAILED` e dados sendo carregados do Firestore: correto.
- Ainda com o erro: o build não está usando o fork. Confirme com `strings` que as CAs entraram no binário:

```bash
strings -a "build/macos/Build/Products/Release/ToDo Bomber.app/Contents/MacOS/ToDo Bomber" \
  "build/macos/Build/Products/Release/ToDo Bomber.app/Contents/Frameworks/FirebaseFirestoreInternal.framework/FirebaseFirestoreInternal" 2>/dev/null \
  | grep -c "MIIEgzCCA2ugAwIBAgIUXwD2DB8uaAVq"
```

  (deve ser ≥ 1; se for 0, o Firestore pré-compilado ainda está sendo usado — revise o passo 4.4).

Em uma máquina **sem Netskope** (ou com o Netskope desativado), abra o app e confirme que o Firestore continua conectando.

## 6. Manutenção e cuidados

- **Outras empresas/tenants Netskope** usam outra CA: o app só funcionará atrás do Netskope da GCB.
- **Renovação das CAs:** a raiz vence em 2032 e a intermediária em 2036. Se a TI trocar a CA, reexporte:
  `security find-certificate -a -c goskope -p /Library/Keychains/System.keychain` e atualize o fork.
- **Atualizações do Firebase:** a cada upgrade do `cloud_firestore`, rebase o fork na nova tag do SDK e reaplique este patch.
- **Segurança:** o app passa a confiar em uma CA interceptadora. Aceitável para uso interno; evite para distribuição pública.
- **Limpeza:** `~/Library/Containers/br.dev.minello.todo/Data/todo-ca-bundle.pem` foi copiado nos testes e não é mais necessário; pode apagar.
