import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../constants/app_technical_strings.dart';

/// Gestor de rutas del sistema operativo para HakkinLauncher.
class OsPaths {
  OsPaths._();

  /// Obtiene la carpeta base de datos de HakkinLauncher según el S.O.
  static Future<Directory> getAppBaseDirectory() async {
    final supportDir = await getApplicationSupportDirectory();
    final dir = Directory(p.join(supportDir.path, AppTechnicalStrings.dirHakkinLauncher));
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
