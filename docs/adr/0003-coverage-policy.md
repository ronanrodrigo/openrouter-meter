# ADR 0003 — Política de cobertura

Data: 2026-09-17
Status: aceito

## Contexto

A política da biblioteca é 80% de linhas por `xccov`. Aplicada a este app, a maior parte das
linhas do target de app é declaração de view SwiftUI. Medido de verdade, o alvo fica em
~24%: os arquivos de lógica estão bem cobertos (`Formatters` 92%, `UsageViewModel` 78%,
`CompositionRoot` 82%), e as views estão em 0% porque teste unitário de view mede existência
de código, não comportamento. Puxar o alvo para 70% exigiria testes de fumaça de view — que
não pegam regressão e tornam o gate lento e frágil.

## Decisão

Duas políticas, explícitas em `make verify-pr`:

1. **Pacotes SwiftPM — 80% de linhas, com gate.** `Domain`, `Application` e `Infrastructure`
   são medidos por `xcrun llvm-cov export` sobre o binário de teste de cada pacote, contando
   apenas os fontes do próprio pacote (dependências aparecem instrumentadas no binário e
   diluiriam o denominador). Hoje: Domain 97%, Application 100%, Infrastructure 91%.
2. **Target de app — medido e reportado, sem mínimo.** O `xccov` roda e imprime o número,
   mas não reprova. As views são declarativas; a verificação delas é visual e por
   pré-visualização, e a lógica que elas chamam já está coberta pelo item 1 e pelos testes
   de `Formatters`, `UsageViewModel` e `CompositionRoot` no alvo de app.

## Consequências

- Nenhuma regra de negócio pode migrar para uma view para fugir do gate de 80%: a fronteira
  de camadas e o lint a impedem, e excesso de lógica em view é achado de review.
- O número do alvo de app é honesto e visível, não escondido atrás de um limite artificial.
- Introduzir um mínimo para o alvo de app — ou rebaixar o dos pacotes — exige ADR novo.
