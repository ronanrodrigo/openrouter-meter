## O que mudou

<!-- Descreva a mudança e o porquê. O quê o diff já mostra; explique o motivo. -->

## Evidência do gate

<!-- Cole a saída real da última linha do `make verify-pr` (passou/falhou e o resumo). -->

```
$ make verify-pr
```

## Checklist

- [ ] `make verify-pr` verde (formatação, lint, testes dos pacotes, testes do app, cobertura)
- [ ] Sem credencial no diff — nenhuma chave, `.env`, `.p12`, provisioning profile ou `.p8`
- [ ] Testes adicionados ou atualizados para o comportamento novo
- [ ] Regra de negócio não foi parar em uma view (vive em `Domain` / `Application`)
- [ ] Mínimo de cobertura dos pacotes não foi rebaixado
- [ ] Se a mudança mexe em alvo, scheme ou assinatura, foi em `project.yml` e não no `.xcodeproj`
- [ ] Se a mudança é uma decisão nova, há um ADR em `docs/adr/`

## Issue relacionada

<!-- Ex.: Closes #12 -->
