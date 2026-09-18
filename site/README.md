# site/

Esta pasta **não hospeda mais a landing do app**.

A página do OpenRouter Meter passou a viver dentro do site pessoal, no lab:
**https://ronanrodrigo.dev/lab/openrouter-meter**.

O que sobrou aqui é um `vercel.json` com um redirect permanente: qualquer
caminho em `openrouter-meter.vercel.app` responde 308 para a página nova, e
o projeto da Vercel (`openrouter-meter`, raiz `site/`) continua servindo esse
redirect. Os prints do app também moraram aqui e agora estão em
`public/lab/openrouter-meter/` no repositório `ronanrodrigo/site` — a página
no lab é a fonte única da apresentação.
