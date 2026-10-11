import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../constants/app_strings.dart';
import '../constants/app_technical_strings.dart';

/// Gestor de rutas del sistema operativo para HakkinLauncher.
class OsPaths {
  OsPaths._();

  /// Obtiene la carpeta base de datos de HakkinLauncher según el S.O.,
  /// operando directamente a nivel de la carpeta con el identificador del paquete.
  static Future<Directory> getAppBaseDirectory() async {
    final supportDir = await getApplicationSupportDirectory();
    final dir = (Platform.isWindows &&
            p.basename(supportDir.path) == AppTechnicalStrings.dirHakkinLauncher &&
            p.basename(supportDir.parent.path) == AppTechnicalStrings.launcherId1)
        ? supportDir.parent
        : supportDir;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Carpeta donde se instalan las aplicaciones y juegos por defecto.
  static Future<Directory> getDefaultAppsInstallDirectory() async {
    final base = await getAppBaseDirectory();
    final appsDir = Directory(p.join(base.path, AppTechnicalStrings.dirApps));
    if (!await appsDir.exists()) {
      await appsDir.create(recursive: true);
    }
    return appsDir;
  }

  /// Carpeta de staging y descargas temporales.
  static Future<Directory> getDownloadsDirectory() async {
    final base = await getAppBaseDirectory();
    final downloadsDir = Directory(p.join(base.path, AppTechnicalStrings.dirDownloads));
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }
    return downloadsDir;
  }

  /// Carpeta de logs de ejecución.
  static Future<Directory> getLogsDirectory() async {
    final base = await getAppBaseDirectory();
    final logsDir = Directory(p.join(base.path, AppTechnicalStrings.dirLogs));
    if (!await logsDir.exists()) {
      await logsDir.create(recursive: true);
    }
    return logsDir;
  }

  /// Carpeta donde se almacenan y ejecutan binarios y herramientas auxiliares (ej. hpatchz).
  static Future<Directory> getToolsDirectory() async {
    final base = await getAppBaseDirectory();
    final toolsDir = Directory(p.join(base.path, AppTechnicalStrings.dirTools));
    if (!await toolsDir.exists()) {
      await toolsDir.create(recursive: true);
    }
    return toolsDir;
  }

  /// Retorna la referencia al archivo de una herramienta según el sistema operativo.
  static Future<File> getToolFile(String toolName) async {
    final toolsDir = await getToolsDirectory();
    final ext = Platform.isWindows ? AppTechnicalStrings.extExe : AppTechnicalStrings.empty;
    return File(p.join(toolsDir.path, toolName + ext));
  }

  /// Abre el selector nativo de carpetas del sistema operativo (Finder, Explorador de archivos, etc.).
  /// Retorna la ruta seleccionada o `null` si el usuario cancela la operación.
  static Future<String?> pickDirectory({String? initialDirectory}) async {
    try {
      String? validInitialDir;
      if (initialDirectory != null && initialDirectory.isNotEmpty) {
        final dir = Directory(initialDirectory);
        if (await dir.exists()) {
          validInitialDir = dir.path;
        } else if (await dir.parent.exists()) {
          validInitialDir = dir.parent.path;
        }
      }

      if (Platform.isMacOS) {
        var script = AppTechnicalStrings.generateMacOsChooseFolderScript(
          prompt: AppStrings.selectInstallDirectoryPrompt,
          defaultLocation: validInitialDir,
        );
        var result = await Process.run(
          AppTechnicalStrings.cmdOsascript,
          [AppTechnicalStrings.argMinusE, script],
        );
        if (result.exitCode != 0 && validInitialDir != null) {
          // Si el usuario canceló (código -128 en AppleScript), no reintentar
          final errOut = result.stderr.toString();
          if (!errOut.contains(AppTechnicalStrings.appleScriptCancelCode)) {
            script = AppTechnicalStrings.generateMacOsChooseFolderScript(
              prompt: AppStrings.selectInstallDirectoryPrompt,
            );
            result = await Process.run(
              AppTechnicalStrings.cmdOsascript,
              [AppTechnicalStrings.argMinusE, script],
            );
          }
        }
        if (result.exitCode == 0) {
          final rawPath = result.stdout.toString().trim();
          if (rawPath.isNotEmpty) {
            return p.normalize(Directory(rawPath).path);
          }
        }
        return null;
      } else if (Platform.isWindows) {
        final script = AppTechnicalStrings.generateWindowsChooseFolderScript(
          description: AppStrings.selectInstallDirectoryPrompt,
          initialDirectory: validInitialDir,
        );
        final result = await Process.run(
          AppTechnicalStrings.cmdPowershell,
          [
            AppTechnicalStrings.argNoProfile,
            AppTechnicalStrings.argMinusCommand,
            script,
          ],
        );
        if (result.exitCode == 0) {
          final rawPath = result.stdout.toString().trim();
          if (rawPath.isNotEmpty) {
            return p.normalize(Directory(rawPath).path);
          }
        }
        return null;
      } else if (Platform.isLinux) {
        try {
          final result = await Process.run(
            AppTechnicalStrings.cmdZenity,
            [
              AppTechnicalStrings.argFileSelection,
              AppTechnicalStrings.argDirectory,
              AppTechnicalStrings.zenityTitleArg(
                AppStrings.selectInstallDirectoryPrompt,
              ),
            ],
          );
          if (result.exitCode == 0) {
            final rawPath = result.stdout.toString().trim();
            if (rawPath.isNotEmpty) {
              return p.normalize(Directory(rawPath).path);
            }
          }
          return null;
        } catch (_) {
          final result = await Process.run(
            AppTechnicalStrings.cmdKdialog,
            [
              AppTechnicalStrings.argGetExistingDirectory,
              validInitialDir ?? AppTechnicalStrings.empty,
            ],
          );
          if (result.exitCode == 0) {
            final rawPath = result.stdout.toString().trim();
            if (rawPath.isNotEmpty) {
              return p.normalize(Directory(rawPath).path);
            }
          }
          return null;
        }
      }
    } catch (e) {
      debugPrint(AppStrings.logDirectoryPickerError(e));
    }
    return null;
  }

  /// Abre la carpeta indicada en el explorador de archivos nativo del sistema operativo.
  static Future<bool> openDirectory(String directoryPath) async {
    try {
      if (directoryPath.isEmpty) return false;
      final dir = Directory(directoryPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      if (Platform.isMacOS) {
        final result = await Process.run(
          AppTechnicalStrings.cmdOpen,
          [dir.path],
        );
        return result.exitCode == 0;
      } else if (Platform.isWindows) {
        await Process.run(
          AppTechnicalStrings.cmdExplorer,
          [dir.path],
        );
        return true;
      } else if (Platform.isLinux) {
        final result = await Process.run(
          AppTechnicalStrings.cmdXdgOpen,
          [dir.path],
        );
        return result.exitCode == 0;
      }
    } catch (e) {
      debugPrint(AppStrings.logOpenDirectoryError(e));
    }
    return false;
  }

  /// Identificador de la plataforma actual compatible con el esquema de plataformas del catálogo.
  static String getCurrentPlatformKey() {
    if (Platform.isWindows) {
      return AppTechnicalStrings.platformWindowsX64;
    } else if (Platform.isMacOS) {
      // Diferenciar Apple Silicon vs Intel
      // Por convención si es arm64 o fallback x64
      final arch = Platform.version.toLowerCase();
      if (arch.contains(AppTechnicalStrings.archArm64) ||
          arch.contains(AppTechnicalStrings.archAarch64)) {
        return AppTechnicalStrings.platformMacosArm64;
      }
      return AppTechnicalStrings.platformMacosX64;
    } else if (Platform.isLinux) {
      return AppTechnicalStrings.platformLinuxX64;
    } else if (Platform.isAndroid) {
      return AppTechnicalStrings.platformAndroid;
    } else if (Platform.isIOS) {
      return AppTechnicalStrings.platformIos;
    }
    return AppTechnicalStrings.platformUnknown;
  }
}
