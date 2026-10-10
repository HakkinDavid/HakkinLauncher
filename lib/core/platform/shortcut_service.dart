import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../constants/app_strings.dart';
import '../constants/app_technical_strings.dart';

/// Servicio para registrar accesos directos de aplicaciones en el sistema operativo.
class ShortcutService {
  ShortcutService._();

  /// Crea un acceso directo en el Escritorio.
  static Future<bool> createDesktopShortcut({
    required String appTitle,
    required String executablePath,
    String? iconPath,
  }) async {
    try {
      final userHome = Platform.environment[AppTechnicalStrings.envHome] ??
          Platform.environment[AppTechnicalStrings.envUserProfile] ??
          AppTechnicalStrings.empty;
      if (userHome.isEmpty) return false;

      if (Platform.isWindows) {
        final desktopPath = p.join(
          userHome,
          AppTechnicalStrings.dirDesktop,
          appTitle + AppTechnicalStrings.extLnk,
        );
        return await _createWindowsShortcut(
          targetPath: executablePath,
          shortcutPath: desktopPath,
          iconPath: iconPath,
        );
      } else if (Platform.isLinux) {
        final slug = appTitle
            .toLowerCase()
            .replaceAll(AppTechnicalStrings.space, AppTechnicalStrings.underscore);
        final desktopPath = p.join(
          userHome,
          AppTechnicalStrings.dirDesktop,
          slug + AppTechnicalStrings.extDesktop,
        );
        return await _createLinuxDesktopEntry(
          appTitle: appTitle,
          executablePath: executablePath,
          desktopFilePath: desktopPath,
          iconPath: iconPath,
        );
      } else if (Platform.isMacOS) {
        var targetToLink = executablePath;
        final appBundleIdx = executablePath.indexOf(AppTechnicalStrings.extApp);
        if (appBundleIdx != -1) {
          targetToLink = executablePath.substring(
            0,
            appBundleIdx + AppTechnicalStrings.extApp.length,
          );
        }

        final desktopPath = p.join(
          userHome,
          AppTechnicalStrings.dirDesktop,
          appTitle,
        );
        final link = Link(desktopPath);
        if (await link.exists()) await link.delete();
        await link.create(targetToLink);
        return true;
      }
    } catch (e) {
      debugPrint(AppStrings.logDesktopShortcutError(e));
    }
    return false;
  }

  /// Crea un acceso directo en el menú de aplicaciones del sistema.
  static Future<bool> createStartMenuEntry({
    required String appTitle,
    required String executablePath,
    String? iconPath,
  }) async {
    try {
      if (Platform.isWindows) {
        final appData = Platform.environment[AppTechnicalStrings.envAppData] ??
            AppTechnicalStrings.empty;
        if (appData.isEmpty) return false;
        final startMenuDir = p.join(userHomeStartMenuBase(appData));
        await Directory(startMenuDir).create(recursive: true);
        final shortcutPath = p.join(startMenuDir, appTitle + AppTechnicalStrings.extLnk);
        return await _createWindowsShortcut(
          targetPath: executablePath,
          shortcutPath: shortcutPath,
          iconPath: iconPath,
        );
      } else if (Platform.isLinux) {
        final userHome = Platform.environment[AppTechnicalStrings.envHome] ??
            AppTechnicalStrings.empty;
        final appsDir = p.join(userHome, AppTechnicalStrings.dirLinuxApps);
        await Directory(appsDir).create(recursive: true);
        final slug = appTitle
            .toLowerCase()
            .replaceAll(AppTechnicalStrings.space, AppTechnicalStrings.underscore);
        final entryPath = p.join(appsDir, slug + AppTechnicalStrings.extDesktop);
        return await _createLinuxDesktopEntry(
          appTitle: appTitle,
          executablePath: executablePath,
          desktopFilePath: entryPath,
          iconPath: iconPath,
        );
      }
    } catch (e) {
      debugPrint(AppStrings.logStartMenuError(e));
    }
    return false;
  }

  static String userHomeStartMenuBase(String appData) =>
      p.join(appData, AppTechnicalStrings.dirStartMenu);

  static Future<bool> _createWindowsShortcut({
    required String targetPath,
    required String shortcutPath,
    String? iconPath,
  }) async {
    try {
      final script = AppTechnicalStrings.generateWindowsShortcutScript(
        shortcutPath: shortcutPath,
        targetPath: targetPath,
        workingDir: File(targetPath).parent.path,
        iconPath: iconPath,
      );
      final res = await Process.run(
        AppTechnicalStrings.cmdPowershell,
        [
          AppTechnicalStrings.argNoProfile,
          AppTechnicalStrings.argMinusCommand,
          script,
        ],
      );
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
      final content = AppTechnicalStrings.generateLinuxDesktopEntry(
        appTitle: appTitle,
        executablePath: executablePath,
        workingDir: File(executablePath).parent.path,
        iconPath: iconPath,
      );
      final file = File(desktopFilePath);
      await file.writeAsString(content);
      await Process.run(
        AppTechnicalStrings.cmdChmod,
        [AppTechnicalStrings.argPlusX, desktopFilePath],
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
