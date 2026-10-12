import 'package:flutter_test/flutter_test.dart';
import 'package:hakkin_launcher/core/constants/app_constants.dart';
import 'package:hakkin_launcher/core/constants/app_technical_strings.dart';
import 'package:hakkin_launcher/core/platform/background_check_service.dart';
import 'package:hakkin_launcher/core/platform/process_launcher.dart';
import 'package:hakkin_launcher/core/platform/startup_service.dart';
import 'package:hakkin_launcher/core/platform/window_service.dart';
import 'package:hakkin_launcher/features/catalog/data/models/app_entry.dart';
import 'package:hakkin_launcher/features/self_update/services/self_update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SelfUpdateService - Version Comparison & Detection', () {
    test('isNewerVersion compares semantic versioning accurately', () {
      expect(SelfUpdateService.isNewerVersion('1.0.1', '1.0.0'), isTrue);
      expect(SelfUpdateService.isNewerVersion('1.1.0', '1.0.0'), isTrue);
      expect(SelfUpdateService.isNewerVersion('2.0.0', '1.0.0'), isTrue);
      expect(SelfUpdateService.isNewerVersion('1.0.0.1', '1.0.0'), isTrue);
      expect(SelfUpdateService.isNewerVersion('v1.0.1', '1.0.0'), isTrue);
      // Formato YY.MM.DD-HH
      expect(SelfUpdateService.isNewerVersion('26.10.10-00', '26.10.09-20'), isTrue);
      expect(SelfUpdateService.isNewerVersion('26.10.09-20', '26.10.10-00'), isFalse);
      expect(SelfUpdateService.isNewerVersion('26.10.09-21', '26.10.09-20'), isTrue);
      expect(SelfUpdateService.isNewerVersion('26.10.10-00', '26.10.10-00'), isFalse);
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
      // Elevation fallback
      expect(script, contains('osascript -e'));
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
      // Consoleless-safe wait loop (no find /i pipe or timeout command)
      expect(script, isNot(contains('find /i')));
      expect(script, isNot(contains('timeout /t')));
      expect(script, contains('tasklist /fi "PID eq %CURRENT_PID%" /fo csv /nh > "%PID_FILE%"'));
      expect(script, contains('ping 127.0.0.1 -n 2 >NUL 2>&1'));

      final psCmd = AppTechnicalStrings.powershellStartHiddenCmd(r'C:\Hakkin\Downloads\update_helper.bat');
      expect(psCmd, contains("Start-Process -FilePath 'cmd'"));
      expect(psCmd, contains('-WindowStyle Hidden'));
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
      // Elevation fallback
      expect(script, contains('pkexec'));
    });
  });

  group('Automatic Self-Update Conditions (Hidden or 1-Minute Navigation Debounce)', () {
    const newerMeta = LauncherMeta(
      latestVersion: '999.0.0',
      releases: {},
    );

    setUp(() {
      ProcessLauncher.clearRunningAppsForTesting();
      WindowService.instance.setHiddenForTesting(false);
      BackgroundCheckService.instance.resetStateForTesting();
    });

    tearDown(() {
      ProcessLauncher.clearRunningAppsForTesting();
      WindowService.instance.setHiddenForTesting(false);
      BackgroundCheckService.instance.resetStateForTesting();
    });

    test('Default navigation debounce constant is 1 minute', () {
      expect(AppConstants.selfUpdateNavigationDebounce, const Duration(minutes: 1));
    });

    test('Does not auto-update when visible and actively being navigated', () async {
      final triggered = <String>[];
      BackgroundCheckService.instance.registerAutoSelfUpdateHandler((meta) async {
        triggered.add(meta.latestVersion);
      });

      BackgroundCheckService.instance.recordUserNavigation(
        debounce: const Duration(minutes: 1),
      );

      final result = await BackgroundCheckService.instance.evaluateAutoSelfUpdate(
        launcherMeta: newerMeta,
      );

      expect(result, isFalse);
      expect(triggered, isEmpty);
    });

    test('Condition a) Executes auto-update immediately when launcher is hidden and no apps are running', () async {
      final triggered = <String>[];
      BackgroundCheckService.instance.registerAutoSelfUpdateHandler((meta) async {
        triggered.add(meta.latestVersion);
      });

      BackgroundCheckService.instance.updateKnownLauncherMeta(newerMeta);
      expect(triggered, isEmpty);

      // Al pasar a estado hidden (system tray / taskbar / background), se ejecuta en automático
      WindowService.instance.setHiddenForTesting(true);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(triggered, ['999.0.0']);
    });

    test('Condition b) Executes auto-update after navigation debounce elapses and resets on user navigation', () async {
      final triggered = <String>[];
      BackgroundCheckService.instance.registerAutoSelfUpdateHandler((meta) async {
        triggered.add(meta.latestVersion);
      });

      BackgroundCheckService.instance.updateKnownLauncherMeta(newerMeta);
      BackgroundCheckService.instance.recordUserNavigation(
        debounce: const Duration(milliseconds: 80),
      );

      // Navegación intermedia antes de que se cumpla el debounce reinicia el contador
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(triggered, isEmpty);
      BackgroundCheckService.instance.recordUserNavigation(
        debounce: const Duration(milliseconds: 80),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(triggered, isEmpty);

      // Al cumplirse el periodo completo sin navegación, se autoactualiza
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(triggered, ['999.0.0']);
    });

    test('Does NOT auto-update while any program is running, and triggers once program finishes', () async {
      final triggered = <String>[];
      BackgroundCheckService.instance.registerAutoSelfUpdateHandler((meta) async {
        triggered.add(meta.latestVersion);
      });

      // Simular un programa del catálogo en ejecución
      ProcessLauncher.setRunningPidForTesting('dev.bonsanbec.tecate', 42424);
      expect(ProcessLauncher.hasRunningApps, isTrue);

      // Aunque esté hidden y haya actualización disponible, no debe interrumpir
      WindowService.instance.setHiddenForTesting(true);
      final whileRunning = await BackgroundCheckService.instance.evaluateAutoSelfUpdate(
        launcherMeta: newerMeta,
      );
      expect(whileRunning, isFalse);
      expect(triggered, isEmpty);

      // Al finalizar el programa en ejecución, dispara la autoactualización pendiente
      ProcessLauncher.setRunningPidForTesting('dev.bonsanbec.tecate', null);
      expect(ProcessLauncher.hasRunningApps, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(triggered, ['999.0.0']);
    });
  });

  group('SelfUpdateService - Persistence of Execution Mode (Hidden vs Foreground)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      WindowService.instance.setHiddenForTesting(false);
    });

    tearDown(() {
      WindowService.instance.setHiddenForTesting(false);
    });

    test('Update scripts preserve hidden mode when startHidden is true across macOS, Windows, and Linux', () {
      final macHidden = SelfUpdateService.generateMacOSUpdateScript(
        currentPid: 111,
        currentExePath: '/Applications/HakkinLauncher.app/Contents/MacOS/HakkinLauncher',
        targetAppPath: '/Applications/HakkinLauncher.app',
        zipFilePath: '/tmp/update.zip',
        logFilePath: '/tmp/update.log',
        startHidden: true,
      );
      expect(macHidden, contains('export HAKKIN_STARTUP="1"'));
      expect(macHidden, contains(r'open -g -n "$TARGET_APP" --args --startup'));

      final winHidden = SelfUpdateService.generateWindowsUpdateScript(
        currentPid: 222,
        currentExePath: r'C:\Hakkin\HakkinLauncher.exe',
        appDir: r'C:\Hakkin',
        zipFilePath: r'C:\Hakkin\update.zip',
        logFilePath: r'C:\Hakkin\update.log',
        startHidden: true,
      );
      expect(winHidden, contains('set HAKKIN_STARTUP=1'));
      expect(winHidden, contains('start "" "%CURRENT_EXE%" --startup'));

      final linuxHidden = SelfUpdateService.generateLinuxUpdateScript(
        currentPid: 333,
        currentExePath: '/opt/hakkin/HakkinLauncher',
        appDir: '/opt/hakkin',
        zipFilePath: '/tmp/update.zip',
        logFilePath: '/tmp/update.log',
        startHidden: true,
      );
      expect(linuxHidden, contains('export HAKKIN_STARTUP="1"'));
      expect(linuxHidden, contains(r'"$CURRENT_EXE" --startup &'));
    });

    test('Update scripts preserve foreground mode and clear HAKKIN_STARTUP when startHidden is false', () {
      final macFg = SelfUpdateService.generateMacOSUpdateScript(
        currentPid: 111,
        currentExePath: '/Applications/HakkinLauncher.app/Contents/MacOS/HakkinLauncher',
        targetAppPath: '/Applications/HakkinLauncher.app',
        zipFilePath: '/tmp/update.zip',
        logFilePath: '/tmp/update.log',
        startHidden: false,
      );
      expect(macFg, contains('unset HAKKIN_STARTUP'));
      expect(macFg, contains(r'if ! open -n "$TARGET_APP"; then'));
      expect(macFg, isNot(contains('--startup')));

      final winFg = SelfUpdateService.generateWindowsUpdateScript(
        currentPid: 222,
        currentExePath: r'C:\Hakkin\HakkinLauncher.exe',
        appDir: r'C:\Hakkin',
        zipFilePath: r'C:\Hakkin\update.zip',
        logFilePath: r'C:\Hakkin\update.log',
        startHidden: false,
      );
      expect(winFg, contains('set HAKKIN_STARTUP='));
      expect(winFg, isNot(contains('--startup')));

      final linuxFg = SelfUpdateService.generateLinuxUpdateScript(
        currentPid: 333,
        currentExePath: '/opt/hakkin/HakkinLauncher',
        appDir: '/opt/hakkin',
        zipFilePath: '/tmp/update.zip',
        logFilePath: '/tmp/update.log',
        startHidden: false,
      );
      expect(linuxFg, contains('unset HAKKIN_STARTUP'));
      expect(linuxFg, isNot(contains('--startup')));
    });

    test('Persists hidden mode across self-update and consumes the one-shot flag on restart', () async {
      WindowService.instance.setHiddenForTesting(true);
      await StartupService.savePostUpdateHiddenState(WindowService.instance.isHidden);

      // Al reiniciar tras actualizar, permanece escondido aunque no tenga --startup en args
      final resolvedOnUpdateRestart = await StartupService.resolveStartHidden([]);
      expect(resolvedOnUpdateRestart, isTrue);

      // En un inicio manual posterior, el estado temporal ya fue consumido y abre en primer plano
      final resolvedOnNextNormalLaunch = await StartupService.resolveStartHidden([]);
      expect(resolvedOnNextNormalLaunch, isFalse);
    });

    test('Persists foreground mode across self-update even if session originally had --startup', () async {
      WindowService.instance.setHiddenForTesting(false);
      await StartupService.savePostUpdateHiddenState(WindowService.instance.isHidden);

      // Al reiniciar tras actualizar estando en primer plano, aparece en primer plano
      final resolvedOnUpdateRestart = await StartupService.resolveStartHidden([
        AppTechnicalStrings.argStartup,
      ]);
      expect(resolvedOnUpdateRestart, isFalse);

      // En el siguiente arranque del sistema, vuelve a respetar --startup
      final resolvedOnNextSystemBoot = await StartupService.resolveStartHidden([
        AppTechnicalStrings.argStartup,
      ]);
      expect(resolvedOnNextSystemBoot, isTrue);
    });
  });
}
