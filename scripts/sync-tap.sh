#!/usr/bin/env bash
# Atualiza o cask no tap do Homebrew a partir do release JÁ publicado.
#
# Uso: scripts/sync-tap.sh <VERSION>
#
# Por que existe: o sha256 do cask precisa ser o do zip que está no release, não o de um
# build local. O build universal não é bit a bit reprodutível, então repetir o empacotamento
# produz outro hash e o cask passaria a apontar para um arquivo que não é o publicado. Aqui o
# sha256 é lido do próprio asset OpenRouterMeter-<VERSION>.zip.sha256 do release.
#
# Passos: confere o release -> baixa o .sha256 -> renderiza o cask a partir de
# packaging/homebrew-tap/Casks/openrouter-meter.rb -> commit e push no tap.
set -euo pipefail

cd "$(dirname "$0")/.."

ROOT="$(pwd)"
TAP_REPO="${TAP_REPO:-ronanrodrigo/homebrew-tap}"
TAP_CASK_TEMPLATE="$ROOT/packaging/homebrew-tap/Casks/openrouter-meter.rb"
TAP_CASK_PATH="Casks/openrouter-meter.rb"
APP_REPO="${APP_REPO:-ronanrodrigo/openrouter-meter}"

fail() {
    echo "erro: $*" >&2
    exit 1
}

VERSION="${1:-}"
[ -n "$VERSION" ] || fail "informe a versão: scripts/sync-tap.sh <VERSION>"

TAG="v$VERSION"
ZIP_NAME="OpenRouterMeter-$VERSION.zip"
SHA_ASSET="$ZIP_NAME.sha256"

command -v gh >/dev/null || fail "gh não encontrado; instale com 'brew install gh'"
[ -f "$TAP_CASK_TEMPLATE" ] || fail "template do cask ausente em $TAP_CASK_TEMPLATE"

echo "== sincronizando o tap com o release $TAG"

# 1) O release precisa existir e trazer o zip e o .sha256.
gh release view "$TAG" --repo "$APP_REPO" >/dev/null 2>&1 \
    || fail "o release $TAG não existe em $APP_REPO; publique o release antes de sincronizar o tap"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "== baixando $SHA_ASSET do release $TAG"
gh release download "$TAG" --repo "$APP_REPO" --pattern "$SHA_ASSET" --dir "$WORK" --clobber \
    || fail "não foi possível baixar $SHA_ASSET do release $TAG"

SHA="$(awk '{print $1; exit}' "$WORK/$SHA_ASSET")"
[ -n "$SHA" ] || fail "não foi possível ler o sha256 de $SHA_ASSET"
case "$SHA" in
    *[!0-9a-f]*) fail "sha256 inválido em $SHA_ASSET: '$SHA'" ;;
esac
[ "${#SHA}" -eq 64 ] || fail "sha256 com tamanho inesperado em $SHA_ASSET: '$SHA'"
echo "== sha256 do release: $SHA"

# 2) O zip precisa estar no release.
gh release download "$TAG" --repo "$APP_REPO" --pattern "$ZIP_NAME" --dir "$WORK" --clobber >/dev/null 2>&1 \
    || fail "o release $TAG não traz $ZIP_NAME"

# 3) Renderiza o cask e publica no tap.
echo "== clonando/atualizando $TAP_REPO"
gh repo clone "$TAP_REPO" "$WORK/tap" -- --depth 1 >/dev/null 2>&1 \
    || fail "não foi possível clonar $TAP_REPO (ele existe e você tem acesso?)"

mkdir -p "$WORK/tap/Casks"
sed -e "s/__VERSION__/$VERSION/g" -e "s/__SHA256__/$SHA/g" \
    "$TAP_CASK_TEMPLATE" > "$WORK/tap/$TAP_CASK_PATH"

cd "$WORK/tap"
# No CI não existe identidade git configurada no clone; no uso local a identidade do usuário
# é preservada.
if [ -z "$(git config user.email 2>/dev/null || true)" ]; then
    git config user.name "openrouter-meter release"
    git config user.email "releases@users.noreply.github.com"
fi
git add "$TAP_CASK_PATH"
if git diff --cached --quiet; then
    echo "== cask já estava atualizado para $VERSION"
else
    git commit -q -m "openrouter-meter $VERSION"
    git push -q
    echo "== cask atualizado e enviado para $TAP_REPO"
fi

echo
echo "tap sincronizado. instalação:"
echo "  brew install --cask ronanrodrigo/tap/openrouter-meter"
