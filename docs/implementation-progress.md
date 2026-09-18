# Progresso de implementação

Memória cronológica de execução do repositório. Entradas datadas, curtas. O que está feito,
o que está em andamento e o estado do gate.

## 2026-09-17 — Fatia inicial implementada

- Camadas SwiftPM criadas: `Packages/Domain` (Money, tokens, janelas, erros), `Packages/Application`
  (gateways e `BuildUsageReportService`) e `Packages/Infrastructure` (HTTP da OpenRouter,
  `state.db` do Hermes, Keychain, adaptadores `Sample`). Direção de dependência imposta pelos
  `Package.swift` e reforçada por regras custom do SwiftLint.
- Target de app `OpenRouterMeter`: `MenuBarExtra` com o saldo no título e painel de consumo
  (hoje e últimos sete dias), view model `@Observable @MainActor`, design system e composition root.
- Gate único `make verify-pr` (formatação, lint, testes dos pacotes, testes do app, cobertura).
  Cobertura: 80% nos pacotes e 70% no alvo de app (mínimo reativado com o harness de renderização).
- Ícone do app gerado por `scripts/generate-appicon.swift`; `.xcodeproj` gerado por XcodeGen e
  não versionado.
- ADRs 0001–0003 registrados (arquitetura em camadas, fontes de dados e degradação, política
  de cobertura).

## 2026-09-17 — Preparação para repositório público

- Adicionados `LICENSE` (MIT), `CONTRIBUTING.md`, `SECURITY.md` e `CODE_OF_CONDUCT.md`.
- Adicionados templates de issue e de pull request em `.github/`.
- Adicionado CI em GitHub Actions (`.github/workflows/verify.yml`, runner `macos-15`) rodando
  `make verify-pr` em push na `main` e em pull request — ver ADR 0004. **O CI ainda não rodou
  nenhuma vez.**
- Verificado `Package.swift` das três camadas: nenhuma dependência externa (todas por caminho,
  internas). Não há terceiro sob licença a redistribuir, então não há `THIRD-PARTY-NOTICES`.

## 2026-09-18 — Distribuição por Homebrew cask

- O app passa a ser distribuído por Homebrew cask: tap público `ronanrodrigo/homebrew-tap`,
  cask `Casks/openrouter-meter.rb`, token `openrouter-meter`. Instalação:
  `brew install --cask ronanrodrigo/tap/openrouter-meter`. Compilar do código-fonte continua
  possível como caminho de desenvolvedor.
- Release automatizado: tag `v<VERSION>` dispara `.github/workflows/release.yml` (runner
  `macos-15`), que roda o gate, compila Release universal (arm64 + x86_64), empacota
  `OpenRouterMeter-<VERSION>.zip` com `ditto` e publica no GitHub Releases. O mesmo caminho
  existe localmente via `scripts/package.sh`, `scripts/release.sh` e os alvos `make package` /
  `make release VERSION=x.y.z`. O conteúdo do tap é versionado em `packaging/homebrew-tap/`.
- Invariante de versão: a tag `v<VERSION>` precisa ser igual a `MARKETING_VERSION` no
  `project.yml`.
- Assinatura ad-hoc (`CODE_SIGN_IDENTITY="-"`, hardened runtime) e sem notarização, porque não
  há certificado Developer ID no fluxo. O Homebrew 7 aplica quarentena a todo cask baixado e
  não tem mais a flag `--no-quarantine`, então o cask remove `com.apple.quarantine` da app
  instalada em `postflight`; sem isso o Gatekeeper bloqueia a abertura. Consequência aceita e
  risco registrados, com follow-up: assinar com Developer ID e notarizar quando o projeto
  tiver o certificado, o que também permitiria remover o `postflight`.
- Atualização do cask pelo CI exige o segredo `TAP_GITHUB_TOKEN` (PAT com escrita no tap); sem
  ele o passo é pulado e o resumo do job mostra o comando local (`make sync-tap VERSION=x.y.z`).
- O cask é sincronizado a partir do release publicado (`scripts/sync-tap.sh` lê o asset
  `.sha256` do release): o build universal não é bit a bit reprodutível, então o hash de um
  build local não vale para o cask.
- ADR 0005 registrado. Ele é o gatilho previsto no ADR 0004, que exige ADR novo para etapas
  além do gate (build de release e artefato).

## Estado atual

- Gate local `make verify-pr` verde na máquina de desenvolvimento.
- CI commitado e validado sintaticamente, aguardando o primeiro push para rodar de verdade.
- Distribuição por Homebrew cask decidida e escrita (ADR 0005), com release automatizado por
  tag. Nem o release nem a instalação pelo cask rodaram ainda: dependem do primeiro push e de
  uma tag `v<VERSION>` que case com `MARKETING_VERSION`.
- Sem segredos e sem PII no conteúdo versionado.
