import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hakkin_launcher/core/crypto/hash_validator.dart';
import 'package:hakkin_launcher/features/catalog/data/models/app_entry.dart';

void main() {
  group('Catalog Manifest & Schema Tests', () {
    test('Parsea correctamente un catálogo JSON con plataformas y delta updates', () {
      const sampleJson = '''
      {
        "version": "1.0.0",
        "catalog_timestamp": "2026-10-07T23:00:00Z",
        "launcher_meta": {
          "latest_version": "1.0.0",
          "releases": {
            "macos-arm64": {
              "url": "https://example.com/launcher.zip",
              "sha256": "abcdef123456"
            }
          }
        },
        "apps": [
          {
            "id": "com.hakkin.testgame",
            "slug": "test-game",
            "title": "Test Game",
            "category": "game",
            "developer": "Hakkin",
            "summary": "Juego de prueba",
            "description_markdown": "# Juego de prueba",
            "tags": ["Indie", "Action"],
            "assets": {
              "icon": "https://example.com/icon.png",
              "poster": "https://example.com/poster.jpg"
            },
            "latest_version": "1.2.0",
            "platforms": {
              "macos-arm64": {
                "executable_relative_path": "TestGame.app/Contents/MacOS/TestGame",
                "full_package": {
                  "version": "1.2.0",
                  "url": "https://example.com/test-1.2.0.zip",
                  "size_bytes": 1000000,
                  "sha256": "11223344"
                },
                "delta_updates": [
                  {
                    "from_version": "1.1.0",
                    "to_version": "1.2.0",
                    "patch_format": "hdiff",
                    "url": "https://example.com/patch-1.1-1.2.hdiff",
                    "size_bytes": 50000,
                    "patch_sha256": "55667788",
                    "target_sha256": "11223344"
                  }
                ],
                "protected_user_paths": [
                  "saves/**",
                  "config.ini"
                ],
                "scripts": {
                  "post_install": "scripts/setup.sh"
                }
              }
            }
          }
        ]
      }
      ''';

      final decoded = jsonDecode(sampleJson) as Map<String, dynamic>;
      final manifest = CatalogManifest.fromJson(decoded);

      expect(manifest.version, '1.0.0');
      expect(manifest.apps.length, 1);

      final app = manifest.apps.first;
      expect(app.id, 'com.hakkin.testgame');
      expect(app.title, 'Test Game');
      expect(app.category, 'game');
      expect(app.supportsPlatform('macos-arm64'), isTrue);
      expect(app.supportsPlatform('windows-x64'), isFalse);

      final release = app.getPlatformRelease('macos-arm64');
      expect(release, isNotNull);
      expect(release!.executableRelativePath, 'TestGame.app/Contents/MacOS/TestGame');
      expect(release.protectedUserPaths, contains('saves/**'));
      expect(release.scripts.postInstall, 'scripts/setup.sh');

      // Prueba de búsqueda de delta patch
      final delta = release.findDeltaFor('1.1.0', '1.2.0');
      expect(delta, isNotNull);
      expect(delta!.patchFormat, 'hdiff');
      expect(delta.sizeBytes, 50000);
      expect(delta.patchSha256, '55667788');

      // Prueba de delta inexistente
      final missingDelta = release.findDeltaFor('1.0.0', '1.2.0');
      expect(missingDelta, isNull);
    });
  });

  group('HashValidator Cryptographic Tests', () {
    test('Calcula correctamente el hash SHA-256 de una cadena', () {
      const text = 'HakkinLauncher';
      final hash = HashValidator.hashString(text);

      expect(hash, isNotEmpty);
      expect(hash.length, 64);
    });
  });
}
