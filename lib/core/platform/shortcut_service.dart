import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../constants/app_strings.dart';
import '../constants/app_technical_strings.dart';

/// Servicio para registrar y eliminar accesos directos de aplicaciones en el sistema operativo.
class ShortcutService {
  ShortcutService._();

  /// Crea un acceso directo en el Escritorio.
  static Future<bool> createDesktopShortcut({
    required String appTitle,
    required String executablePath,
    String? iconPath,
  }) async {
    try {
      final userHome = _getUserHome();
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
        final slug = _toLinuxSlug(appTitle);
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
        final targetToLink = await _resolveAndSanitizeMacOsTarget(executablePath);
        final desktopPath = p.join(
          userHome,
          AppTechnicalStrings.dirDesktop,
          appTitle,
        );
        await _deleteShortcutEntityIfExists(desktopPath);
        await Link(desktopPath).create(targetToLink);
        return true;
      }
    } catch (e) {
      debugPrint(AppStrings.logDesktopShortcutError(e));
    }
    return false;
  }

  /// Comprueba si ya existe un acceso directo para la aplicación en el Escritorio y lo actualiza.
  static Future<bool> updateDesktopShortcutIfExists({
    required String appTitle,
    required String executablePath,
    String? iconPath,
  }) async {
    try {
      final userHome = _getUserHome();
      if (userHome.isEmpty) return false;

      if (Platform.isMacOS) {
        final desktopPath = p.join(
          userHome,
          AppTechnicalStrings.dirDesktop,
          appTitle,
        );
        final desktopAppPath = p.join(
          userHome,
          AppTechnicalStrings.dirDesktop,
          appTitle + AppTechnicalStrings.extApp,
        );
        if (await _shortcutEntityExists(desktopPath) ||
            await _shortcutEntityExists(desktopAppPath)) {
          return await createDesktopShortcut(
            appTitle: appTitle,
            executablePath: executablePath,
            iconPath: iconPath,
          );
        }
      } else if (Platform.isWindows) {
        final desktopPath = p.join(
          userHome,
          AppTechnicalStrings.dirDesktop,
          appTitle + AppTechnicalStrings.extLnk,
        );
        if (await _shortcutEntityExists(desktopPath)) {
          return await createDesktopShortcut(
            appTitle: appTitle,
            executablePath: executablePath,
            iconPath: iconPath,
          );
        }
      } else if (Platform.isLinux) {
        final slug = _toLinuxSlug(appTitle);
        final desktopPath = p.join(
          userHome,
          AppTechnicalStrings.dirDesktop,
          slug + AppTechnicalStrings.extDesktop,
        );
        if (await _shortcutEntityExists(desktopPath)) {
          return await createDesktopShortcut(
            appTitle: appTitle,
            executablePath: executablePath,
            iconPath: iconPath,
          );
        }
      }
    } catch (_) {}
    return false;
  }

  /// Crea un acceso directo en el menú de aplicaciones del sistema (Start Menu en Windows,
  /// carpeta Aplicaciones / Launchpad en macOS, o menú XDG en Linux).
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
        final startMenuDir = userHomeStartMenuBase(appData);
        await Directory(startMenuDir).create(recursive: true);
        final shortcutPath = p.join(
          startMenuDir,
          appTitle + AppTechnicalStrings.extLnk,
        );
        // Limpiar entrada previa en subcarpeta heredada Hakkin si existiera
        final legacyPath = p.join(
          appData,
          AppTechnicalStrings.dirStartMenuLegacyHakkin,
          appTitle + AppTechnicalStrings.extLnk,
        );
        await _deleteShortcutEntityIfExists(legacyPath);
        await _cleanupEmptyDirectory(
          p.join(appData, AppTechnicalStrings.dirStartMenuLegacyHakkin),
        );

        return await _createWindowsShortcut(
          targetPath: executablePath,
          shortcutPath: shortcutPath,
          iconPath: iconPath,
        );
      } else if (Platform.isLinux) {
        final userHome = _getUserHome();
        if (userHome.isEmpty) return false;
        final appsDir = p.join(userHome, AppTechnicalStrings.dirLinuxApps);
        await Directory(appsDir).create(recursive: true);
        final slug = _toLinuxSlug(appTitle);
        final entryPath = p.join(appsDir, slug + AppTechnicalStrings.extDesktop);
        return await _createLinuxDesktopEntry(
          appTitle: appTitle,
          executablePath: executablePath,
          desktopFilePath: entryPath,
          iconPath: iconPath,
        );
      } else if (Platform.isMacOS) {
        final userHome = _getUserHome();
        final targetToLink = await _resolveAndSanitizeMacOsTarget(executablePath);
        final targetAppsDir = await _resolveMacOsApplicationsDirectory(userHome);
        if (targetAppsDir.isEmpty) return false;

        final isAppBundle = targetToLink.endsWith(AppTechnicalStrings.extApp);
        final linkName = (isAppBundle && !appTitle.endsWith(AppTechnicalStrings.extApp))
            ? appTitle + AppTechnicalStrings.extApp
            : appTitle;

        final linkPath = p.join(targetAppsDir, linkName);
        final plainPath = p.join(targetAppsDir, appTitle);

        await _deleteShortcutEntityIfExists(linkPath);
        if (plainPath != linkPath) {
          await _deleteShortcutEntityIfExists(plainPath);
        }

        await Link(linkPath).create(targetToLink);

        // Registrar en LaunchServices para que Launchpad y Spotlight detecten la aplicación de inmediato
        try {
          final lsregister = File(AppTechnicalStrings.cmdLsregister);
          if (await lsregister.exists()) {
            await Process.run(
              lsregister.path,
              [AppTechnicalStrings.argMinusF, linkPath],
            );
          }
        } catch (_) {}

        return true;
      }
    } catch (e) {
      debugPrint(AppStrings.logStartMenuError(e));
    }
    return false;
  }

  /// Comprueba si ya existe un acceso directo en el menú de aplicaciones / carpeta Aplicaciones y lo actualiza.
  static Future<bool> updateStartMenuEntryIfExists({
    required String appTitle,
    required String executablePath,
    String? iconPath,
  }) async {
    try {
      if (Platform.isMacOS) {
        final userHome = _getUserHome();
        final candidates = <String>[
          p.join(AppTechnicalStrings.dirApplicationsSystem, appTitle),
          p.join(AppTechnicalStrings.dirApplicationsSystem, appTitle + AppTechnicalStrings.extApp),
          if (userHome.isNotEmpty) ...[
            p.join(userHome, AppTechnicalStrings.dirApplicationsUser, appTitle),
            p.join(
              userHome,
              AppTechnicalStrings.dirApplicationsUser,
              appTitle + AppTechnicalStrings.extApp,
            ),
          ],
        ];
        for (final candidate in candidates) {
          if (await _shortcutEntityExists(candidate)) {
            return await createStartMenuEntry(
              appTitle: appTitle,
              executablePath: executablePath,
              iconPath: iconPath,
            );
          }
        }
      } else if (Platform.isWindows) {
        final appData = Platform.environment[AppTechnicalStrings.envAppData] ??
            AppTechnicalStrings.empty;
        if (appData.isEmpty) return false;
        final directPath = p.join(
          userHomeStartMenuBase(appData),
          appTitle + AppTechnicalStrings.extLnk,
        );
        final legacyPath = p.join(
          appData,
          AppTechnicalStrings.dirStartMenuLegacyHakkin,
          appTitle + AppTechnicalStrings.extLnk,
        );
        final rootProgramsPath = p.join(
          appData,
          AppTechnicalStrings.dirStartMenuPrograms,
          appTitle + AppTechnicalStrings.extLnk,
        );
        if (await _shortcutEntityExists(directPath) ||
            await _shortcutEntityExists(legacyPath) ||
            await _shortcutEntityExists(rootProgramsPath)) {
          return await createStartMenuEntry(
            appTitle: appTitle,
            executablePath: executablePath,
            iconPath: iconPath,
          );
        }
      } else if (Platform.isLinux) {
        final userHome = _getUserHome();
        if (userHome.isEmpty) return false;
        final slug = _toLinuxSlug(appTitle);
        final entryPath = p.join(
          userHome,
          AppTechnicalStrings.dirLinuxApps,
          slug + AppTechnicalStrings.extDesktop,
        );
        if (await _shortcutEntityExists(entryPath)) {
          return await createStartMenuEntry(
            appTitle: appTitle,
            executablePath: executablePath,
            iconPath: iconPath,
          );
        }
      }
    } catch (_) {}
    return false;
  }

  /// Elimina todos los accesos directos o enlaces simbólicos creados para una aplicación
  /// en cualquier ubicación del sistema (Escritorio, Start Menu, Aplicaciones/Launchpad, XDG).
  static Future<void> removeShortcutsForApp({
    required String appTitle,
    required String executablePath,
    String? installDirectory,
  }) async {
    try {
      final userHome = _getUserHome();

      if (Platform.isMacOS) {
        final candidates = <String>[
          if (userHome.isNotEmpty) ...[
            p.join(userHome, AppTechnicalStrings.dirDesktop, appTitle),
            p.join(userHome, AppTechnicalStrings.dirDesktop, appTitle + AppTechnicalStrings.extApp),
            p.join(userHome, AppTechnicalStrings.dirApplicationsUser, appTitle),
            p.join(
              userHome,
              AppTechnicalStrings.dirApplicationsUser,
              appTitle + AppTechnicalStrings.extApp,
            ),
          ],
          p.join(AppTechnicalStrings.dirApplicationsSystem, appTitle),
          p.join(AppTechnicalStrings.dirApplicationsSystem, appTitle + AppTechnicalStrings.extApp),
        ];

        for (final path in candidates) {
          await _deleteShortcutEntityIfExists(path);
        }

        // Inspeccionar enlaces simbólicos que apunten a executablePath o installDirectory
        final searchDirs = <String>[
          if (userHome.isNotEmpty) ...[
            p.join(userHome, AppTechnicalStrings.dirDesktop),
            p.join(userHome, AppTechnicalStrings.dirApplicationsUser),
          ],
          AppTechnicalStrings.dirApplicationsSystem,
        ];
        await _removeMatchingSymlinksInDirectories(
          directories: searchDirs,
          executablePath: executablePath,
          installDirectory: installDirectory,
        );
      } else if (Platform.isWindows) {
        final appData = Platform.environment[AppTechnicalStrings.envAppData] ??
            AppTechnicalStrings.empty;
        final oneDrive = Platform.environment[AppTechnicalStrings.envOneDrive] ??
            AppTechnicalStrings.empty;
        final lnkFileName = appTitle + AppTechnicalStrings.extLnk;

        final candidates = <String>[
          if (userHome.isNotEmpty)
            p.join(userHome, AppTechnicalStrings.dirDesktop, lnkFileName),
          if (oneDrive.isNotEmpty)
            p.join(oneDrive, AppTechnicalStrings.dirDesktop, lnkFileName),
          if (appData.isNotEmpty) ...[
            p.join(userHomeStartMenuBase(appData), lnkFileName),
            p.join(appData, AppTechnicalStrings.dirStartMenuLegacyHakkin, lnkFileName),
            p.join(appData, AppTechnicalStrings.dirStartMenuPrograms, lnkFileName),
          ],
        ];

        for (final path in candidates) {
          await _deleteShortcutEntityIfExists(path);
        }

        if (appData.isNotEmpty) {
          await _cleanupEmptyDirectory(p.join(appData, AppTechnicalStrings.dirStartMenu));
          await _cleanupEmptyDirectory(
            p.join(appData, AppTechnicalStrings.dirStartMenuLegacyHakkin),
          );
        }
      } else if (Platform.isLinux) {
        if (userHome.isEmpty) return;
        final slug = _toLinuxSlug(appTitle);
        final desktopFileName = slug + AppTechnicalStrings.extDesktop;
        final desktopDir = p.join(userHome, AppTechnicalStrings.dirDesktop);
        final appsDir = p.join(userHome, AppTechnicalStrings.dirLinuxApps);

        await _deleteShortcutEntityIfExists(p.join(desktopDir, desktopFileName));
        await _deleteShortcutEntityIfExists(p.join(appsDir, desktopFileName));

        // Escanear archivos .desktop que apunten al ejecutable o directorio de la aplicación
        await _removeMatchingLinuxDesktopEntries(
          directories: [desktopDir, appsDir],
          executablePath: executablePath,
          installDirectory: installDirectory,
        );
      }
    } catch (e) {
      debugPrint(AppStrings.logRemoveShortcutsError(e));
    }
  }

  /// Migra accesos directos de la subcarpeta heredada `Hakkin` hacia `HakkinLauncher`
  /// en Windows Start Menu y elimina la carpeta heredada.
  static Future<void> cleanupRedundantLauncherShortcuts() async {
    if (!Platform.isWindows) return;
    try {
      final appData = Platform.environment[AppTechnicalStrings.envAppData] ??
          AppTechnicalStrings.empty;
      if (appData.isEmpty) return;

      final legacyHakkinDir = Directory(
        p.join(appData, AppTechnicalStrings.dirStartMenuLegacyHakkin),
      );
      if (await legacyHakkinDir.exists()) {
        final targetHakkinLauncherDir = Directory(
          p.join(appData, AppTechnicalStrings.dirStartMenu),
        );
        await targetHakkinLauncherDir.create(recursive: true);

        await for (final entity in legacyHakkinDir.list(followLinks: false)) {
          if (entity is File && entity.path.endsWith(AppTechnicalStrings.extLnk)) {
            final destPath = p.join(targetHakkinLauncherDir.path, p.basename(entity.path));
            if (!await File(destPath).exists()) {
              await entity.copy(destPath);
            }
          }
        }
        await legacyHakkinDir.delete(recursive: true);
      }
    } catch (_) {}
  }

  static String userHomeStartMenuBase(String appData) =>
      p.join(appData, AppTechnicalStrings.dirStartMenu);

  static String _getUserHome() {
    return Platform.environment[AppTechnicalStrings.envHome] ??
        Platform.environment[AppTechnicalStrings.envUserProfile] ??
        AppTechnicalStrings.empty;
  }

  static String _toLinuxSlug(String appTitle) {
    return appTitle
        .toLowerCase()
        .replaceAll(AppTechnicalStrings.space, AppTechnicalStrings.underscore);
  }

  static Future<String> _resolveAndSanitizeMacOsTarget(String executablePath) async {
    var targetToLink = executablePath;
    final appBundleIdx = executablePath.indexOf(AppTechnicalStrings.extApp);
    if (appBundleIdx != -1) {
      targetToLink = executablePath.substring(
        0,
        appBundleIdx + AppTechnicalStrings.extApp.length,
      );

      // Saneamiento preventivo del bundle antes de crear el enlace simbólico
      try {
        final codeSigDir = Directory(p.join(
          targetToLink,
          AppTechnicalStrings.dirContents,
          AppTechnicalStrings.dirCodeSignature,
        ));
        if (!await codeSigDir.exists()) {
          await Process.run(
            AppTechnicalStrings.cmdCodesign,
            [
              AppTechnicalStrings.argForce,
              AppTechnicalStrings.argDeep,
              AppTechnicalStrings.argMinusS,
              AppTechnicalStrings.argMinus,
              targetToLink,
            ],
          );
        }
        await Process.run(
          AppTechnicalStrings.cmdXattr,
          [AppTechnicalStrings.argMinusCr, targetToLink],
        );
      } catch (_) {}
    }
    return targetToLink;
  }

  static Future<String> _resolveMacOsApplicationsDirectory(String userHome) async {
    final systemApps = Directory(AppTechnicalStrings.dirApplicationsSystem);
    if (await _canWriteToDirectory(systemApps)) {
      return systemApps.path;
    }
    if (userHome.isNotEmpty) {
      final userApps = Directory(p.join(userHome, AppTechnicalStrings.dirApplicationsUser));
      if (!await userApps.exists()) {
        await userApps.create(recursive: true);
      }
      return userApps.path;
    }
    return AppTechnicalStrings.empty;
  }

  static Future<bool> _canWriteToDirectory(Directory dir) async {
    try {
      if (!await dir.exists()) return false;
      final testFile = File(
        p.join(dir.path, AppTechnicalStrings.testHakkinWriteFile(pid)),
      );
      await testFile.writeAsString(AppTechnicalStrings.empty);
      await testFile.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _shortcutEntityExists(String path) async {
    final type = await FileSystemEntity.type(path, followLinks: false);
    return type == FileSystemEntityType.link || type == FileSystemEntityType.file;
  }

  static Future<void> _deleteShortcutEntityIfExists(String path) async {
    try {
      final type = await FileSystemEntity.type(path, followLinks: false);
      if (type == FileSystemEntityType.link) {
        await Link(path).delete();
      } else if (type == FileSystemEntityType.file) {
        await File(path).delete();
      }
    } catch (_) {}
  }

  static Future<void> _cleanupEmptyDirectory(String dirPath) async {
    try {
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        final entries = await dir.list(followLinks: false).toList();
        if (entries.isEmpty) {
          await dir.delete();
        }
      }
    } catch (_) {}
  }

  static Future<void> _removeMatchingSymlinksInDirectories({
    required List<String> directories,
    required String executablePath,
    String? installDirectory,
  }) async {
    final normExe = executablePath.isNotEmpty ? p.normalize(executablePath) : AppTechnicalStrings.empty;
    final normInstall = (installDirectory != null && installDirectory.isNotEmpty)
        ? p.normalize(installDirectory)
        : AppTechnicalStrings.empty;

    for (final dirPath in directories) {
      try {
        final dir = Directory(dirPath);
        if (!await dir.exists()) continue;
        await for (final entity in dir.list(followLinks: false)) {
          if (entity is Link) {
            try {
              final target = p.normalize(await entity.target());
              final matchesExe = normExe.isNotEmpty &&
                  (target == normExe || normExe.startsWith(target + AppTechnicalStrings.slash));
              final matchesInstall = normInstall.isNotEmpty &&
                  (target == normInstall ||
                      target.startsWith(normInstall + AppTechnicalStrings.slash));
              if (matchesExe || matchesInstall) {
                await entity.delete();
              }
            } catch (_) {}
          }
        }
      } catch (_) {}
    }
  }

  static Future<void> _removeMatchingLinuxDesktopEntries({
    required List<String> directories,
    required String executablePath,
    String? installDirectory,
  }) async {
    for (final dirPath in directories) {
      try {
        final dir = Directory(dirPath);
        if (!await dir.exists()) continue;
        await for (final entity in dir.list(followLinks: false)) {
          if (entity is File && entity.path.endsWith(AppTechnicalStrings.extDesktop)) {
            try {
              final content = await entity.readAsString();
              final matchesExe = executablePath.isNotEmpty && content.contains(executablePath);
              final matchesInstall = installDirectory != null &&
                  installDirectory.isNotEmpty &&
                  content.contains(installDirectory);
              if (matchesExe || matchesInstall) {
                await entity.delete();
              }
            } catch (_) {}
          }
        }
      } catch (_) {}
    }
  }

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
