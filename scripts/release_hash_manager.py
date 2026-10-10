#!/usr/bin/env python3
"""
scripts/release_hash_manager.py
--------------------------------
Gestor criptográfico para releases de HakkinLauncher.

Responsabilidades:
1. Hash de Fuentes: Calcula el hash SHA-256 compuesto de las fuentes Flutter.
2. Caché Local: Evita re-compilar binarios si el artefacto empaquetado existe y las fuentes no cambiaron.
3. Evaluación y Manifiesto de Release:
   - Descarga e inspecciona version_manifest.json del último release en GitHub.
   - Compara los hashes locales contra los remotos por cada plataforma.
   - Si no hubo cambios: Cancela la operación sin subir duplicados.
   - Si cambiaron binarios o se añadieron nuevos:
     - Crea la nueva versión con el tag especificado.
     - Identifica los binarios actualizados para subirlos.
     - Identifica los binarios intactos para referenciarlos a su release de origen.
     - Genera build/release/version_manifest.json y build/release/release_notes.md.
     - Sincroniza tools/launcher_meta.json y regenera el catálogo.
"""

import os
import sys
import json
import hashlib
import argparse
import subprocess
import re
import urllib.request
from datetime import datetime, timezone

WORKSPACE_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD_DIR = os.path.join(WORKSPACE_ROOT, "build", "release")
LOCAL_MANIFEST_PATH = os.path.join(BUILD_DIR, ".export_manifest.json")
VERSION_MANIFEST_FILE = os.path.join(BUILD_DIR, "version_manifest.json")
RELEASE_NOTES_FILE = os.path.join(BUILD_DIR, "release_notes.md")
CATALOG_FILE = os.path.join(WORKSPACE_ROOT, "docs", "catalog.json")
MIN_VALID_SIZE = 1_000_000  # 1 MB mínimo para binarios empaquetados válidos


def read_catalog_launcher_meta():
    """Obtiene launcher_meta directamente desde el Single Source of Truth (docs/catalog.json)."""
    if os.path.isfile(CATALOG_FILE):
        try:
            with open(CATALOG_FILE, "r", encoding="utf-8") as f:
                cat = json.load(f)
                return cat.get("launcher_meta") or {}
        except Exception:
            pass
    return {}


def update_catalog_launcher_meta(meta):
    """Actualiza launcher_meta directamente dentro de docs/catalog.json."""
    if os.path.isfile(CATALOG_FILE):
        try:
            with open(CATALOG_FILE, "r", encoding="utf-8") as f:
                cat = json.load(f)
            cat["launcher_meta"] = meta
            cat["catalog_timestamp"] = datetime.now(timezone.utc).isoformat()
            with open(CATALOG_FILE, "w", encoding="utf-8") as f:
                json.dump(cat, f, indent=2, ensure_ascii=False)
            return True
        except Exception as e:
            print(f"Error actualizando catalog.json: {e}", file=sys.stderr)
    return False


TARGET_CONFIG = {
    # Paquetes de Actualización y Portables (.zip)
    "macos-arm64": {
        "filename": "HakkinLauncher-macos-arm64.zip",
        "path": os.path.join(BUILD_DIR, "HakkinLauncher-macos-arm64.zip"),
        "display_name": "macOS Apple Silicon (arm64)",
        "type": "update",
    },
    "macos-x64": {
        "filename": "HakkinLauncher-macos-x64.zip",
        "path": os.path.join(BUILD_DIR, "HakkinLauncher-macos-x64.zip"),
        "display_name": "macOS Intel (x64)",
        "type": "update",
    },
    "windows-x64": {
        "filename": "HakkinLauncher-windows-x64.zip",
        "path": os.path.join(BUILD_DIR, "HakkinLauncher-windows-x64.zip"),
        "display_name": "Windows x64",
        "type": "update",
    },
    "linux-x64": {
        "filename": "HakkinLauncher-linux-x64.zip",
        "path": os.path.join(BUILD_DIR, "HakkinLauncher-linux-x64.zip"),
        "display_name": "Linux x64",
        "type": "update",
    },
    # Instaladores Nativos para Nuevos Usuarios
    "windows-msi": {
        "filename": "HakkinLauncher-windows-x64.msi",
        "path": os.path.join(BUILD_DIR, "HakkinLauncher-windows-x64.msi"),
        "display_name": "Windows x64 (Instalador nativo .msi)",
        "type": "installer",
        "platform_key": "windows-x64",
    },
    "macos-dmg": {
        "filename": "HakkinLauncher-macos.dmg",
        "path": os.path.join(BUILD_DIR, "HakkinLauncher-macos.dmg"),
        "display_name": "macOS Universal (Imagen .dmg con /Applications)",
        "type": "installer",
        "platform_key": "macos",
    },
    "linux-deb": {
        "filename": "HakkinLauncher-linux-amd64.deb",
        "path": os.path.join(BUILD_DIR, "HakkinLauncher-linux-amd64.deb"),
        "display_name": "Linux Ubuntu / Debian (Paquete nativo .deb)",
        "type": "installer",
        "platform_key": "linux-x64",
    },
}

FILENAME_TO_TARGET = {cfg["filename"]: tgt for tgt, cfg in TARGET_CONFIG.items()}


def compute_file_sha256(filepath):
    """Calcula SHA-256 de un archivo en bloques de 1MB."""
    if not os.path.isfile(filepath):
        return None
    h = hashlib.sha256()
    with open(filepath, "rb") as f:
        while chunk := f.read(1048576):
            h.update(chunk)
    return h.hexdigest()


def compute_source_hash(target=None):
    """
    Calcula un hash compuesto de todo el contenido relevante de Flutter:
    - lib/
    - pubspec.yaml, pubspec.lock
    - carpeta de plataforma nativa correspondiente: macos, windows, linux
    """
    h = hashlib.sha256()
    search_dirs = [os.path.join(WORKSPACE_ROOT, "lib")]

    if target:
        if "macos" in target:
            search_dirs.append(os.path.join(WORKSPACE_ROOT, "macos"))
        elif "windows" in target:
            search_dirs.append(os.path.join(WORKSPACE_ROOT, "windows"))
        elif "linux" in target:
            search_dirs.append(os.path.join(WORKSPACE_ROOT, "linux"))
    else:
        for p in ["macos", "windows", "linux"]:
            pdir = os.path.join(WORKSPACE_ROOT, p)
            if os.path.isdir(pdir):
                search_dirs.append(pdir)

    for sdir in search_dirs:
        if not os.path.isdir(sdir):
            continue
        for root, dirs, files in os.walk(sdir):
            dirs[:] = [d for d in dirs if d not in (".dart_tool", "build", ".tmp", "Pods", "ephemeral", ".git")]
            for fname in sorted(files):
                if fname.startswith(".DS_Store") or fname.endswith(".log"):
                    continue
                fpath = os.path.join(root, fname)
                try:
                    st = os.stat(fpath)
                    rel = os.path.relpath(fpath, WORKSPACE_ROOT)
                    h.update(f"{rel}:{st.st_size}:{st.st_mtime_ns}".encode("utf-8"))
                except OSError:
                    continue

    for root_file in ["pubspec.yaml", "pubspec.lock"]:
        rfpath = os.path.join(WORKSPACE_ROOT, root_file)
        if os.path.isfile(rfpath):
            try:
                st = os.stat(rfpath)
                h.update(f"{root_file}:{st.st_size}:{st.st_mtime_ns}".encode("utf-8"))
            except OSError:
                pass

    return h.hexdigest()


def load_local_manifest():
    if os.path.isfile(LOCAL_MANIFEST_PATH):
        try:
            with open(LOCAL_MANIFEST_PATH, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return {"source_hashes": {}, "targets": {}}


def save_local_manifest(data):
    os.makedirs(BUILD_DIR, exist_ok=True)
    with open(LOCAL_MANIFEST_PATH, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)


def is_target_cached(target):
    """Verifica si el binario local está al día con el estado actual de las fuentes."""
    if target == "macos":
        subtargets = ["macos-arm64", "macos-x64"]
    elif target == "windows":
        subtargets = ["windows-x64"]
    elif target == "linux":
        subtargets = ["linux-x64"]
    else:
        subtargets = [target]

    for sub in subtargets:
        cfg = TARGET_CONFIG.get(sub)
        if not cfg:
            return False, f"Target desconocido: {sub}"
        target_file = cfg["path"]
        if not os.path.isfile(target_file):
            return False, f"El archivo {os.path.basename(target_file)} no existe en build/release/."

        if os.path.getsize(target_file) < MIN_VALID_SIZE:
            return False, f"El archivo {os.path.basename(target_file)} es inválido o dummy (< 1MB)."

        manifest = load_local_manifest()
        cached_source_hash = manifest.get("source_hashes", {}).get(sub)
        current_source_hash = compute_source_hash(sub)

        if not cached_source_hash or cached_source_hash != current_source_hash:
            return False, f"Las fuentes de {sub} han cambiado desde la última compilación."

        target_entry = manifest.get("targets", {}).get(sub, {})
        cached_file_hash = target_entry.get("sha256")
        actual_file_hash = compute_file_sha256(target_file)

        if not cached_file_hash or cached_file_hash != actual_file_hash:
            return False, f"El hash del archivo {os.path.basename(target_file)} no coincide con el manifiesto local."

    return True, "Artefactos y fuentes idénticos."


def update_target_cache(target):
    """Actualiza la entrada del target en el manifiesto tras una compilación exitosa."""
    if target == "macos":
        subtargets = ["macos-arm64", "macos-x64"]
    elif target == "windows":
        subtargets = ["windows-x64"]
    elif target == "linux":
        subtargets = ["linux-x64"]
    else:
        subtargets = [target]

    manifest = load_local_manifest()
    all_ok = True

    for sub in subtargets:
        cfg = TARGET_CONFIG.get(sub)
        if not cfg:
            continue
        target_file = cfg["path"]
        if not os.path.isfile(target_file):
            all_ok = False
            continue

        if os.path.getsize(target_file) < MIN_VALID_SIZE:
            all_ok = False
            continue

        current_source_hash = compute_source_hash(sub)
        actual_file_hash = compute_file_sha256(target_file)
        size_bytes = os.path.getsize(target_file)

        manifest.setdefault("source_hashes", {})[sub] = current_source_hash
        manifest.setdefault("targets", {})[sub] = {
            "file": os.path.relpath(target_file, WORKSPACE_ROOT),
            "sha256": actual_file_hash,
            "size_bytes": size_bytes,
            "updated_at": datetime.now(timezone.utc).isoformat()
        }

    save_local_manifest(manifest)
    return all_ok


def get_repo_slug():
    """Detecta el repositorio 'owner/repo' configurado en git origin."""
    try:
        res = subprocess.run(
            ["git", "remote", "get-url", "origin"],
            capture_output=True, text=True, check=True
        )
        url = res.stdout.strip()
        m = re.search(r"github\.com[:/]([^/]+)/([^/.]+)", url)
        if m:
            return f"{m.group(1)}/{m.group(2)}"
    except Exception:
        pass
    return "HakkinDavid/HakkinLauncher"


def get_git_commit():
    """Obtiene el hash SHA del commit actual."""
    try:
        res = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            capture_output=True, text=True, check=True
        )
        return res.stdout.strip()
    except Exception:
        return "unknown"


def evaluate_release(local_files, remote_manifest_text, new_tag, force=False):
    """
    Función central de evaluación de release basada en version_manifest.json.
    Compara los binarios locales con el manifiesto del último release.
    """
    os.makedirs(BUILD_DIR, exist_ok=True)
    repo = get_repo_slug()
    commit_sha = get_git_commit()
    now_utc = datetime.now(timezone.utc).isoformat()

    remote_manifest = {}
    if remote_manifest_text:
        try:
            remote_manifest = json.loads(remote_manifest_text)
        except Exception:
            pass

    remote_binaries = remote_manifest.get("binaries", {})
    new_binaries = {}
    files_to_upload = []
    updated_platforms = []
    preserved_platforms = []

    # Evaluar cada binario local proporcionado
    for fpath in local_files:
        if not os.path.isfile(fpath):
            continue

        size_bytes = os.path.getsize(fpath)
        if size_bytes < MIN_VALID_SIZE:
            print(f"⚠️ Aviso: Omitiendo {os.path.basename(fpath)} ({size_bytes} bytes < 1MB, posible dummy o corrupto).", file=sys.stderr)
            continue

        fname = os.path.basename(fpath)
        platform_id = FILENAME_TO_TARGET.get(fname, os.path.splitext(fname)[0])
        display_name = TARGET_CONFIG.get(platform_id, {}).get("display_name", platform_id)
        local_hash = compute_file_sha256(fpath)
        size_bytes = os.path.getsize(fpath)

        remote_entry = remote_binaries.get(platform_id, {})
        remote_hash = remote_entry.get("sha256")

        if (not force) and remote_hash and (local_hash == remote_hash):
            # PRESERVED: Sin cambios respecto al release anterior
            origin_tag = remote_entry.get("origin_release", remote_manifest.get("release_version", new_tag))
            download_url = remote_entry.get("download_url") or f"https://github.com/{repo}/releases/download/{origin_tag}/{fname}"

            new_binaries[platform_id] = {
                "filename": fname,
                "display_name": display_name,
                "sha256": local_hash,
                "size_bytes": size_bytes,
                "status": "PRESERVED",
                "origin_release": origin_tag,
                "download_url": download_url
            }
            preserved_platforms.append(platform_id)
        else:
            # UPDATED: Modificado o nuevo
            download_url = f"https://github.com/{repo}/releases/download/{new_tag}/{fname}"
            new_binaries[platform_id] = {
                "filename": fname,
                "display_name": display_name,
                "sha256": local_hash,
                "size_bytes": size_bytes,
                "status": "UPDATED",
                "origin_release": new_tag,
                "download_url": download_url
            }
            files_to_upload.append(fpath)
            updated_platforms.append(platform_id)

    # Preservar plataformas remotas no incluidas en la compilación local actual
    for remote_pid, remote_info in remote_binaries.items():
        if remote_pid not in new_binaries:
            new_binaries[remote_pid] = {
                "filename": remote_info.get("filename", f"HakkinLauncher-{remote_pid}.zip"),
                "display_name": remote_info.get("display_name", remote_pid),
                "sha256": remote_info.get("sha256", ""),
                "size_bytes": remote_info.get("size_bytes", 0),
                "status": "PRESERVED",
                "origin_release": remote_info.get("origin_release", remote_manifest.get("release_version", new_tag)),
                "download_url": remote_info.get("download_url", "")
            }
            preserved_platforms.append(remote_pid)

    # Determinar acción
    if len(updated_platforms) == 0 and not force:
        action = "NOTHING_TO_DO"
        reason = "Todos los binarios evaluados son idénticos a los del último release en GitHub."
    else:
        action = "CREATE_RELEASE"
        reason = f"Se publicará el release {new_tag} con {len(updated_platforms)} binario(s) actualizado(s) y {len(preserved_platforms)} preservado(s)."

    # Construir el nuevo version_manifest.json
    manifest_data = {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "format_version": "1.0",
        "release_version": new_tag,
        "published_at_utc": now_utc,
        "git_commit": commit_sha,
        "repository": repo,
        "binaries": new_binaries
    }

    with open(VERSION_MANIFEST_FILE, "w", encoding="utf-8") as f:
        json.dump(manifest_data, f, indent=2)

    clean_version_tag = re.sub(r'^v+', '', new_tag)
    display_tag = f"v{clean_version_tag}"

    existing_meta = read_catalog_launcher_meta()

    installers_meta = {
        TARGET_CONFIG[pid].get("platform_key", pid): {
            "format": os.path.splitext(b["filename"])[1].lstrip("."),
            "url": b["download_url"],
            "sha256": b["sha256"],
            "size_bytes": b.get("size_bytes", 0)
        }
        for pid, b in new_binaries.items()
        if TARGET_CONFIG.get(pid, {}).get("type") == "installer" and b.get("download_url") and b.get("sha256") and b.get("size_bytes", 0) > 0
    }

    releases_meta = {
        pid: {
            "url": b["download_url"],
            "sha256": b["sha256"],
            "size_bytes": b.get("size_bytes", 0)
        }
        for pid, b in new_binaries.items()
        if TARGET_CONFIG.get(pid, {}).get("type") != "installer" and b.get("download_url") and b.get("sha256") and b.get("size_bytes", 0) > 0
    }

    launcher_meta_data = {
        "latest_version": clean_version_tag,
        "min_required_launcher_version": existing_meta.get("min_required_launcher_version", "1.0.0"),
        "installers": installers_meta,
        "releases": releases_meta
    }

    update_catalog_launcher_meta(launcher_meta_data)

    update_app_constants_version(clean_version_tag)

    # Generar Release Notes en Markdown con secciones separadas para instaladores y autoactualización
    installer_lines = [
        "### 🚀 Instaladores Nativos Recomendados (Nuevos Usuarios)",
        "",
        "| Plataforma | Formato | Archivo | Tamaño | SHA-256 | Descarga |",
        "| :--- | :--- | :--- | :--- | :--- | :--- |"
    ]
    package_lines = [
        "### 📦 Paquetes Portables y Autoactualización en Segundo Plano",
        "",
        "| Plataforma | Archivo | Tamaño | SHA-256 | Descarga |",
        "| :--- | :--- | :--- | :--- | :--- |"
    ]

    has_installers = False
    for pid in sorted(new_binaries.keys()):
        b = new_binaries[pid]
        cfg = TARGET_CONFIG.get(pid, {})
        size_mb = f"{b['size_bytes'] / (1024 * 1024):.1f} MB" if b["size_bytes"] else "N/A"
        sha_short = b["sha256"][:12] + "..." if b["sha256"] else "N/A"
        
        if b["status"] == "UPDATED":
            link_label = f"Descargar {display_tag}"
        else:
            link_label = f"Descargar {b['origin_release']}"

        url = b.get("download_url", "#")
        if cfg.get("type") == "installer":
            has_installers = True
            fmt = os.path.splitext(b['filename'])[1].lstrip('.').upper()
            installer_lines.append(
                f"| **{cfg.get('display_name', pid)}** | `{fmt}` | `{b['filename']}` | {size_mb} | `{sha_short}` | [{link_label}]({url}) |"
            )
        else:
            package_lines.append(
                f"| **{cfg.get('display_name', pid)}** | `{b['filename']}` | {size_mb} | `{sha_short}` | [{link_label}]({url}) |"
            )

    all_notes = []
    if has_installers:
        all_notes.extend(installer_lines)
        all_notes.append("")
    all_notes.extend(package_lines)

    with open(RELEASE_NOTES_FILE, "w", encoding="utf-8") as f:
        f.write("\n".join(all_notes) + "\n")

    if action == "CREATE_RELEASE":
        files_to_upload.append(VERSION_MANIFEST_FILE)

    eval_result = {
        "action": action,
        "reason": reason,
        "release_tag": new_tag,
        "updated_platforms": updated_platforms,
        "preserved_platforms": preserved_platforms,
        "files_to_upload": files_to_upload,
        "manifest_path": VERSION_MANIFEST_FILE,
        "notes_path": RELEASE_NOTES_FILE,
        "catalog_path": CATALOG_FILE,
    }

    try:
        os.makedirs(BUILD_DIR, exist_ok=True)
        eval_summary_file = os.path.join(BUILD_DIR, "eval_summary.json")
        with open(eval_summary_file, "w", encoding="utf-8") as f:
            json.dump(eval_result, f, indent=2)
        eval_result["eval_summary_path"] = eval_summary_file
    except Exception as e:
        print(f"Aviso: No se pudo guardar eval_summary.json: {e}", file=sys.stderr)

    return eval_result


def update_app_constants_version(version_tag):
    """Actualiza defaultAppVersion en lib/core/constants/app_technical_strings.dart (o app_constants.dart)."""
    clean_tag = re.sub(r'^v+', '', version_tag)
    tech_file = os.path.join(WORKSPACE_ROOT, "lib", "core", "constants", "app_technical_strings.dart")
    constants_file = os.path.join(WORKSPACE_ROOT, "lib", "core", "constants", "app_constants.dart")
    target_file = tech_file if os.path.isfile(tech_file) else constants_file
    if not os.path.isfile(target_file):
        return False
    with open(target_file, "r", encoding="utf-8") as f:
        content = f.read()

    pattern = r"(static const (?:String )?defaultAppVersion = )'[^']*';"
    if re.search(pattern, content):
        new_content = re.sub(pattern, rf"\g<1>'{clean_tag}';", content)
        if new_content != content:
            with open(target_file, "w", encoding="utf-8") as f:
                f.write(new_content)
            print(f"Versión base en {os.path.basename(target_file)} sincronizada con: {clean_tag}", file=sys.stderr)
            return True
        else:
            print(f"Versión base en {os.path.basename(target_file)} ya está al día ({clean_tag}).", file=sys.stderr)
            return True
    return False


def sync_launcher_meta_from_remote(repo=None):
    """
    Inspecciona GitHub Releases para HakkinLauncher y regenera tools/launcher_meta.json.
    - Si no hay ningún release publicado en GitHub (ej. todas las versiones fueron borradas):
      Genera launcher_meta seguro y resiliente con releases: {}.
    - Si hay un release publicado:
      Descarga e inspecciona version_manifest.json (o los assets del release) y genera
      tools/launcher_meta.json con las URLs, hashes y tamaños reales publicados.
    """
    repo = repo or get_repo_slug()
    print(f"🔍 Sincronizando launcher_meta desde GitHub Releases para {repo}...")

    latest_tag = None
    manifest_data = None

    # 1. Intentar obtener el último release con gh CLI
    try:
        res = subprocess.run(
            ["gh", "release", "view", "--repo", repo, "--json", "tagName,assets"],
            capture_output=True, text=True
        )
        if res.returncode == 0:
            rel_info = json.loads(res.stdout)
            latest_tag = rel_info.get("tagName")
            assets = rel_info.get("assets", [])
            has_manifest = any(a.get("name") == "version_manifest.json" for a in assets)
            if has_manifest and latest_tag:
                dl_res = subprocess.run(
                    ["gh", "release", "download", latest_tag, "--repo", repo, "-p", "version_manifest.json", "-O", "-"],
                    capture_output=True, text=True
                )
                if dl_res.returncode == 0 and dl_res.stdout.strip():
                    try:
                        manifest_data = json.loads(dl_res.stdout)
                    except Exception:
                        pass
    except Exception as e:
        print(f"Aviso: gh CLI no disponible o falló: {e}", file=sys.stderr)

    # 2. Si gh no obtuvo manifest_data, intentar via urllib con API de GitHub
    if not manifest_data:
        token = os.environ.get("GITHUB_TOKEN")
        headers = {"User-Agent": "HakkinLauncher-ReleaseHashManager/1.0"}
        if token:
            headers["Authorization"] = f"Bearer {token}"
        api_url = f"https://api.github.com/repos/{repo}/releases?per_page=1"
        try:
            req = urllib.request.Request(api_url, headers=headers)
            with urllib.request.urlopen(req, timeout=10) as resp:
                if resp.status == 200:
                    releases = json.loads(resp.read().decode("utf-8"))
                    if isinstance(releases, list) and len(releases) > 0:
                        rel = releases[0]
                        latest_tag = rel.get("tag_name")
                        for asset in rel.get("assets", []):
                            if asset.get("name") == "version_manifest.json":
                                m_url = asset.get("browser_download_url")
                                m_req = urllib.request.Request(m_url, headers=headers)
                                with urllib.request.urlopen(m_req, timeout=10) as m_resp:
                                    if m_resp.status == 200:
                                        manifest_data = json.loads(m_resp.read().decode("utf-8"))
                                break
        except Exception as e:
            print(f"Aviso: Consulta API de GitHub falló o sin conexión: {e}", file=sys.stderr)

    # 3. Construir launcher_meta_data resiliente
    if manifest_data and isinstance(manifest_data, dict):
        clean_tag = re.sub(r'^v+', '', str(manifest_data.get("release_version", latest_tag or "1.0.0")))
        releases_dict = {}
        installers_dict = {}
        for pid, b in manifest_data.get("binaries", {}).items():
            if isinstance(b, dict) and b.get("download_url") and b.get("sha256"):
                cfg = TARGET_CONFIG.get(pid, {})
                if cfg.get("type") == "installer":
                    plat_key = cfg.get("platform_key", pid)
                    fmt = os.path.splitext(b.get("filename", ""))[1].lstrip(".")
                    installers_dict[plat_key] = {
                        "format": fmt,
                        "url": b["download_url"],
                        "sha256": b["sha256"],
                        "size_bytes": b.get("size_bytes", 0)
                    }
                else:
                    releases_dict[pid] = {
                        "url": b["download_url"],
                        "sha256": b["sha256"],
                        "size_bytes": b.get("size_bytes", 0)
                    }

        meta = {
            "latest_version": clean_tag,
            "min_required_launcher_version": "1.0.0",
            "installers": installers_dict,
            "releases": releases_dict
        }
        print(f"✅ Se sincronizó launcher_meta con el release {clean_tag} ({len(releases_dict)} paquetes, {len(installers_dict)} instaladores)")
    elif latest_tag:
        clean_tag = re.sub(r'^v+', '', str(latest_tag))
        releases_dict = {}
        installers_dict = {}
        if assets:
            for asset in assets:
                aname = asset.get("name", "")
                pid = FILENAME_TO_TARGET.get(aname)
                if pid:
                    cfg = TARGET_CONFIG.get(pid, {})
                    digest = asset.get("digest", "")
                    sha = digest.split("sha256:")[-1] if "sha256:" in digest else ""
                    url = asset.get("url") or f"https://github.com/{repo}/releases/download/{latest_tag}/{aname}"
                    size = asset.get("size", 0)
                    if cfg.get("type") == "installer":
                        plat_key = cfg.get("platform_key", pid)
                        fmt = os.path.splitext(aname)[1].lstrip(".")
                        installers_dict[plat_key] = {
                            "format": fmt,
                            "url": url,
                            "sha256": sha,
                            "size_bytes": size
                        }
                    else:
                        releases_dict[pid] = {
                            "url": url,
                            "sha256": sha,
                            "size_bytes": size
                        }
        meta = {
            "latest_version": clean_tag,
            "min_required_launcher_version": "1.0.0",
            "installers": installers_dict,
            "releases": releases_dict
        }
        if releases_dict:
            print(f"✅ Se sincronizó launcher_meta directamente desde los activos del release {clean_tag} ({len(releases_dict)} binarios)")
        else:
            print(f"⚠️ Tag {latest_tag} localizado sin activos descargables; releases inicializado vacío.")
    else:
        # No hay ningún release en GitHub (todas las versiones fueron borradas)
        meta = {
            "latest_version": "1.0.0",
            "min_required_launcher_version": "1.0.0",
            "releases": {}
        }
        print("ℹ️ No hay versiones publicadas en GitHub (todas borradas). launcher_meta restablecido de forma segura y resiliente.")

    update_catalog_launcher_meta(meta)
    return meta


def sync_catalog():
    """Ejecuta catalog_generator.py para actualizar docs/catalog.json como Single Source of Truth."""
    l_meta = read_catalog_launcher_meta()
    latest_ver = l_meta.get("latest_version")
    if latest_ver:
        update_app_constants_version(latest_ver)

    cat_gen = os.path.join(WORKSPACE_ROOT, "tools", "catalog_generator.py")
    if not os.path.isfile(cat_gen):
        print("Aviso: tools/catalog_generator.py no encontrado.", file=sys.stderr)
        return False
    try:
        subprocess.run(
            [sys.executable, cat_gen],
            check=True,
            cwd=WORKSPACE_ROOT
        )
        print("Catálogo de HakkinLauncher sincronizado exitosamente con la nueva versión.")
        return True
    except Exception as e:
        print(f"Error sincronizando catálogo: {e}", file=sys.stderr)
        return False


def main():
    parser = argparse.ArgumentParser(description="Gestor criptográfico para releases de HakkinLauncher.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # Subcomando: source-hash
    p_src = subparsers.add_parser("source-hash", help="Muestra el hash compuesto actual de las fuentes")
    p_src.add_argument("--target", choices=["macos-arm64", "macos-x64", "windows-x64", "linux-x64"])

    # Subcomando: check-local-cache
    p_check = subparsers.add_parser("check-local-cache", help="Verifica si un target local está al día")
    p_check.add_argument("--target", required=True, choices=["macos-arm64", "macos-x64", "windows-x64", "linux-x64", "macos", "windows", "linux"])

    # Subcomando: update-local-cache
    p_upd = subparsers.add_parser("update-local-cache", help="Actualiza el registro de caché de un target")
    p_upd.add_argument("--target", required=True, choices=["macos-arm64", "macos-x64", "windows-x64", "linux-x64", "macos", "windows", "linux"])

    # Subcomando: eval-release
    p_eval = subparsers.add_parser("eval-release", help="Evalúa el release contra el version_manifest remoto")
    p_eval.add_argument("--remote-manifest", default="", help="Texto o ruta de version_manifest.json del release anterior")
    p_eval.add_argument("--new-tag", required=True, help="Nuevo tag de versión")
    p_eval.add_argument("--force", action="store_true", help="Fuerza actualización de todas las plataformas")
    p_eval.add_argument("files", nargs="+", help="Rutas de los binarios locales a evaluar")

    # Subcomando: sync-catalog
    subparsers.add_parser("sync-catalog", help="Sincroniza docs/catalog.json como Single Source of Truth")

    # Subcomando: sync-launcher-meta
    p_meta = subparsers.add_parser("sync-launcher-meta", help="Regenera launcher_meta en docs/catalog.json desde el release remoto de GitHub")
    p_meta.add_argument("--repo", default=None, help="Repositorio owner/repo (opcional)")

    # Subcomando: set-version
    p_ver = subparsers.add_parser("set-version", help="Sincroniza defaultAppVersion en app_constants.dart")
    p_ver.add_argument("--version", required=True, help="Versión de versión a sincronizar")

    args = parser.parse_args()

    # Normalizar targets simplificados: macos a macos-arm64 o macos-x64
    def normalize_target(t):
        if t == "macos":
            import platform
            return "macos-arm64" if platform.machine() in ("arm64", "aarch64") else "macos-x64"
        elif t == "windows":
            return "windows-x64"
        elif t == "linux":
            return "linux-x64"
        return t

    if args.command == "source-hash":
        target = normalize_target(args.target) if args.target else None
        print(compute_source_hash(target))

    elif args.command == "check-local-cache":
        target = normalize_target(args.target)
        cached, reason = is_target_cached(target)
        if cached:
            print(f"[CACHE_HIT] {target}: {reason}")
            sys.exit(0)
        else:
            print(f"[CACHE_MISS] {target}: {reason}")
            sys.exit(1)

    elif args.command == "update-local-cache":
        target = normalize_target(args.target)
        ok = update_target_cache(target)
        if ok:
            print(f"[CACHE_UPDATED] {target}")
            sys.exit(0)
        else:
            print(f"[CACHE_ERROR] No se pudo actualizar {target}")
            sys.exit(1)

    elif args.command == "eval-release":
        remote_text = args.remote_manifest
        if os.path.isfile(remote_text):
            with open(remote_text, "r", encoding="utf-8") as f:
                remote_text = f.read()

        result = evaluate_release(args.files, remote_text, args.new_tag, force=args.force)
        print(json.dumps(result, indent=2))

        if result["action"] == "CREATE_RELEASE":
            sys.exit(0)
        else:
            sys.exit(2)

    elif args.command == "sync-catalog":
        ok = sync_catalog()
        sys.exit(0 if ok else 1)

    elif args.command == "sync-launcher-meta":
        sync_launcher_meta_from_remote(repo=args.repo)
        sys.exit(0)

    elif args.command == "set-version":
        ok = update_app_constants_version(args.version)
        sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
