import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hakkin_launcher/core/platform/process_launcher.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('process_launcher_test_');
  });

  tearDownAll(() {
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  group('ProcessLauncher - Executable Resolution', () {
    test('resolveExecutablePath returns targetPath if file directly exists', () {
      final dummyFile = File(p.join(tempDir.path, 'direct_app.exe'))..createSync();
      final resolved = ProcessLauncher.resolveExecutablePath(dummyFile.path);
      expect(resolved, dummyFile.path);
    });

    test('resolveExecutablePath resolves macOS CFBundleExecutable from Info.plist', () {
      final appDir = Directory(p.join(tempDir.path, 'MyGame.app'))..createSync(recursive: true);
      final contentsDir = Directory(p.join(appDir.path, 'Contents'))..createSync(recursive: true);
      final macosDir = Directory(p.join(contentsDir.path, 'MacOS'))..createSync(recursive: true);

      final plistFile = File(p.join(contentsDir.path, 'Info.plist'));
      plistFile.writeAsStringSync('''<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>RealGameBinary</string>
</dict>
</plist>''');

      final realBinary = File(p.join(macosDir.path, 'RealGameBinary'))..createSync();

      // Caso 1: Se pasó una ruta errónea hacia un binario inexistente dentro del bundle
      final wrongPath = p.join(macosDir.path, 'wrong_name');
      final resolvedFromWrong = ProcessLauncher.resolveExecutablePath(wrongPath);
      expect(resolvedFromWrong, realBinary.path);

      // Caso 2: Se pasó el directorio MyGame.app como target
      final resolvedFromBundle = ProcessLauncher.resolveExecutablePath(appDir.path);
      expect(resolvedFromBundle, realBinary.path);

      // Caso 3: Se pasó un directorio de instalación que contiene MyGame.app
      final installDir = tempDir.path;
      final resolvedFromInstallDir = ProcessLauncher.resolveExecutablePath(
        p.join(installDir, 'non_existent_exe'),
        installDir,
      );
      expect(resolvedFromInstallDir, realBinary.path);
    });
  });

  group('ProcessLauncher - Lifecycle State', () {
    test('isAppRunning returns false for unstarted app', () {
      expect(ProcessLauncher.isAppRunning('unknown-app-id'), isFalse);
    });

    test('isPidAlive detects current process and non-existent pid', () async {
      final myPid = pid;
      expect(await ProcessLauncher.isPidAlive(myPid), isTrue);
      expect(await ProcessLauncher.isPidAlive(9999999), isFalse);
    });

    test('launchApp executes in detached mode and tracks PID', () async {
      final scriptPath = p.join(tempDir.path, 'sleep_app.sh');
      final script = File(scriptPath);
      script.writeAsStringSync('#!/bin/sh\nsleep 10\n');
      await Process.run('chmod', ['+x', scriptPath]);

      final launched = await ProcessLauncher.launchApp(
        appId: 'test-detached-app',
        executablePath: scriptPath,
      );

      expect(launched, isTrue);
      expect(ProcessLauncher.isAppRunning('test-detached-app'), isTrue);
      final appPid = ProcessLauncher.getAppPid('test-detached-app');
      expect(appPid, isNotNull);

      // Limpiar y terminar el proceso de prueba
      final killed = await ProcessLauncher.killApp('test-detached-app');
      expect(killed, isTrue);
      expect(ProcessLauncher.isAppRunning('test-detached-app'), isFalse);
    });
  });
}
