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

## Estado atual

- Gate local `make verify-pr` verde na máquina de desenvolvimento.
- CI commitado e validado sintaticamente, aguardando o primeiro push para rodar de verdade.
- Sem segredos e sem PII no conteúdo versionado.
