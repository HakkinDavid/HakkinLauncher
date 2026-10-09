#!/usr/bin/env python3
"""
tools/test_catalog_generator.py
--------------------------------
Pruebas unitarias para el generador de catálogo, normalización de versiones y validación de contrato.
"""

import json
import os
import unittest

from catalog_generator import (
    clean_version,
    parse_version_tuple,
    validate_manifest,
    generate_catalog,
    KNOWN_ASSET_CACHE
)


class TestCatalogGenerator(unittest.TestCase):

    def test_clean_version_standard_tags(self):
        self.assertEqual(clean_version("v26.08.04"), "26.08.04")
        self.assertEqual(clean_version("v26.06.02"), "26.06.02")
        self.assertEqual(clean_version("26.10.08-13"), "26.10.08-13")
        self.assertEqual(clean_version("v1.64-prod-2D"), "1.64")
        self.assertEqual(clean_version("v2.5"), "2.5")
        self.assertEqual(clean_version("1.1"), "1.1")

    def test_clean_version_avoids_arch_tokens(self):
        # El token arm64 no debe interpretarse como versión 64.0.0
        self.assertEqual(
            clean_version("v1.0", "v1.0", "WiimoteUserlandDriver-mac-arm64"),
            "1.0"
        )
        self.assertNotEqual(
            clean_version("v1.0", "v1.0", "WiimoteUserlandDriver-mac-arm64"),
            "64.0.0"
        )

    def test_clean_version_latest_tag_with_release_name(self):
        self.assertEqual(
            clean_version("latest", "Mapa Migrante v3.0", "migrant-aid-map-android.apk"),
            "3.0"
        )
        self.assertEqual(
            clean_version("latest", "CAT Helper v1.2", "CATHelper.apk"),
            "1.2"
        )
        self.assertEqual(
            clean_version("latest", "v0.0.1", "tecate-windows-v0.0.1-release.zip"),
            "0.0.1"
        )

    def test_clean_version_mod_jars(self):
        self.assertEqual(
            clean_version("26.1", "CatifyMod Fabric 26.1", "catify-1.1.1.jar"),
            "1.1.1"
        )
        self.assertEqual(
            clean_version("latest", "CatifyMod Forge 26.1", "catify-1.0.2.jar"),
            "1.0.2"
        )

    def test_parse_version_tuple_ordering(self):
        v1 = parse_version_tuple("26.08.04")
        v2 = parse_version_tuple("26.06.02")
        v3 = parse_version_tuple("25.11.12")
        v4 = parse_version_tuple("1.0.0")

        self.assertGreater(v1, v2)
        self.assertGreater(v2, v3)
        self.assertGreater(v3, v4)

        ts_new = parse_version_tuple("26.10.08-13")
        ts_old = parse_version_tuple("0.0.1")
        self.assertGreater(ts_new, ts_old)

    def test_known_asset_cache_integrity(self):
        self.assertGreaterEqual(len(KNOWN_ASSET_CACHE), 40)
        for url, meta in KNOWN_ASSET_CACHE.items():
            self.assertTrue(url.startswith("https://"))
            self.assertEqual(len(meta["sha256"]), 64)
            self.assertGreater(meta["size_bytes"], 0)

    def test_catalog_generation_and_validation(self):
        workspace_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        overrides_path = os.path.join(workspace_root, "tools", "catalog_overrides.json")
        schema_path = os.path.join(workspace_root, "docs", "CATALOG_SCHEMA.json")
        catalog_path = os.path.join(workspace_root, "docs", "catalog.json")

        manifest = generate_catalog(overrides_path, existing_catalog_path=catalog_path)
        self.assertTrue(validate_manifest(manifest, schema_path))

        # Comprobar que ninguna app tenga 64.0.0 o falsas versiones 1.0.0 en 26.xx
        for app in manifest["apps"]:
            for pkey, plat in app["platforms"].items():
                versions = [v["version"] for v in plat["versions"]]
                self.assertNotIn("64.0.0", versions)

                # Si es firefighter-form, verificar que 26.06.02 está presente antes de 26.08.04
                if app["id"] == "com.hakkin.firefighter-form":
                    self.assertIn("26.08.04", versions)
                    self.assertIn("26.06.02", versions)
                    self.assertNotIn("1.0.0", versions)

                # Si es PWMS, verificar que 26.09.08 está presente antes de 26.09.11
                if app["id"] == "com.hakkin.pwms":
                    self.assertIn("26.09.11", versions)
                    self.assertIn("26.09.08", versions)
                    self.assertNotIn("1.0.0", versions)


if __name__ == "__main__":
    unittest.main()
