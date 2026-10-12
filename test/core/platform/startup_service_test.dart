import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hakkin_launcher/core/constants/app_constants.dart';
import 'package:hakkin_launcher/core/constants/app_technical_strings.dart';
import 'package:hakkin_launcher/core/platform/startup_service.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('StartupService Tests', () {
    late Directory tempHomeDir;

    setUp(() async {
      tempHomeDir = await Directory.systemTemp.createTemp('hakkin_startup_test_');
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() async {
      if (await tempHomeDir.exists()) {
        await tempHomeDir.delete(recursive: true);
      }
    });

    test('La preferencia de arranque está activada por defecto', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final defaultValue =
          prefs.getBool(AppConstants.prefLaunchAtStartupKey) ?? true;
      expect(defaultValue, isTrue);
    });

    test('Genera correctamente plantillas de arranque para macOS y Linux', () {
      final plist = AppTechnicalStrings.generateMacOsLaunchAgentPlist(
        label: AppTechnicalStrings.launcherId1,
        executablePath: '/Applications/HakkinLauncher.app/Contents/MacOS/hakkin_launcher',
      );
      expect(plist, contains(AppTechnicalStrings.launcherId1));
      expect(plist, contains('<key>RunAtLoad</key>'));
      expect(plist, contains('<true/>'));

      final desktopEntry = AppTechnicalStrings.generateLinuxAutostartDesktopEntry(
        appTitle: AppConstants.appName,
        executablePath: '/opt/hakkin_launcher/hakkin_launcher',
        workingDir: '/opt/hakkin_launcher',
      );
      expect(desktopEntry, contains('Name=HakkinLauncher'));
      expect(desktopEntry, contains('X-GNOME-Autostart-enabled=true'));
    });

    test('Registra y elimina el archivo de arranque en el sistema actual', () async {
      if (Platform.isMacOS || Platform.isLinux) {
        final fakeExe = p.join(tempHomeDir.path, 'hakkin_launcher');
        await File(fakeExe).writeAsString('');

        final enabledResult = await StartupService.setLaunchAtStartup(
          true,
          customHomeDir: tempHomeDir.path,
          customExecutablePath: fakeExe,
        );
        expect(enabledResult, isTrue);
        expect(
          await StartupService.isRegisteredInSystem(
            customHomeDir: tempHomeDir.path,
          ),
          isTrue,
        );

        final disabledResult = await StartupService.setLaunchAtStartup(
          false,
          customHomeDir: tempHomeDir.path,
          customExecutablePath: fakeExe,
        );
        expect(disabledResult, isTrue);
        expect(
          await StartupService.isRegisteredInSystem(
            customHomeDir: tempHomeDir.path,
          ),
          isFalse,
        );
      }
    });
  });
}
