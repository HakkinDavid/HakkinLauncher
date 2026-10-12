#!/usr/bin/env python3
"""
tools/test_catalog_generator.py
--------------------------------
Pruebas unitarias para el generador de catálogo, normalización de versiones y validación de contrato.
"""

import json
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from catalog_generator import (
    clean_version,
    parse_version_tuple,
    validate_manifest,
    generate_catalog,
    purge_orphaned_and_nonexistent_versions,
    normalize_sentence_case_label,
    format_title,
    format_summary,
    format_tags,
    format_description_markdown,
    format_changelog,
    KNOWN_ASSET_CACHE,
    ManifestAdapter
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

        overrides = overrides_path if os.path.isfile(overrides_path) else None
        manifest = generate_catalog(overrides_path=overrides, existing_catalog_path=catalog_path)
        self.assertTrue(validate_manifest(manifest, schema_path))

        # Comprobar que ninguna app tenga 64.0.0 o falsas versiones 1.0.0 en 26.xx
        for app in manifest["apps"]:
            for pkey, plat in app["platforms"].items():
                versions = [v["version"] for v in plat["versions"]]
                self.assertNotIn("64.0.0", versions)

                # Si es firefighter-form, verificar que 26.06.02 está presente antes de 26.08.04
                if app["id"] == "dev.bonsanbec.firefighter-form":
                    self.assertIn("26.08.04", versions)
                    self.assertIn("26.06.02", versions)
                    self.assertNotIn("1.0.0", versions)

                # Si es PWMS, verificar que 26.09.08 está presente antes de 26.09.11
                if app["id"] == "dev.bonsanbec.pwms":
                    self.assertIn("26.09.11", versions)
                    self.assertIn("26.09.08", versions)
                    self.assertNotIn("1.0.0", versions)

                # Si es Fractochales, verificar que soporta windows-x64, macos-arm64 y android
                if app["id"] == "dev.bonsanbec.fractochales":
                    self.assertIn("windows-x64", app["platforms"])
                    self.assertIn("macos-arm64", app["platforms"])
                    self.assertIn("android", app["platforms"])

    def test_purge_orphaned_and_nonexistent_versions_removes_invalid_entries(self):
        # Manifiesto con versión válida, versión con paquete corrupto, versión fantasma
        # y parche delta apuntando a versión inexistente (huérfana)
        mock_manifest = {
            "version": "2.0.0",
            "catalog_timestamp": "2026-10-09T00:00:00Z",
            "launcher_meta": None,
            "apps": [
                {
                    "id": "com.test.app",
                    "slug": "test-app",
                    "title": "Test App",
                    "category": "app",
                    "developer": "TestDev",
                    "summary": "Summary",
                    "description_markdown": "Desc",
                    "tags": [],
                    "assets": {},
                    "latest_version": "99.0.0",
                    "platforms": {
                        "windows-x64": {
                            "latest_version": "99.0.0",
                            "protected_user_paths": [],
                            "versions": [
                                {
                                    "version": "2.0.0",
                                    "package": {
                                        "url": "https://github.com/test/app/releases/download/v2.0.0/app.zip",
                                        "size_bytes": 1000,
                                        "sha256": "a" * 64
                                    },
                                    "delta_patches": [
                                        # Parche válido desde 1.0.0
                                        {
                                            "from_version": "1.0.0",
                                            "url": "https://github.com/test/app/releases/download/v2.0.0/patch_1_to_2.hdiff",
                                            "size_bytes": 200,
                                            "patch_sha256": "b" * 64,
                                            "target_sha256": "a" * 64
                                        },
                                        # Parche huérfano desde versión inexistente 0.5.0
                                        {
                                            "from_version": "0.5.0",
                                            "url": "https://github.com/test/app/releases/download/v2.0.0/patch_orphan.hdiff",
                                            "size_bytes": 200,
                                            "patch_sha256": "c" * 64,
                                            "target_sha256": "a" * 64
                                        },
                                        # Parche reflexivo (hacia sí misma)
                                        {
                                            "from_version": "2.0.0",
                                            "url": "https://github.com/test/app/releases/download/v2.0.0/patch_self.hdiff",
                                            "size_bytes": 200,
                                            "patch_sha256": "d" * 64,
                                            "target_sha256": "a" * 64
                                        }
                                    ]
                                },
                                {
                                    "version": "1.0.0",
                                    "package": {
                                        "url": "https://github.com/test/app/releases/download/v1.0.0/app.zip",
                                        "size_bytes": 900,
                                        "sha256": "e" * 64
                                    },
                                    "delta_patches": []
                                },
                                # Versión huérfana/fantasma 64.0.0
                                {
                                    "version": "64.0.0",
                                    "package": {
                                        "url": "https://github.com/test/app/releases/download/v1.0.0/app-arm64.zip",
                                        "size_bytes": 900,
                                        "sha256": "f" * 64
                                    },
                                    "delta_patches": []
                                },
                                # Versión inexistente con paquete corrupto (size_bytes <= 0)
                                {
                                    "version": "0.9.0",
                                    "package": {
                                        "url": "https://github.com/test/app/releases/download/v0.9.0/app.zip",
                                        "size_bytes": 0,
                                        "sha256": "g" * 64
                                    },
                                    "delta_patches": []
                                },
                                # Versión con sha256 inválido
                                {
                                    "version": "0.8.0",
                                    "package": {
                                        "url": "https://github.com/test/app/releases/download/v0.8.0/app.zip",
                                        "size_bytes": 500,
                                        "sha256": "invalid_short_hash"
                                    },
                                    "delta_patches": []
                                }
                            ]
                        }
                    }
                }
            ]
        }

        purged = purge_orphaned_and_nonexistent_versions(mock_manifest)
        plat = purged["apps"][0]["platforms"]["windows-x64"]
        remaining_versions = [v["version"] for v in plat["versions"]]

        # 1. Sólo 2.0.0 y 1.0.0 deben sobrevivir
        self.assertEqual(remaining_versions, ["2.0.0", "1.0.0"])
        self.assertNotIn("64.0.0", remaining_versions)
        self.assertNotIn("0.9.0", remaining_versions)
        self.assertNotIn("0.8.0", remaining_versions)

        # 2. Latest version debe recalcularse a 2.0.0
        self.assertEqual(plat["latest_version"], "2.0.0")
        self.assertEqual(purged["apps"][0]["latest_version"], "2.0.0")

        # 3. Delta patches en 2.0.0: sólo el parche desde 1.0.0 debe conservarse
        patches_v2 = plat["versions"][0]["delta_patches"]
        self.assertEqual(len(patches_v2), 1)
        self.assertEqual(patches_v2[0]["from_version"], "1.0.0")
        # El parche huérfano (from_version: 0.5.0) y el reflexivo (from_version: 2.0.0) fueron purgados completamente
        from_versions = [p["from_version"] for p in patches_v2]
        self.assertNotIn("0.5.0", from_versions)
        self.assertNotIn("2.0.0", from_versions)

    def test_catalog_has_no_orphaned_delta_references(self):
        catalog_path = os.path.join(
            os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
            "docs",
            "catalog.json"
        )
        with open(catalog_path, "r", encoding="utf-8") as f:
            cat = json.load(f)

        for app in cat["apps"]:
            for pkey, plat in app["platforms"].items():
                valid_vers = {v["version"] for v in plat["versions"]}
                # latest_version debe pertenecer a las versiones válidas
                self.assertIn(plat["latest_version"], valid_vers)
                for v in plat["versions"]:
                    self.assertNotIn("64.0.0", v["version"])
                    for dp in v.get("delta_patches", []):
                        from_v = dp.get("from_version")
                        # No debe haber referencias a versiones inexistentes/huérfanas
                        self.assertIn(from_v, valid_vers)
                        self.assertNotEqual(from_v, v["version"])

    def test_string_normativa_normalization(self):
        self.assertEqual(
            format_title("Sistema de Apoyo Migrante."),
            "Sistema de apoyo migrante"
        )
        self.assertEqual(
            format_title("Aplicación de Atención Prehospitalaria y Servicios Digitales para Bomberos"),
            "Aplicación de atención prehospitalaria y servicios digitales para bomberos"
        )
        self.assertEqual(
            format_title("Tecate Simulator."),
            "Tecate Simulator"
        )
        self.assertEqual(
            normalize_sentence_case_label("Características Principales:"),
            "Características principales"
        )
        self.assertEqual(
            normalize_sentence_case_label("Compatibilidad con Windows, macOS y 3D."),
            "Compatibilidad con Windows, macOS y 3D"
        )
        self.assertEqual(
            format_summary("simulador interactivo en primera persona:"),
            "Simulador interactivo en primera persona."
        )
        self.assertEqual(
            format_tags(["Atención Prehospitalaria.", "Flutter", "AutoHotkey", "Mapas", "OIM"]),
            ["Atención prehospitalaria", "Mapas", "OIM"]
        )

        raw_md = (
            "# Sistema de Apoyo Migrante.\n\n"
            "Aplicación móvil de asistencia humanitaria:\n\n"
            "### Características Principales:\n"
            "- **Mapa Interactivo**: Muestra albergues y comedores en tiempo real\n"
            "- **Exportación a PDF**: Genera documentos listos para imprimir."
        )
        expected_md = (
            "# Sistema de apoyo migrante\n\n"
            "Aplicación móvil de asistencia humanitaria.\n\n"
            "### Características principales\n"
            "- **Mapa interactivo**: Muestra albergues y comedores en tiempo real.\n"
            "- **Exportación a PDF**: Genera documentos listos para imprimir."
        )
        self.assertEqual(
            format_description_markdown(raw_md, title="Sistema de Apoyo Migrante"),
            expected_md
        )

        self.assertEqual(
            format_changelog("What's Changed\n* Fix bug in https://github.com/test/pr/1", "Sistema de Apoyo Migrante", "3.0"),
            "Lanzamiento de Sistema de apoyo migrante versión 3.0 con mejoras y correcciones."
        )
        self.assertEqual(
            format_changelog("Actualización con soporte de Riverpod y SQLite", "Fractochales", "3.27"),
            "Lanzamiento de Fractochales versión 3.27 con mejoras y correcciones."
        )
        self.assertEqual(
            format_changelog("corrección de errores menores", "Fractochales", "3.27"),
            "Corrección de errores menores."
        )

    def test_manifest_adapter_preserved_binary(self):
        mock_manifest = {
            "release_version": "26.10.11-19",
            "published_at_utc": "2026-10-12T02:34:10.225247+00:00",
            "binaries": {
                "macos": {
                    "filename": "tecate-macos.zip",
                    "sha256": "6" * 64,
                    "size_bytes": 1000000,
                    "status": "UPDATED",
                    "origin_release": "26.10.11-19",
                    "download_url": "https://github.com/Bonsanbec/tecate-simulator/releases/download/26.10.11-19/tecate-macos.zip"
                },
                "windows": {
                    "filename": "tecate-windows.zip",
                    "sha256": "b" * 64,
                    "size_bytes": 1000000,
                    "status": "PRESERVED",
                    "origin_release": "26.10.08-13",
                    "download_url": "https://github.com/Bonsanbec/tecate-simulator/releases/download/26.10.08-13/tecate-windows.zip"
                }
            }
        }
        app_meta = {
            "title": "Tecate Simulator",
            "platforms": {
                "macos-arm64": {"entry_point": "tecate.app"},
                "windows-x64": {"entry_point": "tecate.exe"}
            }
        }
        adapted = ManifestAdapter.adapt(mock_manifest, app_meta)
        self.assertIn("macos-arm64", adapted)
        self.assertIn("windows-x64", adapted)
        # El binario actualizado toma la versión del nuevo release
        self.assertEqual(adapted["macos-arm64"]["version"], "26.10.11-19")
        # El binario preservado mantiene su origin_release y no suplanta versiones previas
        self.assertEqual(adapted["windows-x64"]["version"], "26.10.08-13")


if __name__ == "__main__":
    unittest.main()

