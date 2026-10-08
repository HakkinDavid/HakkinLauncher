import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hakkin_launcher/features/catalog/data/models/app_entry.dart';

void main() {
  group('Catalog Contract Verification Tests (HakkinDavid & Bonsanbec)', () {
    const catalogPath = 'docs/catalog.json';
    const examplePath = 'docs/catalog_example.json';

    void verifyManifestStructure(CatalogManifest manifest, String sourceName) {
      expect(manifest.version, '1.0.0', reason: '$sourceName: version must be 1.0.0');
      expect(manifest.catalogTimestamp, isNotEmpty, reason: '$sourceName: timestamp must be present');
      expect(manifest.launcherMeta, isNotNull, reason: '$sourceName: launcher_meta should exist');
      expect(manifest.apps.length, 10, reason: '$sourceName: must contain exactly 10 audited apps');

      final appIds = manifest.apps.map((a) => a.id).toSet();
      expect(
        appIds,
        containsAll([
          'com.bonsanbec.tecate-simulator',
          'com.bonsanbec.fractochales',
          'com.bonsanbec.migrant-aid-map',
          'com.hakkin.firefighter-form',
          'com.hakkin.pwms',
          'com.hakkin.smart-scheduler',
          'com.hakkin.wiimote-userland-driver',
          'com.hakkin.languages-autohotkey',
          'com.hakkin.cathelper',
          'com.hakkin.catify-mod',
        ]),
        reason: '$sourceName: must contain all 10 expected app IDs',
      );

      for (final app in manifest.apps) {
        expect(app.id, isNotEmpty);
        expect(app.slug, isNotEmpty);
        expect(app.title, isNotEmpty);
        expect(app.category, isIn(['game', 'app', 'tool']));
        expect(app.developer, isNotEmpty);
        expect(app.summary, isNotEmpty);
        expect(app.descriptionMarkdown, isNotEmpty);
        expect(app.latestVersion, isNotEmpty);
        expect(app.platforms, isNotEmpty, reason: 'App ${app.id} must support at least one platform');

        for (final entry in app.platforms.entries) {
          final platformKey = entry.key;
          final release = entry.value;

          expect(release.executableRelativePath, isNotEmpty,
              reason: 'App ${app.id} on $platformKey missing executable path');
          expect(release.protectedUserPaths, isEmpty,
              reason: 'App ${app.id} on $platformKey must have empty protected_user_paths per instruction');

          final pkg = release.fullPackage;
          expect(pkg.version, isNotEmpty);
          expect(pkg.url, startsWith('https://github.com/'));
          expect(pkg.sizeBytes, greaterThan(0),
              reason: 'App ${app.id} package size must be positive');
          expect(pkg.sha256.length, 64,
              reason: 'App ${app.id} SHA256 must be exactly 64 hex characters');
          expect(RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(pkg.sha256), isTrue,
              reason: 'App ${app.id} SHA256 must be valid hex');
        }
      }

      // Verificación específica de tecate-simulator (soporte multiplataforma)
      final tecate = manifest.apps.firstWhere((a) => a.id == 'com.bonsanbec.tecate-simulator');
      expect(tecate.category, 'game');
      expect(tecate.supportsPlatform('windows-x64'), isTrue);
      expect(tecate.supportsPlatform('macos-arm64'), isTrue);

      final tecateWin = tecate.getPlatformRelease('windows-x64');
      expect(tecateWin, isNotNull);
      expect(tecateWin!.executableRelativePath, 'TecateSimulator.exe');
      expect(tecateWin.fullPackage.sizeBytes, 771167643);
      expect(tecateWin.fullPackage.sha256, 'c3e622e8a6cc35ff295c44c770496a2f06847c735605c8f4a22b2ba45019be2a');

      final tecateMac = tecate.getPlatformRelease('macos-arm64');
      expect(tecateMac, isNotNull);
      expect(tecateMac!.executableRelativePath, 'TecateSimulator.app/Contents/MacOS/TecateSimulator');
      expect(tecateMac.fullPackage.sizeBytes, 798030827);
      expect(tecateMac.fullPackage.sha256, '86286cae84f07e0978bc32fb9597cc06bd795030e0c6d96c6fcf6ccd42801cbd');
    }

    test('Valida docs/catalog.json generado contra el contrato Dart', () {
      final file = File(catalogPath);
      expect(file.existsSync(), isTrue, reason: '$catalogPath must exist');
      final content = file.readAsStringSync();
      final decoded = jsonDecode(content) as Map<String, dynamic>;
      final manifest = CatalogManifest.fromJson(decoded);

      verifyManifestStructure(manifest, 'catalog.json');
    });

    test('Valida docs/catalog_example.json sincronizado contra el contrato Dart', () {
      final file = File(examplePath);
      expect(file.existsSync(), isTrue, reason: '$examplePath must exist');
      final content = file.readAsStringSync();
      final decoded = jsonDecode(content) as Map<String, dynamic>;
      final manifest = CatalogManifest.fromJson(decoded);

      verifyManifestStructure(manifest, 'catalog_example.json');
    });
  });
}
