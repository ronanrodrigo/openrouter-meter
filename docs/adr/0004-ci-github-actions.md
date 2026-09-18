# ADR 0004 — CI no GitHub Actions

Data: 2026-09-17
Status: aceito

## Contexto

O repositório vai virar público em `github.com/ronanrodrigo`. O gate do projeto é único e
local: `make verify-pr` roda formatação, lint, testes dos pacotes, testes do app e cobertura,
e é a única fonte de verdade sobre "está pronto". Até aqui esse gate só rodava na máquina de
quem desenvolve — nada impedia que um push na `main` ou um pull request de terceiro
chegasse sem nenhuma verificação. Num repositório público, isso deixa de ser aceitável: o
PR precisa ser validado por uma máquina que não é a de quem o escreveu.

O projeto não versiona o `.xcodeproj` (é gerado por XcodeGen a partir de `project.yml`), então
qualquer runner de CI precisa gerar o projeto antes de compilar — o que o próprio `make` já
faz. A biblioteca de apps iOS do autor usa Bitrise como padrão; este projeto é um app de
barra de menus do macOS, sem distribuição por TestFlight nem assinatura de loja no fluxo.

## Decisão

Adotar **GitHub Actions** com `runs-on: macos-15`, no workflow `.github/workflows/verify.yml`,
disparado em push na `main` e em `pull_request`. O workflow instala as ferramentas que faltam
(`xcodegen`, `swiftlint`, `swiftformat` via Homebrew), roda `make verify-pr` e nada mais. O
gate do CI é exatamente o gate local — nenhuma etapa nova, nenhuma divergência entre "verde
na minha máquina" e "verde no CI".

## Alternativas consideradas

- **Bitrise** (padrão dos repos iOS da biblioteca): resolvido, mas pago e dimensionado para
  pipelines de assinatura e distribuição que este projeto não tem. Para rodar um `make` e
  falhar ou passar, é peso e custo sem retorno.
- **Rodar o gate só localmente**: zero configuração, porém deixa o repositório público sem
  nenhuma verificação de PR. Um contribuidor sem o toolchain instalado, ou um push apressado,
  passaria sem barreira.
- **Outro provedor de CI com runner macOS** (Cirrus, CircleCI): exigiria uma segunda conta e
  um segundo painel para um projeto que já vive no GitHub. Menos superfície, mais lugares
  onde olhar.

O runner macOS do GitHub Actions é gratuito para repositórios públicos, o que torna a opção
sem custo direto.

## Consequências

- Todo push na `main` e todo pull request passam por `make verify-pr` numa máquina limpa. O
  CI é a barreira objetiva de merge.
- O workflow precisa gerar o `.xcodeproj` antes de buildar — coberto por `make`, que já
  encadeia `generate` em `build`/`test-app`.
- O runner macOS é mais lento e tem fila; o feedback do CI não substitui rodar o gate local
  durante o desenvolvimento. O CI confirma, não substitui.
- **O CI ainda não rodou nenhuma vez.** O workflow foi escrito e validado sintaticamente
  (YAML), mas o comportamento real do `make verify-pr` num runner `macos-15` só será
  conhecido no primeiro push. Se o runner não tiver uma versão de Xcode com Swift 6, o
  primeiro passo a ajustar é a seleção de Xcode.
- Introduzir etapas além do gate (build de release, notarização, artefato) exige ADR novo.
