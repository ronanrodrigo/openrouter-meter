<div align="center">

# OpenRouter Meter

**Quanto ainda resta na sua conta do OpenRouter — sempre à vista na barra de menus do macOS.**

[![verify-pr](https://github.com/ronanrodrigo/openrouter-meter/actions/workflows/verify.yml/badge.svg)](https://github.com/ronanrodrigo/openrouter-meter/actions/workflows/verify.yml)
![macOS 15+](https://img.shields.io/badge/macOS-15%2B-000000?logo=apple&logoColor=white)
![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)
[![Licença MIT](https://img.shields.io/badge/licen%C3%A7a-MIT-2f6feb.svg)](LICENSE)

<img src="docs/images/barra-e-painel.png" width="400" alt="Print real do app: o item da barra de menus do macOS com o ícone de medidor e o saldo US$ 87,93, e logo abaixo o painel completo com saldo restante, requisições gratuitas, custo de hoje e dos últimos sete dias e os modelos principais">

</div>

Sem clicar, o saldo. Com um clique, o painel completo: consumo, cota de requisições
gratuitas, tokens, chamadas, custo e os modelos que mais pesaram hoje e nos últimos sete dias.
O print acima é de uma conta real, com a barra de menus e o relatório inteiro na mesma imagem.

<table>
<tr>
<td><img src="docs/images/painel-escuro.png" width="310" alt="Painel do OpenRouter Meter no modo escuro"></td>
<td><img src="docs/images/painel-claro.png" width="310" alt="Painel do OpenRouter Meter no modo claro"></td>
</tr>
<tr>
<td align="center"><sub>Modo escuro</sub></td>
<td align="center"><sub>Modo claro</sub></td>
</tr>
</table>

## O que ele mostra

<img src="docs/images/painel-real.png" width="340" align="right" alt="Painel do app em execução, lido de uma conta real">

**Na barra de menus**, o valor escolhido em Ajustes: o saldo restante (padrão) ou o custo de
hoje. Sem leitura ainda, a barra mostra `—`.

**No painel**:

- **Saldo restante**, com o medidor de consumo logo abaixo — crédito consumido, em
  porcentagem, e a linha `US$ 122,07 de US$ 210,00` com `58%`.
- **Requisições gratuitas**, a cota diária dos modelos gratuitos: `34 de 1.000 · restam 966`.
- **HOJE** e **ÚLTIMOS 7 DIAS** — dois cartões com **Tokens**, **Chamadas** e **Custo**, e a
  distribuição entre os **Modelos principais** (participação em tokens de entrada, barra por
  modelo).
- **Rodapé** com quando foi atualizado (`Atualizado agora`) e os botões de atualizar, ajustes
  e sair.

O cabeçalho diz de onde veio o detalhamento, e os Ajustes controlam o que aparece na barra e
a cadência de atualização: 1 minuto, 5 minutos (padrão), 15 minutos ou 1 hora. Ao abrir o
painel o relatório é relido, e o app atualiza sozinho no intervalo escolhido.

## Instalação

Requisitos: **macOS 15 ou mais recente**, **Xcode 26** com toolchain **Swift 6** e as
ferramentas de build (via [Homebrew](https://brew.sh)):

```bash
brew install xcodegen swiftlint swiftformat
```

Clone e rode:

```bash
git clone https://github.com/ronanrodrigo/openrouter-meter.git
cd openrouter-meter
make app
```

`make app` gera o projeto com `xcodegen generate` (o `.xcodeproj` não é versionado e é
reconstruído a cada build), compila com `xcodebuild` e abre o aplicativo.

### A chave da OpenRouter

O app precisa de uma chave da API para ler o saldo. Duas origens, nesta ordem:

1. **Keychain do macOS**, gravado pelos Ajustes do app (ícone de engrenagem no rodapé do
   painel → **Chave da API da OpenRouter** → **Salvar**). O serviço usado é
   `dev.ronanrodrigo.OpenRouterMeter`.
2. **`OPENROUTER_API_KEY` em `$HERMES_HOME/.env`** (padrão `~/.hermes/.env`), se você já usa
   o Hermes — assim não há configuração duplicada. Esse arquivo pertence ao Hermes: o app só
   lê, nunca escreve.

Sem chave configurada em lugar nenhum, o painel mostra
`Nenhuma chave da OpenRouter configurada. Salve uma chave em Ajustes para ver o saldo.` com um
botão **Abrir Ajustes**, e a barra de menus fica em `—`. Nenhuma credencial é versionada: a
chave vive no Keychain ou em um `.env` fora do git.

## De onde vêm os números

| O que aparece no painel | Origem |
| --- | --- |
| Saldo restante, crédito contratado e consumo acumulado | `GET /api/v1/credits` da OpenRouter |
| Uso diário, semanal e mensal, plano gratuito e cota de modelos gratuitos | `GET /api/v1/key` da OpenRouter |
| Tokens, chamadas, custo e modelos de **HOJE** e **ÚLTIMOS 7 DIAS** | histórico local do Hermes: `$HERMES_HOME/state.db`, tabela `session_model_usage`, aberta somente para leitura |

O cabeçalho do painel indica qual das duas origens respondeu pelo detalhamento:
**Atividade da conta** (atividade oficial da OpenRouter) ou **Histórico local do Hermes**.

**A parte honesta:** `GET /api/v1/activity`, a atividade oficial da conta, responde **403**
para uma chave de inferência comum — ela exige uma chave de *provisioning*. Por isso, no caso
geral, o detalhamento por modelo vem do histórico local do Hermes: só entra o que passou pelo
Hermes, com o custo efetivamente cobrado (`actual_cost_usd`) e, na falta dele, a estimativa
(`estimated_cost_usd`). Com uma chave de provisioning, o app passa a usar a atividade oficial
sozinho e cai para o histórico local apenas se ela estiver indisponível — você não configura
nada além da chave.

## Arquitetura

Quatro camadas, com a direção de dependência imposta pelos `Package.swift` de cada pacote —
um import fora da direção não compila:

```mermaid
graph TD
  subgraph App["App · SwiftUI"]
    MB["MenuBarExtra<br/>título: saldo"]
    Panel["MenuBarPanelView"]
    VM["UsageViewModel<br/>@Observable @MainActor"]
    CR["CompositionRoot"]
  end
  subgraph Packages["Pacotes SwiftPM"]
    APP["Application<br/>CreditsGateway · UsageGateway · CredentialStore<br/>BuildUsageReportService · FallbackUsageGateway"]
    DOM["Domain<br/>Money · TokenCounts · UsageWindow<br/>AccountSnapshot · UsageReport"]
    INF["Infrastructure<br/>OpenRouter HTTP · Hermes state.db<br/>Keychain · adaptadores Sample"]
  end
  MB --> VM
  Panel --> VM
  VM --> APP
  CR --> INF
  CR --> APP
  APP --> DOM
  INF --> APP
```

- **`Packages/Domain`** — valores e regras puras, sem `Foundation`: `Money` em micro-dólares
  inteiros, contagem de tokens, janelas de consumo, `AccountSnapshot`, `UsageReport` e os
  erros estáveis do produto.
- **`Packages/Application`** — gateways nomeados pela capacidade, nunca pelo fornecedor
  (`CreditsGateway`, `UsageGateway`, `CredentialStore`), o `BuildUsageReportService.execute()`
  e as duas costuras de degradação (`FallbackUsageGateway`,
  `FirstAvailableCredentialStore`).
- **`Packages/Infrastructure`** — todo o IO: HTTP da OpenRouter, leitura somente-leitura do
  `state.db` do Hermes via SQLite3, Keychain e os adaptadores `Sample` determinísticos usados
  por previews e testes. Erro de fornecedor é traduzido para `UsageError` na fronteira.
- **`OpenRouterMeter/Sources`** — views SwiftUI, view model `@Observable` `@MainActor`, design
  system, formatação e o `CompositionRoot`, único lugar que instancia adaptadores concretos.

Detalhes, fluxo de atualização e decisões em [`docs/architecture.md`](docs/architecture.md) e
nos ADRs:

- [ADR 0001 — App de barra de menus em camadas SwiftPM](docs/adr/0001-architecture.md)
- [ADR 0002 — Fontes de dados e degradação](docs/adr/0002-data-sources.md)
- [ADR 0003 — Política de cobertura](docs/adr/0003-coverage-policy.md)
- [ADR 0004 — CI no GitHub Actions](docs/adr/0004-ci-github-actions.md)

## Desenvolvimento

O gate é único: nada é declarado pronto sem `make verify-pr` verde, e é ele que o CI
([`.github/workflows/verify.yml`](.github/workflows/verify.yml), runner `macos-15`) executa a
cada push na `main` e a cada pull request.

```bash
make verify-pr   # format-check, lint, testes dos pacotes, testes do app e cobertura
make test        # só os testes
make lint        # SwiftLint --strict
make format      # SwiftFormat
make app         # compila e abre o app
make clean       # remove build/, .xcodeproj e os .build dos pacotes
```

### Cobertura

Duas políticas, explícitas no gate e explicadas no
[ADR 0003](docs/adr/0003-coverage-policy.md):

| Medida | Mínimo | Última execução local |
| --- | --- | --- |
| `Domain` | 80% de linhas | 99,17% |
| `Application` | 80% de linhas | 100% |
| `Infrastructure` | 80% de linhas | 95,78% |
| Alvo de app agregado (`xccov` sobre o `.xcresult`) | 70% de linhas | 87,30% |

Os números dos pacotes vêm de `llvm-cov` sobre o binário de teste de cada pacote, contando só
os fontes do próprio pacote. O alvo de app é medido pelo `xccov` sobre o `.xcresult` — que
agrega o alvo e as camadas instrumentadas dentro do bundle; isolado, o alvo
`OpenRouterMeter.app` mede 96,70%. O mínimo de 70% existe desde
que o harness `OpenRouterMeter/Tests/ViewRenderingTests.swift` passou a desenhar cada view de
verdade com `ImageRenderer`, em claro e em escuro, exigindo dimensão esperada, PNG gravado e
render com mais de uma cor. Testes hoje: 20 em `Domain`, 12 em `Application`, 33 em
`Infrastructure` e 40 no alvo de app. Mudança de política exige ADR novo; nunca rebaixe os
mínimos para uma mudança passar.

### Fronteiras de camada no lint

O `.swiftlint.yml` é especificação executável de arquitetura, não estética. As fronteiras
ficam em configurações aninhadas por camada (o SwiftLint aplica o `.swiftlint.yml` do
diretório mais próximo), e há regra custom que barra credencial literal no fonte. O lint é
reforço da direção de dependência — o mecanismo primário é o `Package.swift`.

### Hook de credencial

O repositório traz um hook de `pre-commit` que bloqueia qualquer commit que introduza
credencial, olhando apenas o que está preparado (`git diff --cached`):

```bash
git config core.hooksPath .githooks   # ativa neste clone
bash scripts/check-credential-hook.sh # prova os três casos do hook
```

Um falso positivo consciente pode ser liberado com `ALLOW_SECRET_COMMIT=1 git commit ...`.

## Limitações

- **Só macOS 15 ou mais recente**, e o app é compilado a partir do código-fonte: não há
  binário assinado ou notarizado, nem instalação por `brew install --cask`.
- **O detalhamento de tokens e modelos depende do Hermes** enquanto não houver chave de
  provisioning. Consumo de outras ferramentas com a mesma conta não aparece nos cartões.
- **Custo por janela é o que o histórico registra**: o valor cobrado quando existe
  (`actual_cost_usd`); na falta dele, a estimativa (`estimated_cost_usd`).
- **Sem chave, não há saldo**: a barra de menus fica em `—` e o painel só mostra o aviso de
  configuração.
- **Interface e documentação em pt-BR**; o código e os nomes de arquivo, em inglês.

## Licença e créditos

[MIT](LICENSE) — Copyright (c) 2026 Ronan Rodrigo Nunes.

Este app é a versão nativa do script `~/.hermes/scripts/openrouter-balance.sh`, que continua
existindo para o cronjob diário. Não é afiliado à OpenRouter; os dados vêm da
[API pública da OpenRouter](https://openrouter.ai/docs) e do histórico local do
[Hermes](https://hermes-agent.nousresearch.com/docs).

Contribuições são bem-vindas — comece por [`CONTRIBUTING.md`](CONTRIBUTING.md). Para relatar
uma vulnerabilidade, veja [`SECURITY.md`](SECURITY.md); o projeto segue o
[`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md).

<div align="center">

<sub><a href="https://github.com/ronanrodrigo/openrouter-meter">github.com/ronanrodrigo/openrouter-meter</a> · <a href="https://openrouter-meter.vercel.app">openrouter-meter.vercel.app</a></sub>

</div>
