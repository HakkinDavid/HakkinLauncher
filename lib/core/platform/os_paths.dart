import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Gestor de rutas del sistema operativo para HakkinLauncher.
class OsPaths {
  OsPaths._();

  /// Obtiene la carpeta base de datos de HakkinLauncher según el S.O.
  static Future<Directory> getAppBaseDirectory() async {
    final supportDir = await getApplicationSupportDirectory();
    final dir = Directory(p.join(supportDir.path, 'HakkinLauncher'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Carpeta donde se instalan las aplicaciones y juegos por defecto.
  static Future<Directory> getDefaultAppsInstallDirectory() async {
    final base = await getAppBaseDirectory();
    final appsDir = Directory(p.join(base.path, 'Apps'));
    if (!await appsDir.exists()) {
      await appsDir.create(recursive: true);
    }
    return appsDir;
  }

  /// Carpeta de staging y descargas temporales.
  static Future<Directory> getDownloadsDirectory() async {
    final base = await getAppBaseDirectory();
    final downloadsDir = Directory(p.join(base.path, 'Downloads'));
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }
    return downloadsDir;
  }

  /// Carpeta de logs de ejecución.
  static Future<Directory> getLogsDirectory() async {
    final base = await getAppBaseDirectory();
    final logsDir = Directory(p.join(base.path, 'Logs'));
    if (!await logsDir.exists()) {
      await logsDir.create(recursive: true);
    }
    return logsDir;
  }

  /// Identificador de la plataforma actual compatible con el esquema de plataformas del catálogo.
  static String getCurrentPlatformKey() {
    if (Platform.isWindows) {
      return 'windows-x64';
    } else if (Platform.isMacOS) {
      // Diferenciar Apple Silicon vs Intel
      // Por convención si es arm64 o fallback x64
      final arch = Platform.version.toLowerCase();
      if (arch.contains('arm64') || arch.contains('aarch64')) {
        return 'macos-arm64';
      }
      return 'macos-x64';
    } else if (Platform.isLinux) {
      return 'linux-x64';
    } else if (Platform.isAndroid) {
      return 'android';
    } else if (Platform.isIOS) {
      return 'ios';
    }
    return 'unknown';
  }
}
