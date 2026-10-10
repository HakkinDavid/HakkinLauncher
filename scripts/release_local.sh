#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# scripts/release_local.sh
# ------------------------------------------------------------------------------
# Genera los binarios de release de HakkinLauncher localmente para todas las plataformas,
# los empaqueta en .zip y gestiona la publicación en GitHub Releases utilizando
# `version_manifest.json` como fuente de verdad:
#
# 1. Caché local:
#    - Si el código fuente Flutter no ha cambiado y los .zip existen, omite la compilación.
#
# 2. Evaluación con referencia cruzada:
#    - Descarga el `version_manifest.json` del último release en GitHub.
#    - Si todos los binarios coinciden: Cancela la operación sin subir duplicados.
#    - Si algún binario cambió o es nuevo:
#      - Crea una nueva release con el tag en formato YY.MM.DD-HH marcada como latest.
#      - Sube únicamente los binarios modificados o nuevos.
#      - Para los binarios no modificados, genera referencias directas de descarga
#        hacia su release de origen en las notas y en el manifiesto.
#      - Actualiza automáticamente `docs/catalog.json` (Single Source of Truth).
#
# Uso:
#   ./scripts/release_local.sh [all|macos|windows|linux] [VERSION_TAG] [--force]
#
# Opciones:
#   all|macos|windows|linux  Plataforma a compilar. Valor por defecto: all.
#   VERSION_TAG              Etiqueta de versión para releases. Valor por defecto: YY.MM.DD-HH.
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

# Parámetros y banderas: todas las plataformas por defecto, tag YY.MM.DD-HH
TARGET="all"
TAG=""
FORCE=false

for arg in "$@"; do
  case "$arg" in
    --help|-h)
      echo "Uso: $0 [all|windows|macos|linux] [VERSION_TAG] [--force]"
      echo ""
      echo "Opciones:"
      echo "  all|windows|...   Plataforma a exportar. Por defecto: all."
      echo "  VERSION_TAG       Etiqueta de versión para nuevos releases. Por defecto: YY.MM.DD-HH."
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
echo "  HAKKIN LAUNCHER: PUBLICACIÓN LOCAL DE RELEASE"
echo "  Versión:           $TAG"
echo "  Objetivo export:   $TARGET"
echo "  Modo forzado:      $FORCE"
echo "================================================================="

# Sincronizar versión base en app_constants.dart
python3 "$HASH_MGR" set-version --version "$TAG"

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
echo "[Caché local] Comprobando integridad de fuentes y artefactos existentes..."

for t in "${TARGETS_TO_PROCESS[@]}"; do
  if [[ "$FORCE" == false ]] && python3 "$HASH_MGR" check-local-cache --target "$t" >/dev/null 2>&1; then
    echo "[$t] Artefactos al día, fuentes sin cambios. Omitiendo compilación."
  else
    echo "[$t] Procesando y empaquetando binarios..."

    case "$t" in
      macos)
        if [[ "$HOST_OS" == "darwin" ]]; then
          echo "   Compilando bundle macOS nativo con Flutter..."
          flutter build macos --release --dart-define=APP_VERSION="$TAG" --build-name="$TAG"

          APP_PATH=""
          for candidate in build/macos/Build/Products/Release/*.app; do
            if [[ -d "$candidate" ]]; then
              APP_PATH="$candidate"
              break
            fi
          done

          if [[ -z "$APP_PATH" ]]; then
            echo "Error: No se encontró .app en build/macos/Build/Products/Release/."
            exit 1
          fi

          # Empaquetar para macOS Apple Silicon y macOS Intel
          for arch in "arm64" "x64"; do
            ZIP_DEST="build/release/HakkinLauncher-macos-${arch}.zip"
            rm -f "$ZIP_DEST"
            echo "   Empaquetando $ZIP_DEST..."
            if command -v ditto >/dev/null 2>&1; then
              ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_DEST"
            else
              (cd "$(dirname "$APP_PATH")" && zip -r -q -y "$WORKSPACE_ROOT/$ZIP_DEST" "$(basename "$APP_PATH")")
            fi
            python3 "$HASH_MGR" update-local-cache --target "macos-${arch}"
          done
          echo "[$t] Empaquetado completado y registrado en caché local."
        else
          echo "[macos] La compilación nativa de macOS requiere un host macOS."
        fi
        ;;

      windows)
        ZIP_DEST="build/release/HakkinLauncher-windows-x64.zip"
        if [[ "$HOST_OS" =~ msys|mingw|cygwin ]]; then
          echo "   Compilando nativo Windows con Flutter..."
          flutter build windows --release --dart-define=APP_VERSION="$TAG" --build-name="$TAG"
          WIN_RELEASE_DIR="build/windows/x64/runner/Release"
          rm -f "$ZIP_DEST"
          (cd "$WIN_RELEASE_DIR" && zip -r -q "$WORKSPACE_ROOT/$ZIP_DEST" .)
          python3 "$HASH_MGR" update-local-cache --target "windows-x64"
          echo "[$t] Empaquetado completado y registrado en caché local."
        else
          # Host no Windows
          if [[ "$TARGET" != "all" ]]; then
            echo "❌ Error: La compilación de Windows requiere un host Windows o GitHub Actions CI."
            exit 1
          fi

          PRESERVED=false
          if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
            LATEST_REMOTE_TAG="$(gh release view --json tagName -q .tagName 2>/dev/null || true)"
            if [[ -n "$LATEST_REMOTE_TAG" ]]; then
              TMP_DL="$(mktemp -d)"
              if gh release download "$LATEST_REMOTE_TAG" -p "HakkinLauncher-windows-x64.zip" -D "$TMP_DL" 2>/dev/null; then
                DL_SIZE=$(stat -f%z "$TMP_DL/HakkinLauncher-windows-x64.zip" 2>/dev/null || stat -c%s "$TMP_DL/HakkinLauncher-windows-x64.zip" 2>/dev/null || echo 0)
                if [[ "$DL_SIZE" -gt 1000000 ]]; then
                  echo "   Preservando binario legítimo previo de Windows (${DL_SIZE} bytes)..."
                  mv "$TMP_DL/HakkinLauncher-windows-x64.zip" "$ZIP_DEST"
                  python3 "$HASH_MGR" update-local-cache --target "windows-x64"
                  PRESERVED=true
                fi
              fi
              rm -rf "$TMP_DL"
            fi
          fi

          if [[ "$PRESERVED" == true ]]; then
            echo "[$t] Binario legítimo previo preservado y registrado en caché local."
          else
            echo "ℹ️ [$t] Host macOS ($HOST_OS) detectado. Flutter no soporta compilar Windows en Mac."
          fi
        fi
        ;;

      linux)
        ZIP_DEST="build/release/HakkinLauncher-linux-x64.zip"
        if [[ "$HOST_OS" =~ linux ]]; then
          echo "   Compilando nativo Linux con Flutter..."
          flutter build linux --release --dart-define=APP_VERSION="$TAG" --build-name="$TAG"
          LINUX_RELEASE_DIR="build/linux/x64/release/bundle"
          rm -f "$ZIP_DEST"
          (cd "$LINUX_RELEASE_DIR" && zip -r -q "$WORKSPACE_ROOT/$ZIP_DEST" .)
          python3 "$HASH_MGR" update-local-cache --target "linux-x64"
          echo "[$t] Empaquetado completado y registrado en caché local."
        else
          # Host no Linux
          if [[ "$TARGET" != "all" ]]; then
            echo "❌ Error: La compilación de Linux requiere un host Linux o GitHub Actions CI."
            exit 1
          fi

          PRESERVED=false
          if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
            LATEST_REMOTE_TAG="$(gh release view --json tagName -q .tagName 2>/dev/null || true)"
            if [[ -n "$LATEST_REMOTE_TAG" ]]; then
              TMP_DL="$(mktemp -d)"
              if gh release download "$LATEST_REMOTE_TAG" -p "HakkinLauncher-linux-x64.zip" -D "$TMP_DL" 2>/dev/null; then
                DL_SIZE=$(stat -f%z "$TMP_DL/HakkinLauncher-linux-x64.zip" 2>/dev/null || stat -c%s "$TMP_DL/HakkinLauncher-linux-x64.zip" 2>/dev/null || echo 0)
                if [[ "$DL_SIZE" -gt 1000000 ]]; then
                  echo "   Preservando binario legítimo previo de Linux (${DL_SIZE} bytes)..."
                  mv "$TMP_DL/HakkinLauncher-linux-x64.zip" "$ZIP_DEST"
                  python3 "$HASH_MGR" update-local-cache --target "linux-x64"
                  PRESERVED=true
                fi
              fi
              rm -rf "$TMP_DL"
            fi
          fi

          if [[ "$PRESERVED" == true ]]; then
            echo "[$t] Binario legítimo previo preservado y registrado en caché local."
          else
            echo "ℹ️ [$t] Host macOS ($HOST_OS) detectado. Flutter no soporta compilar Linux en Mac."
          fi
        fi
        ;;
    esac
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
  echo "Error: No se encontraron archivos empaquetados en build/release/."
  exit 1
fi

echo "Binarios locales evaluados:"
for f in "${BINARY_FILES[@]}"; do
  echo "   - $(basename "$f") - $(du -h "$f" | cut -f1)"
done

# ------------------------------------------------------------------------------
# 3. Evaluación contra version_manifest.json del último release
# ------------------------------------------------------------------------------
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  echo "[GitHub] Consultando el último release para evaluar version_manifest.json..."

  LATEST_TAG="$(gh release view --json tagName -q .tagName 2>/dev/null || true)"
  REMOTE_MANIFEST=""

  if [[ -n "$LATEST_TAG" ]]; then
    echo "Último release en GitHub detectado: $LATEST_TAG"
    REMOTE_MANIFEST="$(gh release download "$LATEST_TAG" -p "version_manifest.json" -O - 2>/dev/null || true)"
  else
    echo "No se detectaron releases previos. Se inicializará el primer release del repositorio."
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

  ACTION="$(python3 -c "import sys, json, os; p='build/release/eval_summary.json'; d=json.load(open(p)) if os.path.isfile(p) else (json.loads(s[s.find('{'):]) if (s:=sys.stdin.read()) and '{' in s else {}); print(d.get('action', ''))" <<< "$EVAL_JSON")"
  REASON="$(python3 -c "import sys, json, os; p='build/release/eval_summary.json'; d=json.load(open(p)) if os.path.isfile(p) else (json.loads(s[s.find('{'):]) if (s:=sys.stdin.read()) and '{' in s else {}); print(d.get('reason', ''))" <<< "$EVAL_JSON")"

  if [[ "$ACTION" == "NOTHING_TO_DO" ]]; then
    echo "================================================================="
    echo "VALIDACIÓN: TODOS LOS ARTEFACTOS ESTÁN AL DÍA"
    echo "================================================================="
    echo "$REASON"
    echo ""
    echo "Se cancela la publicación. No se requieren cambios ni duplicados."
    echo "   Para forzar una nueva versión, use: $0 --force"
    echo "================================================================="
    exit 0
  fi

  # Extraer datos de la evaluación
  FILES_TO_UPLOAD=($(python3 -c "import sys, json, os; p='build/release/eval_summary.json'; d=json.load(open(p)) if os.path.isfile(p) else (json.loads(s[s.find('{'):]) if (s:=sys.stdin.read()) and '{' in s else {}); print(' '.join(d.get('files_to_upload', [])))" <<< "$EVAL_JSON"))
  UPDATED_PLATS="$(python3 -c "import sys, json, os; p='build/release/eval_summary.json'; d=json.load(open(p)) if os.path.isfile(p) else (json.loads(s[s.find('{'):]) if (s:=sys.stdin.read()) and '{' in s else {}); print(', '.join(d.get('updated_platforms', [])))" <<< "$EVAL_JSON")"
  PRESERVED_PLATS="$(python3 -c "import sys, json, os; p='build/release/eval_summary.json'; d=json.load(open(p)) if os.path.isfile(p) else (json.loads(s[s.find('{'):]) if (s:=sys.stdin.read()) and '{' in s else {}); print(', '.join(d.get('preserved_platforms', [])))" <<< "$EVAL_JSON")"
  NOTES_FILE="$(python3 -c "import sys, json, os; p='build/release/eval_summary.json'; d=json.load(open(p)) if os.path.isfile(p) else (json.loads(s[s.find('{'):]) if (s:=sys.stdin.read()) and '{' in s else {}); print(d.get('notes_path', ''))" <<< "$EVAL_JSON")"

  echo "================================================================="
  echo "PUBLICANDO NUEVO RELEASE: $TAG como latest"
  echo "================================================================="
  echo "  - Plataformas actualizadas para subida:   ${UPDATED_PLATS:-ninguna}"
  echo "  - Plataformas preservadas por referencia: ${PRESERVED_PLATS:-ninguna}"
  echo "  - Archivos a transferir:                  ${#FILES_TO_UPLOAD[@]}"
  echo "================================================================="

  # ------------------------------------------------------------------------------
  # 4. Creación o actualización del Release en GitHub
  # ------------------------------------------------------------------------------
  if gh release view "$TAG" >/dev/null 2>&1; then
    echo "El release $TAG ya existe en GitHub. Actualizando activos con --clobber..."
    gh release upload "$TAG" "${FILES_TO_UPLOAD[@]}" --clobber
    gh release edit "$TAG" --notes-file "$NOTES_FILE" --latest --title "HakkinLauncher v$TAG"
  else
    echo "Creando nuevo release $TAG como 'latest'..."
    gh release create "$TAG" "${FILES_TO_UPLOAD[@]}" \
      --title "HakkinLauncher v$TAG" \
      --notes-file "$NOTES_FILE" \
      --latest
  fi

  echo "Release $TAG publicado exitosamente en GitHub:"
  gh release view "$TAG" --web 2>/dev/null || gh release view "$TAG"

  # ------------------------------------------------------------------------------
  # 5. Sincronización del catálogo maestro local de HakkinLauncher
  # ------------------------------------------------------------------------------
  echo "Sincronizando catálogo de HakkinLauncher..."
  python3 "$HASH_MGR" sync-catalog

else
  # Sin CLI de GitHub
  python3 "$HASH_MGR" eval-release --new-tag "$TAG" "${BINARY_FILES[@]}" >/dev/null
  python3 "$HASH_MGR" sync-catalog
  echo "Advertencia: 'gh' CLI no está autenticada o disponible en el PATH."
  echo "   Los binarios y 'version_manifest.json' están listos en 'build/release/'."
  echo "   Para publicar en GitHub: gh auth login && $0"
fi

echo "Proceso de release finalizado con éxito."
