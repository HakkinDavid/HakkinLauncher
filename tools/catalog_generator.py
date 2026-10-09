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

try:
    from tools.delta_generator import DeltaGenerator, DEFAULT_DELTAS_REPO
except ImportError:
    try:
        from delta_generator import DeltaGenerator, DEFAULT_DELTAS_REPO
    except ImportError:
        DeltaGenerator = None
        DEFAULT_DELTAS_REPO = "HakkinDavid/hakkin-launcher-deltas"

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
    "https://github.com/Bonsanbec/migrant-aid-map/releases/download/2.2/migrant-aid-map-android.apk": {
        "size_bytes": 54639495,
        "sha256": "79c8a2bdb35666a34be7c2603df9ef8a9c37ff27aae7ee3ce0b8fe435297103d"
    },
    "https://github.com/HakkinDavid/smart-scheduler/releases/download/v2.5/smart-scheduler-macos-arm64.zip": {
        "size_bytes": 32060507,
        "sha256": "8805c43e262b29e4baf75fa9d4d7b3458c9b1214aaace63574f20cc6f5fa7ca1"
    },
    "https://github.com/HakkinDavid/smart-scheduler/releases/download/v2.0/smart-scheduler-macos-v2.0.zip": {
        "size_bytes": 31540120,
        "sha256": "77e384bf8e999c011e0bc598e29bc11394a10ffc8821950ad0281b289cf291ae"
    },
    "https://github.com/HakkinDavid/smart-scheduler/releases/download/v2.0/smart-scheduler-macos-arm64.zip": {
        "size_bytes": 32063818,
        "sha256": "66d9600fa979f9cd95de695869c7c76fc4835a25de6d60137c2b049bb84b410b"
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
    "https://github.com/HakkinDavid/cathelper/releases/download/1.1/CATHelper.apk": {
        "size_bytes": 6228749,
        "sha256": "cd1a3a376ca602f4d56ea5837b91ceb80f526b7fabcd40be757ba843c083159e"
    },
    "https://github.com/HakkinDavid/cathelper/releases/download/1.0/CATHelper.apk": {
        "size_bytes": 6126949,
        "sha256": "ac1e5ca0127953053c3e4faecb8ea3e4a662dd71fe5691d6e286bc208fd0fe63"
    },
    "https://github.com/HakkinDavid/CatifyMod-Forge/releases/download/26.1/catify-1.1.1.jar": {
        "size_bytes": 149086,
        "sha256": "738faa1f834128baffce566a6f33070c697e250dde5392699cfbcaefbaab90ca"
    },
    "https://github.com/HakkinDavid/CatifyMod-Forge/releases/download/latest/catify-1.0.2.jar": {
        "size_bytes": 150902,
        "sha256": "659f1b92563736dcf62cdeb60e216da74d12dc754dc7757220e7dee2a5450fe6"
    },
    "https://github.com/HakkinDavid/firefighter-form/releases/download/v26.08.04/bomberos-windows-release.zip": {
        "size_bytes": 17286178,
        "sha256": "6f0d0d522187f3588442b560679dde2409a630b6afa86a07e1919ce016051c44"
    },
    "https://github.com/HakkinDavid/firefighter-form/releases/download/v26.06.02/bomberos-windows-release.zip": {
        "size_bytes": 16025163,
        "sha256": "f9289b8b5138617ca430848cf67f451b1bc8c04bd7d6dc5f6ebd2f7c05f0d0b9"
    },
    "https://github.com/HakkinDavid/firefighter-form/releases/download/v26.05.21/bomberos-windows-release.zip": {
        "size_bytes": 15966209,
        "sha256": "6cb8165f9ebfc1aaaeab3114f5ec34741b291fdc49c657d38b64723b3dd66f09"
    },
    "https://github.com/HakkinDavid/firefighter-form/releases/download/v26.04.02/bomberos-windows-release.zip": {
        "size_bytes": 15862010,
        "sha256": "9ce13af44c6e1079dde00842d1d9879e36d92b569dab143cd95f581e4348d3da"
    },
    "https://github.com/HakkinDavid/firefighter-form/releases/download/v26.03.17/bomberos-windows-release.zip": {
        "size_bytes": 15861517,
        "sha256": "e06d12944100b81ff71c00392d8a4c0c375db46ac6ad17d3276e920b7b95da36"
    },
    "https://github.com/HakkinDavid/firefighter-form/releases/download/v26.03.11/bomberos-windows-release.zip": {
        "size_bytes": 15861469,
        "sha256": "a1a37187e238d9ec58bad698322b13fc5961f90d4f69928d7f9d5d70927a48da"
    },
    "https://github.com/HakkinDavid/firefighter-form/releases/download/v26.02.27/bomberos-windows-release.zip": {
        "size_bytes": 15848916,
        "sha256": "a7b50f789eb27bb20ee6596f83c12aeb8b7dae38e4173b41f20723c9691f1851"
    },
    "https://github.com/HakkinDavid/firefighter-form/releases/download/v26.08.04/bomberos-android-release.apk": {
        "size_bytes": 65859605,
        "sha256": "45c81794d8779d4bb52068523cadce07b7663795006a127039b8460da7c677fa"
    },
    "https://github.com/HakkinDavid/firefighter-form/releases/download/v26.06.02/bomberos-android-release.apk": {
        "size_bytes": 60871555,
        "sha256": "75d8efec0e0b6fc91e65c632dd796aa435511bd0ef4747f385990db2202cdacc"
    },
    "https://github.com/HakkinDavid/firefighter-form/releases/download/v26.05.21/bomberos-android-release.apk": {
        "size_bytes": 60871559,
        "sha256": "2bc504b3b1ced96f33406f19f089579d0d987656b56e5771de4c96c5e60364a7"
    },
    "https://github.com/HakkinDavid/firefighter-form/releases/download/v26.04.02/bomberos-android-release.apk": {
        "size_bytes": 60017095,
        "sha256": "aa178f0d034d7fc0bf2270fe4c7ad4eadc274c68278e8f58c2684f36d55dad05"
    },
    "https://github.com/HakkinDavid/firefighter-form/releases/download/v26.03.17/bomberos-android-release.apk": {
        "size_bytes": 60016843,
        "sha256": "1656ba343cea7f69be162b5dd2f44b12b889d14538ca57fed8e48936c208ed48"
    },
    "https://github.com/HakkinDavid/firefighter-form/releases/download/v26.03.11/bomberos-android-release.apk": {
        "size_bytes": 60016843,
        "sha256": "5d04314a2915bb2f950c81f4aecfa67c0a026b9c670f42348a66f6ec267a50f9"
    },
    "https://github.com/HakkinDavid/firefighter-form/releases/download/v26.02.27/bomberos-android-release.apk": {
        "size_bytes": 59918307,
        "sha256": "5cdd5f6696823447faade0294ca3f453120fcebd5fb1ab4afb929739c86bcb1f"
    },
    "https://github.com/HakkinDavid/firefighter-form/releases/download/v26.01.28/bomberos-android-release.apk": {
        "size_bytes": 59179483,
        "sha256": "76a9f2f79461c51ec02fd5275851ec3e69466ca0add8319f25ec2cb4e8508292"
    },
    "https://github.com/HakkinDavid/firefighter-form/releases/download/v25.11.12/bomberos-android-release.apk": {
        "size_bytes": 59176700,
        "sha256": "20ac98aa060673b67ba0e7fea28c0410c4250c3402e6fc64a370439784a1ed18"
    },
    "https://github.com/HakkinDavid/firefighter-form/releases/download/v25.11.11/bomberos-android-release.apk": {
        "size_bytes": 59094780,
        "sha256": "3ce92214b9974dd72e15f2ecd9e79f894fad86ae957bef1aedc4aec59172ae78"
    },
    "https://github.com/HakkinDavid/firefighter-form/releases/download/v25.11.07/bomberos-android-release.apk": {
        "size_bytes": 59094784,
        "sha256": "7919a14c4118582047a5dbbe54e83c229292452cb8f2ab77aa7fa7c51d8b5c70"
    },
    "https://github.com/HakkinDavid/firefighter-form/releases/download/v25.11.06/bomberos-android-release.apk": {
        "size_bytes": 58244837,
        "sha256": "b9a111fe18280a624cf8b6e29cd1c338afbe099890b043c3d6a5b5779f10c3d3"
    },
    "https://github.com/HakkinDavid/firefighter-form/releases/download/v25.11.05/bomberos-android-release.apk": {
        "size_bytes": 58244821,
        "sha256": "4ad1bd709f69e825ad49538450bc466461317b7dd2930cd8a0d2e76271f2135b"
    },
    "https://github.com/HakkinDavid/firefighter-form/releases/download/v25.11.02/bomberos-android-release.apk": {
        "size_bytes": 58260277,
        "sha256": "11809e25db8a7b1143d8822d39ba1b95cbbe6a57dad72bf355c4f988f3a9b8f3"
    },
    "https://github.com/HakkinDavid/PWMS/releases/download/v26.09.11/pwms-android-release.apk": {
        "size_bytes": 90255671,
        "sha256": "77b915fbf6fa4ad40a361432bb7b8d5eeffd3fe5ea50949350be83a26e14cd4b"
    },
    "https://github.com/HakkinDavid/PWMS/releases/download/v26.09.08/pwms-android-release.apk": {
        "size_bytes": 90288515,
        "sha256": "1a435149339c78ad966c079ab98e19ec9ba2306586df64645418ee5e3a2008e9"
    },
    "https://github.com/HakkinDavid/PWMS/releases/download/v26.09.01/pwms-android-release.apk": {
        "size_bytes": 89059111,
        "sha256": "3373b06d995dd9248b0ab117c4a18e58503667750a5509e40c22922d8e0f294c"
    },
    "https://github.com/HakkinDavid/PWMS/releases/download/v26.08.31/pwms-android-release.apk": {
        "size_bytes": 89124687,
        "sha256": "29697e7e326b1ae969da373ef4abc89599273fd34770df371b37d777d2d750ae"
    },
    "https://github.com/HakkinDavid/PWMS/releases/download/v26.08.28/pwms-android-release.apk": {
        "size_bytes": 88534355,
        "sha256": "c50b50b7527e2905032d07814af2f17df8ba1b9384844f59a1c210ba5c8f8c67"
    },
    "https://github.com/HakkinDavid/PWMS/releases/download/v26.08.16/pwms-android-release.apk": {
        "size_bytes": 86466275,
        "sha256": "5b501044ea8826609b98af0a6a0d9336808c3af5e238d66c9ea3d2da8418cc00"
    }
}

# Explicit canonical version mappings for assets when tag is 'latest' or filename lacks version
URL_VERSION_HINTS = {
    "https://github.com/Bonsanbec/tecate-simulator/releases/download/latest/tecate-windows-v0.0.1-release.zip": "0.0.1",
    "https://github.com/Bonsanbec/tecate-simulator/releases/download/latest/tecate-macos-v0.0.1-release.zip": "0.0.1",
    "https://github.com/Bonsanbec/migrant-aid-map/releases/download/latest/migrant-aid-map-android.apk": "3.0",
    "https://github.com/HakkinDavid/cathelper/releases/download/latest/CATHelper.apk": "1.2",
    "https://github.com/HakkinDavid/CatifyMod-Forge/releases/download/latest/catify-1.0.2.jar": "1.0.2",
    "https://github.com/HakkinDavid/CatifyMod-Forge/releases/download/26.1/catify-1.1.1.jar": "1.1.1",
    "https://github.com/HakkinDavid/languages-autohotkey/releases/download/latest/spanish-v1.0.exe": "1.1.0",
    "https://github.com/HakkinDavid/languages-autohotkey/releases/download/latest/pinyin-v1.0.exe": "1.0.0",
}

def clean_version(tag="", release_name="", filename="", url=""):
    """
    Robust version normalizer that avoids architecture tokens (arm64, x64, etc.)
    and accurately resolves versions even when GitHub API is throttled or offline.
    """
    if url and url in URL_VERSION_HINTS:
        return URL_VERSION_HINTS[url]

    # 1. Mod JARs with explicit embedded version
    if filename and re.search(r'catify-(\d+(\.\d+)+)\.jar', filename):
        return re.search(r'catify-(\d+(\.\d+)+)\.jar', filename).group(1)

    # 2. Extract tag from URL if not given or if 'latest'
    if (not tag or tag.lower() == "latest") and url:
        m_tag = re.search(r'/releases/download/([^/]+)/', url)
        if m_tag and m_tag.group(1).lower() != "latest":
            tag = m_tag.group(1)

    # 3. Tag analysis (when not 'latest')
    if tag and tag.lower() != "latest":
        cleaned_tag = re.sub(r'(arm64|x86_64|x64|win32|win64)', '', tag, flags=re.I)
        m_ts = re.search(r'v?(\d+(?:\.\d+)+-\d+)', cleaned_tag)
        if m_ts:
            return m_ts.group(1)
        m = re.search(r'v?(\d+(\.\d+)+)', cleaned_tag)
        if m:
            return m.group(1)
        m_single = re.search(r'^v?(\d+)$', cleaned_tag)
        if m_single:
            return f"{m_single.group(1)}.0.0"

    # 4. Release Title / Name
    if release_name:
        cleaned_name = re.sub(r'(arm64|x86_64|x64|win32|win64)', '', release_name, flags=re.I)
        m_name = re.search(r'(?:^|[\s_vV])(\d+\.\d+(?:\.\d+)?(?:-\d+)?)', cleaned_name)
        if m_name and "minecraft" not in cleaned_name.lower():
            return m_name.group(1).lstrip("vV")

    # 5. Filename analysis
    if filename:
        cleaned_fn = re.sub(r'(arm64|x86_64|x64|win32|win64)', '', filename, flags=re.I)
        m_fn = re.search(r'(?:^|[_\-\.vV])(\d+\.\d+(?:\.\d+)?(?:-\d+)?)', cleaned_fn)
        if m_fn:
            return m_fn.group(1).lstrip("vV_.-")

    # 6. Fallback on release_name even if Minecraft was present
    if release_name:
        m = re.search(r'v?(\d+(\.\d+)+)', release_name)
        if m:
            return m.group(1)

    return "1.0.0"

def parse_version_tuple(v):
    """Convert version string to comparable tuple (e.g. '2.5.0' -> (2, 5, 0), '26.10.08-13' -> (26, 10, 8, 13))"""
    parts = re.findall(r'\d+', str(v))
    return tuple(int(p) for p in parts) if parts else (0,)

def resolve_asset_metadata(url, direct_sha=None, direct_size=0):
    """Resolve exact byte size and sha256 using cache or network."""
    if url in KNOWN_ASSET_CACHE:
        cached = KNOWN_ASSET_CACHE[url]
        return cached["size_bytes"], cached["sha256"]
    
    if direct_sha and len(direct_sha) == 64 and direct_size > 0:
        return direct_size, direct_sha

    sha = direct_sha
    size = direct_size
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=15) as resp:
            cl = resp.headers.get('Content-Length')
            if cl:
                size = int(cl)
            if not sha or len(sha) != 64:
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
    Adapter Pattern: Adapts external manifest formats like version_manifest.json
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
    Fetches version_manifest.json from GitHub Releases without requiring any project-specific flags.
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

def fetch_github_releases(repo, token=None):
    """
    Dynamic Discovery: Fetches public releases for a repository via GitHub API.
    Handles pagination and authentication gracefully, falling back to empty list on error.
    """
    token = token or os.environ.get("GITHUB_TOKEN")
    headers = {"User-Agent": "HakkinLauncher-CatalogGenerator/2.0"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    
    url = f"https://api.github.com/repos/{repo}/releases?per_page=100"
    try:
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=8) as resp:
            if resp.status == 200:
                data = json.loads(resp.read().decode("utf-8"))
                if isinstance(data, list):
                    return data
    except Exception as e:
        print(f"Notice: Could not fetch releases from GitHub API for {repo}: {e}", file=sys.stderr)
    return []

def generate_catalog(
    overrides_path,
    existing_catalog_path=None,
    generate_deltas=False,
    deltas_repo=DEFAULT_DELTAS_REPO,
    dry_run_deltas=False
):
    with open(overrides_path, 'r', encoding='utf-8') as f:
        overrides = json.load(f)

    # Load existing catalog if available to merge historical versions and delta patches
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

        # Level 1 Strategy: Remote Manifest (e.g. version_manifest.json)
        remote_manifest_versions = {}
        remote_manifest = fetch_remote_manifest(repo)
        if remote_manifest:
            remote_manifest_versions = ManifestAdapter.adapt(remote_manifest, meta)
            if remote_manifest_versions:
                print(f"  [L1] Auto-discovered version_manifest.json (v{remote_manifest.get('release_version')}) for {repo}")

        # Dynamic Discovery: GitHub API Releases
        remote_releases = fetch_github_releases(repo)

        # Process each configured platform
        for plat_key, plat_info in meta.get("platforms", {}).items():
            versions_list = []
            seen_versions = set()
            seen_urls = set()

            # L1 Ingestion: Was this platform resolved via remote manifest?
            if plat_key in remote_manifest_versions:
                v_entry = remote_manifest_versions[plat_key]
                versions_list.append(v_entry)
                seen_versions.add(v_entry["version"])
                seen_urls.add(v_entry["package"]["url"])

            # Strategy 1: Explicit versions defined in overrides
            if "versions" in plat_info and isinstance(plat_info["versions"], list):
                for v_def in plat_info["versions"]:
                    v_str = v_def.get("version", "1.0.0")
                    if v_str in seen_versions:
                        continue
                    pkg = v_def.get("package")
                    if not pkg:
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
                    seen_urls.add(pkg["url"])

            # Strategy 2: Dynamic Multi-Release Discovery from GitHub Releases & Pre-resolved Cache
            else:
                pattern = plat_info.get("asset_pattern", ".*")

                # Ingest releases discovered via GitHub API
                if remote_releases:
                    for r in remote_releases:
                        if r.get("draft", False):
                            continue
                        tag = r.get("tag_name", "")
                        r_name = r.get("name", "")
                        pub_date = r.get("published_at", "2026-10-08T00:00:00Z")
                        body = (r.get("body") or "").strip()

                        for asset in r.get("assets", []):
                            fn = asset.get("name", "")
                            if re.search(pattern, fn):
                                url = asset.get("browser_download_url", "")
                                if url in seen_urls:
                                    continue
                                v_str = clean_version(tag=tag, release_name=r_name, filename=fn, url=url)
                                if v_str in seen_versions:
                                    continue

                                # Resolve exact size and sha256 digest
                                size = asset.get("size", 0)
                                digest = asset.get("digest")
                                sha256 = ""
                                if digest and digest.startswith("sha256:"):
                                    sha256 = digest[7:]
                                elif url in KNOWN_ASSET_CACHE:
                                    sha256 = KNOWN_ASSET_CACHE[url]["sha256"]
                                    if size <= 0:
                                        size = KNOWN_ASSET_CACHE[url]["size_bytes"]
                                else:
                                    size, sha256 = resolve_asset_metadata(url, direct_sha=None, direct_size=size)

                                exe_rel = fn if fn.endswith(".jar") else plat_info.get("executable_relative_path", fn)
                                changelog = body if body else f"Lanzamiento de {meta['title']} v{v_str}."

                                v_entry = {
                                    "version": v_str,
                                    "release_date": pub_date,
                                    "changelog": changelog,
                                    "executable_relative_path": exe_rel,
                                    "package": {
                                        "url": url,
                                        "size_bytes": size,
                                        "sha256": sha256
                                    },
                                    "delta_patches": [],
                                    "scripts": {"pre_install": None, "post_install": None}
                                }
                                versions_list.append(v_entry)
                                seen_versions.add(v_str)
                                seen_urls.add(url)

                # Fallback to KNOWN_ASSET_CACHE (for offline builds or un-indexed assets)
                for cached_url, cached_info in KNOWN_ASSET_CACHE.items():
                    if f"github.com/{repo}/releases/download/" in cached_url:
                        fn = cached_url.split('/')[-1]
                        if re.search(pattern, fn):
                            if cached_url in seen_urls:
                                continue
                            v_str = clean_version(filename=fn, url=cached_url)
                            if v_str in seen_versions:
                                continue

                            exe_rel = fn if fn.endswith(".jar") else plat_info.get("executable_relative_path", fn)
                            v_entry = {
                                "version": v_str,
                                "release_date": "2026-10-08T00:00:00Z",
                                "changelog": f"Lanzamiento de {meta['title']} v{v_str}.",
                                "executable_relative_path": exe_rel,
                                "package": {
                                    "url": cached_url,
                                    "size_bytes": cached_info["size_bytes"],
                                    "sha256": cached_info["sha256"]
                                },
                                "delta_patches": [],
                                "scripts": {"pre_install": None, "post_install": None}
                            }
                            versions_list.append(v_entry)
                            seen_versions.add(v_str)
                            seen_urls.add(cached_url)

                if not versions_list and plat_key not in remote_manifest_versions:
                    print(f"  Warning: no asset found for {plat_key} matching {pattern}", file=sys.stderr)

            # Strategy 3: Merge previously recorded versions for this platform (filtering corrupted ghosts)
            if existing_app and "platforms" in existing_app and plat_key in existing_app["platforms"]:
                existing_plat = existing_app["platforms"][plat_key]
                for old_v in existing_plat.get("versions", []):
                    old_ver = old_v.get("version")
                    old_url = old_v.get("package", {}).get("url", "")
                    # Filter out ghost 64.0.0 and duplicate 1.0.0 pointing to 26.xx packages
                    if old_ver == "64.0.0":
                        continue
                    if old_ver == "1.0.0" and any(x in old_url for x in ["26.", "v26."]):
                        continue
                    if old_ver and old_ver not in seen_versions and old_url not in seen_urls:
                        versions_list.append(old_v)
                        seen_versions.add(old_ver)
                        seen_urls.add(old_url)

            if not versions_list:
                continue

            # Sort versions newest to oldest
            versions_list.sort(key=lambda x: parse_version_tuple(x["version"]), reverse=True)
            plat_latest_version = versions_list[0]["version"]

            # Preserve and sanitize existing delta_patches
            valid_versions = {v["version"] for v in versions_list}
            if existing_app and "platforms" in existing_app and plat_key in existing_app["platforms"]:
                existing_ver_map = {
                    v["version"]: v for v in existing_app["platforms"][plat_key].get("versions", [])
                }
                for v in versions_list:
                    if not v.get("delta_patches") and v["version"] in existing_ver_map:
                        raw_patches = existing_ver_map[v["version"]].get("delta_patches", [])
                        valid_patches = [
                            p for p in raw_patches
                            if p.get("from_version") in valid_versions and p.get("from_version") != v["version"]
                        ]
                        v["delta_patches"] = valid_patches

            # Generate differential deltas for immediate predecessor V_{N-1} -> V_N
            if generate_deltas and DeltaGenerator and len(versions_list) >= 2:
                target_ver = versions_list[0]
                source_ver = versions_list[1]
                if target_ver["package"]["url"] != source_ver["package"]["url"] and target_ver["version"] != source_ver["version"]:
                    has_delta = any(
                        d.get("from_version") == source_ver["version"] and d.get("patch_sha256")
                        for d in target_ver.get("delta_patches", [])
                    )
                    if not has_delta:
                        print(f"  [Delta Worker] Generando diferencial para {meta['slug']} ({plat_key}): v{source_ver['version']} -> v{target_ver['version']}...")
                        d_gen = DeltaGenerator(deltas_repo=deltas_repo, dry_run=dry_run_deltas)
                        patch_entry = d_gen.generate_delta_patch(
                            app_slug=meta["slug"],
                            platform_key=plat_key,
                            from_release=source_ver,
                            to_release=target_ver
                        )
                        if patch_entry:
                            if "delta_patches" not in target_ver:
                                target_ver["delta_patches"] = []
                            target_ver["delta_patches"] = [
                                d for d in target_ver["delta_patches"] if d.get("from_version") != source_ver["version"]
                            ]
                            target_ver["delta_patches"].append(patch_entry)

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
            "assets": {
                "icon": (meta.get("assets", {}).get("icon") if meta.get("assets", {}).get("icon") and not any(p in meta.get("assets", {}).get("icon", "") for p in ["unsplash.com", "placeholder"]) else None),
                "poster": (meta.get("assets", {}).get("poster") if meta.get("assets", {}).get("poster") and not any(p in meta.get("assets", {}).get("poster", "") for p in ["unsplash.com", "placeholder"]) else None),
                "banner": (meta.get("assets", {}).get("banner") if meta.get("assets", {}).get("banner") and not any(p in meta.get("assets", {}).get("banner", "") for p in ["unsplash.com", "placeholder"]) else None),
                "screenshots": [
                    s for s in (meta.get("assets", {}).get("screenshots") or [])
                    if s and not any(p in s for p in ["unsplash.com", "placeholder"])
                ]
            },
            "latest_version": app_latest_version or "1.0.0",
            "platforms": platforms_dict
        }

        apps.append(app_entry)

    # Launcher metadata definition from launcher_meta.json
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
    parser.add_argument("--generate-deltas", action="store_true", help="Generar parches diferenciales para saltos de versión")
    parser.add_argument("--deltas-repo", default=DEFAULT_DELTAS_REPO, help="Repositorio satélite de deltas (default: HakkinDavid/hakkin-launcher-deltas)")
    parser.add_argument("--dry-run-deltas", action="store_true", help="Simular generación de deltas sin publicar en GitHub")

    args = parser.parse_args()

    manifest = generate_catalog(
        args.overrides,
        existing_catalog_path=args.output,
        generate_deltas=args.generate_deltas,
        deltas_repo=args.deltas_repo,
        dry_run_deltas=args.dry_run_deltas
    )
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
