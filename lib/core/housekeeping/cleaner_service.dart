import 'dart:io';
import '../platform/os_paths.dart';

/// Servicio de mantenimiento del sistema.
class CleanerService {
  CleanerService._();

  /// Limpia los archivos residuales en la carpeta de descargas temporales.
  static Future<int> cleanTemporaryFiles() async {
    int deletedCount = 0;
    try {
      final downloadsDir = await OsPaths.getDownloadsDirectory();
      if (await downloadsDir.exists()) {
        final entities = downloadsDir.listSync();
        for (final entity in entities) {
          if (entity is File) {
            final name = entity.path.toLowerCase();
            if (name.endsWith('.tmp') ||
                name.endsWith('.zip') ||
                name.endsWith('.hdiff') ||
                name.endsWith('.patch')) {
              await entity.delete();
              deletedCount++;
            }
          }
        }
      }
    } catch (_) {}
    return deletedCount;
  }

  /// Rota y limpia logs antiguos si superan el tamaño máximo de 10 MB.
  static Future<void> rotateLogs({int maxSizeBytes = 10 * 1024 * 1024}) async {
    try {
      final logsDir = await OsPaths.getLogsDirectory();
      if (await logsDir.exists()) {
        final entities = logsDir.listSync();
        int totalSize = 0;
        final logFiles = <File>[];

        for (final entity in entities) {
          if (entity is File) {
            totalSize += await entity.length();
            logFiles.add(entity);
          }
        }

        if (totalSize > maxSizeBytes) {
          // Ordenar por fecha de modificación y eliminar los más viejos
          logFiles.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
          for (final f in logFiles.take(logFiles.length ~/ 2)) {
            await f.delete();
          }
        }
      }
    } catch (_) {}
  }
}
