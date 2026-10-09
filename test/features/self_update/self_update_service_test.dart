import 'package:flutter_test/flutter_test.dart';
import 'package:hakkin_launcher/core/constants/app_constants.dart';
import 'package:hakkin_launcher/features/catalog/data/models/app_entry.dart';
import 'package:hakkin_launcher/features/self_update/services/self_update_service.dart';

void main() {
  group('SelfUpdateService - Version Comparison & Detection', () {
    test('isNewerVersion compares semantic versioning accurately', () {
      expect(SelfUpdateService.isNewerVersion('1.0.1', '1.0.0'), isTrue);
      expect(SelfUpdateService.isNewerVersion('1.1.0', '1.0.0'), isTrue);
      expect(SelfUpdateService.isNewerVersion('2.0.0', '1.0.0'), isTrue);
      expect(SelfUpdateService.isNewerVersion('1.0.0.1', '1.0.0'), isTrue);
      expect(SelfUpdateService.isNewerVersion('v1.0.1', '1.0.0'), isTrue);
      expect(SelfUpdateService.isNewerVersion('26.10.08', '1.0.0'), isTrue);

      // Igualdad
      expect(SelfUpdateService.isNewerVersion('1.0.0', '1.0.0'), isFalse);
      expect(SelfUpdateService.isNewerVersion('v1.0.0', '1.0.0'), isFalse);

      // Versión anterior
      expect(SelfUpdateService.isNewerVersion('0.9.9', '1.0.0'), isFalse);
      expect(SelfUpdateService.isNewerVersion('0.1.0', '1.0.0'), isFalse);
    });

    test('isUpdateAvailable evaluates against AppConstants.appVersion correctly', () {
      final service = SelfUpdateService();

      expect(service.isUpdateAvailable(null), isFalse);

      final sameMeta = LauncherMeta(
        latestVersion: AppConstants.appVersion,
        releases: {},
      );
      expect(service.isUpdateAvailable(sameMeta), isFalse);

      final olderMeta = const LauncherMeta(
        latestVersion: '0.9.0',
        releases: {},
      );
      expect(service.isUpdateAvailable(olderMeta), isFalse);

      final newerMeta = const LauncherMeta(
        latestVersion: '999.0.0',
        releases: {},
      );
      expect(service.isUpdateAvailable(newerMeta), isTrue);
    });
  });

  group('SelfUpdateService - Platform Key Resolution & Fallback Strategy', () {
    test('resolves exact platform keys when available', () {
      final meta = const LauncherMeta(
        latestVersion: '1.2.0',
        releases: {
          'macos-arm64': {
            'url': 'https://example.com/macos-arm64.zip',
            'sha256': 'abcdef',
          },
          'windows-x64': {
            'url': 'https://example.com/windows-x64.zip',
            'sha256': '123456',
          },
        },
      );

      final macArm = SelfUpdateService.resolveReleaseForPlatform(meta, 'macos-arm64');
      expect(macArm, isNotNull);
      expect(macArm!['url'], 'https://example.com/macos-arm64.zip');

      final win = SelfUpdateService.resolveReleaseForPlatform(meta, 'windows-x64');
      expect(win, isNotNull);
      expect(win!['url'], 'https://example.com/windows-x64.zip');
    });

    test('resolves fallback platform keys when exact match is missing', () {
      // Caso 1: Usuario en macos-x64 pero solo hay macos-universal o macos
      final metaUniversal = const LauncherMeta(
        latestVersion: '1.2.0',
        releases: {
          'macos-universal': {
            'url': 'https://example.com/macos-universal.zip',
            'sha256': 'universal_hash',
          },
        },
      );

      final fallbackMacX64 = SelfUpdateService.resolveReleaseForPlatform(metaUniversal, 'macos-x64');
      expect(fallbackMacX64, isNotNull);
      expect(fallbackMacX64!['url'], 'https://example.com/macos-universal.zip');

      // Caso 2: Usuario en windows-x64 pero la release está rotulada como "windows"
      final metaGenericWin = const LauncherMeta(
        latestVersion: '1.2.0',
        releases: {
          'windows': {
            'url': 'https://example.com/windows-generic.zip',
            'sha256': 'win_hash',
          },
        },
      );

      final fallbackWin = SelfUpdateService.resolveReleaseForPlatform(metaGenericWin, 'windows-x64');
      expect(fallbackWin, isNotNull);
      expect(fallbackWin!['url'], 'https://example.com/windows-generic.zip');

      // Caso 3: Plataforma totalmente ajena
      final fallbackUnknown = SelfUpdateService.resolveReleaseForPlatform(metaGenericWin, 'solaris-sparc');
      expect(fallbackUnknown, isNull);
    });
  });

  group('SelfUpdateService - Helper Scripts & Rollback Mechanisms Audit', () {
    test('generateMacOSUpdateScript contains staging, atomic swap, and rollback', () {
      final script = SelfUpdateService.generateMacOSUpdateScript(
        currentPid: 12345,
        currentExePath: '/Applications/HakkinLauncher.app/Contents/MacOS/HakkinLauncher',
        targetAppPath: '/Applications/HakkinLauncher.app',
        zipFilePath: '/tmp/downloads/HakkinLauncher_update.zip',
        logFilePath: '/tmp/downloads/HakkinLauncher_self_update.log',
      );

      expect(script, contains('CURRENT_PID="12345"'));
      expect(script, contains('TARGET_APP="/Applications/HakkinLauncher.app"'));
      expect(script, contains(r'BACKUP_APP="${TARGET_APP}.update_backup"'));
      expect(script, contains('STAGING_DIR='));
      expect(script, contains('rollback()'));
      // Rollback restore action
      expect(script, contains(r'cp -R "$BACKUP_APP" "$TARGET_APP"'));
      // Quarantine cleanup
      expect(script, contains(r'xattr -dr com.apple.quarantine "$TARGET_APP"'));
      // Atomic move
      expect(script, contains(r'mv "$FOUND_APP" "$TARGET_APP"'));
      // Re-launch
      expect(script, contains(r'open -n "$TARGET_APP"'));
    });

    test('generateWindowsUpdateScript contains staging, backup, and rollback', () {
      final script = SelfUpdateService.generateWindowsUpdateScript(
        currentPid: 54321,
        currentExePath: r'C:\Hakkin\HakkinLauncher.exe',
        appDir: r'C:\Hakkin',
        zipFilePath: r'C:\Hakkin\Downloads\update.zip',
        logFilePath: r'C:\Hakkin\Downloads\update.log',
      );

      expect(script, contains('CURRENT_PID=54321'));
      expect(script, contains(r'APP_DIR=C:\Hakkin'));
      expect(script, contains('BACKUP_DIR=%APP_DIR%_backup'));
      expect(script, contains('STAGING_DIR=%TEMP%'));
      expect(script, contains(':rollback'));
      // Rollback restore action
      expect(script, contains(r'xcopy "%BACKUP_DIR%" "%APP_DIR%\"'));
      // Launch app
      expect(script, contains('start "" "%CURRENT_EXE%"'));
    });

    test('generateLinuxUpdateScript contains staging, backup, and rollback', () {
      final script = SelfUpdateService.generateLinuxUpdateScript(
        currentPid: 9876,
        currentExePath: '/opt/hakkin/HakkinLauncher',
        appDir: '/opt/hakkin',
        zipFilePath: '/tmp/update.zip',
        logFilePath: '/tmp/update.log',
      );

      expect(script, contains('CURRENT_PID="9876"'));
      expect(script, contains('APP_DIR="/opt/hakkin"'));
      expect(script, contains(r'BACKUP_DIR="${APP_DIR}.update_backup"'));
      expect(script, contains('rollback()'));
      expect(script, contains(r'cp -a "$BACKUP_DIR" "$APP_DIR"'));
      expect(script, contains(r'chmod +x "$CURRENT_EXE"'));
      expect(script, contains(r'"$CURRENT_EXE" &'));
    });
  });
}
