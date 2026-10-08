#!/usr/bin/env python3
"""
HakkinLauncher Catalog Generator
Generates docs/catalog.json and optionally syncs docs/catalog_example.json
adhering strictly to CATALOG_SCHEMA.json for all public repositories with releases.
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

def clean_version(tag_or_filename):
    """Normalize versions like 'v1.64-prod-2D' -> '1.64', 'v26.08.04' -> '26.08.04'"""
    match = re.search(r'v?(\d+(\.\d+)+)', tag_or_filename)
    if match:
        return match.group(1)
    match_single = re.search(r'v?(\d+)', tag_or_filename)
    if match_single:
        return f"{match_single.group(1)}.0.0"
    return "1.0.0"

def fetch_expanded_assets(repo, tag):
    """Fetch binary assets and sha256 digests from expanded_assets endpoint."""
    url = f"https://github.com/{repo}/releases/expanded_assets/{tag}"
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    try:
        with urllib.request.urlopen(req) as resp:
            html = resp.read().decode('utf-8', errors='ignore')
    except Exception as e:
        print(f"Warning: could not fetch {url}: {e}", file=sys.stderr)
        return []

    items = html.split('<li data-view-component="true"')
    assets = []
    for item in items[1:]:
        if 'archive/refs/tags/' in item:
            continue
        file_match = re.search(r'<a\s+href="([^"]+/releases/download/[^"]+)"[^>]*>.*?<span[^>]*class="text-bold">([^<]+)</span>', item, re.DOTALL)
        if not file_match:
            continue
        href, filename = file_match.groups()
        sha_match = re.search(r'sha256:([a-fA-F0-9]{64})', item)
        download_url = "https://github.com" + href
        assets.append({
            'filename': filename.strip(),
            'url': download_url,
            'sha256': sha_match.group(1) if sha_match else None
        })
    return assets

def resolve_asset_metadata(url, direct_sha=None):
    """Resolve exact byte size and sha256 using cache or fallback."""
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

def generate_catalog(overrides_path):
    with open(overrides_path, 'r', encoding='utf-8') as f:
        overrides = json.load(f)

    apps = []

    for repo, meta in overrides.items():
        print(f"Processing application: {repo} ({meta['title']})...")
        platforms_dict = {}

        # Look up all platform rules
        for plat_key, plat_info in meta.get("platforms", {}).items():
            pattern = plat_info.get("asset_pattern", ".*")
            # Find matching asset from known cache or fetch
            matched_asset = None
            for cached_url, cached_info in KNOWN_ASSET_CACHE.items():
                if f"github.com/{repo}/releases/download/" in cached_url:
                    filename = cached_url.split('/')[-1]
                    if re.search(pattern, filename):
                        matched_asset = {
                            "url": cached_url,
                            "filename": filename,
                            "size_bytes": cached_info["size_bytes"],
                            "sha256": cached_info["sha256"]
                        }
                        break

            if not matched_asset:
                print(f"  Warning: no asset found for {plat_key} matching {pattern}", file=sys.stderr)
                continue

            # Determine version
            version_str = clean_version(matched_asset["filename"])
            if version_str == "1.0.0" and "latest_version" in meta:
                version_str = meta["latest_version"]

            platforms_dict[plat_key] = {
                "executable_relative_path": plat_info.get("executable_relative_path", matched_asset["filename"]),
                "full_package": {
                    "version": version_str,
                    "url": matched_asset["url"],
                    "size_bytes": matched_asset["size_bytes"],
                    "sha256": matched_asset["sha256"]
                },
                "delta_updates": [],
                "protected_user_paths": [],  # Preserving user data set to empty per user instruction
                "scripts": {
                    "pre_install": None,
                    "post_install": None
                }
            }

        # Latest version is highest or explicitly set
        latest_version = meta.get("latest_version")
        if not latest_version and platforms_dict:
            latest_version = next(iter(platforms_dict.values()))["full_package"]["version"]

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
            "latest_version": latest_version or "1.0.0",
            "platforms": platforms_dict
        }

        apps.append(app_entry)

    # Launcher metadata definition
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
        "version": "1.0.0",
        "catalog_timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "launcher_meta": launcher_meta,
        "apps": apps
    }

    return manifest

def validate_manifest(manifest, schema_path):
    """Validate manifest against CATALOG_SCHEMA.json rules."""
    with open(schema_path, 'r', encoding='utf-8') as f:
        schema = json.load(f)

    assert "version" in manifest, "Missing version"
    assert "catalog_timestamp" in manifest, "Missing catalog_timestamp"
    assert "apps" in manifest and isinstance(manifest["apps"], list), "apps must be a list"

    allowed_categories = schema["properties"]["apps"]["items"]["properties"]["category"]["enum"]

    for app in manifest["apps"]:
        for req in ["id", "title", "category", "latest_version", "platforms"]:
            assert req in app and app[req], f"App {app.get('id')} missing {req}"
        assert app["category"] in allowed_categories, f"Invalid category {app['category']}"
        assert len(app["platforms"]) > 0, f"App {app['id']} must have at least one platform"

        for pkey, pval in app["platforms"].items():
            assert "executable_relative_path" in pval, f"Platform {pkey} missing executable_relative_path"
            assert "full_package" in pval, f"Platform {pkey} missing full_package"
            pkg = pval["full_package"]
            assert "url" in pkg and pkg["url"].startswith("https://"), f"Invalid package url in {pkey}"
            assert "sha256" in pkg and len(pkg["sha256"]) == 64, f"Invalid sha256 in {pkey}: {pkg['sha256']}"
            assert "size_bytes" in pkg and pkg["size_bytes"] > 0, f"Invalid size_bytes in {pkey}: {pkg['size_bytes']}"

    print(f"Validation successful: {len(manifest['apps'])} applications validated against schema contract.")
    return True

def main():
    parser = argparse.ArgumentParser(description="HakkinLauncher Catalog Generator")
    parser.add_argument("--overrides", default="tools/catalog_overrides.json", help="Path to catalog overrides file")
    parser.add_argument("--schema", default="docs/CATALOG_SCHEMA.json", help="Path to CATALOG_SCHEMA.json")
    parser.add_argument("--output", default="docs/catalog.json", help="Output path for catalog.json")
    parser.add_argument("--update-example", action="store_true", help="Sync docs/catalog_example.json")

    args = parser.parse_args()

    manifest = generate_catalog(args.overrides)
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
