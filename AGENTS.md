# AGENTS.md

Instruções para agentes que trabalham neste repositório.

## Identidade

**OpenRouter Meter** — app de barra de menus do macOS (SwiftUI, `MenuBarExtra`) que exibe o
saldo e o consumo da conta do OpenRouter. Interface em pt-BR, código e nomes de arquivo em
inglês, documentação em pt-BR.

## Comandos

```bash
make verify-pr   # gate completo: format-check, lint, testes dos pacotes, testes do app, cobertura
make app         # compila e abre o app
make test        # todos os testes
make lint        # SwiftLint --strict
```

Rode `make verify-pr` antes de declarar qualquer trabalho pronto e cole a saída real no PR.

## Regras não negociáveis

- **Direção de dependência**: `App → Application → Domain` e `Infrastructure → Application`.
  Ela é imposta pelos `Package.swift` de cada camada; um import fora da direção não compila.
  As regras custom do `.swiftlint.yml` reforçam a mesma fronteira.
- **Domain puro**: sem `Foundation`, `AppKit`, `SwiftUI`, `SQLite3`, `Security` ou qualquer SDK.
- **Swift 6 com concorrência estrita**. `@unchecked Sendable` só com sincronização interna
  comprovada e comentada.
- **`@Observable` é o padrão**; `ObservableObject`, `@Published` e `@StateObject` são proibidos.
- **Sem credencial no fonte**: a chave vive no Keychain ou em `$HERMES_HOME/.env` (fora do git).
- **Sem segredo em artefato**: nunca versione `.p12`, provisioning profile, `.p8` ou `.env`.
- **Cobertura**: 80% de linhas com gate nos pacotes (`Domain`, `Application`,
  `Infrastructure`) e 70% no target de app. O alvo de app tem mínimo desde o harness de
  renderização das views (`OpenRouterMeter/Tests/ViewRenderingTests.swift`), que desenha cada
  view com `ImageRenderer` em claro e em escuro. Números de hoje e a política completa: ver
  ADR 0003. Nunca rebaixe os mínimos para fazer uma mudança passar; mudança de política exige
  ADR.
- **`.xcodeproj` não é versionado**: é gerado por `xcodegen generate` a partir de `project.yml`.

## Mapa do repositório

| Caminho | Papel |
| --- | --- |
| `Packages/Domain` | Valores e regras puras do consumo e do crédito |
| `Packages/Application` | Gateways (capacidades) e serviços com `execute(...)` |
| `Packages/Infrastructure` | OpenRouter (HTTP), Hermes (`state.db`), Keychain, `Sample` |
| `OpenRouterMeter/Sources` | Views SwiftUI, view model `@Observable`, composition root |
| `docs/` | Arquitetura, progresso de implementação e ADRs |
| `scripts/` | Gerador do ícone e gate de cobertura |
