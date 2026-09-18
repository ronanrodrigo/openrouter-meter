# Política de segurança

## Como reportar uma vulnerabilidade

**Não abra uma issue pública para relatar uma vulnerabilidade.** Uma issue pública expõe o
problema antes de existir correção.

Prefira, nesta ordem:

1. **GitHub Security Advisories** — aba *Security* → *Report a vulnerability* em
   `github.com/ronanrodrigo/openrouter-meter`. O relato fica privado entre você e o
   mantenedor até a publicação do aviso.
2. **E-mail** — escreva para o mantenedor (**Ronan Rodrigo Nunes**) pelo endereço de contato
   do perfil do GitHub, com o assunto `[openrouter-meter] security`.

Inclua, quando possível: versão do app e do macOS, passos para reproduzir, o impacto que
você enxerga e qualquer prova de conceito.

O retorno é feito o mais rápido possível; este é um projeto pessoal sem SLA formal. Você
será creditado no aviso, se quiser.

## Versões suportadas

O projeto é distribuído a partir da `main`. Correções de segurança entram na `main`; não há
manutenção de branches antigos.

## Política de credencial

O OpenRouter Meter consome a API da OpenRouter com a chave da própria conta do usuário. A
política é rígida e vale para quem usa e para quem contribui:

- **Nunca commite uma chave de API.** Nem em código, nem em teste, nem em `README`, nem em
  screenshot, nem em `.env` versionado. O `.gitignore` cobre `.env` e `.env.*`.
- **Onde a chave pode viver:**
  - **Keychain**, sob o serviço `dev.ronanrodrigo.OpenRouterMeter`, preenchido pelos Ajustes
    do app. É o caminho padrão.
  - **`$HERMES_HOME/.env`** (padrão `~/.hermes/.env`), na variável `OPENROUTER_API_KEY`,
    fora do repositório. É o caminho de reaproveitamento de quem já usa o Hermes.
- **O app lê a chave em runtime.** Ela é lida da fonte acima no momento da consulta e usada
  apenas no cabeçalho HTTP da requisição à OpenRouter. Não é escrita em disco, não é logada
  e não é embutida no binário.
- **Nunca versione artefato de assinatura**: `.p12`, provisioning profile, `.p8`, `.xcconfig`.
- Ao abrir um PR, confirme no template que o diff não contém credencial.

Se você suspeitar que uma chave foi exposta em algum commit, revogue-a no painel da
OpenRouter imediatamente e abra o relato privado descrito acima.

## Escopo

Este é um app cliente: ele guarda a chave localmente e conversa com a API da OpenRouter. Não
hospeda serviço, não coleta telemetria e não envia dados para terceiros além da própria
OpenRouter, para a qual o usuário já aponta a chave.
