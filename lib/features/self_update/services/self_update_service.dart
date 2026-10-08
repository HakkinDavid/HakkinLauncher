import 'dart:io';
import 'package:path/path.dart' as p;
import '../../../core/constants/app_constants.dart';
import '../../../core/crypto/hash_validator.dart';
import '../../../core/platform/notification_service.dart';
import '../../../core/platform/os_paths.dart';
import '../../catalog/data/models/app_entry.dart';
import '../../updater/services/downloader_service.dart';

enum SelfUpdateStage {
  idle,
  checking,
  updateAvailable,
  downloading,
  verifyingChecksum,
  readyToRestart,
  error,
}

class SelfUpdateStatus {
  final SelfUpdateStage stage;
  final String message;
  final double progress;
  final String? newVersion;
  final String? error;

  const SelfUpdateStatus({
    required this.stage,
    required this.message,
    this.progress = 0.0,
    this.newVersion,
    this.error,
  });
}

/// Servicio encargado de la auto-actualización autónoma y atómica de HakkinLauncher.
class SelfUpdateService {
  final DownloaderService _downloader;

  SelfUpdateService({DownloaderService? downloader})
      : _downloader = downloader ?? DownloaderService();

  /// Comprueba si hay una nueva versión disponible del propio lanzador.
  bool isUpdateAvailable(LauncherMeta? launcherMeta) {
    if (launcherMeta == null) return false;
    return launcherMeta.latestVersion != AppConstants.appVersion;
  }

  /// Ejecuta el flujo completo de auto-actualización del lanzador.
  Stream<SelfUpdateStatus> performSelfUpdate(LauncherMeta launcherMeta) async* {
    yield const SelfUpdateStatus(
      stage: SelfUpdateStage.checking,
      message: 'Comprobando paquetes del lanzador...',
      progress: 0.1,
    );

    final platformKey = OsPaths.getCurrentPlatformKey();
    final releaseData = launcherMeta.releases[platformKey];

    if (releaseData == null) {
      yield const SelfUpdateStatus(
        stage: SelfUpdateStage.error,
        message: 'No hay paquete del lanzador para tu plataforma actual.',
        error: 'Plataforma no soportada',
      );
      return;
    }

    final downloadUrl = releaseData['url'] as String?;
    final expectedSha256 = (releaseData['sha256'] as String?) ?? '';

    if (downloadUrl == null || downloadUrl.isEmpty) {
      yield const SelfUpdateStatus(
        stage: SelfUpdateStage.error,
        message: 'URL de descarga de la actualización no válida.',
        error: 'URL vacía',
      );
      return;
    }

    // 1. Descarga del paquete de actualización
    final downloadsDir = await OsPaths.getDownloadsDirectory();
    final updateZipPath = p.join(downloadsDir.path, 'hakkin_launcher_update.zip');

    yield SelfUpdateStatus(
      stage: SelfUpdateStage.downloading,
      message: 'Descargando actualización v${launcherMeta.latestVersion}...',
      progress: 0.2,
      newVersion: launcherMeta.latestVersion,
    );

    try {
      await _downloader.downloadFile(
        url: downloadUrl,
        destinationPath: updateZipPath,
        onProgress: (p) {},
      );

      // 2. Verificación criptográfica
      yield const SelfUpdateStatus(
        stage: SelfUpdateStage.verifyingChecksum,
        message: 'Verificando integridad del nuevo lanzador...',
        progress: 0.6,
      );

      final zipFile = File(updateZipPath);
      if (expectedSha256.isNotEmpty) {
        final isValid = await HashValidator.verifySha256(zipFile, expectedSha256);
        if (!isValid) {
          yield const SelfUpdateStatus(
            stage: SelfUpdateStage.error,
            message: 'Error de integridad: el hash SHA-256 no coincide.',
            error: 'Hash mismatch',
          );
          return;
        }
      }

      // 3. Preparación del script de reemplazo y reinicio autónomo
      yield const SelfUpdateStatus(
        stage: SelfUpdateStage.readyToRestart,
        message: 'Preparando reinicio del lanzador...',
        progress: 0.9,
      );

      await NotificationService.showNotification(
        title: 'Actualización lista',
        body: 'HakkinLauncher se reiniciará para aplicar la nueva versión.',
      );

      await _applyUpdateAndRestart(zipFile);

      yield const SelfUpdateStatus(
        stage: SelfUpdateStage.readyToRestart,
        message: 'Reiniciando...',
        progress: 1.0,
      );
    } catch (e) {
      yield SelfUpdateStatus(
        stage: SelfUpdateStage.error,
        message: 'Error durante la auto-actualización: $e',
        error: e.toString(),
      );
    }
  }

  /// Lanza el proceso helper desacoplado y finaliza el proceso actual.
  Future<void> _applyUpdateAndRestart(File zipFile) async {
    final currentPid = pid;
    final currentExePath = Platform.resolvedExecutable;
    final appDir = File(currentExePath).parent.path;

    if (Platform.isMacOS) {
      // En macOS, si es bundle .app, apuntamos al contenedor .app
      String targetAppPath = currentExePath;
      if (currentExePath.contains('.app/Contents/MacOS')) {
        targetAppPath = '${currentExePath.split('.app/Contents/MacOS').first}.app';
      }

      final scriptFile = File(p.join(zipFile.parent.path, 'update_helper.sh'));
      await scriptFile.writeAsString('''#!/bin/bash
while kill -0 $currentPid 2>/dev/null; do
    sleep 0.5
done
unzip -o "${zipFile.path}" -d "$appDir"
open "$targetAppPath"
rm -f "${zipFile.path}"
rm -f "\$0"
''');
      await Process.run('chmod', ['+x', scriptFile.path]);

      // Lanzar desacoplado
      await Process.start('/bin/bash', [scriptFile.path], mode: ProcessStartMode.detached);
      exit(0);
    } else if (Platform.isWindows) {
      final scriptFile = File(p.join(zipFile.parent.path, 'update_helper.bat'));
      await scriptFile.writeAsString('''@echo off
timeout /t 2 /nobreak > nul
tar -xf "${zipFile.path}" -C "$appDir"
start "" "$currentExePath"
del "${zipFile.path}"
del "%~f0"
''');

      await Process.start('cmd', ['/c', scriptFile.path], mode: ProcessStartMode.detached);
      exit(0);
    } else if (Platform.isLinux) {
      final scriptFile = File(p.join(zipFile.parent.path, 'update_helper.sh'));
      await scriptFile.writeAsString('''#!/bin/bash
while kill -0 $currentPid 2>/dev/null; do
    sleep 0.5
done
tar -xzf "${zipFile.path}" -C "$appDir"
"$currentExePath" &
rm -f "${zipFile.path}"
rm -f "\$0"
''');
      await Process.run('chmod', ['+x', scriptFile.path]);
      await Process.start('/bin/bash', [scriptFile.path], mode: ProcessStartMode.detached);
      exit(0);
    }
  }
}
