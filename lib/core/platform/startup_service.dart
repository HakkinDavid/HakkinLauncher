import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../constants/app_strings.dart';
import '../constants/app_technical_strings.dart';

/// Servicio para gestionar la ejecución automática de HakkinLauncher al arranque del sistema.
class StartupService {
  StartupService._();

  /// Determina si la instancia actual fue iniciada automáticamente por el arranque del sistema.
  static bool isLaunchedFromStartup([List<String> args = const []]) {
    if (args.contains(AppTechnicalStrings.argStartup)) {
      return true;
    }
    if (Platform.executableArguments.contains(AppTechnicalStrings.argStartup)) {
      return true;
    }
    if (Platform.environment[AppTechnicalStrings.envHakkinStartup] ==
        AppTechnicalStrings.valStartupActive) {
      return true;
    }
    return false;
  }

  /// Persiste el estado de visibilidad previo a una autoactualización para restaurarlo tras el reinicio.
  static Future<void> savePostUpdateHiddenState(bool isHidden) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.prefPostUpdateHiddenKey, isHidden);
    } catch (e) {
      debugPrint(AppStrings.logStartupServiceError(e));
    }
  }

  /// Resuelve si el lanzador debe iniciar oculto o en primer plano, consumiendo el estado
  /// persistido previo a una autoactualización si existe o recurriendo a la detección de arranque del sistema.
  static Future<bool> resolveStartHidden([List<String> args = const []]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(AppConstants.prefPostUpdateHiddenKey)) {
        final postUpdateHidden =
            prefs.getBool(AppConstants.prefPostUpdateHiddenKey) ?? false;
        await prefs.remove(AppConstants.prefPostUpdateHiddenKey);
        return postUpdateHidden;
      }
    } catch (e) {
      debugPrint(AppStrings.logStartupServiceError(e));
    }
    return isLaunchedFromStartup(args);
  }

  /// Inicializa el estado de arranque del sistema, activándolo por defecto si no se ha configurado.
  static Future<void> initialize() async {
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final bool enabled;
      if (prefs.containsKey(AppConstants.prefLaunchAtStartupKey)) {
        enabled = prefs.getBool(AppConstants.prefLaunchAtStartupKey) ?? true;
      } else {
        enabled = true;
        await prefs.setBool(AppConstants.prefLaunchAtStartupKey, true);
      }

      // Evitar registrar rutas temporales de volúmenes montados (.dmg) en macOS
      if (Platform.isMacOS &&
          Platform.resolvedExecutable.startsWith(AppTechnicalStrings.dirVolumes)) {
        return;
      }

      await setLaunchAtStartup(enabled);
    } catch (e) {
      debugPrint(AppStrings.logStartupServiceError(e));
    }
  }

  /// Activa o desactiva la ejecución automática de HakkinLauncher al iniciar sesión en el sistema operativo.
  static Future<bool> setLaunchAtStartup(
    bool enabled, {
    String? customHomeDir,
    String? customExecutablePath,
  }) async {
    try {
      final executablePath = customExecutablePath ?? Platform.resolvedExecutable;
      if (executablePath.isEmpty) return false;

      if (Platform.isMacOS) {
        final userHome = customHomeDir ?? _getUserHome();
        if (userHome.isEmpty) return false;

        final launchAgentsDir = Directory(
          p.join(userHome, AppTechnicalStrings.dirMacOsLaunchAgents),
        );
        final plistFile = File(
          p.join(
            launchAgentsDir.path,
            AppTechnicalStrings.fileMacOsLaunchAgentPlist,
          ),
        );

        if (enabled) {
          if (!await launchAgentsDir.exists()) {
            await launchAgentsDir.create(recursive: true);
          }
          final plistContent = AppTechnicalStrings.generateMacOsLaunchAgentPlist(
            label: AppTechnicalStrings.launcherId1,
            executablePath: executablePath,
          );
          await plistFile.writeAsString(plistContent);
        } else {
          if (await plistFile.exists()) {
            await plistFile.delete();
          }
        }
        return true;
      } else if (Platform.isWindows) {
        if (enabled) {
          final res = await Process.run(
            AppTechnicalStrings.cmdReg,
            [
              AppTechnicalStrings.argAdd,
              AppTechnicalStrings.winRegistryRunKey,
              AppTechnicalStrings.argSlashV,
              AppConstants.appName,
              AppTechnicalStrings.argSlashT,
              AppTechnicalStrings.argRegSz,
              AppTechnicalStrings.argSlashD,
              AppTechnicalStrings.windowsStartupCommand(executablePath),
              AppTechnicalStrings.argSlashF,
            ],
          );
          return res.exitCode == 0;
        } else {
          await Process.run(
            AppTechnicalStrings.cmdReg,
            [
              AppTechnicalStrings.argDelete,
              AppTechnicalStrings.winRegistryRunKey,
              AppTechnicalStrings.argSlashV,
              AppConstants.appName,
              AppTechnicalStrings.argSlashF,
            ],
          );
          // Limpiar también cualquier acceso directo en la carpeta Startup si existiera
          final appData =
              Platform.environment[AppTechnicalStrings.envAppData] ??
                  AppTechnicalStrings.empty;
          if (appData.isNotEmpty) {
            final startupLnk = File(
              p.join(
                appData,
                AppTechnicalStrings.dirWindowsStartup,
                AppConstants.appName + AppTechnicalStrings.extLnk,
              ),
            );
            if (await startupLnk.exists()) {
              await startupLnk.delete();
            }
          }
          return true;
        }
      } else if (Platform.isLinux) {
        final userHome = customHomeDir ?? _getUserHome();
        if (userHome.isEmpty) return false;

        final autostartDir = Directory(
          p.join(userHome, AppTechnicalStrings.dirLinuxAutostart),
        );
        final desktopFile = File(
          p.join(
            autostartDir.path,
            AppTechnicalStrings.fileLinuxAutostartDesktop,
          ),
        );

        if (enabled) {
          if (!await autostartDir.exists()) {
            await autostartDir.create(recursive: true);
          }
          final content =
              AppTechnicalStrings.generateLinuxAutostartDesktopEntry(
            appTitle: AppConstants.appName,
            executablePath: executablePath,
            workingDir: File(executablePath).parent.path,
          );
          await desktopFile.writeAsString(content);
          await Process.run(
            AppTechnicalStrings.cmdChmod,
            [AppTechnicalStrings.argPlusX, desktopFile.path],
          );
        } else {
          if (await desktopFile.exists()) {
            await desktopFile.delete();
          }
        }
        return true;
      }
    } catch (e) {
      debugPrint(AppStrings.logStartupServiceError(e));
    }
    return false;
  }

  /// Comprueba si el lanzador se encuentra registrado en el arranque del sistema operativo.
  static Future<bool> isRegisteredInSystem({String? customHomeDir}) async {
    try {
      if (Platform.isMacOS) {
        final userHome = customHomeDir ?? _getUserHome();
        if (userHome.isEmpty) return false;
        final plistFile = File(
          p.join(
            userHome,
            AppTechnicalStrings.dirMacOsLaunchAgents,
            AppTechnicalStrings.fileMacOsLaunchAgentPlist,
          ),
        );
        return await plistFile.exists();
      } else if (Platform.isWindows) {
        final res = await Process.run(
          AppTechnicalStrings.cmdReg,
          [
            AppTechnicalStrings.argQuery,
            AppTechnicalStrings.winRegistryRunKey,
            AppTechnicalStrings.argSlashV,
            AppConstants.appName,
          ],
        );
        return res.exitCode == 0;
      } else if (Platform.isLinux) {
        final userHome = customHomeDir ?? _getUserHome();
        if (userHome.isEmpty) return false;
        final desktopFile = File(
          p.join(
            userHome,
            AppTechnicalStrings.dirLinuxAutostart,
            AppTechnicalStrings.fileLinuxAutostartDesktop,
          ),
        );
        return await desktopFile.exists();
      }
    } catch (_) {}
    return false;
  }

  static String _getUserHome() {
    return Platform.environment[AppTechnicalStrings.envHome] ??
        Platform.environment[AppTechnicalStrings.envUserProfile] ??
        AppTechnicalStrings.empty;
  }
}
