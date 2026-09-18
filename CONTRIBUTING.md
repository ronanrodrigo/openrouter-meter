# Como contribuir

Obrigado pelo interesse no **OpenRouter Meter**. Este documento descreve como preparar o
ambiente, o que o gate exige e como propor mudanças.

## Ambiente

Requisitos:

- macOS 15 ou mais recente
- Xcode com toolchain Swift 6
- [XcodeGen](https://github.com/yonaskolb/XcodeGen), SwiftLint e SwiftFormat:

```bash
brew install xcodegen swiftlint swiftformat
```

O `.xcodeproj` **não é versionado**: ele é gerado por `xcodegen generate` a partir de
`project.yml`. Nunca edite o `.xcodeproj` à mão — a mudança se perde na próxima geração.
Ajustes de alvo, scheme ou assinatura vão em `project.yml`.

## Comandos

```bash
make app         # gera o projeto, compila e abre o app
make verify-pr   # gate completo antes do PR
make test        # todos os testes
make lint        # SwiftLint --strict
make format      # SwiftFormat
```

`make verify-pr` é a única fonte de verdade sobre "está pronto". Ele roda, em ordem:

1. `tools` — confere que XcodeGen, SwiftLint, SwiftFormat e o Xcode existem.
2. `format-check` — `swiftformat --lint .` reprova qualquer formatação divergente.
3. `lint` — `swiftlint lint --strict`, incluindo as regras custom de fronteira de camada.
4. `test-packages` — `swift test` por pacote (`Domain`, `Application`, `Infrastructure`).
5. `test-app` — `xcodebuild test` do target de app.
6. `coverage` — 80% de linhas nos pacotes e 70% no alvo de app
   (ver [ADR 0003](docs/adr/0003-coverage-policy.md)).

Rode o gate antes de declarar qualquer trabalho pronto e **cole a saída real** no PR.
Nunca rebaixe o mínimo de cobertura dos pacotes para fazer uma mudança passar: mudança de
política exige um ADR novo.

## Arquitetura

Quatro camadas, com a direção de dependência imposta pelos `Package.swift`:

- `Packages/Domain` — valores e regras puras do consumo e do crédito; nenhum import de framework.
- `Packages/Application` — gateways (capacidades) e serviços com `execute(...)`; nenhum nome de fornecedor.
- `Packages/Infrastructure` — IO: HTTP da OpenRouter, `state.db` do Hermes, Keychain e adaptadores `Sample`.
- `OpenRouterMeter/Sources` — views SwiftUI, view model `@Observable`, design system e composition root.

Detalhes em [`docs/architecture.md`](docs/architecture.md) e nos ADRs em [`docs/adr/`](docs/adr/).

### Regra: regra de negócio não vive em view

Uma view **descreve hierarquia visual**, nada mais. Ela não calcula saldo, não soma tokens,
não formata número de negócio e não decide degradação. Regra que o produto depende vive em
`Domain`; orquestração vive em `Application`; estado de tela vive no view model
`@Observable`. Mover lógica para uma view para "resolver rápido" é achado de review e, além
disso, tira a linha do alcance do gate de cobertura — exatamente o que o
[ADR 0003](docs/adr/0003-coverage-policy.md) proíbe.

## Padrão de commit

Conventional Commits, com a descrição **em pt-BR**:

```
<tipo>(escopo opcional): descrição curta no imperativo

Corpo opcional explicando o porquê, não o quê.
```

Tipos usados: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `perf`, `build`, `ci`.

Exemplos:

```
feat(painel): exibe modelos que mais pesaram nos últimos sete dias
fix(infra): trata banco do Hermes ausente como janela vazia
docs(adr): registra a política de cobertura do alvo de app
```

## Como abrir uma issue

Use os templates em `.github/ISSUE_TEMPLATE/`:

- **bug_report** — descreva o comportamento observado, o esperado, a versão do macOS, a
  versão do Xcode e os passos para reproduzir.
- **feature_request** — descreva o problema antes da solução; uma proposta sem o problema
  que ela resolve normalmente precisa de mais discussão do que código.

## Como abrir um PR

1. Faça um fork (ou use um branch no repositório, se tiver acesso).
2. Crie um branch com nome curto e descritivo, derivado do tipo da mudança — por exemplo
   `fix/banco-ausente`, `feat/janela-sete-dias`.
3. Faça commits pequenos seguindo o padrão acima.
4. Rode `make verify-pr` até ficar verde.
5. Abra o PR usando o template. Ele pede o que mudou, a evidência do gate e a confirmação
   de que não há credencial no diff.
6. Responda aos comentários de review com commits novos; não force-push sobre um PR em review.

O CI (`.github/workflows/verify.yml`) roda `make verify-pr` em cada push na `main` e em cada
pull request. Um PR com o gate vermelho no CI não é mesclado.
