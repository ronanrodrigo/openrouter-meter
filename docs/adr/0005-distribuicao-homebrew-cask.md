# ADR 0005 — Distribuição por Homebrew cask

Data: 2026-09-18
Status: aceito

## Contexto

Até aqui o app só existia para quem clonasse o repositório e compilasse: `make app` gera o
`.xcodeproj` com XcodeGen e abre o app na máquina de quem desenvolve. Não havia artefato
publicado nem caminho de instalação para quem só quer usar o app. O ADR 0004 fixou o CI em
GitHub Actions e deixou explícito que "introduzir etapas além do gate (build de release,
notarização, artefato) exige ADR novo". Este é esse ADR: o gate continua sendo `make
verify-pr`, e o release é uma etapa nova que precisa de decisão registrada.

O ADR 0004 também já observou que este projeto é um app de barra de menus do macOS, sem
distribuição por loja e sem assinatura de loja no fluxo. Não há certificado Developer ID
disponível, então o caminho de distribuição precisa funcionar dentro dessa restrição.

## Decisão

Distribuir o app por **Homebrew cask** em tap público próprio, `ronanrodrigo/homebrew-tap`,
com o cask `Casks/openrouter-meter.rb` e token `openrouter-meter`. A instalação passa a ser:

```bash
brew install --cask ronanrodrigo/tap/openrouter-meter
```

Compilar do código-fonte continua possível e é o caminho de desenvolvedor; o cask é o caminho
de quem quer o app e não o código.

O release é automatizado: uma tag `v<VERSION>` no repositório principal dispara
`.github/workflows/release.yml` (runner `macos-15`), que roda o gate completo, compila Release
universal (arm64 + x86_64), empacota `OpenRouterMeter-<VERSION>.zip` com `ditto`, deixando
`OpenRouterMeter.app` na raiz do arquivo, e publica no GitHub Releases. O mesmo caminho existe
localmente via `scripts/package.sh`, `scripts/release.sh` e os alvos `make package` e
`make release VERSION=x.y.z`, para que o release não dependa só do CI. O conteúdo do tap vive
versionado neste repositório, em `packaging/homebrew-tap/`.

Invariante de versão: a tag `v<VERSION>` precisa ser igual a `MARKETING_VERSION` em
`project.yml`. Divergência entre as duas é erro de release, não detalhe.

O cask é sincronizado a partir do **release publicado**, não de um build local:
`scripts/sync-tap.sh` baixa o asset `OpenRouterMeter-<VERSION>.zip.sha256` do release e
renderiza o cask com esse hash. O build universal não é bit a bit reprodutível, então o hash
de um build local não é o hash do zip publicado — partir do artefato publicado é o que
mantém o cask consistente com o que o usuário baixa.

A assinatura é ad-hoc (`CODE_SIGN_IDENTITY="-"`, com hardened runtime) e **sem notarização**,
porque não há certificado Developer ID no fluxo. Essa é a restrição que dá forma às
consequências abaixo.

## Alternativas consideradas

- **Continuar só com código-fonte**: é o estado atual, sem artefato para baixar. Funciona para
  quem tem o toolchain, mas exige Xcode, XcodeGen e um `make` antes do primeiro uso. Fecha a
  porta para quem quer só o app.
- **Distribuir DMG no GitHub Releases, sem tap**: publica o artefato e nenhuma camada a mais,
  mas transfere ao usuário a tarefa de achar a release, baixar, arrastar o app e conviver com
  o Gatekeeper. O Homebrew já resolve instalação, atualização e desinstalação para o usuário de
  macOS, e o custo de um cask é um arquivo Ruby versionado.
- **Notarizar agora**: é o caminho correto a longo prazo, e é o follow-up registrado nas
  consequências. Não é possível agora: notarização exige certificado Developer ID, que o
  projeto não tem. Adotá-la hoje significaria inventar ou comprar credencial para desbloquear
  um passo que o restante do fluxo não usa.
- **Instalar por script** (`curl | sh` ou um `install.sh`): instala sem depender do Homebrew,
  mas exige manter um instalador próprio, com atualização e desinstalação que ficam por conta
  do projeto. O Homebrew oferece isso de graça para um app empacotado como `.app`.

## Consequências

Positivas:

- O app passa a ter caminho de instalação de uma linha, e a atualização acompanha
  `brew upgrade`. Quem quiser o código continua clonando e rodando `make app`.
- O release deixa de ser manual e passa a ser reprodutível: a mesma tag que publica o
  artefato roda o gate antes, então não se publica um build que o gate não aprovou.
- O conteúdo do tap é versionado junto do app, em `packaging/homebrew-tap/`, o que evita a
  divergência entre o cask e o artefato que ele aponta.

Negativas e riscos:

- **Quarentena.** O Homebrew 7 aplica quarentena a todo cask baixado e não tem mais a flag
  `--no-quarantine`. Sem tratar isso, o Gatekeeper bloqueia a abertura do app em toda
  instalação. O cask remove o atributo `com.apple.quarantine` da app instalada no
  `postflight_steps` — é o que faz a instalação funcionar dentro da restrição de assinatura. É uma
  consequência aceita, não um detalhe: o `postflight_steps` existe por causa da ausência de
  notarização, e a remoção da quarentena é uma operação do cask sobre o app instalado, não
  uma assinatura. Isso é risco de confiança para quem instala: a checagem que o Gatekeeper
  faria está sendo contornada por um passo do cask.
- **Ad-hoc sem notarização** é o mesmo risco visto de outro ângulo: o app não tem atestado de
  autoria da Apple. Enquanto o fluxo não tiver Developer ID, a garantia é a origem do tap e a
  integridade do zip, não a notarização.
- **Atualização do cask pelo CI depende de um segredo.** O workflow precisa de
  `TAP_GITHUB_TOKEN`, um PAT com permissão de escrita no tap. Sem esse segredo, o passo de
  atualização do cask é pulado e o resumo do job mostra o comando local para atualizar o tap à
  mão. Ou seja: o release do artefato não depende do segredo, mas a propagação ao tap depende.
- **Confiança no tap.** O Homebrew 7 recusa carregar casks de taps de terceiros que não estejam
  confiados. Nomear o cask por inteiro na linha de comando —
  `brew install --cask ronanrodrigo/tap/openrouter-meter`, o comando que a documentação
  recomenda — autoriza a instalação sem passo extra. Pelo nome curto
  (`brew install --cask openrouter-meter`, depois de um `brew tap`), é preciso confiar antes:
  `brew trust --cask ronanrodrigo/tap/openrouter-meter`. É um passo a mais que só existe
  porque o tap não é oficial.
- Publicar um cask em tap próprio adiciona um segundo repositório a manter, e uma nova classe
  de falha (token expirado, tap dessincronizado do artefato).

Follow-up explícito: quando o projeto tiver certificado Developer ID, assinar com Developer ID
e notarizar (notarytool). Isso remove a necessidade do `postflight` e devolve ao Gatekeeper a
decisão sobre o app.

Fora de escopo deste ADR: publicação na Mac App Store, atualização automática dentro do app
(Sparkle ou equivalente), distribuição fora do macOS e telemetria de instalação. O tap não é
um tap oficial do Homebrew; é um tap público do próprio projeto.
