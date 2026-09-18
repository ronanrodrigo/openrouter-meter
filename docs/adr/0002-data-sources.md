# ADR 0002 — Fontes de dados e degradação

Data: 2026-09-17
Status: aceito

## Contexto

A OpenRouter expõe o crédito da conta em `GET /api/v1/credits` e `GET /api/v1/key`, mas a
atividade por modelo (`GET /api/v1/activity`) responde `403 — Only management keys can fetch
activity for an account` para uma chave comum. Sem essa fonte, não há tokens nem modelos por
janela. Ao mesmo tempo, o Hermes mantém em `state.db` a tabela `session_model_usage`, com
tokens por modelo e custo estimado de tudo que passou por ele.

## Decisão

- **Saldo e uso da conta**: sempre da API da OpenRouter (`/credits` + `/key`). É o único dado
  que fala da conta inteira, e é o número principal do app.
- **Detalhamento por modelo**: `FallbackUsageGateway` tenta a atividade oficial quando existe
  chave de provisioning e cai para o histórico local do Hermes quando ela não existe ou falha.
  A origem usada é exposta no relatório e aparece na interface.
- **Credencial**: `FirstAvailableCredentialStore` usa a chave do Keychain e, na ausência dela,
  lê `OPENROUTER_API_KEY` de `$HERMES_HOME/.env`. O app nunca pede que o usuário cole a chave
  se ela já existe no ambiente.
- **Degradação assimétrica**: o saldo é obrigatório (falha derruba o relatório); o
  detalhamento é opcional (falha apenas encolhe o relatório).

## Consequências

- O detalhamento pode não cobrir tráfego que não passou pelo Hermes; por isso a interface
  identifica a origem dos dados em vez de apresentá-los como verdade da conta.
- Criar uma chave de provisioning da OpenRouter melhora o detalhamento sem mudar código: o
  adaptador oficial já existe e passa a ser o primeiro da cadeia.
- O app lê `state.db` somente para leitura; um banco ausente ou sem a tabela devolve janela
  vazia, nunca erro.
