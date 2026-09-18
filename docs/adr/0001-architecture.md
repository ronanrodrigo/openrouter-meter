# ADR 0001 — App de barra de menus em camadas SwiftPM

Data: 2026-09-17
Status: aceito

## Contexto

O saldo do OpenRouter era consultado por um script de shell (`openrouter-balance.sh`) e
entregue por cronjob no Telegram. O script responde bem ao "quanto resta", mas é ruim para
o "em quê": a pergunta aparece no meio do trabalho, e esperar a próxima notificação de 9h
ou 18h não serve.

## Decisão

Construir um app de barra de menus em SwiftUI, com `LSUIElement`, e separar o projeto em
camadas SwiftPM — `Domain`, `Application`, `Infrastructure` e o target `App` — com a direção
de dependência imposta pelos `Package.swift` e reforçada por regras custom do SwiftLint.

Manter `~/.hermes/scripts/openrouter-balance.sh` e o cronjob das 9h/18h: o app é leitura sob
demanda, o cronjob continua sendo o registro periódico.

## Alternativas consideradas

- **Script + notificação**: zero custo de manutenção, mas não responde sob demanda e não tem interface.
- **App de arquivo único sem camadas**: mais rápido de escrever, porém coloca IO de rede, IO de banco e formatação no mesmo arquivo, e o teste rápido (sem app, sem rede) deixa de existir.
- **Widget de Central de Notificações**: exigiria app hospedeiro, assinatura de distribuição e ciclo de vida próprio — mais peso do que o problema justifica.

## Consequências

- Testes de lógica rodam em segundos, por `swift test` por pacote, sem compilar o app nem abrir a interface.
- O custo é a cerimônia de quatro módulos para um app pequeno; aceito porque a fronteira impede que o IO se espalhe.
- `.xcodeproj` passa a ser artefato gerado por XcodeGen e entra no `.gitignore`.
