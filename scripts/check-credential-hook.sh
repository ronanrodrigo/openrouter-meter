#!/usr/bin/env bash
# Prova o hook de credencial: um arquivo com token falso precisa ser BLOQUEADO,
# e os arquivos reais do repo precisam PASSAR. Roda no próprio repo e limpa tudo no fim.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

# O token falso é montado em tempo de execução: um literal longo no repo seria
# (corretamente) bloqueado pelo próprio hook que estamos verificando.
FAKE="sk-or-v1-$(printf 'a%.0s' $(seq 1 40))"
PROBE="probe-credential-check.txt"

cleanup() {
    git rm --cached -q "$PROBE" 2>/dev/null || true
    rm -f "$PROBE"
}
trap cleanup EXIT

echo "== 1) arquivo com token falso deve ser bloqueado"
printf 'chave: %s\n' "$FAKE" > "$PROBE"
git add -f "$PROBE" >/dev/null 2>&1
if bash .githooks/pre-commit; then
    echo "FALHA: o hook deixou passar um token"
    exit 1
else
    echo "ok: bloqueado (exit != 0)"
fi
cleanup

echo
echo "== 2) fixtures curtas de teste não podem ser bloqueadas"
printf 'let token = "sk-or-v1-teste"\n' > "$PROBE"
git add -f "$PROBE" >/dev/null 2>&1
if bash .githooks/pre-commit; then
    echo "ok: fixture curta passou"
else
    echo "FALHA: fixture curta foi bloqueada (falso positivo)"
    exit 1
fi
cleanup

echo
echo "== 3) o que está de fato preparado no repo precisa passar"
git add -A >/dev/null 2>&1
if bash .githooks/pre-commit; then
    echo "ok: conjunto real passou"
    git reset -q
else
    echo "FALHA: o conjunto real foi bloqueado"
    git reset -q
    exit 1
fi

echo
echo "hook de credencial verificado nos três casos."
