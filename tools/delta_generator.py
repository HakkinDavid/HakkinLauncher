#!/usr/bin/env python3
"""
tools/delta_generator.py
-------------------------
Generador centralizado de parches diferenciales (HDiffPatch) para HakkinLauncher.

Arquitectura Desacoplada y Centralizada (Opción A):
- Los repositorios de terceros (ej. Bonsanbec/tecate-simulator) no requieren ninguna
  acción, script ni dependencia de HakkinLauncher; solo publican sus paquetes completos.
- Los parches diferenciales (.hdiff) se almacenan en un repositorio satélite dedicado
  (por defecto 'HakkinDavid/hakkin-launcher-deltas') bajo releases etiquetados con:
      {slug}.{versión_origen}...{versión_destino}
      Ejemplo: tecate-simulator.0.0.1...26.10.08-13
- Cada release aloja los assets diferenciales de las plataformas soportadas:
      {slug}_{platform_key}.hdiff
"""

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.request
import zipfile

DEFAULT_DELTAS_REPO = os.environ.get("HAKKIN_DELTAS_REPO", "HakkinDavid/hakkin-launcher-deltas")


def compute_sha256(filepath):
    """Calcula el hash SHA-256 de un archivo en bloques de 1MB."""
    if not os.path.isfile(filepath):
        return None
    h = hashlib.sha256()
    with open(filepath, "rb") as f:
        while chunk := f.read(1048576):
            h.update(chunk)
    return h.hexdigest()


PACKAGE_CACHE_DIR = os.path.join(tempfile.gettempdir(), "hakkin_pkg_cache")
os.makedirs(PACKAGE_CACHE_DIR, exist_ok=True)


def download_file_with_cache(url, expected_sha=None):
    """Descarga un archivo con caché persistente y reporte de progreso."""
    if expected_sha and len(expected_sha) == 64:
        cache_file = os.path.join(PACKAGE_CACHE_DIR, f"{expected_sha}.pkg")
        if os.path.isfile(cache_file) and os.path.getsize(cache_file) > 0:
            if compute_sha256(cache_file) == expected_sha:
                print(f"    [Caché Local] Usando paquete en caché: {os.path.basename(cache_file)} ({os.path.getsize(cache_file):,} bytes)")
                return cache_file

    url_hash = hashlib.sha256(url.encode()).hexdigest()[:16]
    temp_target = os.path.join(PACKAGE_CACHE_DIR, f"dl_{url_hash}.part")
    final_target = os.path.join(PACKAGE_CACHE_DIR, f"{expected_sha or url_hash}.pkg")

    req = urllib.request.Request(
        url,
        headers={"User-Agent": "HakkinLauncher-DeltaGenerator/2.0 (Python urllib)"}
    )
    with urllib.request.urlopen(req, timeout=300) as resp, open(temp_target, "wb") as out:
        total_size = int(resp.headers.get("content-length", 0))
        downloaded = 0
        last_logged_mb = 0
        while chunk := resp.read(1048576):
            out.write(chunk)
            downloaded += len(chunk)
            curr_mb = downloaded // (1024 * 1024)
            if curr_mb - last_logged_mb >= 50 or downloaded == total_size:
                last_logged_mb = curr_mb
                total_mb_str = f" / {total_size // (1024 * 1024)} MB" if total_size > 0 else ""
                print(f"    [Descarga] {curr_mb} MB{total_mb_str}...", end="\r", flush=True)
        print()

    if os.path.exists(temp_target):
        shutil.move(temp_target, final_target)
    return final_target


def format_delta_tag(slug, from_version, to_version):
    """
    Genera el tag del release del repositorio satélite según la especificación:
    {nombre_del_repositorio}.{versión_origen}-to-{versión_destino}
    Nota: Git prohíbe secuencias de puntos consecutivos '..' o '...' en tags
    (git-check-ref-format regla 3). Se utiliza '-to-' para representar el rango origen...destino.
    """
    clean_from = re.sub(r'^[vV]+', '', str(from_version).strip())
    clean_to = re.sub(r'^[vV]+', '', str(to_version).strip())
    clean_slug = str(slug).strip()
    return f"{clean_slug}.{clean_from}-to-{clean_to}"


def format_delta_asset_name(slug, platform_key):
    """Nombre del archivo asset diferencial dentro del release satélite."""
    return f"{slug}_{platform_key}.hdiff"


class DeltaGenerator:
    def __init__(self, deltas_repo=DEFAULT_DELTAS_REPO, hdiffz_cmd="hdiffz", dry_run=False):
        self.deltas_repo = deltas_repo
        if hdiffz_cmd == "hdiffz":
            local_bin = os.path.join(os.path.dirname(os.path.abspath(__file__)), "bin", "hdiffz")
            if os.path.isfile(local_bin) and os.access(local_bin, os.X_OK):
                hdiffz_cmd = local_bin
        self.hdiffz_cmd = hdiffz_cmd
        self.dry_run = dry_run
        self._hdiffz_available = None

    def check_hdiffz(self):
        """Verifica si hdiffz está disponible en el PATH o en la ruta configurada."""
        if self._hdiffz_available is not None:
            return self._hdiffz_available
        try:
            res = subprocess.run([self.hdiffz_cmd, "-v"], capture_output=True, text=True)
            self._hdiffz_available = (res.returncode == 0)
        except Exception:
            self._hdiffz_available = False
        return self._hdiffz_available

    def check_remote_release_exists(self, tag):
        """Consulta si el release ya existe en el repositorio satélite vía GitHub API pública."""
        url = f"https://api.github.com/repos/{self.deltas_repo}/releases/tags/{tag}"
        try:
            req = urllib.request.Request(
                url,
                headers={
                    "User-Agent": "HakkinLauncher-DeltaGenerator/2.0",
                    "Accept": "application/vnd.github.v3+json"
                }
            )
            with urllib.request.urlopen(req, timeout=5) as resp:
                if resp.status == 200:
                    data = json.loads(resp.read().decode("utf-8"))
                    return data
        except Exception:
            pass
        return None

    def generate_delta_patch(
        self,
        app_slug,
        platform_key,
        from_release,
        to_release,
        work_dir=None
    ):
        """
        Genera el parche diferencial entre from_release y to_release para una plataforma.
        Retorna el diccionario de entrada para delta_patches del catálogo o None si falla.
        """
        tag = format_delta_tag(app_slug, from_release["version"], to_release["version"])
        asset_name = format_delta_asset_name(app_slug, platform_key)
        expected_url = f"https://github.com/{self.deltas_repo}/releases/download/{tag}/{asset_name}"

        # 1. Verificar si el asset ya existe en el release satélite remoto
        remote_release = self.check_remote_release_exists(tag)
        if remote_release:
            for asset in remote_release.get("assets", []):
                if asset.get("name") == asset_name:
                    print(f"  [Satellite Cache] Asset {asset_name} ya existe en release {tag}.")
                    patch_sha = ""
                    digest = asset.get("digest", "")
                    if digest and digest.startswith("sha256:"):
                        patch_sha = digest[7:]
                    target_sha = to_release.get("executable_sha256", "")
                    if not target_sha:
                        target_sha = to_release.get("package", {}).get("sha256", "")
                    return {
                        "from_version": from_release["version"],
                        "to_version": to_release["version"],
                        "patch_format": "hdiff",
                        "url": asset.get("browser_download_url", expected_url),
                        "size_bytes": asset.get("size", 0),
                        "patch_sha256": patch_sha,
                        "target_sha256": target_sha
                    }

        if not self.check_hdiffz():
            print(f"  [Aviso] hdiffz no disponible en el sistema. Omitiendo generación de delta para {tag}.", file=sys.stderr)
            return None

        clean_temp = False
        if not work_dir:
            work_dir = tempfile.mkdtemp(prefix=f"delta_{app_slug}_")
            clean_temp = True

        try:
            from_pkg = from_release["package"]
            to_pkg = to_release["package"]

            print(f"  [Delta] Obteniendo paquete origen v{from_release['version']} ({from_pkg['url']})...")
            from_file = download_file_with_cache(from_pkg["url"], from_pkg.get("sha256"))

            print(f"  [Delta] Obteniendo paquete destino v{to_release['version']} ({to_pkg['url']})...")
            to_file = download_file_with_cache(to_pkg["url"], to_pkg.get("sha256"))

            patch_file = os.path.join(work_dir, asset_name)

            is_from_zip = zipfile.is_zipfile(from_file)
            is_to_zip = zipfile.is_zipfile(to_file)

            target_binary_sha256 = ""

            if is_from_zip and is_to_zip:
                # Descompresión para diff de directorio completo (juegos y bundles)
                print(f"  [Delta] Descomprimiendo paquetes ZIP para diferencial de directorio...")
                from_dir = os.path.join(work_dir, "unpacked_from")
                to_dir = os.path.join(work_dir, "unpacked_to")
                os.makedirs(from_dir, exist_ok=True)
                os.makedirs(to_dir, exist_ok=True)

                with zipfile.ZipFile(from_file, 'r') as zf:
                    zf.extractall(from_dir)
                with zipfile.ZipFile(to_file, 'r') as zf:
                    zf.extractall(to_dir)

                # Calcular hash del ejecutable objetivo en la versión nueva
                exe_rel = to_release.get("executable_relative_path", "")
                target_exe_path = os.path.join(to_dir, exe_rel)
                if os.path.isfile(target_exe_path):
                    target_binary_sha256 = compute_sha256(target_exe_path)
                else:
                    target_binary_sha256 = to_pkg.get("sha256", "")

                # Ejecutar hdiffz a nivel de directorio (-s-16k compresión estándar)
                print(f"  [Delta] Ejecutando hdiffz en directorios...")
                cmd = [self.hdiffz_cmd, "-s-16k", from_dir, to_dir, patch_file]
                res = subprocess.run(cmd, capture_output=True, text=True)
                if res.returncode != 0:
                    print(f"  [Error] Fallo en hdiffz: {res.stderr}", file=sys.stderr)
                    return None
            else:
                # Paquete de archivo único o binario plano
                print(f"  [Delta] Ejecutando hdiffz en archivos planos...")
                target_binary_sha256 = compute_sha256(to_file)
                cmd = [self.hdiffz_cmd, "-s-16k", from_file, to_file, patch_file]
                res = subprocess.run(cmd, capture_output=True, text=True)
                if res.returncode != 0:
                    print(f"  [Error] Fallo en hdiffz: {res.stderr}", file=sys.stderr)
                    return None

            patch_size = os.path.getsize(patch_file)
            patch_sha = compute_sha256(patch_file)
            full_to_size = to_pkg["size_bytes"]
            reduction_pct = (1.0 - (patch_size / full_to_size)) * 100.0 if full_to_size > 0 else 0.0

            print(f"  [Delta Éxito] Parche generado: {patch_size:,} bytes (reducción de {reduction_pct:.1f}% frente a {full_to_size:,} bytes).")

            # Publicar al repositorio satélite si no estamos en dry-run
            if not self.dry_run:
                self._publish_to_satellite(tag, patch_file, app_slug, from_release['version'], to_release['version'])

            return {
                "from_version": from_release["version"],
                "to_version": to_release["version"],
                "patch_format": "hdiff",
                "url": expected_url,
                "size_bytes": patch_size,
                "patch_sha256": patch_sha,
                "target_sha256": target_binary_sha256
            }

        except Exception as e:
            print(f"  [Error] Excepción generando delta: {e}", file=sys.stderr)
            return None
        finally:
            if clean_temp and os.path.isdir(work_dir):
                shutil.rmtree(work_dir, ignore_errors=True)

    def _publish_to_satellite(self, tag, patch_file, slug, from_ver, to_ver):
        """Publica el archivo diferencial en el repositorio satélite mediante GitHub CLI (gh)."""
        title = f"Delta: {slug} v{from_ver} -> v{to_ver}"
        notes = f"Parche diferencial generado automáticamente para HakkinLauncher.\nOrigen: v{from_ver}\nDestino: v{to_ver}\nTag: `{tag}`"

        # Verificar si gh CLI está disponible
        gh_check = shutil.which("gh")
        if not gh_check:
            print(f"  [Aviso] GitHub CLI (gh) no encontrado en PATH. El archivo {os.path.basename(patch_file)} debe subirse manualmente al release {tag}.", file=sys.stderr)
            return False

        try:
            # 1. Intentar subir asset a release existente
            view_cmd = ["gh", "release", "view", tag, "--repo", self.deltas_repo]
            if subprocess.run(view_cmd, capture_output=True).returncode == 0:
                upload_cmd = ["gh", "release", "upload", tag, patch_file, "--repo", self.deltas_repo, "--clobber"]
                res = subprocess.run(upload_cmd, capture_output=True, text=True)
                if res.returncode == 0:
                    print(f"  [GitHub Satélite] Asset subido a release existente: {tag}")
                    return True

            # 2. Si no existe, crear release
            create_cmd = [
                "gh", "release", "create", tag, patch_file,
                "--repo", self.deltas_repo,
                "--title", title,
                "--notes", notes
            ]
            res = subprocess.run(create_cmd, capture_output=True, text=True)
            if res.returncode == 0:
                print(f"  [GitHub Satélite] Nuevo release creado con éxito: {tag}")
                return True
            else:
                print(f"  [Aviso] No se pudo crear release satélite {tag}: {res.stderr.strip()}", file=sys.stderr)
                return False
        except Exception as e:
            print(f"  [Aviso] Error invocando gh CLI: {e}", file=sys.stderr)
            return False


def main():
    parser = argparse.ArgumentParser(description="Generador centralizado de parches diferenciales HakkinLauncher.")
    parser.add_argument("--slug", help="Slug de la aplicación (ej. tecate-simulator)")
    parser.add_argument("--from-ver", help="Versión de origen")
    parser.add_argument("--to-ver", help="Versión de destino")
    parser.add_argument("--deltas-repo", default=DEFAULT_DELTAS_REPO, help="Repositorio satélite de deltas")
    parser.add_argument("--dry-run", action="store_true", help="Simulación sin publicar a GitHub")
    parser.add_argument("--format-tag-only", action="store_true", help="Imprime el tag formateado y termina")

    args = parser.parse_args()

    if args.format_tag_only:
        if not (args.slug and args.from_ver and args.to_ver):
            print("Error: --slug, --from-ver y --to-ver son requeridos para --format-tag-only.", file=sys.stderr)
            sys.exit(1)
        tag = format_delta_tag(args.slug, args.from_ver, args.to_ver)
        print(tag)
        sys.exit(0)

    print("Ejecuta 'tools/catalog_generator.py --generate-deltas' para procesamiento por catálogo completo, o invoca la API Python.")


if __name__ == "__main__":
    main()
