import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hakkin_launcher/features/catalog/data/models/app_entry.dart';

void main() {
  group('Catalog Contract Verification Tests v2.0', () {
    const catalogPath = 'docs/catalog.json';
    const examplePath = 'docs/catalog_example.json';

    void verifyManifestStructure(CatalogManifest manifest, String sourceName) {
      expect(manifest.version, '2.0.0', reason: '$sourceName: version must be 2.0.0');
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

          expect(release.latestVersion, isNotEmpty);
          expect(release.versions, isNotEmpty, reason: 'App ${app.id} on $platformKey must have versions array');
          expect(release.protectedUserPaths, isEmpty,
              reason: 'App ${app.id} on $platformKey must have empty protected_user_paths per instruction');

          for (final ver in release.versions) {
            expect(ver.version, isNotEmpty);
            expect(ver.executableRelativePath, isNotEmpty,
                reason: 'App ${app.id} on $platformKey version ${ver.version} missing executable path');

            final pkg = ver.package;
            expect(pkg.url, startsWith('https://github.com/'));
            expect(pkg.sizeBytes, greaterThan(0),
                reason: 'App ${app.id} package size must be positive');
            expect(pkg.sha256.length, 64,
                reason: 'App ${app.id} SHA256 must be exactly 64 hex characters');
            expect(RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(pkg.sha256), isTrue,
                reason: 'App ${app.id} SHA256 must be valid hex');
          }
        }
      }

      // 1. Verificación de tecate-simulator
      final tecate = manifest.apps.firstWhere((a) => a.id == 'com.bonsanbec.tecate-simulator');
      expect(tecate.title, 'Tecate Simulator');
      expect(tecate.category, 'game');
      expect(tecate.latestVersion, '26.10.08-13');
      expect(tecate.supportsPlatform('windows-x64'), isTrue);
      expect(tecate.supportsPlatform('macos-arm64'), isTrue);

      final tecateWin = tecate.getPlatformRelease('windows-x64')!;
      expect(tecateWin.latestRelease.version, '26.10.08-13');
      expect(tecateWin.latestRelease.executableRelativePath, 'tecate.exe');
      expect(tecateWin.latestRelease.package.sizeBytes, 1084841300);
      expect(tecateWin.latestRelease.package.sha256, 'b38a07970facf3ef41569bac85aef707254c80e4251a0c401c6c207cfa671f29');
      // Versión histórica preservada en el catálogo v2.0
      expect(tecateWin.getRelease('0.0.1'), isNotNull);
      expect(tecateWin.getRelease('0.0.1')!.package.sizeBytes, 771167643);

      final tecateMac = tecate.getPlatformRelease('macos-arm64')!;
      expect(tecateMac.latestRelease.version, '26.10.08-13');
      expect(tecateMac.latestRelease.executableRelativePath, 'tecate.app/Contents/MacOS/Tecate- Pueblo Mágico y Social');
      expect(tecateMac.latestRelease.package.sizeBytes, 1111734578);
      expect(tecateMac.latestRelease.package.sha256, 'a5ff201a1cfc14bce9fe53bfb1f1e02acb349deaef0ae3a34392fa2a34faa98d');
      // Versión histórica preservada en el catálogo v2.0
      expect(tecateMac.getRelease('0.0.1'), isNotNull);
      expect(tecateMac.getRelease('0.0.1')!.package.sizeBytes, 798030827);

      // 2. Verificación de fractochales
      final fracto = manifest.apps.firstWhere((a) => a.id == 'com.bonsanbec.fractochales');
      expect(fracto.title, 'Fractochales');
      expect(fracto.latestVersion, '3.27');
      expect(fracto.supportsPlatform('windows-x64'), isTrue);
      expect(fracto.supportsPlatform('macos-arm64'), isTrue);
      expect(fracto.supportsPlatform('android'), isTrue);

      final fractoWin = fracto.getPlatformRelease('windows-x64')!;
      expect(fractoWin.latestRelease.version, '3.27');
      expect(fractoWin.latestRelease.executableRelativePath, 'Fractochales v3.27/main.exe');
      expect(fractoWin.latestRelease.package.sizeBytes, 29001895);
      expect(fractoWin.getRelease('1.64'), isNotNull);
      expect(fractoWin.getRelease('1.64')!.executableRelativePath, 'main.exe');
      expect(fractoWin.getRelease('1.64')!.package.sizeBytes, 23238440);

      final fractoMac = fracto.getPlatformRelease('macos-arm64')!;
      expect(fractoMac.latestRelease.version, '3.27');
      expect(fractoMac.latestRelease.executableRelativePath,
          'fractochales-mac-arm64-v3.27.app/Contents/MacOS/Fractochales');
      expect(fractoMac.latestRelease.package.sizeBytes, 29737927);

      final fractoAndroid = fracto.getPlatformRelease('android')!;
      expect(fractoAndroid.latestRelease.version, '3.27');
      expect(fractoAndroid.latestRelease.executableRelativePath, 'fractochales-android-v3.27.apk');
      expect(fractoAndroid.latestRelease.package.sizeBytes, 29535928);

      // 3. Verificación de firefighter-form
      final bomberos = manifest.apps.firstWhere((a) => a.id == 'com.hakkin.firefighter-form');
      expect(bomberos.getPlatformRelease('windows-x64')!.latestRelease.executableRelativePath, 'bomberos.exe');

      // 4. Verificación de smart-scheduler
      final scheduler = manifest.apps.firstWhere((a) => a.id == 'com.hakkin.smart-scheduler');
      final schedulerMac = scheduler.getPlatformRelease('macos-arm64')!;
      expect(schedulerMac.versions.length, 2, reason: 'smart-scheduler must contain 2 versions');
      expect(schedulerMac.latestVersion, '2.5.0');
      expect(schedulerMac.availableVersions, ['2.5.0', '2.0.0']);
      expect(schedulerMac.latestRelease.executableRelativePath,
          'Smart Scheduler.app/Contents/MacOS/Smart Scheduler');

      // Verificar parche delta hacia 2.5.0 desde 2.0.0
      final schedulerDelta = schedulerMac.findDeltaFor('2.0.0', '2.5.0');
      expect(schedulerDelta, isNotNull);
      expect(schedulerDelta!.patchFormat, 'hdiff');
      expect(schedulerDelta.sizeBytes, 1420500);

      // 5. Verificación de languages-autohotkey
      final languages = manifest.apps.firstWhere((a) => a.id == 'com.hakkin.languages-autohotkey');
      final languagesWin = languages.getPlatformRelease('windows-x64')!;
      expect(languagesWin.versions.length, 2, reason: 'languages-autohotkey must have 2 versions');
      expect(languagesWin.getRelease('1.1.0')!.executableRelativePath, 'spanish-v1.0.exe');
      expect(languagesWin.getRelease('1.0.0')!.executableRelativePath, 'pinyin-v1.0.exe');
    }

    test('Valida docs/catalog.json generado contra el contrato Dart v2.0', () {
      final file = File(catalogPath);
      expect(file.existsSync(), isTrue, reason: '$catalogPath must exist');
      final content = file.readAsStringSync();
      final decoded = jsonDecode(content) as Map<String, dynamic>;
      final manifest = CatalogManifest.fromJson(decoded);

      verifyManifestStructure(manifest, 'catalog.json');
    });

    test('Valida docs/catalog_example.json sincronizado contra el contrato Dart v2.0', () {
      final file = File(examplePath);
      expect(file.existsSync(), isTrue, reason: '$examplePath must exist');
      final content = file.readAsStringSync();
      final decoded = jsonDecode(content) as Map<String, dynamic>;
      final manifest = CatalogManifest.fromJson(decoded);

      verifyManifestStructure(manifest, 'catalog_example.json');
    });
  });
}
