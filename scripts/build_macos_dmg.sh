#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# scripts/build_macos_dmg.sh
# ------------------------------------------------------------------------------
# Genera una imagen de disco nativa de macOS (.dmg) para HakkinLauncher
# con enlace simbólico a /Applications, facilitando la instalación mediante
# arrastre o traslado automático.
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

APP_PATH="${1:-}"
OUTPUT_DMG="${2:-$WORKSPACE_ROOT/build/release/HakkinLauncher-macos.dmg}"

if [[ -z "$APP_PATH" ]]; then
  for candidate in "$WORKSPACE_ROOT"/build/macos/Build/Products/Release/*.app; do
    if [[ -d "$candidate" ]]; then
      APP_PATH="$candidate"
      break
    fi
  done
fi

if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "❌ Error: No se encontró el bundle .app en '$APP_PATH'." >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT_DMG")"
rm -f "$OUTPUT_DMG"

echo "📦 Preparando imagen de disco DMG desde: $APP_PATH"
STAGING_DIR="$(mktemp -d -t hakkin_dmg_staging_XXXXXX)"
trap 'rm -rf "$STAGING_DIR"' EXIT

# Copiar bundle preservando metadatos y permisos
cp -R "$APP_PATH" "$STAGING_DIR/"

# Crear enlace simbólico institucional a la carpeta /Applications
ln -s /Applications "$STAGING_DIR/Applications"

echo "💿 Creando imagen UDZO con hdiutil..."
hdiutil create \
  -volname "HakkinLauncher" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$OUTPUT_DMG"

if [[ -f "$OUTPUT_DMG" ]]; then
  SIZE_BYTES=$(stat -f%z "$OUTPUT_DMG" 2>/dev/null || stat -c%s "$OUTPUT_DMG" 2>/dev/null || echo 0)
  echo "✅ Imagen DMG creada con éxito: $OUTPUT_DMG (${SIZE_BYTES} bytes)"
else
  echo "❌ Error: Falló la creación del archivo DMG." >&2
  exit 1
fi
