# homebrew-tap

Tap pessoal de fórmulas e casks do Ronan Rodrigo.

## Instalação

```bash
brew tap ronanrodrigo/tap
```

O comando acima não é necessário quando se instala um cask diretamente pelo nome completo,
porque o Homebrew faz o tap automaticamente.

O Homebrew 7 exige confiança (tap trust) para casks de taps de terceiros. Instalar pelo nome
completo do cask, como nos comandos deste README, já autoriza a instalação. Para instalar pelo
nome curto, confie antes:

```bash
brew trust --cask ronanrodrigo/tap/openrouter-meter
```

## OpenRouter Meter

App de barra de menus do macOS que exibe o saldo e o consumo da conta do OpenRouter.

```bash
brew install --cask ronanrodrigo/tap/openrouter-meter
```

Atualizar:

```bash
brew upgrade --cask openrouter-meter
```

Desinstalar (mantendo preferências):

```bash
brew uninstall --cask openrouter-meter
```

Desinstalar e remover os resíduos:

```bash
brew uninstall --zap --cask openrouter-meter
```

O cask remove a quarentena da app instalada no `postflight`; o app é assinado de forma
ad-hoc e não é notarizado.

## Manutenção

O cask `Casks/openrouter-meter.rb` é um template com os marcadores `__VERSION__` e
`__SHA256__`. Ele é renderizado a partir do release publicado pelo script
`scripts/sync-tap.sh` do repositório do app (`ronanrodrigo/openrouter-meter`) — que lê o
sha256 do próprio asset `.sha256` do release, e não de um build local. O release e o zip são
publicados por `scripts/release.sh` ou pelo workflow de release, disparado por tag.
Não edite o cask à mão no tap: a fonte de verdade é `packaging/homebrew-tap/` no
repositório do app.
