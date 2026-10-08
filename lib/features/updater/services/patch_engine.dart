import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../../../../core/crypto/hash_validator.dart';
import '../../../../core/housekeeping/cleaner_service.dart';
import '../../../../core/platform/notification_service.dart';
import '../../../../core/platform/os_paths.dart';
import '../../../../core/platform/process_launcher.dart';
import '../../catalog/data/models/app_entry.dart';
import '../../library/data/models/installed_app.dart';
import '../../library/data/repositories/library_repository.dart';
import 'downloader_service.dart';

enum UpdateStage {
  idle,
  checking,
  downloading,
  verifyingChecksum,
  runningPreScripts,
  applyingDelta,
  extractingFullPackage,
  preservingUserData,
  runningPostScripts,
  completed,
  failed,
}

class UpdateStatus {
  final UpdateStage stage;
  final String message;
  final double progress; // 0.0 a 1.0
  final String? error;

  const UpdateStatus({
    required this.stage,
    required this.message,
    this.progress = 0.0,
    this.error,
  });
}

/// Motor de instalación y actualización inteligente con soporte para Delta Patching, Fallback y Protección de Datos.
class PatchEngine {
  final DownloaderService _downloader;
  final LibraryRepository _libraryRepository;

  PatchEngine({
    DownloaderService? downloader,
    LibraryRepository? libraryRepository,
  })  : _downloader = downloader ?? DownloaderService(),
        _libraryRepository = libraryRepository ?? LibraryRepository();

  /// Ejecuta el flujo completo de instalación o actualización.
  Stream<UpdateStatus> installOrUpdate({
    required AppEntry app,
    required String platformKey,
    String? customInstallPath,
  }) async* {
    yield const UpdateStatus(
      stage: UpdateStage.checking,
      message: 'Comprobando estado de la aplicación...',
      progress: 0.05,
    );

    final platformRelease = app.getPlatformRelease(platformKey);
    if (platformRelease == null) {
      yield const UpdateStatus(
        stage: UpdateStage.failed,
        message: 'Esta aplicación no tiene versión para tu plataforma actual.',
        error: 'Plataforma no soportada',
      );
      return;
    }

    final installed = await _libraryRepository.getInstalledApp(app.id);
    final isAnUpdate = installed != null;
    final downloadsDir = await OsPaths.getDownloadsDirectory();
    final defaultAppsDir = await OsPaths.getDefaultAppsInstallDirectory();
    final targetInstallDir = Directory(
      customInstallPath ?? installed?.installDirectory ?? p.join(defaultAppsDir.path, app.slug),
    );

    // Determinar si es una actualización delta factible
    bool shouldAttemptDelta = false;
    DeltaUpdate? matchedDelta;

    if (installed != null && installed.installedVersion != app.latestVersion) {
      matchedDelta = platformRelease.findDeltaFor(
        installed.installedVersion,
        app.latestVersion,
      );
      if (matchedDelta != null) {
        shouldAttemptDelta = true;
      }
    }

    // 1. Intentar Delta Update si aplica
    if (shouldAttemptDelta && matchedDelta != null) {
      yield UpdateStatus(
        stage: UpdateStage.downloading,
        message: 'Descargando parche de actualización (${(matchedDelta.sizeBytes / 1048576).toStringAsFixed(1)} MB)...',
        progress: 0.1,
      );

      final patchFilePath = p.join(downloadsDir.path, '${app.slug}_update.hdiff');
      bool deltaSuccess = false;

      try {
        await _downloader.downloadFile(
          url: matchedDelta.url,
          destinationPath: patchFilePath,
          onProgress: (p) {},
        );

        // Verificar integridad del parche
        yield const UpdateStatus(
          stage: UpdateStage.verifyingChecksum,
          message: 'Verificando firma de seguridad del parche...',
          progress: 0.4,
        );

        final patchFile = File(patchFilePath);
        final patchValid = matchedDelta.patchSha256.isEmpty ||
            await HashValidator.verifySha256(patchFile, matchedDelta.patchSha256);

        if (patchValid) {
          // Ejecutar scripts pre-instalación si existen
          if (platformRelease.scripts.preInstall != null && await targetInstallDir.exists()) {
            yield const UpdateStatus(
              stage: UpdateStage.runningPreScripts,
              message: 'Ejecutando script previo a la actualización...',
              progress: 0.5,
            );
            final preScriptPath = p.join(targetInstallDir.path, platformRelease.scripts.preInstall);
            await ProcessLauncher.runScript(
              scriptPath: preScriptPath,
              workingDirectory: targetInstallDir.path,
            );
          }

          yield const UpdateStatus(
            stage: UpdateStage.applyingDelta,
            message: 'Aplicando parche diferencial...',
            progress: 0.6,
          );

          deltaSuccess = await _applyHDiffPatch(
            patchFile: patchFile,
            targetDirectory: targetInstallDir,
            executableRelativePath: platformRelease.executableRelativePath,
          );

          // Verificar hash del binario resultante post-patch
          if (deltaSuccess && matchedDelta.targetSha256.isNotEmpty) {
            final exeFile = File(p.join(targetInstallDir.path, platformRelease.executableRelativePath));
            if (await exeFile.exists()) {
              final hashMatch = await HashValidator.verifySha256(exeFile, matchedDelta.targetSha256);
              if (!hashMatch) {
                debugPrint('Aviso: Hash del binario tras parche no coincide. Descartando delta.');
                deltaSuccess = false;
              }
            } else {
              deltaSuccess = false;
            }
          }
        }
      } catch (e) {
        debugPrint('Fallo al aplicar parche delta: $e. Activando fallback.');
        deltaSuccess = false;
      }

      if (deltaSuccess) {
        // Ejecutar script post-instalación si existe
        if (platformRelease.scripts.postInstall != null && await targetInstallDir.exists()) {
          final postScriptPath = p.join(targetInstallDir.path, platformRelease.scripts.postInstall);
          await ProcessLauncher.runScript(
            scriptPath: postScriptPath,
            workingDirectory: targetInstallDir.path,
          );
        }

        // Delta exitoso
        await _finalizeInstallation(
          app: app,
          platformRelease: platformRelease,
          targetInstallDir: targetInstallDir,
          platformKey: platformKey,
        );

        await CleanerService.cleanTemporaryFiles();

        // Notificación nativa
        await NotificationService.notifyUpdateCompleted(app.title, app.latestVersion);

        yield const UpdateStatus(
          stage: UpdateStage.completed,
          message: '¡Actualización diferencial completada con éxito!',
          progress: 1.0,
        );
        return;
      }

      // Si el delta falló, continuamos de forma transparente al Full Package Fallback
      debugPrint('Activando descarga limpia de paquete completo (Fallback)');
    }

    // 2. Descarga de paquete completo (Instalación limpia o Fallback)
    final fullPkg = platformRelease.fullPackage;
    yield UpdateStatus(
      stage: UpdateStage.downloading,
      message: 'Descargando paquete completo (${(fullPkg.sizeBytes / 1048576).toStringAsFixed(1)} MB)...',
      progress: 0.2,
    );

    final fullPackageZipPath = p.join(downloadsDir.path, '${app.slug}_full.zip');

    try {
      await _downloader.downloadFile(
        url: fullPkg.url,
        destinationPath: fullPackageZipPath,
        onProgress: (p) {},
      );

      // Verificar SHA-256 del paquete completo
      yield const UpdateStatus(
        stage: UpdateStage.verifyingChecksum,
        message: 'Verificando integridad criptográfica del paquete...',
        progress: 0.5,
      );

      final zipFile = File(fullPackageZipPath);
      final isFullValid = fullPkg.sha256.isEmpty ||
          await HashValidator.verifySha256(zipFile, fullPkg.sha256);

      if (!isFullValid) {
        yield const UpdateStatus(
          stage: UpdateStage.failed,
          message: 'Error de integridad: el hash SHA-256 no coincide.',
          error: 'Hash mismatch',
        );
        return;
      }

      // Proteger datos de usuario si ya existía una instalación previa
      final userBackups = <String, List<int>>{};
      if (await targetInstallDir.exists() && platformRelease.protectedUserPaths.isNotEmpty) {
        yield const UpdateStatus(
          stage: UpdateStage.preservingUserData,
          message: 'Protegiendo partidas y configuraciones de usuario...',
          progress: 0.65,
        );

        for (final userRelPath in platformRelease.protectedUserPaths) {
          final cleanedRel = userRelPath.replaceAll('**', '').replaceAll('*', '');
          final protectedFile = File(p.join(targetInstallDir.path, cleanedRel));
          if (await protectedFile.exists()) {
            userBackups[cleanedRel] = await protectedFile.readAsBytes();
          }
        }
      }

      // Ejecutar scripts pre-instalación si existen
      if (platformRelease.scripts.preInstall != null && await targetInstallDir.exists()) {
        yield const UpdateStatus(
          stage: UpdateStage.runningPreScripts,
          message: 'Ejecutando script pre-instalación...',
          progress: 0.7,
        );
        final preScriptPath = p.join(targetInstallDir.path, platformRelease.scripts.preInstall);
        await ProcessLauncher.runScript(
          scriptPath: preScriptPath,
          workingDirectory: targetInstallDir.path,
        );
      }

      // Extracción del paquete
      yield const UpdateStatus(
        stage: UpdateStage.extractingFullPackage,
        message: 'Extrayendo archivos de la aplicación...',
        progress: 0.75,
      );

      if (!await targetInstallDir.exists()) {
        await targetInstallDir.create(recursive: true);
      }

      await _extractZip(zipFile, targetInstallDir);

      // Restaurar datos de usuario protegidos
      if (userBackups.isNotEmpty) {
        for (final entry in userBackups.entries) {
          final dest = File(p.join(targetInstallDir.path, entry.key));
          if (!await dest.parent.exists()) {
            await dest.parent.create(recursive: true);
          }
          await dest.writeAsBytes(entry.value);
        }
      }

      // Ejecutar scripts post-instalación si existen
      if (platformRelease.scripts.postInstall != null) {
        yield const UpdateStatus(
          stage: UpdateStage.runningPostScripts,
          message: 'Ejecutando script post-instalación...',
          progress: 0.9,
        );
        final scriptPath = p.join(targetInstallDir.path, platformRelease.scripts.postInstall);
        await ProcessLauncher.runScript(
          scriptPath: scriptPath,
          workingDirectory: targetInstallDir.path,
        );
      }

      // Finalizar y registrar en la biblioteca
      await _finalizeInstallation(
        app: app,
        platformRelease: platformRelease,
        targetInstallDir: targetInstallDir,
        platformKey: platformKey,
      );

      // Limpieza de temporales
      await CleanerService.cleanTemporaryFiles();

      // Emitir notificación nativa
      if (isAnUpdate) {
        await NotificationService.notifyUpdateCompleted(app.title, app.latestVersion);
      } else {
        await NotificationService.notifyInstallCompleted(app.title);
      }

      yield const UpdateStatus(
        stage: UpdateStage.completed,
        message: '¡Instalación completada correctamente!',
        progress: 1.0,
      );
    } catch (e) {
      yield UpdateStatus(
        stage: UpdateStage.failed,
        message: 'Ocurrió un error durante la instalación: $e',
        error: e.toString(),
      );
    }
  }

  /// Aplica el parche binario hpatchz si está disponible en el entorno o en bundle.
  Future<bool> _applyHDiffPatch({
    required File patchFile,
    required Directory targetDirectory,
    required String executableRelativePath,
  }) async {
    try {
      final exeFile = File(p.join(targetDirectory.path, executableRelativePath));
      if (!await exeFile.exists()) return false;

      // Intentar ejecutar el comando nativo hpatchz
      final result = await Process.run(
        'hpatchz',
        [exeFile.path, patchFile.path, exeFile.path],
      );
      return result.exitCode == 0;
    } catch (_) {
      // Si no hay utilería hpatchz instalada globalmente, indicamos fallback
      return false;
    }
  }

  /// Extrae un archivo ZIP en el directorio destino de forma asíncrona.
  Future<void> _extractZip(File zipFile, Directory targetDirectory) async {
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    for (final file in archive) {
      final filename = file.name;
      final outPath = p.join(targetDirectory.path, filename);
      if (file.isFile) {
        final outFile = File(outPath);
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);
      } else {
        await Directory(outPath).create(recursive: true);
      }
    }
  }

  Future<void> _finalizeInstallation({
    required AppEntry app,
    required PlatformRelease platformRelease,
    required Directory targetInstallDir,
    required String platformKey,
  }) async {
    final exePath = p.join(targetInstallDir.path, platformRelease.executableRelativePath);

    // Asegurar permisos de ejecución en macOS / Linux
    if (Platform.isMacOS || Platform.isLinux) {
      try {
        await Process.run('chmod', ['+x', exePath]);
      } catch (_) {}
    }

    final installedApp = InstalledApp(
      id: app.id,
      title: app.title,
      installedVersion: app.latestVersion,
      executablePath: exePath,
      installDirectory: targetInstallDir.path,
      installedAt: DateTime.now(),
      sizeBytes: platformRelease.fullPackage.sizeBytes,
      platformKey: platformKey,
    );

    await _libraryRepository.saveInstalledApp(installedApp);
  }
}
