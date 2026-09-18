# OpenRouter Meter __VERSION__

## O que mudou

- Descreva aqui as mudanças desta versão, em poucas linhas.

## Requisitos

- macOS 15 (Sequoia) ou mais recente.
- O app é um item da barra de menus (`MenuBarExtra`): não abre janela nem aparece no Dock.

## Como instalar

```bash
brew install --cask ronanrodrigo/tap/openrouter-meter
```

Para atualizar uma instalação existente:

```bash
brew upgrade --cask openrouter-meter
```

## Assinatura

Esta versão é assinada de forma ad-hoc (sem notarização). O cask remove a quarentena do
`com.apple.quarantine` no `postflight`, portanto não é preciso autorizar manualmente no
Gatekeeper após instalar.

## Verificação

O arquivo `OpenRouterMeter-__VERSION__.zip.sha256` acompanha o release com o checksum do zip.
