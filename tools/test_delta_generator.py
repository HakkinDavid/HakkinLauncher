#!/usr/bin/env python3
"""
tools/test_delta_generator.py
-----------------------------
Pruebas unitarias para el generador centralizado de deltas y repositorio satélite.
"""

import os
import tempfile
import unittest
import zipfile

from delta_generator import (
    format_delta_tag,
    format_delta_asset_name,
    compute_sha256,
    DeltaGenerator,
    DEFAULT_DELTAS_REPO
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


if __name__ == "__main__":
    unittest.main()
