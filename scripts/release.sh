#!/usr/bin/env bash
# Orquestrador de release local do OpenRouter Meter.
#
# Uso: scripts/release.sh [--skip-gate] [--no-tap] <VERSION>
#   --skip-gate  não roda `make verify-pr` (útil para testar o pipeline)
#   --no-tap     não atualiza o tap do Homebrew
#   VERSION      versão a publicar (obrigatória). A tag será v<VERSION> e precisa
#                bater com MARKETING_VERSION em project.yml.
#
# Passos: árvore limpa -> invariante de versão -> gate -> scripts/package.sh ->
# release no GitHub (cria ou atualiza) -> cask no tap ronanrodrigo/homebrew-tap.
#
# Notas de release: usa packaging/release-notes/v<VERSION>.md quando existe; senão
# cai em packaging/release-notes/TEMPLATE.md, substituindo __VERSION__.
set -euo pipefail

cd "$(dirname "$0")/.."

ROOT="$(pwd)"
PROJECT_YML="project.yml"
DIST_DIR="$ROOT/build/dist"

SKIP_GATE=0
NO_TAP=0
VERSION=""

fail() {
    echo "erro: $*" >&2
    exit 1
}

for arg in "$@"; do
    case "$arg" in
        --skip-gate) SKIP_GATE=1 ;;
        --no-tap) NO_TAP=1 ;;
        -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
        -*) fail "opção desconhecida: $arg" ;;
        *) [ -z "$VERSION" ] || fail "mais de uma versão informada: '$VERSION' e '$arg'"; VERSION="$arg" ;;
    esac
done

[ -n "$VERSION" ] || fail "informe a versão: scripts/release.sh [--skip-gate] [--no-tap] <VERSION>"

TAG="v$VERSION"
ZIP_NAME="OpenRouterMeter-$VERSION.zip"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"
SHA_PATH="$ZIP_PATH.sha256"

echo "== Release OpenRouter Meter $VERSION (tag $TAG)"

command -v gh >/dev/null || fail "gh não encontrado; instale com 'brew install gh'"

# 1) Árvore de trabalho limpa.
if [ -n "$(git status --porcelain)" ]; then
    fail "a árvore de trabalho tem mudanças não commitadas; commite ou descarte antes de publicar"
fi
echo "== árvore de trabalho limpa"

# 2) Invariante de versão: tag v<VERSION> == MARKETING_VERSION em project.yml.
PROJECT_VERSION="$(awk -F'"' '/MARKETING_VERSION:/ {print $2; exit}' "$PROJECT_YML")"
[ -n "$PROJECT_VERSION" ] || fail "MARKETING_VERSION não encontrado em $PROJECT_YML"
[ "$VERSION" = "$PROJECT_VERSION" ] || fail "versão divergente: pedida '$VERSION', mas $PROJECT_YML traz '$PROJECT_VERSION'"
echo "== versão confere com project.yml ($PROJECT_VERSION)"

# 3) Gate.
if [ "$SKIP_GATE" -eq 1 ]; then
    echo "== gate pulado (--skip-gate)"
else
    echo "== make verify-pr"
    make verify-pr
fi

# 4) Empacotamento.
echo "== scripts/package.sh $VERSION"
bash scripts/package.sh "$VERSION"
[ -f "$ZIP_PATH" ] || fail "o zip não foi gerado em $ZIP_PATH"

# 5) Notas de release.
NOTES_DIR="$ROOT/packaging/release-notes"
if [ -f "$NOTES_DIR/v$VERSION.md" ]; then
    NOTES_FILE="$NOTES_DIR/v$VERSION.md"
else
    NOTES_FILE="$ROOT/build/dist/release-notes-$VERSION.md"
    echo "== notas de release: v$VERSION.md ausente, usando TEMPLATE.md"
    sed "s/__VERSION__/$VERSION/g" "$NOTES_DIR/TEMPLATE.md" > "$NOTES_FILE"
fi

# 6) Release no GitHub: cria, ou atualiza com --clobber.
if gh release view "$TAG" >/dev/null 2>&1; then
    echo "== release $TAG já existe; enviando o zip com --clobber"
    gh release upload "$TAG" "$ZIP_PATH" "$SHA_PATH" --clobber
    gh release edit "$TAG" --title "OpenRouter Meter $VERSION" --notes-file "$NOTES_FILE"
else
    echo "== criando o release $TAG"
    gh release create "$TAG" "$ZIP_PATH" "$SHA_PATH" \
        --title "OpenRouter Meter $VERSION" \
        --notes-file "$NOTES_FILE"
fi

URL="https://github.com/ronanrodrigo/openrouter-meter/releases/download/$TAG/$ZIP_NAME"
echo "== release publicado: $URL"

# 7) Tap do Homebrew: o cask é atualizado a partir do release publicado, para o sha256 ser
#    o do zip que está no release (build universal não é bit a bit reprodutível).
if [ "$NO_TAP" -eq 1 ]; then
    echo "== tap pulado (--no-tap)"
    echo "   para atualizar depois: scripts/sync-tap.sh $VERSION"
    echo
    echo "release concluído."
    exit 0
fi

bash scripts/sync-tap.sh "$VERSION"

echo
echo "release concluído. instalação:"
echo "  brew install --cask ronanrodrigo/tap/openrouter-meter"
