#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# scripts/build_linux_deb.sh
# ------------------------------------------------------------------------------
# Genera un paquete de instalación nativo Debian/Ubuntu (.deb) para HakkinLauncher,
# con integración en menús del sistema, binario en /usr/bin e icono hicolor.
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

VERSION_TAG="${1:-1.0.0}"
BUNDLE_DIR="${2:-$WORKSPACE_ROOT/build/linux/x64/release/bundle}"
OUTPUT_DEB="${3:-$WORKSPACE_ROOT/build/release/HakkinLauncher-linux-amd64.deb}"

# Normalizar versión para dpkg (sin 'v' inicial y caracteres válidos)
CLEAN_VERSION="$(echo "$VERSION_TAG" | sed 's/^v//' | tr '-' '.')"

if [[ ! -d "$BUNDLE_DIR" ]]; then
  echo "❌ Error: Directorio de compilación Linux no encontrado en '$BUNDLE_DIR'." >&2
  exit 1
fi

if ! command -v dpkg-deb >/dev/null 2>&1; then
  echo "❌ Error: La herramienta 'dpkg-deb' no está instalada en el sistema." >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT_DEB")"
rm -f "$OUTPUT_DEB"

echo "📦 Preparando estructura de empaquetado .deb para HakkinLauncher v$CLEAN_VERSION..."
STAGING_DIR="$(mktemp -d -t hakkin_deb_staging_XXXXXX)"
trap 'rm -rf "$STAGING_DIR"' EXIT

# Crear directorios del paquete Debian
mkdir -p "$STAGING_DIR/DEBIAN"
mkdir -p "$STAGING_DIR/opt/HakkinLauncher"
mkdir -p "$STAGING_DIR/usr/bin"
mkdir -p "$STAGING_DIR/usr/share/applications"
mkdir -p "$STAGING_DIR/usr/share/icons/hicolor/512x512/apps"

# 1. Copiar contenido de la aplicación en /opt/HakkinLauncher
cp -a "$BUNDLE_DIR/." "$STAGING_DIR/opt/HakkinLauncher/"
chmod +x "$STAGING_DIR/opt/HakkinLauncher/hakkin_launcher" 2>/dev/null || true
if [[ -f "$STAGING_DIR/opt/HakkinLauncher/HakkinLauncher" ]]; then
  chmod +x "$STAGING_DIR/opt/HakkinLauncher/HakkinLauncher"
fi

# 2. Enlace simbólico en /usr/bin
EXE_NAME="hakkin_launcher"
if [[ -f "$STAGING_DIR/opt/HakkinLauncher/HakkinLauncher" ]]; then
  EXE_NAME="HakkinLauncher"
fi
ln -s "/opt/HakkinLauncher/$EXE_NAME" "$STAGING_DIR/usr/bin/hakkin-launcher"

# 3. Icono del sistema
ICON_SOURCE="$WORKSPACE_ROOT/assets/hakkinlauncher.png"
if [[ -f "$ICON_SOURCE" ]]; then
  cp "$ICON_SOURCE" "$STAGING_DIR/usr/share/icons/hicolor/512x512/apps/hakkin-launcher.png"
fi

# 4. Archivo .desktop institucional
cat <<EOF > "$STAGING_DIR/usr/share/applications/hakkin-launcher.desktop"
[Desktop Entry]
Type=Application
Name=HakkinLauncher
GenericName=Lanzador de Software y Videojuegos
Comment=Cliente universal de distribución, actualización diferencial y ejecución de software y videojuegos
Exec=/opt/HakkinLauncher/$EXE_NAME %u
Icon=hakkin-launcher
Terminal=false
Categories=Game;Utility;
Keywords=Games;Launcher;Hakkin;Updates;
StartupWMClass=$EXE_NAME
EOF
chmod 644 "$STAGING_DIR/usr/share/applications/hakkin-launcher.desktop"

# 5. Control file
cat <<EOF > "$STAGING_DIR/DEBIAN/control"
Package: hakkin-launcher
Version: $CLEAN_VERSION
Section: games
Priority: optional
Architecture: amd64
Maintainer: HakkinDavid <dev@hakkin.org>
Depends: libgtk-3-0, libayatana-appindicator3-1, liblzma5, libnotify4
Description: HakkinLauncher
 Cliente universal de distribución, actualización diferencial y ejecución de software y videojuegos.
EOF

echo "🔨 Compilando paquete .deb con dpkg-deb..."
dpkg-deb --build --root-owner-group "$STAGING_DIR" "$OUTPUT_DEB"

if [[ -f "$OUTPUT_DEB" ]]; then
  SIZE_BYTES=$(stat -f%z "$OUTPUT_DEB" 2>/dev/null || stat -c%s "$OUTPUT_DEB" 2>/dev/null || echo 0)
  echo "✅ Paquete .deb generado con éxito: $OUTPUT_DEB (${SIZE_BYTES} bytes)"
else
  echo "❌ Error: Falló la compilación del paquete .deb." >&2
  exit 1
fi
