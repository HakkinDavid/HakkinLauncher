import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Servicio para registrar aplicaciones en el sistema operativo (Accesos directos, Menú Inicio, .desktop).
class ShortcutService {
  ShortcutService._();

  /// Crea un acceso directo en el Escritorio.
  static Future<bool> createDesktopShortcut({
    required String appTitle,
    required String executablePath,
    String? iconPath,
  }) async {
    try {
      final userHome = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';
      if (userHome.isEmpty) return false;

      if (Platform.isWindows) {
        final desktopPath = p.join(userHome, 'Desktop', '$appTitle.lnk');
        return await _createWindowsShortcut(
          targetPath: executablePath,
          shortcutPath: desktopPath,
          iconPath: iconPath,
        );
      } else if (Platform.isLinux) {
        final desktopPath = p.join(userHome, 'Desktop', '${appTitle.toLowerCase().replaceAll(' ', '_')}.desktop');
        return await _createLinuxDesktopEntry(
          appTitle: appTitle,
          executablePath: executablePath,
          desktopFilePath: desktopPath,
          iconPath: iconPath,
        );
      } else if (Platform.isMacOS) {
        final desktopPath = p.join(userHome, 'Desktop', appTitle);
        // En macOS, crear symlink
        final link = Link(desktopPath);
        if (await link.exists()) await link.delete();
        await link.create(executablePath);
        return true;
      }
    } catch (e) {
      debugPrint('Error creando acceso directo de escritorio: $e');
    }
    return false;
  }

  /// Crea un acceso directo en el Menú Inicio (Windows) o en ~/.local/share/applications/ (Linux).
  static Future<bool> createStartMenuEntry({
    required String appTitle,
    required String executablePath,
    String? iconPath,
  }) async {
    try {
      if (Platform.isWindows) {
        final appData = Platform.environment['APPDATA'] ?? '';
        if (appData.isEmpty) return false;
        final startMenuDir = p.join(appData, 'Microsoft', 'Windows', 'Start Menu', 'Programs', 'Hakkin');
        await Directory(startMenuDir).create(recursive: true);
        final shortcutPath = p.join(startMenuDir, '$appTitle.lnk');
        return await _createWindowsShortcut(
          targetPath: executablePath,
          shortcutPath: shortcutPath,
          iconPath: iconPath,
        );
      } else if (Platform.isLinux) {
        final userHome = Platform.environment['HOME'] ?? '';
        final appsDir = p.join(userHome, '.local', 'share', 'applications');
        await Directory(appsDir).create(recursive: true);
        final entryPath = p.join(appsDir, '${appTitle.toLowerCase().replaceAll(' ', '_')}.desktop');
        return await _createLinuxDesktopEntry(
          appTitle: appTitle,
          executablePath: executablePath,
          desktopFilePath: entryPath,
          iconPath: iconPath,
        );
      }
    } catch (e) {
      debugPrint('Error registrando en menú de aplicaciones: $e');
    }
    return false;
  }

  static Future<bool> _createWindowsShortcut({
    required String targetPath,
    required String shortcutPath,
    String? iconPath,
  }) async {
    try {
      final script = '''
\$ws = New-Object -ComObject WScript.Shell
\$s = \$ws.CreateShortcut('$shortcutPath')
\$s.TargetPath = '$targetPath'
\$s.WorkingDirectory = '${File(targetPath).parent.path}'
${iconPath != null ? "\$s.IconLocation = '$iconPath'" : ""}
\$s.Save()
''';
      final res = await Process.run('powershell', ['-NoProfile', '-Command', script]);
      return res.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _createLinuxDesktopEntry({
    required String appTitle,
    required String executablePath,
    required String desktopFilePath,
    String? iconPath,
  }) async {
    try {
      final content = '''[Desktop Entry]
Type=Application
Name=$appTitle
Exec="$executablePath"
Path=${File(executablePath).parent.path}
${iconPath != null ? "Icon=$iconPath" : ""}
Terminal=false
Categories=Game;Utility;
''';
      final file = File(desktopFilePath);
      await file.writeAsString(content);
      await Process.run('chmod', ['+x', desktopFilePath]);
      return true;
    } catch (_) {
      return false;
    }
  }
}
