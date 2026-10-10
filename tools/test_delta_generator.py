#!/usr/bin/env python3
"""
tools/test_delta_generator.py
-----------------------------
Pruebas unitarias para el generador centralizado de deltas y repositorio satélite.
"""

import os
import sys
import tempfile
import unittest
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from delta_generator import (
    format_delta_tag,
    format_delta_asset_name,
    compute_sha256,
    DeltaGenerator,
    DEFAULT_DELTAS_REPO,
    get_package_cache_dir,
    download_file_with_cache
)


class TestDeltaGenerator(unittest.TestCase):

    def test_format_delta_tag_standard(self):
        tag = format_delta_tag("tecate-simulator", "0.0.1", "26.10.08-13")
        self.assertEqual(tag, "tecate-simulator.0.0.1-to-26.10.08-13")

    def test_format_delta_tag_strips_v_prefix(self):
        tag = format_delta_tag("fractochales", "v1.60", "v1.64")
        self.assertEqual(tag, "fractochales.1.60-to-1.64")

        tag2 = format_delta_tag("firefighter-form", "V26.08.01", "v26.08.04")
        self.assertEqual(tag2, "firefighter-form.26.08.01-to-26.08.04")

    def test_format_delta_asset_name(self):
        self.assertEqual(
            format_delta_asset_name("tecate-simulator", "windows-x64"),
            "tecate-simulator_windows-x64.hdiff"
        )
        self.assertEqual(
            format_delta_asset_name("tecate-simulator", "macos-arm64"),
            "tecate-simulator_macos-arm64.hdiff"
        )

    def test_compute_sha256(self):
        with tempfile.NamedTemporaryFile(mode="w", delete=False) as f:
            f.write("HakkinLauncher Test Content")
            temp_path = f.name
        try:
            # echo -n "HakkinLauncher Test Content" | sha256sum
            # SHA-256 esperado: e.g. comprobamos longitud 64 y consistencia
            sha = compute_sha256(temp_path)
            self.assertEqual(len(sha), 64)
            self.assertTrue(all(c in "0123456789abcdef" for c in sha))
        finally:
            if os.path.exists(temp_path):
                os.remove(temp_path)

    def test_expected_download_url(self):
        tag = format_delta_tag("tecate-simulator", "0.0.1", "26.10.08-13")
        asset = format_delta_asset_name("tecate-simulator", "windows-x64")
        expected_url = f"https://github.com/{DEFAULT_DELTAS_REPO}/releases/download/{tag}/{asset}"
        self.assertEqual(
            expected_url,
            "https://github.com/HakkinDavid/hakkin-launcher-deltas/releases/download/tecate-simulator.0.0.1-to-26.10.08-13/tecate-simulator_windows-x64.hdiff"
        )

    def test_generator_initialization(self):
        gen = DeltaGenerator(deltas_repo="TestOrg/test-deltas", dry_run=True)
        self.assertEqual(gen.deltas_repo, "TestOrg/test-deltas")
        self.assertTrue(gen.dry_run)

    def test_package_cache_dir_custom_env(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            orig = os.environ.get("HAKKIN_PKG_CACHE_DIR")
            try:
                os.environ["HAKKIN_PKG_CACHE_DIR"] = tmp_dir
                cache_dir = get_package_cache_dir()
                self.assertEqual(cache_dir, os.path.abspath(tmp_dir))
                self.assertTrue(os.path.isdir(cache_dir))
            finally:
                if orig is not None:
                    os.environ["HAKKIN_PKG_CACHE_DIR"] = orig
                else:
                    os.environ.pop("HAKKIN_PKG_CACHE_DIR", None)

    def test_download_file_with_cache_hit_by_sha(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            orig = os.environ.get("HAKKIN_PKG_CACHE_DIR")
            try:
                os.environ["HAKKIN_PKG_CACHE_DIR"] = tmp_dir
                cache_dir = get_package_cache_dir()
                test_content = b"Cached Test Package Data 12345"
                import hashlib
                expected_sha = hashlib.sha256(test_content).hexdigest()
                cached_file_path = os.path.join(cache_dir, f"{expected_sha}.pkg")
                with open(cached_file_path, "wb") as f:
                    f.write(test_content)

                # Si el archivo con el SHA existe en caché, no debe realizar petición HTTP
                result_path = download_file_with_cache("http://invalid-fake-host-url.org/file.zip", expected_sha=expected_sha)
                self.assertEqual(result_path, cached_file_path)
                with open(result_path, "rb") as f:
                    self.assertEqual(f.read(), test_content)
            finally:
                if orig is not None:
                    os.environ["HAKKIN_PKG_CACHE_DIR"] = orig
                else:
                    os.environ.pop("HAKKIN_PKG_CACHE_DIR", None)

    def test_download_file_with_cache_hit_by_url_hash(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            orig = os.environ.get("HAKKIN_PKG_CACHE_DIR")
            try:
                os.environ["HAKKIN_PKG_CACHE_DIR"] = tmp_dir
                cache_dir = get_package_cache_dir()
                test_url = "http://invalid-fake-host-url.org/app_v1.zip"
                import hashlib
                url_hash = hashlib.sha256(test_url.encode()).hexdigest()[:16]
                cached_file_path = os.path.join(cache_dir, f"{url_hash}.pkg")
                with open(cached_file_path, "wb") as f:
                    f.write(b"URL Hash Cached Data")

                result_path = download_file_with_cache(test_url, expected_sha=None)
                self.assertEqual(result_path, cached_file_path)
            finally:
                if orig is not None:
                    os.environ["HAKKIN_PKG_CACHE_DIR"] = orig
                else:
                    os.environ.pop("HAKKIN_PKG_CACHE_DIR", None)


if __name__ == "__main__":
    unittest.main()
