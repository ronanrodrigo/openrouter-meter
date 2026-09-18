#!/usr/bin/env bash
# Empacota o OpenRouter Meter para distribuição: gera o .xcodeproj, compila Release
# universal (arm64 + x86_64), copia o .app e cria o zip que vai para o release.
#
# Uso: scripts/package.sh [VERSION]
#   VERSION  versão do produto. Precisa bater com MARKETING_VERSION em project.yml.
#            Se omitida, é lida de project.yml.
#
# Saída, em build/dist/:
#   OpenRouterMeter-<VERSION>.zip         zip universal, com OpenRouterMeter.app na raiz
#   OpenRouterMeter-<VERSION>.zip.sha256  <sha256>  <arquivo>, no formato do shasum -a 256
set -euo pipefail

cd "$(dirname "$0")/.."

ROOT="$(pwd)"
PROJECT="OpenRouterMeter.xcodeproj"
SCHEME="OpenRouterMeter"
PROJECT_YML="project.yml"
BUILD_DIR="$ROOT/build"
DIST_DIR="$BUILD_DIR/dist"
ARCHS="arm64 x86_64"
DESTINATION="platform=macOS"

fail() {
    echo "erro: $*" >&2
    exit 1
}

# 1) Versão pretendida e invariante com project.yml.
if [ "$#" -ge 1 ] && [ -n "${1:-}" ]; then
    VERSION="$1"
else
    VERSION="$(awk -F'"' '/MARKETING_VERSION:/ {print $2; exit}' "$PROJECT_YML")"
fi

[ -n "$VERSION" ] || fail "não foi possível determinar a versão (argumento vazio e MARKETING_VERSION ausente em $PROJECT_YML)"

PROJECT_VERSION="$(awk -F'"' '/MARKETING_VERSION:/ {print $2; exit}' "$PROJECT_YML")"
[ -n "$PROJECT_VERSION" ] || fail "MARKETING_VERSION não encontrado em $PROJECT_YML"

if [ "$VERSION" != "$PROJECT_VERSION" ]; then
    fail "versão divergente: foi pedido '$VERSION', mas $PROJECT_YML traz MARKETING_VERSION '$PROJECT_VERSION'. Ajuste $PROJECT_YML antes de empacotar."
fi

echo "== Empacotando OpenRouter Meter $VERSION (universal: $ARCHS)"

# 2) Gera o projeto se preciso (o .xcodeproj não é versionado).
if [ ! -d "$PROJECT" ]; then
    command -v xcodegen >/dev/null || fail "xcodegen não encontrado; instale com 'brew install xcodegen'"
    echo "== xcodegen generate"
    xcodegen generate
fi

# 3) Compila Release universal.
echo "== xcodebuild Release universal"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination "$DESTINATION" \
    ARCHS="$ARCHS" \
    ONLY_ACTIVE_ARCH=NO \
    build

# 4) Localiza o .app no BUILT_PRODUCTS_DIR.
BUILT_PRODUCTS_DIR="$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
    -destination "$DESTINATION" -showBuildSettings 2>/dev/null \
    | awk -F' = ' '/ BUILT_PRODUCTS_DIR/ {print $2}' | head -1)"

[ -n "$BUILT_PRODUCTS_DIR" ] || fail "não foi possível ler BUILT_PRODUCTS_DIR do xcodebuild"

APP_PATH="$BUILT_PRODUCTS_DIR/OpenRouterMeter.app"
if [ ! -d "$APP_PATH" ]; then
    fail "o app não foi encontrado em '$APP_PATH'. O build Release não produziu OpenRouterMeter.app — verifique a saída do xcodebuild acima."
fi

# 5) Copia o .app e empacota com ditto (preserva estrutura e permissões).
echo "== copiando OpenRouterMeter.app para build/dist/"
cp -R "$APP_PATH" "$DIST_DIR/OpenRouterMeter.app"

ZIP_NAME="OpenRouterMeter-$VERSION.zip"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"

echo "== ditto -c -k --keepParent"
ditto -c -k --keepParent "$DIST_DIR/OpenRouterMeter.app" "$ZIP_PATH"

# 6) Checksum no formato do shasum -a 256.
( cd "$DIST_DIR" && shasum -a 256 "$ZIP_NAME" > "$ZIP_NAME.sha256" )

echo
echo "== pronto"
echo "   zip:    $ZIP_PATH"
echo "   sha256: $(awk '{print $1}' "$DIST_DIR/$ZIP_NAME.sha256")"
echo "   app:    $(du -sh "$DIST_DIR/OpenRouterMeter.app" | awk '{print $1}')"
