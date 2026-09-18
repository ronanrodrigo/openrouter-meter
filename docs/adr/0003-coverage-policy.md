# ADR 0003 — Política de cobertura

Data: 2026-09-17
Status: aceito
Revisão: 2026-09-17 — o alvo de app passou a ter mínimo; ver "Revisão" no fim.

## Contexto

A política da biblioteca é 80% de linhas por `xccov`. Aplicada a este app, a maior parte das
linhas do target de app é declaração de view SwiftUI. Medido sem nenhum teste de view, o alvo
ficava em ~24%: os arquivos de lógica estavam bem cobertos (`Formatters` 92%,
`UsageViewModel` 78%, `CompositionRoot` 82%) e as views em 0%, porque teste unitário de view
mede existência de código, não comportamento. Puxar o alvo para 70% exigiria testes de fumaça
de view — que não pegam regressão e tornam o gate lento e frágil.

## Decisão

Duas políticas, explícitas em `make verify-pr`:

1. **Pacotes SwiftPM — 80% de linhas, com gate.** `Domain`, `Application` e `Infrastructure`
   são medidos por `xcrun llvm-cov export` sobre o binário de teste de cada pacote, contando
   apenas os fontes do próprio pacote (dependências aparecem instrumentadas no binário e
   diluiriam o denominador). Hoje: Domain 99,17%, Application 100%, Infrastructure 95,78%.
2. **Target de app — 70% de linhas, com gate.** O `xccov` roda sobre o `.xcresult` e reprova
   abaixo de 70%. Hoje o alvo `OpenRouterMeter.app` fica em ~96,2%; o agregado que o gate mede
   — alvo de app somado às camadas instrumentadas dentro do bundle — fica entre 81,9% e 87,5%
   conforme a instrumentação do bundle no build. Os dois números estão bem acima do mínimo.

## Revisão

O que mudou em relação à versão original deste ADR: o item 2 tinha mínimo zero, com o
argumento de que a verificação de view é visual. O argumento continua verdadeiro para
*comportamento*, mas deixava o gate cego para uma classe concreta de defeito — view que quebra
ao montar, medida errada e render em branco. O harness
`OpenRouterMeter/Tests/ViewRenderingTests.swift` cobre isso desenhando cada view de verdade
com `ImageRenderer`, em claro e em escuro, e exigindo três coisas do resultado: dimensão
esperada, PNG gravado e render com mais de uma cor (varredura esparsa de pixels). Não é teste
de regra de negócio, e o relatório do PR diz isso.

Com o harness, a cobertura do alvo de app saiu de ~29% para 96,70% e o mínimo de 70% passou a
ser um limite com folga — não um alvo perseguido com teste de fumaça.

## Consequências

- Nenhuma regra de negócio pode migrar para uma view para fugir do gate de 80%: a fronteira
  de camadas e o lint a impedem, e excesso de lógica em view é achado de review.
- O número do alvo de app é honesto e visível, e agora reprova: uma view nova sem render
  coberto derruba o gate.
- O harness depende de aparência do sistema: as views são desenhadas em claro e em escuro, e
  o teste exige que os dois renders sejam diferentes — render escuro em branco reprova.
- Introduzir um mínimo para o alvo de app — ou rebaixar o dos pacotes — exige ADR novo.
