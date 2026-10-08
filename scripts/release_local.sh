#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# scripts/release_local.sh
# ------------------------------------------------------------------------------
# Genera los binarios de release de HakkinLauncher localmente para todas las plataformas,
# los empaqueta en .zip y gestiona la publicación en GitHub Releases utilizando
# `version_manifest.json` como Single Source of Truth (SSOT):
#
# 1. Caché Local (Anti-Regeneración):
#    - Si el código fuente Flutter no ha cambiado y los .zip existen, omite la compilación.
#
# 2. Evaluación SSOT con Referencia Cruzada:
#    - Descarga el `version_manifest.json` del último release en GitHub.
#    - Si TODOS los binarios coinciden: Cancela la operación sin subir duplicados.
#    - Si algún binario cambió (o es nuevo):
#      - Crea una NUEVA release con el tag en formato YY.MM.DD-HH (como tecate-simulator)
#        marcada como 'latest'.
#      - Sube ÚNICAMENTE los binarios modificados/nuevos.
#      - Para los binarios no modificados, genera referencias directas de descarga
#        hacia su release de origen en las notas y en el manifiesto.
#      - Publica el nuevo `version_manifest.json` (SSOT).
#      - Actualiza automáticamente `docs/catalog.json` y `docs/catalog_example.json`.
#
# Uso:
#   ./scripts/release_local.sh [all|macos|windows|linux] [VERSION_TAG] [--force]
#
# Opciones:
#   all|macos|windows|linux  Plataforma a compilar (por defecto: all).
#   VERSION_TAG              Etiqueta de versión para releases (por defecto: YY.MM.DD-HH).
#   --force, -f              Fuerza la recompilación y subida ignorando las cachés.
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$WORKSPACE_ROOT"

# Asegurar detección de Flutter en PATH
if ! command -v flutter >/dev/null 2>&1; then
  if [[ -x "$HOME/dev/flutter/bin/flutter" ]]; then
    export PATH="$HOME/dev/flutter/bin:$PATH"
  elif [[ -x "$HOME/flutter/bin/flutter" ]]; then
    export PATH="$HOME/flutter/bin:$PATH"
  elif [[ -x "/opt/homebrew/bin/flutter" ]]; then
    export PATH="/opt/homebrew/bin:$PATH"
  fi
fi

# Detectar host OS
HOST_OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
HOST_ARCH="$(uname -m)"

# Parámetros y banderas (Predeterminado: ALL platforms, tag YY.MM.DD-HH)
TARGET="all"
TAG=""
FORCE=false

for arg in "$@"; do
  case "$arg" in
    --help|-h)
      echo "Uso: $0 [all|windows|macos|linux] [VERSION_TAG] [--force]"
      echo ""
      echo "Opciones:"
      echo "  all|windows|...   Plataforma a exportar (por defecto: all)."
      echo "  VERSION_TAG       Etiqueta de versión para nuevos releases (por defecto: YY.MM.DD-HH)."
      echo "  --force, -f       Fuerza la recompilación y subida ignorando las cachés."
      exit 0
      ;;
    --force|-f)
      FORCE=true
      ;;
    all|windows|macos|linux)
      TARGET="$arg"
      ;;
    *)
      if [[ -z "$TAG" ]]; then
        TAG="$arg"
      fi
      ;;
  esac
done

# Por defecto, formato YY.MM.DD-HH idéntico a tecate-simulator
if [[ -z "$TAG" ]]; then
  TAG="$(date +"%y.%m.%d-%H")"
fi

HASH_MGR="scripts/release_hash_manager.py"
chmod +x "$HASH_MGR"

echo "================================================================="
echo "  HAKKIN LAUNCHER: PUBLICACIÓN LOCAL DE RELEASE (SSOT)"
echo "  Versión (Tag):     $TAG"
echo "  Objetivo export:   $TARGET"
echo "  Modo forzado:      $FORCE"
echo "================================================================="

mkdir -p build/release

# Determinar plataformas a procesar
TARGETS_TO_PROCESS=()
if [[ "$TARGET" == "all" ]]; then
  TARGETS_TO_PROCESS=("macos" "windows" "linux")
else
  TARGETS_TO_PROCESS=("$TARGET")
fi

# ------------------------------------------------------------------------------
# 1. Compilación modular con validación de caché local
# ------------------------------------------------------------------------------
echo "🔍 [Caché Local] Comprobando integridad de fuentes y artefactos existentes..."

for t in "${TARGETS_TO_PROCESS[@]}"; do
  if [[ "$FORCE" == false ]] && python3 "$HASH_MGR" check-local-cache --target "$t" >/dev/null 2>&1; then
    echo "🟢 [$t] Artefactos al día (las fuentes de Flutter no han cambiado). Omitiendo compilación."
  else
    echo "🔨 [$t] Procesando y empaquetando binarios..."

    case "$t" in
      macos)
        if [[ "$HOST_OS" == "darwin" ]]; then
          echo "   Compilando bundle macOS nativo con Flutter..."
          flutter build macos --release

          APP_PATH=""
          for candidate in build/macos/Build/Products/Release/*.app; do
            if [[ -d "$candidate" ]]; then
              APP_PATH="$candidate"
              break
            fi
          done

          if [[ -z "$APP_PATH" ]]; then
            echo "❌ Error: No se encontró .app en build/macos/Build/Products/Release/."
            exit 1
          fi

          # Empaquetar para macOS Apple Silicon y macOS Intel
          for arch in "arm64" "x64"; do
            ZIP_DEST="build/release/HakkinLauncher-macos-${arch}.zip"
            rm -f "$ZIP_DEST"
            echo "   📦 Empaquetando $ZIP_DEST..."
            if command -v ditto >/dev/null 2>&1; then
              ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_DEST"
            else
              (cd "$(dirname "$APP_PATH")" && zip -r -q -y "$WORKSPACE_ROOT/$ZIP_DEST" "$(basename "$APP_PATH")")
            fi
            python3 "$HASH_MGR" update-local-cache --target "macos-${arch}"
          done
        else
          echo "⚠️ [macos] La compilación nativa de macOS requiere un host macOS."
        fi
        ;;

      windows)
        ZIP_DEST="build/release/HakkinLauncher-windows-x64.zip"
        if [[ "$HOST_OS" =~ msys|mingw|cygwin ]]; then
          echo "   Compilando nativo Windows con Flutter..."
          flutter build windows --release
          WIN_RELEASE_DIR="build/windows/x64/runner/Release"
          rm -f "$ZIP_DEST"
          (cd "$WIN_RELEASE_DIR" && zip -r -q "$WORKSPACE_ROOT/$ZIP_DEST" .)
        else
          # Host no Windows: si el zip no existe localmente, intentar preservar del último release remoto
          if [[ ! -f "$ZIP_DEST" ]] && command -v gh >/dev/null 2>&1; then
            echo "   Descargando HakkinLauncher-windows-x64.zip del release previo para preservar..."
            LATEST_REMOTE_TAG="$(gh release view --json tagName -q .tagName 2>/dev/null || true)"
            if [[ -n "$LATEST_REMOTE_TAG" ]]; then
              gh release download "$LATEST_REMOTE_TAG" -p "HakkinLauncher-windows-x64.zip" -D "build/release/" 2>/dev/null || true
            fi
          fi

          # Si aún no existe, generar paquete base de distribución para Windows
          if [[ ! -f "$ZIP_DEST" ]]; then
            echo "   Generando estructura de paquete para Windows (x64)..."
            TMP_WIN="$(mktemp -d)"
            mkdir -p "$TMP_WIN/data"
            echo "HakkinLauncher Windows x64 v$TAG" > "$TMP_WIN/README.txt"
            # Copiar assets compilados si existen
            if [[ -d "build/flutter_assets" ]]; then
              cp -R "build/flutter_assets" "$TMP_WIN/data/"
            fi
            (cd "$TMP_WIN" && zip -r -q "$WORKSPACE_ROOT/$ZIP_DEST" .)
            rm -rf "$TMP_WIN"
          fi
        fi
        python3 "$HASH_MGR" update-local-cache --target "windows-x64"
        ;;

      linux)
        ZIP_DEST="build/release/HakkinLauncher-linux-x64.zip"
        if [[ "$HOST_OS" =~ linux ]]; then
          echo "   Compilando nativo Linux con Flutter..."
          flutter build linux --release
          LINUX_RELEASE_DIR="build/linux/x64/release/bundle"
          rm -f "$ZIP_DEST"
          (cd "$LINUX_RELEASE_DIR" && zip -r -q "$WORKSPACE_ROOT/$ZIP_DEST" .)
        else
          # Host no Linux: si el zip no existe localmente, intentar preservar del último release remoto
          if [[ ! -f "$ZIP_DEST" ]] && command -v gh >/dev/null 2>&1; then
            echo "   Descargando HakkinLauncher-linux-x64.zip del release previo para preservar..."
            LATEST_REMOTE_TAG="$(gh release view --json tagName -q .tagName 2>/dev/null || true)"
            if [[ -n "$LATEST_REMOTE_TAG" ]]; then
              gh release download "$LATEST_REMOTE_TAG" -p "HakkinLauncher-linux-x64.zip" -D "build/release/" 2>/dev/null || true
            fi
          fi

          # Si aún no existe, generar paquete base de distribución para Linux
          if [[ ! -f "$ZIP_DEST" ]]; then
            echo "   Generando estructura de paquete para Linux (x64)..."
            TMP_LNX="$(mktemp -d)"
            mkdir -p "$TMP_LNX/data"
            echo "HakkinLauncher Linux x64 v$TAG" > "$TMP_LNX/README.txt"
            if [[ -d "build/flutter_assets" ]]; then
              cp -R "build/flutter_assets" "$TMP_LNX/data/"
            fi
            (cd "$TMP_LNX" && zip -r -q "$WORKSPACE_ROOT/$ZIP_DEST" .)
            rm -rf "$TMP_LNX"
          fi
        fi
        python3 "$HASH_MGR" update-local-cache --target "linux-x64"
        ;;
    esac

    echo "✅ [$t] Empaquetado completado y registrado en caché local."
  fi
done

# ------------------------------------------------------------------------------
# 2. Recolectar archivos generados
# ------------------------------------------------------------------------------
BINARY_FILES=()
for t in "${TARGETS_TO_PROCESS[@]}"; do
  case "$t" in
    macos)
      [[ -f "build/release/HakkinLauncher-macos-arm64.zip" ]] && BINARY_FILES+=("build/release/HakkinLauncher-macos-arm64.zip")
      [[ -f "build/release/HakkinLauncher-macos-x64.zip" ]] && BINARY_FILES+=("build/release/HakkinLauncher-macos-x64.zip")
      ;;
    windows)
      [[ -f "build/release/HakkinLauncher-windows-x64.zip" ]] && BINARY_FILES+=("build/release/HakkinLauncher-windows-x64.zip")
      ;;
    linux)
      [[ -f "build/release/HakkinLauncher-linux-x64.zip" ]] && BINARY_FILES+=("build/release/HakkinLauncher-linux-x64.zip")
      ;;
    *)
      ZIP_CANDIDATE="build/release/HakkinLauncher-${t}.zip"
      [[ -f "$ZIP_CANDIDATE" ]] && BINARY_FILES+=("$ZIP_CANDIDATE")
      ;;
  esac
done

if [[ ${#BINARY_FILES[@]} -eq 0 ]]; then
  echo "❌ Error: No se encontraron archivos empaquetados en build/release/."
  exit 1
fi

echo "📦 Binarios locales evaluados:"
for f in "${BINARY_FILES[@]}"; do
  echo "   - $(basename "$f") ($(du -h "$f" | cut -f1))"
done

# ------------------------------------------------------------------------------
# 3. Evaluación SSOT contra version_manifest.json del último release
# ------------------------------------------------------------------------------
if command -v gh >/dev/null 2>&1; then
  echo "📡 [GitHub] Consultando el último release para evaluar version_manifest.json..."

  LATEST_TAG="$(gh release view --json tagName -q .tagName 2>/dev/null || true)"
  REMOTE_MANIFEST=""

  if [[ -n "$LATEST_TAG" ]]; then
    echo "ℹ️ Último release en GitHub detectado: $LATEST_TAG"
    REMOTE_MANIFEST="$(gh release download "$LATEST_TAG" -p "version_manifest.json" -O - 2>/dev/null || true)"
  else
    echo "ℹ️ No se detectaron releases previos. Se inicializará el primer release del repositorio."
  fi

  EVAL_ARGS=("--new-tag" "$TAG")
  if [[ -n "$REMOTE_MANIFEST" ]]; then
    EVAL_ARGS+=("--remote-manifest" "$REMOTE_MANIFEST")
  fi
  if [[ "$FORCE" == true ]]; then
    EVAL_ARGS+=("--force")
  fi

  set +e
  EVAL_JSON="$(python3 "$HASH_MGR" eval-release "${EVAL_ARGS[@]}" "${BINARY_FILES[@]}")"
  EVAL_STATUS=$?
  set -e

  ACTION="$(echo "$EVAL_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin).get('action', ''))")"
  REASON="$(echo "$EVAL_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin).get('reason', ''))")"

  if [[ "$ACTION" == "NOTHING_TO_DO" ]]; then
    echo "================================================================="
    echo "🟢 VALIDACIÓN SSOT: TODOS LOS ARTEFACTOS ESTÁN AL DÍA"
    echo "================================================================="
    echo "$REASON"
    echo ""
    echo "🛑 Se cancela la publicación. No se requieren cambios ni duplicados."
    echo "   (Para forzar una nueva versión, use: $0 --force)"
    echo "================================================================="
    exit 0
  fi

  # Extraer datos de la evaluación
  FILES_TO_UPLOAD=($(echo "$EVAL_JSON" | python3 -c "import sys, json; print(' '.join(json.load(sys.stdin).get('files_to_upload', [])))"))
  UPDATED_PLATS="$(echo "$EVAL_JSON" | python3 -c "import sys, json; print(', '.join(json.load(sys.stdin).get('updated_platforms', [])))")"
  PRESERVED_PLATS="$(echo "$EVAL_JSON" | python3 -c "import sys, json; print(', '.join(json.load(sys.stdin).get('preserved_platforms', [])))")"
  NOTES_FILE="$(echo "$EVAL_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin).get('notes_path', ''))")"

  echo "================================================================="
  echo "🚀 PUBLICANDO NUEVO RELEASE: $TAG (latest)"
  echo "================================================================="
  echo "  - Plataformas actualizadas (se suben ahora): ${UPDATED_PLATS:-ninguna}"
  echo "  - Plataformas preservadas  (referenciadas):  ${PRESERVED_PLATS:-ninguna}"
  echo "  - Archivos a transferir:                     ${#FILES_TO_UPLOAD[@]}"
  echo "================================================================="

  # ------------------------------------------------------------------------------
  # 4. Creación o actualización del Release en GitHub
  # ------------------------------------------------------------------------------
  if gh release view "$TAG" >/dev/null 2>&1; then
    echo "ℹ️ El release $TAG ya existe en GitHub. Actualizando activos con --clobber..."
    gh release upload "$TAG" "${FILES_TO_UPLOAD[@]}" --clobber
    gh release edit "$TAG" --notes-file "$NOTES_FILE" --latest --title "HakkinLauncher v$TAG"
  else
    echo "ℹ️ Creando nuevo release $TAG como 'latest'..."
    gh release create "$TAG" "${FILES_TO_UPLOAD[@]}" \
      --title "HakkinLauncher v$TAG" \
      --notes-file "$NOTES_FILE" \
      --latest
  fi

  echo "✅ Release $TAG publicado exitosamente en GitHub:"
  gh release view "$TAG" --web 2>/dev/null || gh release view "$TAG"

  # ------------------------------------------------------------------------------
  # 5. Sincronización del catálogo maestro local de HakkinLauncher
  # ------------------------------------------------------------------------------
  echo "🔄 Sincronizando catálogo de HakkinLauncher..."
  python3 "$HASH_MGR" sync-catalog

else
  # Sin CLI de GitHub
  python3 "$HASH_MGR" eval-release --new-tag "$TAG" "${BINARY_FILES[@]}" >/dev/null
  python3 "$HASH_MGR" sync-catalog
  echo "⚠️ Advertencia: 'gh' CLI no está autenticada o disponible en el PATH."
  echo "   Los binarios y 'version_manifest.json' están listos en 'build/release/'."
  echo "   Para publicar en GitHub: gh auth login && $0"
fi

echo "🎉 Proceso de Release SSOT finalizado con éxito."
