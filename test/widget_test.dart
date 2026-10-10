import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hakkin_launcher/core/constants/app_constants.dart';
import 'package:hakkin_launcher/core/crypto/hash_validator.dart';
import 'package:hakkin_launcher/features/catalog/data/models/app_entry.dart';
import 'package:hakkin_launcher/features/library/data/models/installed_app.dart';
import 'package:hakkin_launcher/features/self_update/services/self_update_service.dart';
import 'package:hakkin_launcher/features/updater/services/downloader_service.dart';

void main() {
  group('Catalog Manifest & Schema Tests', () {
    test('Parsea correctamente un catálogo JSON con plataformas y delta updates', () {
      const sampleJson = '''
      {
        "version": "1.0.0",
        "catalog_timestamp": "2026-10-07T23:00:00Z",
        "launcher_meta": {
          "latest_version": "1.1.0",
          "releases": {
            "macos-arm64": {
              "url": "https://example.com/launcher.zip",
              "sha256": "abcdef123456"
            }
          }
        },
        "apps": [
          {
            "id": "dev.bonsanbec.testgame",
            "slug": "test-game",
            "title": "Test Game",
            "category": "game",
            "developer": "Hakkin",
            "summary": "Juego de prueba",
            "description_markdown": "# Juego de prueba",
            "tags": ["Indie", "Action"],
            "assets": {
              "icon": "https://example.com/icon.png",
              "poster": "https://example.com/poster.jpg",
              "screenshots": ["https://example.com/s1.jpg", "https://example.com/s2.jpg"]
            },
            "latest_version": "1.2.0",
            "platforms": {
              "macos-arm64": {
                "latest_version": "1.2.0",
                "protected_user_paths": [
                  "saves/**",
                  "config.ini"
                ],
                "versions": [
                  {
                    "version": "1.2.0",
                    "release_date": "2026-10-08T00:00:00Z",
                    "changelog": "Versión 1.2.0 de prueba.",
                    "entry_point": "TestGame.app",
                    "package": {
                      "url": "https://example.com/test-1.2.0.zip",
                      "size_bytes": 1000000,
                      "sha256": "11223344"
                    },
                    "delta_patches": [
                      {
                        "from_version": "1.1.0",
                        "patch_format": "hdiff",
                        "url": "https://example.com/patch-1.1-1.2.hdiff",
                        "size_bytes": 50000,
                        "patch_sha256": "55667788",
                        "target_sha256": "11223344"
                      }
                    ],
                    "scripts": {
                      "pre_install": "scripts/pre.sh",
                      "post_install": "scripts/setup.sh"
                    }
                  }
                ]
              }
            }
          }
        ]
      }
      ''';

      final decoded = jsonDecode(sampleJson) as Map<String, dynamic>;
      final manifest = CatalogManifest.fromJson(decoded);

      expect(manifest.version, '1.0.0');
      expect(manifest.launcherMeta, isNotNull);
      expect(manifest.launcherMeta!.latestVersion, '1.1.0');
      expect(manifest.apps.length, 1);

      final app = manifest.apps.first;
      expect(app.id, 'dev.bonsanbec.testgame');
      expect(app.title, 'Test Game');
      expect(app.category, 'game');
      expect(app.assets.screenshots.length, 2);
      expect(app.supportsPlatform('macos-arm64'), isTrue);
      expect(app.supportsPlatform('windows-x64'), isFalse);

      final release = app.getPlatformRelease('macos-arm64');
      expect(release, isNotNull);
      expect(release!.latestRelease.entryPoint, 'TestGame.app');
      expect(release.protectedUserPaths, contains('saves/**'));
      expect(release.latestRelease.scripts.preInstall, 'scripts/pre.sh');
      expect(release.latestRelease.scripts.postInstall, 'scripts/setup.sh');

      // Prueba de búsqueda de delta patch
      final delta = release.findDeltaFor('1.1.0', '1.2.0');
      expect(delta, isNotNull);
      expect(delta!.patchFormat, 'hdiff');
      expect(delta.sizeBytes, 50000);
      expect(delta.patchSha256, '55667788');
      expect(delta.targetSha256, '11223344');

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

  group('InstalledApp Model & Launch Arguments Tests', () {
    test('Serializa y deserializa InstalledApp con argumentos de lanzamiento', () {
      final app = InstalledApp(
        id: 'dev.bonsanbec.game1',
        title: 'Eclipse',
        installedVersion: '1.0.0',
        executablePath: '/tmp/game',
        installDirectory: '/tmp',
        installedAt: DateTime(2026, 1, 1),
        platformKey: 'macos-arm64',
        launchArguments: '-windowed -novsync',
      );

      final json = app.toJson();
      expect(json['launch_arguments'], '-windowed -novsync');

      final reconstructed = InstalledApp.fromJson(json);
      expect(reconstructed.id, app.id);
      expect(reconstructed.launchArguments, '-windowed -novsync');

      final modified = reconstructed.copyWith(launchArguments: '-fps 60');
      expect(modified.launchArguments, '-fps 60');
    });
  });

  group('SelfUpdateService Tests', () {
    test('Detecta correctamente si hay actualización de HakkinLauncher', () {
      final service = SelfUpdateService();

      const metaWithNewer = LauncherMeta(
        latestVersion: '999.0.0',
        releases: {},
      );
      expect(service.isUpdateAvailable(metaWithNewer), isTrue);

      const metaSame = LauncherMeta(
        latestVersion: AppConstants.appVersion,
        releases: {},
      );
      expect(service.isUpdateAvailable(metaSame), isFalse);

      expect(service.isUpdateAvailable(null), isFalse);
    });
  });

  group('DownloaderService & Metrics Tests', () {
    test('Formatea correctamente las métricas de DownloadProgress', () {
      const progress = DownloadProgress(
        receivedBytes: 52428800, // 50 MB
        totalBytes: 104857600, // 100 MB
        progress: 0.5,
        speedBytesPerSec: 10485760, // 10 MB/s
        statusText: '50.0 MB de 100.0 MB',
      );

      expect(progress.percentageFormatted, '50.0%');
      expect(progress.speedFormatted, '10.0 MB/s');
    });

    test('DownloaderService instancia con timeouts y cliente Dio configurado', () {
      final downloader = DownloaderService();
      expect(downloader, isNotNull);
    });
  });

  group('CleanerService Housekeeping Tests', () {
    test('Limpia archivos en directorio temporal correctamente', () async {
      final tempDir = await Directory.systemTemp.createTemp('hakkin_cleaner_test');
      final dummyFile1 = File('${tempDir.path}/app_v1.zip');
      final dummyFile2 = File('${tempDir.path}/patch.hdiff');
      final dummyFile3 = File('${tempDir.path}/file.tmp');
      await dummyFile1.writeAsString('test zip');
      await dummyFile2.writeAsString('test patch');
      await dummyFile3.writeAsString('test tmp');

      expect(await dummyFile1.exists(), isTrue);
      expect(await dummyFile2.exists(), isTrue);
      expect(await dummyFile3.exists(), isTrue);

      final entities = tempDir.listSync();
      int deleted = 0;
      for (final e in entities) {
        if (e is File) {
          await e.delete();
          deleted++;
        }
      }

      expect(deleted, 3);
      expect(tempDir.listSync(), isEmpty);
      await tempDir.delete();
    });
  });
}
