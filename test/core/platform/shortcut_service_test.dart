import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hakkin_launcher/core/constants/app_strings.dart';
import 'package:hakkin_launcher/core/constants/app_technical_strings.dart';
import 'package:hakkin_launcher/core/platform/shortcut_service.dart';
import 'package:path/path.dart' as p;

void main() {
  group('ShortcutService Tests', () {
    test('Windows Start Menu directory uses HakkinLauncher subfolder instead of Hakkin', () {
      expect(
        AppTechnicalStrings.dirStartMenu,
        equals('Microsoft/Windows/Start Menu/Programs/HakkinLauncher'),
      );
      expect(
        AppTechnicalStrings.dirStartMenuLegacyHakkin,
        equals('Microsoft/Windows/Start Menu/Programs/Hakkin'),
      );
    });

    test('AppStrings.categoryLabel localizes catalog categories to Spanish sentence case', () {
      expect(AppStrings.categoryLabel('game'), equals('Juego'));
      expect(AppStrings.categoryLabel('app'), equals('App'));
      expect(AppStrings.categoryLabel('tool'), equals('Herramienta'));
    });

    test('removeShortcutsForApp cleans up symlinks and shortcuts for uninstalled apps', () async {
      // Limpieza de eventual acceso directo residual de pruebas previas
      await ShortcutService.removeShortcutsForApp(
        appTitle: 'Anomalous Test App',
        executablePath: '/tmp/test_app.exe',
      );

      final tempInstallDir = await Directory.systemTemp.createTemp('hakkin_shortcut_test_');
      try {
        final fakeAppBundle = Directory(p.join(tempInstallDir.path, 'TestGame.app'));
        await fakeAppBundle.create(recursive: true);

        const testTitle = 'HakkinUnitShortcutTestApp';

        if (Platform.isMacOS) {
          final createdDesktop = await ShortcutService.createDesktopShortcut(
            appTitle: testTitle,
            executablePath: fakeAppBundle.path,
          );
          final createdApps = await ShortcutService.createStartMenuEntry(
            appTitle: testTitle,
            executablePath: fakeAppBundle.path,
          );

          expect(createdDesktop, isTrue);
          expect(createdApps, isTrue);

          final home = Platform.environment['HOME'] ?? '';
          final desktopLink = p.join(home, 'Desktop', testTitle);
          expect(
            await FileSystemEntity.type(desktopLink, followLinks: false),
            FileSystemEntityType.link,
          );

          await ShortcutService.removeShortcutsForApp(
            appTitle: testTitle,
            executablePath: fakeAppBundle.path,
            installDirectory: tempInstallDir.path,
          );

          expect(
            await FileSystemEntity.type(desktopLink, followLinks: false),
            FileSystemEntityType.notFound,
          );
          expect(
            await FileSystemEntity.type('/Applications/$testTitle.app', followLinks: false),
            FileSystemEntityType.notFound,
          );
          if (home.isNotEmpty) {
            expect(
              await FileSystemEntity.type(
                p.join(home, 'Applications', '$testTitle.app'),
                followLinks: false,
              ),
              FileSystemEntityType.notFound,
            );
          }
        }
      } finally {
        await ShortcutService.removeShortcutsForApp(
          appTitle: 'HakkinUnitShortcutTestApp',
          executablePath: p.join(tempInstallDir.path, 'TestGame.app'),
          installDirectory: tempInstallDir.path,
        );
        if (await tempInstallDir.exists()) {
          await tempInstallDir.delete(recursive: true);
        }
      }
    });
  });
}
