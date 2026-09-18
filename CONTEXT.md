# CONTEXT.md

Glossário do domínio. Termo canônico e definição de negócio — sem tipo, sem protocolo,
sem nome de fornecedor e sem detalhe de implementação.

## Crédito

**Crédito total** — quantidade de dólares já comprada para a conta, somando todas as recargas.
**Consumo acumulado** — soma de tudo que já foi gasto na conta desde o início.
**Saldo** — o que ainda resta: crédito total menos consumo acumulado. É o número principal do produto.
**Medidor de consumo** — fração do crédito total já gasta, exibida como barra.

## Consumo

**Janela** — recorte de tempo do consumo. O produto usa duas: hoje e últimos sete dias.
**Tokens** — volume processado, separado em entrada, saída, leitura de cache, escrita de cache e raciocínio.
**Chamada** — uma requisição ao provedor de modelos.
**Custo estimado** — valor em dólares atribuído a uma janela ou a um modelo, sempre aproximado.
**Modelo** — o modelo de linguagem que originou o consumo; identificado pelo nome completo `fornecedor/modelo`.
**Participação** — fatia de um modelo no consumo da janela, medida em tokens de entrada.

## Operação

**Atualização** — leitura das fontes e reconstrução do relatório exibido.
**Relatório** — visão consolidada de crédito e consumo, com a origem dos dados e o instante da leitura.
**Origem dos dados** — de onde veio o detalhamento: atividade oficial da conta ou histórico local do Hermes.
