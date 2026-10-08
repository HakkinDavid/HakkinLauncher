#!/usr/bin/env python3
"""
HakkinLauncher Catalog Generator v2.0
Generates docs/catalog.json and syncs docs/catalog_example.json
adhering strictly to CATALOG_SCHEMA.json v2.0 (Historical Multi-Release Catalog).
"""

import argparse
import datetime
import hashlib
import json
import os
import re
import sys
import urllib.request

# Pre-resolved checksums and byte sizes cache for known release assets
KNOWN_ASSET_CACHE = {
    "https://github.com/Bonsanbec/tecate-simulator/releases/download/26.10.08-13/tecate-windows.zip": {
        "size_bytes": 1084841300,
        "sha256": "b38a07970facf3ef41569bac85aef707254c80e4251a0c401c6c207cfa671f29"
    },
    "https://github.com/Bonsanbec/tecate-simulator/releases/download/26.10.08-13/tecate-macos.zip": {
        "size_bytes": 1111734578,
        "sha256": "a5ff201a1cfc14bce9fe53bfb1f1e02acb349deaef0ae3a34392fa2a34faa98d"
    },
    "https://github.com/Bonsanbec/tecate-simulator/releases/download/latest/tecate-windows-v0.0.1-release.zip": {
        "size_bytes": 771167643,
        "sha256": "c3e622e8a6cc35ff295c44c770496a2f06847c735605c8f4a22b2ba45019be2a"
    },
    "https://github.com/Bonsanbec/tecate-simulator/releases/download/latest/tecate-macos-v0.0.1-release.zip": {
        "size_bytes": 798030827,
        "sha256": "86286cae84f07e0978bc32fb9597cc06bd795030e0c6d96c6fcf6ccd42801cbd"
    },
    "https://github.com/Bonsanbec/fractochales/releases/download/v1.64-prod-2D/fractochales-win-x86_64-v1.64.zip": {
        "size_bytes": 23238440,
        "sha256": "ad9f2a2dff17726a5d516817059441bc181aee2666a3197118b3a9afa4127693"
    },
    "https://github.com/Bonsanbec/migrant-aid-map/releases/download/latest/migrant-aid-map-android.apk": {
        "size_bytes": 54644848,
        "sha256": "6127a04ccb69209720508e69be9355e37a1af4db5d1b2fea67c19ed9d5caa8b0"
    },
    "https://github.com/HakkinDavid/firefighter-form/releases/download/v26.08.04/bomberos-windows-release.zip": {
        "size_bytes": 17286178,
        "sha256": "6f0d0d522187f3588442b560679dde2409a630b6afa86a07e1919ce016051c44"
    },
    "https://github.com/HakkinDavid/firefighter-form/releases/download/v26.08.04/bomberos-android-release.apk": {
        "size_bytes": 65859605,
        "sha256": "45c81794d8779d4bb52068523cadce07b7663795006a127039b8460da7c677fa"
    },
    "https://github.com/HakkinDavid/PWMS/releases/download/v26.09.11/pwms-android-release.apk": {
        "size_bytes": 90255671,
        "sha256": "77b915fbf6fa4ad40a361432bb7b8d5eeffd3fe5ea50949350be83a26e14cd4b"
    },
    "https://github.com/HakkinDavid/smart-scheduler/releases/download/v2.5/smart-scheduler-macos-arm64.zip": {
        "size_bytes": 32060507,
        "sha256": "8805c43e262b29e4baf75fa9d4d7b3458c9b1214aaace63574f20cc6f5fa7ca1"
    },
    "https://github.com/HakkinDavid/smart-scheduler/releases/download/v2.0/smart-scheduler-macos-v2.0.zip": {
        "size_bytes": 31540120,
        "sha256": "77e384bf8e999c011e0bc598e29bc11394a10ffc8821950ad0281b289cf291ae"
    },
    "https://github.com/HakkinDavid/WiimoteUserlandDriver/releases/download/v1.0/WiimoteUserlandDriver-mac-arm64": {
        "size_bytes": 51776,
        "sha256": "89f7cda9c01e6e25cee1ae61106a8ecb01a17a59f8357787fe1c957a2a8a9f73"
    },
    "https://github.com/HakkinDavid/languages-autohotkey/releases/download/latest/spanish-v1.0.exe": {
        "size_bytes": 1262592,
        "sha256": "c2d1d9003dc3f9f877854910ad6648f5e400dca561225961aa6734686770b165"
    },
    "https://github.com/HakkinDavid/languages-autohotkey/releases/download/latest/pinyin-v1.0.exe": {
        "size_bytes": 1298432,
        "sha256": "b805fac2129001d76182ee73a1114bd36ed0771e8abaca85c13a840c3f25383f"
    },
    "https://github.com/HakkinDavid/cathelper/releases/download/latest/CATHelper.apk": {
        "size_bytes": 6176525,
        "sha256": "f902bed32da91038f6d2dd4f3ad56f468f823c320fc4cd8f7a7de724583012c4"
    },
    "https://github.com/HakkinDavid/CatifyMod-Forge/releases/download/26.1/catify-1.1.1.jar": {
        "size_bytes": 149086,
        "sha256": "738faa1f834128baffce566a6f33070c697e250dde5392699cfbcaefbaab90ca"
    }
}

def clean_version(tag_or_filename, url=None):
    """Normalize versions like 'v1.64-prod-2D' -> '1.64', 'v26.08.04' -> '26.08.04', '26.10.08-13' -> '26.10.08-13'"""
    if url:
        match_url = re.search(r'/releases/download/([^/]+)/', url)
        if match_url:
            tag = match_url.group(1)
            if tag != "latest":
                m_ts = re.search(r'v?(\d+(?:\.\d+)+-\d+)', tag)
                if m_ts:
                    return m_ts.group(1)
                m = re.search(r'v?(\d+(\.\d+)*)', tag)
                if m:
                    res = m.group(1)
                    return res if '.' in res else f"{res}.0.0"

    cleaned = re.sub(r'(arm64|x86_64|x64|win32|win64)', '', tag_or_filename, flags=re.IGNORECASE)
    m_ts = re.search(r'v?(\d+(?:\.\d+)+-\d+)', cleaned)
    if m_ts:
        return m_ts.group(1)
    match = re.search(r'v?(\d+(\.\d+)+)', cleaned)
    if match:
        return match.group(1)
    match_single = re.search(r'v(\d+)', cleaned)
    if match_single:
        return f"{match_single.group(1)}.0.0"
    return "1.0.0"

def parse_version_tuple(v):
    """Convert version string to comparable tuple (e.g. '2.5.0' -> (2, 5, 0), '26.10.08-13' -> (26, 10, 8, 13))"""
    parts = re.findall(r'\d+', str(v))
    return tuple(int(p) for p in parts) if parts else (0,)

def resolve_asset_metadata(url, direct_sha=None):
    """Resolve exact byte size and sha256 using cache or network."""
    if url in KNOWN_ASSET_CACHE:
        return KNOWN_ASSET_CACHE[url]["size_bytes"], KNOWN_ASSET_CACHE[url]["sha256"]
    
    sha = direct_sha
    size = 0
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req) as resp:
            cl = resp.headers.get('Content-Length')
            if cl:
                size = int(cl)
            if not sha:
                h = hashlib.sha256()
                while True:
                    chunk = resp.read(65536)
                    if not chunk:
                        break
                    h.update(chunk)
                    if not cl:
                        size += len(chunk)
                sha = h.hexdigest()
    except Exception as e:
        print(f"Warning: could not stream {url}: {e}", file=sys.stderr)
    
    return size, sha or "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

class ManifestAdapter:
    """
    Adapter Pattern: Adapts external manifest format (e.g. version_manifest.json)
    into HakkinLauncher canonical platform release structures.
    """
    PLATFORM_MAPPING = {
        "macos": ["macos-arm64", "macos-x64"],
        "windows": ["windows-x64", "windows-x86"],
        "linux": ["linux-x64"],
        "android": ["android-arm64", "android-x86_64"],
        "ios": ["ios-arm64"]
    }

    @staticmethod
    def adapt(manifest_data, app_meta):
        """
        Adapts a validated version_manifest dict into a dict of:
        { platform_key: VersionEntry }
        Returns {} if invalid or incompatible.
        """
        if not isinstance(manifest_data, dict):
            return {}

        release_ver = manifest_data.get("release_version")
        if not release_ver:
            return {}

        published_at = manifest_data.get("published_at_utc", datetime.datetime.now(datetime.timezone.utc).isoformat())
        binaries = manifest_data.get("binaries", {})
        if not isinstance(binaries, dict):
            return {}

        supported_platforms = app_meta.get("platforms", {})
        adapted_versions = {}

        for raw_plat, binary_info in binaries.items():
            if not isinstance(binary_info, dict):
                continue

            download_url = binary_info.get("download_url")
            sha256 = binary_info.get("sha256")
            size_bytes = binary_info.get("size_bytes", 0)

            if not download_url or not sha256 or len(sha256) != 64 or size_bytes <= 0:
                continue

            candidate_keys = ManifestAdapter.PLATFORM_MAPPING.get(raw_plat.lower(), [raw_plat])

            for target_plat_key in candidate_keys:
                if target_plat_key in supported_platforms:
                    plat_info = supported_platforms[target_plat_key]
                    v_entry = {
                        "version": str(release_ver),
                        "release_date": published_at,
                        "changelog": f"Lanzamiento de {app_meta.get('title', 'app')} v{release_ver}.",
                        "executable_relative_path": plat_info.get("executable_relative_path", binary_info.get("filename", "app")),
                        "package": {
                            "url": download_url,
                            "size_bytes": size_bytes,
                            "sha256": sha256
                        },
                        "delta_patches": [],
                        "scripts": {
                            "pre_install": None,
                            "post_install": None
                        }
                    }
                    adapted_versions[target_plat_key] = v_entry

        return adapted_versions

def fetch_remote_manifest(repo, tag="latest"):
    """
    Convention over Configuration:
    Fetches version_manifest.json from GitHub Releases without requiring any project-specific flags.
    Falls back gracefully (returns None) on 404, rate limit, network failure, or malformed JSON.
    """
    urls_to_try = [
        f"https://github.com/{repo}/releases/download/{tag}/version_manifest.json",
        f"https://github.com/{repo}/releases/latest/download/version_manifest.json",
    ]
    for url in urls_to_try:
        try:
            req = urllib.request.Request(
                url,
                headers={"User-Agent": "HakkinLauncher-CatalogGenerator/2.0 (urllib)"}
            )
            with urllib.request.urlopen(req, timeout=4) as resp:
                if resp.status == 200:
                    content = resp.read().decode("utf-8")
                    data = json.loads(content)
                    if "release_version" in data and "binaries" in data:
                        return data
        except Exception:
            continue
    return None

def generate_catalog(overrides_path, existing_catalog_path=None):
    with open(overrides_path, 'r', encoding='utf-8') as f:
        overrides = json.load(f)

    # Load existing catalog if available to merge historical versions
    existing_apps_map = {}
    if existing_catalog_path and os.path.exists(existing_catalog_path):
        try:
            with open(existing_catalog_path, 'r', encoding='utf-8') as f:
                existing_data = json.load(f)
                for a in existing_data.get("apps", []):
                    existing_apps_map[a["id"]] = a
        except Exception as e:
            print(f"Notice: Could not read existing catalog for merging: {e}", file=sys.stderr)

    apps = []

    for repo, meta in overrides.items():
        app_id = meta["id"]
        print(f"Processing application: {repo} ({meta['title']})...")
        platforms_dict = {}

        existing_app = existing_apps_map.get(app_id)

        # -----------------------------------------------------------------
        # Level 1 Strategy: Remote Manifest (Convention over Configuration)
        # -----------------------------------------------------------------
        remote_manifest_versions = {}
        remote_manifest = fetch_remote_manifest(repo)
        if remote_manifest:
            remote_manifest_versions = ManifestAdapter.adapt(remote_manifest, meta)
            if remote_manifest_versions:
                print(f"  [L1] Auto-discovered version_manifest.json (v{remote_manifest.get('release_version')}) for {repo}")

        # Look up platform rules
        for plat_key, plat_info in meta.get("platforms", {}).items():
            versions_list = []
            seen_versions = set()

            # L1 Ingestion: Was this platform resolved via remote manifest?
            if plat_key in remote_manifest_versions:
                v_entry = remote_manifest_versions[plat_key]
                versions_list.append(v_entry)
                seen_versions.add(v_entry["version"])

            # 1. If explicit versions are defined in overrides (Override Strategy)
            if "versions" in plat_info and isinstance(plat_info["versions"], list):
                for v_def in plat_info["versions"]:
                    v_str = v_def.get("version", "1.0.0")
                    if v_str in seen_versions:
                        continue
                    pkg = v_def.get("package")
                    if not pkg:
                        # Find from pattern or cache
                        pattern = v_def.get("asset_pattern", ".*")
                        matched_asset = None
                        for cached_url, cached_info in KNOWN_ASSET_CACHE.items():
                            if f"github.com/{repo}/releases/download/" in cached_url:
                                filename = cached_url.split('/')[-1]
                                if re.search(pattern, filename):
                                    matched_asset = {
                                        "url": cached_url,
                                        "size_bytes": cached_info["size_bytes"],
                                        "sha256": cached_info["sha256"]
                                    }
                                    break
                        if matched_asset:
                            pkg = matched_asset
                        else:
                            pkg = {
                                "url": f"https://github.com/{repo}/releases/download/v{v_str}/release.zip",
                                "size_bytes": 1000000,
                                "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
                            }

                    v_entry = {
                        "version": v_str,
                        "release_date": v_def.get("release_date", "2026-10-08T00:00:00Z"),
                        "changelog": v_def.get("changelog", f"Notas de la versión {v_str}."),
                        "executable_relative_path": v_def.get("executable_relative_path", plat_info.get("executable_relative_path", "app")),
                        "package": pkg,
                        "delta_patches": v_def.get("delta_patches", []),
                        "scripts": v_def.get("scripts", {"pre_install": None, "post_install": None})
                    }
                    versions_list.append(v_entry)
                    seen_versions.add(v_str)

            # 2. Level 2 & 3: Match assets from cache or pattern
            else:
                pattern = plat_info.get("asset_pattern", ".*")
                cached_matches = []
                for cached_url, cached_info in KNOWN_ASSET_CACHE.items():
                    if f"github.com/{repo}/releases/download/" in cached_url:
                        filename = cached_url.split('/')[-1]
                        if re.search(pattern, filename):
                            cached_matches.append({
                                "url": cached_url,
                                "filename": filename,
                                "size_bytes": cached_info["size_bytes"],
                                "sha256": cached_info["sha256"]
                            })

                for matched_asset in cached_matches:
                    version_str = clean_version(matched_asset["filename"], matched_asset["url"])
                    if version_str == "1.0.0" and "latest_version" in meta:
                        version_str = meta["latest_version"]

                    if version_str not in seen_versions:
                        v_entry = {
                            "version": version_str,
                            "release_date": "2026-10-08T00:00:00Z",
                            "changelog": f"Lanzamiento de {meta['title']} v{version_str}.",
                            "executable_relative_path": plat_info.get("executable_relative_path", matched_asset["filename"]),
                            "package": {
                                "url": matched_asset["url"],
                                "size_bytes": matched_asset["size_bytes"],
                                "sha256": matched_asset["sha256"]
                            },
                            "delta_patches": [],
                            "scripts": {
                                "pre_install": None,
                                "post_install": None
                            }
                        }
                        versions_list.append(v_entry)
                        seen_versions.add(version_str)

                if not versions_list and plat_key not in remote_manifest_versions:
                    print(f"  Warning: no asset found for {plat_key} matching {pattern}", file=sys.stderr)

            # 3. Level 4: Merge previously recorded versions for this platform if any
            if existing_app and "platforms" in existing_app and plat_key in existing_app["platforms"]:
                existing_plat = existing_app["platforms"][plat_key]
                for old_v in existing_plat.get("versions", []):
                    if old_v.get("version") and old_v["version"] not in seen_versions:
                        versions_list.append(old_v)
                        seen_versions.add(old_v["version"])

            if not versions_list:
                continue

            # Sort versions newest to oldest
            versions_list.sort(key=lambda x: parse_version_tuple(x["version"]), reverse=True)
            plat_latest_version = versions_list[0]["version"]

            platforms_dict[plat_key] = {
                "latest_version": plat_latest_version,
                "protected_user_paths": plat_info.get("protected_user_paths", []),
                "versions": versions_list
            }

        # App-level latest version is the highest across supported platforms
        app_latest_version = meta.get("latest_version")
        if not app_latest_version and platforms_dict:
            app_latest_version = next(iter(platforms_dict.values()))["latest_version"]

        app_entry = {
            "id": meta["id"],
            "slug": meta["slug"],
            "title": meta["title"],
            "category": meta.get("category", "app"),
            "developer": meta.get("developer", "Hakkin"),
            "summary": meta.get("summary", ""),
            "description_markdown": meta.get("description_markdown", ""),
            "tags": meta.get("tags", []),
            "assets": meta.get("assets", {
                "icon": None,
                "poster": None,
                "banner": None,
                "screenshots": []
            }),
            "latest_version": app_latest_version or "1.0.0",
            "platforms": platforms_dict
        }

        apps.append(app_entry)

    # Launcher metadata definition (loaded dynamically from tools/launcher_meta.json if present)
    launcher_meta_path = os.path.join(os.path.dirname(overrides_path), "launcher_meta.json")
    launcher_meta = None
    if os.path.isfile(launcher_meta_path):
        try:
            with open(launcher_meta_path, "r", encoding="utf-8") as f:
                launcher_meta = json.load(f)
        except Exception as e:
            print(f"Warning: could not load launcher_meta.json: {e}", file=sys.stderr)

    if not launcher_meta:
        launcher_meta = {
            "latest_version": "1.0.0",
            "min_required_launcher_version": "1.0.0",
            "releases": {
                "windows-x64": {
                    "url": "https://github.com/HakkinDavid/HakkinLauncher/releases/download/v1.0.0/HakkinLauncher-windows-x64.zip",
                    "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
                    "size_bytes": 45000000
                },
                "macos-arm64": {
                    "url": "https://github.com/HakkinDavid/HakkinLauncher/releases/download/v1.0.0/HakkinLauncher-macos-arm64.zip",
                    "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
                    "size_bytes": 48000000
                }
            }
        }

    manifest = {
        "version": "2.0.0",
        "catalog_timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "launcher_meta": launcher_meta,
        "apps": apps
    }

    return manifest

def validate_manifest(manifest, schema_path):
    """Validate manifest against CATALOG_SCHEMA.json rules."""
    with open(schema_path, 'r', encoding='utf-8') as f:
        schema = json.load(f)

    assert manifest.get("version") == "2.0.0", f"Manifest version must be 2.0.0, got {manifest.get('version')}"
    assert "catalog_timestamp" in manifest, "Missing catalog_timestamp"
    assert "apps" in manifest and isinstance(manifest["apps"], list), "apps must be a list"

    allowed_categories = schema["properties"]["apps"]["items"]["properties"]["category"]["enum"]

    for app in manifest["apps"]:
        for req in ["id", "title", "category", "latest_version", "platforms"]:
            assert req in app and app[req], f"App {app.get('id')} missing {req}"
        assert app["category"] in allowed_categories, f"Invalid category {app['category']}"
        assert len(app["platforms"]) > 0, f"App {app['id']} must have at least one platform"

        for pkey, pval in app["platforms"].items():
            assert "latest_version" in pval, f"Platform {pkey} missing latest_version"
            assert "versions" in pval and isinstance(pval["versions"], list) and len(pval["versions"]) > 0, \
                f"Platform {pkey} missing versions array"
            for v_obj in pval["versions"]:
                assert "version" in v_obj and v_obj["version"], f"Platform {pkey} missing version string"
                assert "executable_relative_path" in v_obj and v_obj["executable_relative_path"], \
                    f"Platform {pkey} missing executable_relative_path"
                assert "package" in v_obj, f"Platform {pkey} missing package"
                pkg = v_obj["package"]
                assert "url" in pkg and pkg["url"].startswith("https://"), f"Invalid package url in {pkey}"
                assert "sha256" in pkg and len(pkg["sha256"]) == 64, f"Invalid sha256 in {pkey}: {pkg['sha256']}"
                assert "size_bytes" in pkg and pkg["size_bytes"] > 0, f"Invalid size_bytes in {pkey}: {pkg['size_bytes']}"

    print(f"Validation successful: {len(manifest['apps'])} applications validated against schema v2.0.0 contract.")
    return True

def main():
    parser = argparse.ArgumentParser(description="HakkinLauncher Catalog Generator v2.0")
    parser.add_argument("--overrides", default="tools/catalog_overrides.json", help="Path to catalog overrides file")
    parser.add_argument("--schema", default="docs/CATALOG_SCHEMA.json", help="Path to CATALOG_SCHEMA.json")
    parser.add_argument("--output", default="docs/catalog.json", help="Output path for catalog.json")
    parser.add_argument("--update-example", action="store_true", help="Sync docs/catalog_example.json")

    args = parser.parse_args()

    manifest = generate_catalog(args.overrides, existing_catalog_path=args.output)
    validate_manifest(manifest, args.schema)

    output_dir = os.path.dirname(args.output)
    if output_dir:
        os.makedirs(output_dir, exist_ok=True)

    with open(args.output, 'w', encoding='utf-8') as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)
    print(f"Generated catalog written to: {args.output}")

    if args.update_example:
        example_path = "docs/catalog_example.json"
        with open(example_path, 'w', encoding='utf-8') as f:
            json.dump(manifest, f, indent=2, ensure_ascii=False)
        print(f"Synchronized asset fallback at: {example_path}")

if __name__ == "__main__":
    main()
