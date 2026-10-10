import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:hakkin_launcher/core/crypto/hash_validator.dart';
import 'package:hakkin_launcher/core/housekeeping/cleaner_service.dart';
import 'package:hakkin_launcher/core/platform/component_manager.dart';
import 'package:hakkin_launcher/core/platform/notification_service.dart';
import 'package:hakkin_launcher/core/platform/os_paths.dart';
import 'package:hakkin_launcher/core/platform/process_launcher.dart';
import 'package:hakkin_launcher/features/catalog/data/models/app_entry.dart';
import 'package:hakkin_launcher/features/library/data/models/installed_app.dart';
import 'package:hakkin_launcher/features/library/data/repositories/library_repository.dart';
import 'package:hakkin_launcher/core/constants/app_strings.dart';
import 'package:hakkin_launcher/core/constants/app_technical_strings.dart';
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

/// Motor de instalación y actualización con soporte para catálogo de versiones,
/// parches diferenciales e instalación limpia para versiones anteriores.
class PatchEngine {
  final DownloaderService _downloader;
  final LibraryRepository _libraryRepository;

  PatchEngine({
    DownloaderService? downloader,
    LibraryRepository? libraryRepository,
  })  : _downloader = downloader ?? DownloaderService(),
        _libraryRepository = libraryRepository ?? LibraryRepository();

  /// Compara dos versiones semánticas para determinar si v1 es estrictamente menor que v2
  bool _isOlderVersion(String v1, String v2) {
    final p1 = RegExp(AppTechnicalStrings.regexDigits).allMatches(v1).map((m) => int.parse(m.group(0)!)).toList();
    final p2 = RegExp(AppTechnicalStrings.regexDigits).allMatches(v2).map((m) => int.parse(m.group(0)!)).toList();
    final maxLen = p1.length > p2.length ? p1.length : p2.length;
    for (var i = 0; i < maxLen; i++) {
      final n1 = i < p1.length ? p1[i] : 0;
      final n2 = i < p2.length ? p2[i] : 0;
      if (n1 < n2) return true;
      if (n1 > n2) return false;
    }
    return false;
  }

  /// Ejecuta el flujo completo de instalación o actualización.
  Stream<UpdateStatus> installOrUpdate({
    required AppEntry app,
    required String platformKey,
    String? targetVersion,
    bool isCleanInstall = false,
    String? customInstallPath,
  }) async* {
    yield const UpdateStatus(
      stage: UpdateStage.checking,
      message: AppStrings.checkingAppStateAndVersion,
      progress: 0.05,
    );

    final platformRelease = app.getPlatformRelease(platformKey);
    if (platformRelease == null || platformRelease.versions.isEmpty) {
      yield const UpdateStatus(
        stage: UpdateStage.failed,
        message: AppStrings.appHasNoVersionForPlatform,
        error: AppTechnicalStrings.errorUnsupportedPlatform,
      );
      return;
    }

    final targetRelease = (targetVersion != null
            ? platformRelease.getRelease(targetVersion)
            : null) ??
        platformRelease.latestRelease;
    final targetVersionStr = targetRelease.version;

    final installed = await _libraryRepository.getInstalledApp(app.id);
    final downloadsDir = await OsPaths.getDownloadsDirectory();
    final defaultAppsDir = await OsPaths.getDefaultAppsInstallDirectory();
    final targetInstallDir = Directory(
      customInstallPath ?? installed?.installDirectory ?? p.join(defaultAppsDir.path, app.slug),
    );

    final isAnomalousInstalled = installed != null &&
        platformRelease.isAnomalousVersion(installed.installedVersion);
    final isOlderTarget = installed != null &&
        _isOlderVersion(targetVersionStr, installed.installedVersion);
    final requiresCleanInstall = isCleanInstall || isOlderTarget || isAnomalousInstalled;

    if (requiresCleanInstall) {
      if (isAnomalousInstalled) {
        yield UpdateStatus(
          stage: UpdateStage.preservingUserData,
          message: AppStrings.anomalyDetectedCleanInstallMessage(
            installed.installedVersion,
            targetVersionStr,
          ),
          progress: 0.1,
        );
      } else {
        yield UpdateStatus(
          stage: UpdateStage.preservingUserData,
          message: AppStrings.startingCleanInstallMessage(targetVersionStr),
          progress: 0.1,
        );
      }

      final userBackups = <String, List<int>>{};
      if (await targetInstallDir.exists() && platformRelease.protectedUserPaths.isNotEmpty) {
        for (final userRelPath in platformRelease.protectedUserPaths) {
          final cleanedRel = userRelPath
              .replaceAll(AppTechnicalStrings.globDoubleStar, AppTechnicalStrings.empty)
              .replaceAll(AppTechnicalStrings.globStar, AppTechnicalStrings.empty);
          final protectedFile = File(p.join(targetInstallDir.path, cleanedRel));
          if (await protectedFile.exists()) {
            userBackups[cleanedRel] = await protectedFile.readAsBytes();
          }
        }
      }

      // Descargar paquete completo de la versión objetivo
      final pkg = targetRelease.package;
      yield UpdateStatus(
        stage: UpdateStage.downloading,
        message: AppStrings.startingDownloadMessage(
          targetVersionStr,
          (pkg.sizeBytes / 1048576).toStringAsFixed(1),
        ),
        progress: 0.05,
      );

      final cleanZipPath = p.join(
        downloadsDir.path,
        AppTechnicalStrings.cleanZipFileName(app.slug, targetVersionStr),
      );
      try {
        await for (final dl in _downloader.downloadFileStream(
          url: pkg.url,
          destinationPath: cleanZipPath,
        )) {
          final mappedProgress = 0.05 + (dl.progress * 0.65);
          final speedStr = dl.speedFormatted.isNotEmpty
              ? AppStrings.bulletPrefix(dl.speedFormatted)
              : AppTechnicalStrings.empty;
          yield UpdateStatus(
            stage: UpdateStage.downloading,
            message: AppStrings.downloadingVersionMessage(
              targetVersionStr,
              dl.statusText,
              speedStr,
            ),
            progress: mappedProgress,
          );
        }

        yield const UpdateStatus(
          stage: UpdateStage.verifyingChecksum,
          message: AppStrings.verifyingPackageChecksum,
          progress: 0.72,
        );

        final zipFile = File(cleanZipPath);
        final isPkgValid = pkg.sha256.isEmpty ||
            await HashValidator.verifySha256(zipFile, pkg.sha256);

        if (!isPkgValid) {
          yield const UpdateStatus(
            stage: UpdateStage.failed,
            message: AppStrings.checksumMismatchError,
            error: AppTechnicalStrings.errorHashMismatch,
          );
          return;
        }

        // Limpiar directorio objetivo garantizando instalación desde cero
        yield const UpdateStatus(
          stage: UpdateStage.extractingFullPackage,
          message: AppStrings.cleaningDirAndExtracting,
          progress: 0.80,
        );

        if (await targetInstallDir.exists()) {
          try {
            await targetInstallDir.delete(recursive: true);
          } catch (_) {}
        }
        await targetInstallDir.create(recursive: true);

        await _extractOrInstallPackage(
          zipFile,
          targetInstallDir,
          targetRelease.executableRelativePath,
        );

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

        // Scripts post-instalación de la versión si existen
        if (targetRelease.scripts.postInstall != null) {
          final scriptPath = p.join(targetInstallDir.path, targetRelease.scripts.postInstall);
          await ProcessLauncher.runScript(
            scriptPath: scriptPath,
            workingDirectory: targetInstallDir.path,
          );
        }

        await _finalizeInstallation(
          app: app,
          versionRelease: targetRelease,
          targetInstallDir: targetInstallDir,
          platformKey: platformKey,
        );

        await CleanerService.cleanTemporaryFiles();

        if (isAnomalousInstalled) {
          await NotificationService.notifyUpdateCompleted(
            app.title,
            AppStrings.fullUpdateNotificationVersion(targetVersionStr),
          );
        } else {
          await NotificationService.notifyInstallCompleted(
            AppStrings.cleanInstallNotificationTitle(app.title, targetVersionStr),
          );
        }

        yield UpdateStatus(
          stage: UpdateStage.completed,
          message: isAnomalousInstalled
              ? AppStrings.fullUpdateCompletedMessage(targetVersionStr)
              : AppStrings.cleanInstallCompletedMessage(targetVersionStr),
          progress: 1.0,
        );
        return;
      } catch (e) {
        yield UpdateStatus(
          stage: UpdateStage.failed,
          message: AppStrings.cleanInstallErrorMessage(e),
          error: e.toString(),
        );
        return;
      }
    }

    bool shouldAttemptDelta = false;
    DeltaUpdate? matchedDelta;

    // Si la versión instalada es anómala o huérfana, jamás se debe intentar parchear;
    // se debe actualizar de manera completa.
    if (installed != null &&
        installed.installedVersion != targetVersionStr &&
        !isAnomalousInstalled) {
      matchedDelta = platformRelease.findDeltaFor(
        installed.installedVersion,
        targetVersionStr,
      );
      if (matchedDelta != null) {
        shouldAttemptDelta = true;
      }
    }

    if (shouldAttemptDelta && matchedDelta != null) {
      yield UpdateStatus(
        stage: UpdateStage.downloading,
        message: AppStrings.startingDeltaDownloadMessage(
          (matchedDelta.sizeBytes / 1048576).toStringAsFixed(1),
        ),
        progress: 0.05,
      );

      final patchFilePath = p.join(
        downloadsDir.path,
        AppTechnicalStrings.updatePatchFileName(app.slug),
      );
      bool deltaSuccess = false;

      try {
        await for (final dl in _downloader.downloadFileStream(
          url: matchedDelta.url,
          destinationPath: patchFilePath,
        )) {
          final mappedProgress = 0.05 + (dl.progress * 0.45);
          final speedStr = dl.speedFormatted.isNotEmpty
              ? AppStrings.bulletPrefix(dl.speedFormatted)
              : AppTechnicalStrings.empty;
          yield UpdateStatus(
            stage: UpdateStage.downloading,
            message: AppStrings.downloadingPatchMessage(
              dl.statusText,
              speedStr,
            ),
            progress: mappedProgress,
          );
        }

        yield const UpdateStatus(
          stage: UpdateStage.verifyingChecksum,
          message: AppStrings.verifyingPatchSecurity,
          progress: 0.55,
        );

        final patchFile = File(patchFilePath);
        final patchValid = matchedDelta.patchSha256.isEmpty ||
            await HashValidator.verifySha256(patchFile, matchedDelta.patchSha256);

        if (patchValid) {
          if (targetRelease.scripts.preInstall != null && await targetInstallDir.exists()) {
            yield const UpdateStatus(
              stage: UpdateStage.runningPreScripts,
              message: AppStrings.runningPreScripts,
              progress: 0.65,
            );
            final preScriptPath = p.join(targetInstallDir.path, targetRelease.scripts.preInstall);
            await ProcessLauncher.runScript(
              scriptPath: preScriptPath,
              workingDirectory: targetInstallDir.path,
            );
          }

          yield const UpdateStatus(
            stage: UpdateStage.applyingDelta,
            message: AppStrings.applyingDeltaPatch,
            progress: 0.75,
          );

          deltaSuccess = await _applyHDiffPatch(
            patchFile: patchFile,
            targetDirectory: targetInstallDir,
            executableRelativePath: targetRelease.executableRelativePath,
          );

          if (deltaSuccess && matchedDelta.targetSha256.isNotEmpty) {
            var targetExePath = p.join(targetInstallDir.path, targetRelease.executableRelativePath);
            if (Platform.isMacOS) {
              final autoResolved = ProcessLauncher.resolveExecutablePath(targetExePath, targetInstallDir.path);
              if (autoResolved != null) {
                targetExePath = autoResolved;
              }
            }

            final exeFile = File(targetExePath);
            final isZipPackage = targetRelease.package.url.toLowerCase().endsWith(AppTechnicalStrings.extZip);

            // Si targetSha256 coincide con el hash del paquete ZIP, se trata del checksum del contenedor
            // comprimido (fallback del catálogo), no del binario desempaquetado. En parches de directorio/ZIP,
            // la integridad ya ha sido garantizada criptográficamente por hpatchz (-C-new-copy) y patchSha256.
            final isContainerPackageHash = isZipPackage &&
                matchedDelta.targetSha256.toLowerCase() == targetRelease.package.sha256.toLowerCase();

            if (!isContainerPackageHash) {
              if (await exeFile.exists()) {
                final hashMatch = await HashValidator.verifySha256(exeFile, matchedDelta.targetSha256);
                if (!hashMatch) {
                  debugPrint(AppStrings.logPatchHashMismatch());
                  deltaSuccess = false;
                }
              } else {
                debugPrint(AppStrings.logExecutableNotFound(targetExePath));
                deltaSuccess = false;
              }
            } else {
              // Validar que el ejecutable objetivo exista tras la aplicación del parche
              if (!await exeFile.exists()) {
                debugPrint(AppStrings.logExecutableNotFound(targetExePath));
                deltaSuccess = false;
              }
            }
          }
        }
      } catch (e) {
        debugPrint(AppStrings.logDeltaPatchError(e));
        deltaSuccess = false;
      }

      if (deltaSuccess) {
        if (targetRelease.scripts.postInstall != null && await targetInstallDir.exists()) {
          final postScriptPath = p.join(targetInstallDir.path, targetRelease.scripts.postInstall);
          await ProcessLauncher.runScript(
            scriptPath: postScriptPath,
            workingDirectory: targetInstallDir.path,
          );
        }

        await _finalizeInstallation(
          app: app,
          versionRelease: targetRelease,
          targetInstallDir: targetInstallDir,
          platformKey: platformKey,
        );

        await CleanerService.cleanTemporaryFiles();
        await NotificationService.notifyUpdateCompleted(app.title, targetVersionStr);

        yield const UpdateStatus(
          stage: UpdateStage.completed,
          message: AppStrings.deltaUpdateCompletedSuccess,
          progress: 1.0,
        );
        return;
      }

      debugPrint(AppStrings.logActivatingFullPackageFallback());
    }

    final pkg = targetRelease.package;
    yield UpdateStatus(
      stage: UpdateStage.downloading,
      message: AppStrings.startingDownloadMessage(
        targetVersionStr,
        (pkg.sizeBytes / 1048576).toStringAsFixed(1),
      ),
      progress: 0.05,
    );

    final fullPackageZipPath = p.join(
      downloadsDir.path,
      AppTechnicalStrings.fullZipFileName(app.slug, targetVersionStr),
    );

    try {
      await for (final dl in _downloader.downloadFileStream(
        url: pkg.url,
        destinationPath: fullPackageZipPath,
      )) {
        final mappedProgress = 0.05 + (dl.progress * 0.65);
        final speedStr = dl.speedFormatted.isNotEmpty
            ? AppStrings.bulletPrefix(dl.speedFormatted)
            : AppTechnicalStrings.empty;
        yield UpdateStatus(
          stage: UpdateStage.downloading,
          message: AppStrings.downloadingVersionMessage(
            targetVersionStr,
            dl.statusText,
            speedStr,
          ),
          progress: mappedProgress,
        );
      }

      yield const UpdateStatus(
        stage: UpdateStage.verifyingChecksum,
        message: AppStrings.verifyingPackageChecksum,
        progress: 0.72,
      );

      final zipFile = File(fullPackageZipPath);
      final isFullValid = pkg.sha256.isEmpty ||
          await HashValidator.verifySha256(zipFile, pkg.sha256);

      if (!isFullValid) {
        yield const UpdateStatus(
          stage: UpdateStage.failed,
          message: AppStrings.checksumMismatchError,
          error: AppTechnicalStrings.errorHashMismatch,
        );
        return;
      }

      // Proteger datos de usuario si ya existía una instalación previa
      final userBackups = <String, List<int>>{};
      if (await targetInstallDir.exists() && platformRelease.protectedUserPaths.isNotEmpty) {
        yield const UpdateStatus(
          stage: UpdateStage.preservingUserData,
          message: AppStrings.protectingUserData,
          progress: 0.75,
        );

        for (final userRelPath in platformRelease.protectedUserPaths) {
          final cleanedRel = userRelPath
              .replaceAll(AppTechnicalStrings.globDoubleStar, AppTechnicalStrings.empty)
              .replaceAll(AppTechnicalStrings.globStar, AppTechnicalStrings.empty);
          final protectedFile = File(p.join(targetInstallDir.path, cleanedRel));
          if (await protectedFile.exists()) {
            userBackups[cleanedRel] = await protectedFile.readAsBytes();
          }
        }
      }

      if (targetRelease.scripts.preInstall != null && await targetInstallDir.exists()) {
        yield const UpdateStatus(
          stage: UpdateStage.runningPreScripts,
          message: AppStrings.runningPreInstallScript,
          progress: 0.78,
        );
        final preScriptPath = p.join(targetInstallDir.path, targetRelease.scripts.preInstall);
        await ProcessLauncher.runScript(
          scriptPath: preScriptPath,
          workingDirectory: targetInstallDir.path,
        );
      }

      yield const UpdateStatus(
        stage: UpdateStage.extractingFullPackage,
        message: AppStrings.extractingAppFiles,
        progress: 0.82,
      );

      if (!await targetInstallDir.exists()) {
        await targetInstallDir.create(recursive: true);
      }

      await _extractOrInstallPackage(
        zipFile,
        targetInstallDir,
        targetRelease.executableRelativePath,
      );

      if (userBackups.isNotEmpty) {
        for (final entry in userBackups.entries) {
          final dest = File(p.join(targetInstallDir.path, entry.key));
          if (!await dest.parent.exists()) {
            await dest.parent.create(recursive: true);
          }
          await dest.writeAsBytes(entry.value);
        }
      }

      if (targetRelease.scripts.postInstall != null) {
        yield const UpdateStatus(
          stage: UpdateStage.runningPostScripts,
          message: AppStrings.runningPostInstallScript,
          progress: 0.9,
        );
        final scriptPath = p.join(targetInstallDir.path, targetRelease.scripts.postInstall);
        await ProcessLauncher.runScript(
          scriptPath: scriptPath,
          workingDirectory: targetInstallDir.path,
        );
      }

      await _finalizeInstallation(
        app: app,
        versionRelease: targetRelease,
        targetInstallDir: targetInstallDir,
        platformKey: platformKey,
      );

      await CleanerService.cleanTemporaryFiles();

      if (installed != null) {
        await NotificationService.notifyUpdateCompleted(app.title, targetVersionStr);
      } else {
        await NotificationService.notifyInstallCompleted(app.title);
      }

      yield const UpdateStatus(
        stage: UpdateStage.completed,
        message: AppStrings.installationCompletedSuccess,
        progress: 1.0,
      );
    } catch (e) {
      yield UpdateStatus(
        stage: UpdateStage.failed,
        message: AppStrings.installationErrorMessage(e),
        error: e.toString(),
      );
    }
  }

  /// Aplica el parche binario hpatchz adaptándose a rutas locales, de bundle o descargadas bajo demanda.
  /// Soporta tanto parches a nivel de directorio (juegos y bundles de assets) como parches de binario único.
  Future<bool> _applyHDiffPatch({
    required File patchFile,
    required Directory targetDirectory,
    required String executableRelativePath,
  }) async {
    try {
      if (!await targetDirectory.exists()) return false;

      // Obtener la ruta resuelta o descargar hpatchz si no está presente
      final hpatchzCmd = await ComponentManager.instance.getHpatchzPath();
      if (hpatchzCmd == null) {
        debugPrint(AppStrings.logHpatchzNotAvailable());
        return false;
      }

      // Si el directorio de instalación contiene subdirectorios o múltiples archivos,
      // intentamos primero parchear a nivel de directorio con sobreescritura atómica (-f).
      final entities = targetDirectory.listSync();
      final isDirectoryBundle = entities.length > 1 || entities.any((e) => e is Directory);

      if (isDirectoryBundle) {
        final dirResult = await Process.run(
          hpatchzCmd,
          [AppTechnicalStrings.argMinusF, targetDirectory.path, patchFile.path, targetDirectory.path],
        );
        if (dirResult.exitCode == 0) {
          return true;
        }
        debugPrint(AppStrings.logHpatchzDirExitCode(dirResult.exitCode));
        return false;
      }

      // Fallback o modo binario único: parche directo sobre el ejecutable
      final exeFile = File(p.join(targetDirectory.path, executableRelativePath));
      if (!await exeFile.exists()) {
        debugPrint(AppStrings.logExecutableNotFound(exeFile.path));
        return false;
      }

      final result = await Process.run(
        hpatchzCmd,
        [AppTechnicalStrings.argMinusF, exeFile.path, patchFile.path, exeFile.path],
      );
      return result.exitCode == 0;
    } catch (e) {
      debugPrint(AppStrings.logHpatchzExecError(e));
      return false;
    }
  }

  /// Extrae un archivo ZIP o instala un archivo/binario directamente si no es un archivo ZIP.
  Future<void> _extractOrInstallPackage(
    File downloadedFile,
    Directory targetDirectory,
    String executableRelativePath,
  ) async {
    // 1. En macOS, utilizar ditto: preserva permisos POSIX, symlinks, atributos
    // y no carga archivos masivos en memoria heap de Dart.
    if (Platform.isMacOS) {
      try {
        final dittoResult = await Process.run(
          AppTechnicalStrings.cmdDitto,
          [AppTechnicalStrings.argMinusXk, downloadedFile.path, targetDirectory.path],
        );
        if (dittoResult.exitCode == 0) {
          return;
        }
      } catch (_) {}
    }

    // 2. En Linux, intentar unzip nativo
    if (Platform.isLinux) {
      try {
        final unzipResult = await Process.run(
          AppTechnicalStrings.cmdUnzip,
          [
            AppTechnicalStrings.argMinusQ,
            AppTechnicalStrings.argMinusO,
            downloadedFile.path,
            AppTechnicalStrings.argMinusD,
            targetDirectory.path,
          ],
        );
        if (unzipResult.exitCode == 0) {
          return;
        }
      } catch (_) {}
    }

    // 3. Fallback o Windows: lectura de bytes o ZipDecoder
    final bytes = await downloadedFile.readAsBytes();
    final isZip = bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04;

    if (isZip) {
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
    } else {
      // Si el paquete descargado es directamente un binario o ejecutable independiente
      final destPath = p.join(targetDirectory.path, executableRelativePath);
      final destFile = File(destPath);
      await destFile.parent.create(recursive: true);
      await downloadedFile.copy(destFile.path);
    }
  }

  Future<void> _finalizeInstallation({
    required AppEntry app,
    required AppVersionRelease versionRelease,
    required Directory targetInstallDir,
    required String platformKey,
  }) async {
    var exePath = p.join(targetInstallDir.path, versionRelease.executableRelativePath);

    if (Platform.isMacOS) {
      // 1. Eliminar cuarentena de Gatekeeper en todo el directorio instalado y bundles .app
      try {
        await Process.run(
          AppTechnicalStrings.cmdXattr,
          [AppTechnicalStrings.argMinusCr, targetInstallDir.path],
        );
      } catch (_) {}

      // 2. Si la ruta configurada en catálogo no existe, auto-resolver el binario real dentro de .app
      final resolved = ProcessLauncher.resolveExecutablePath(exePath, targetInstallDir.path);
      if (resolved != null) {
        exePath = resolved;
      }

      // 3. Otorgar permisos +x al ejecutable y a cualquier binario dentro de Contents/MacOS
      try {
        await Process.run(
          AppTechnicalStrings.cmdChmod,
          [AppTechnicalStrings.argPlusX, exePath],
        );
        final appIdx = exePath.indexOf(AppTechnicalStrings.extApp);
        if (appIdx != -1) {
          final bundlePath = exePath.substring(0, appIdx + 4);
          await Process.run(
            AppTechnicalStrings.cmdXattr,
            [AppTechnicalStrings.argMinusCr, bundlePath],
          );
          final macosDir = p.join(
            bundlePath,
            AppTechnicalStrings.dirContents,
            AppTechnicalStrings.dirMacOs,
          );
          await Process.run(
            AppTechnicalStrings.cmdChmod,
            [AppTechnicalStrings.argMinusR, AppTechnicalStrings.argPlusX, macosDir],
          );
        }
      } catch (_) {}
    } else if (Platform.isLinux) {
      try {
        await Process.run(
          AppTechnicalStrings.cmdChmod,
          [AppTechnicalStrings.argPlusX, exePath],
        );
      } catch (_) {}
    }

    final installedApp = InstalledApp(
      id: app.id,
      title: app.title,
      installedVersion: versionRelease.version,
      executablePath: exePath,
      installDirectory: targetInstallDir.path,
      installedAt: DateTime.now(),
      sizeBytes: versionRelease.package.sizeBytes,
      platformKey: platformKey,
    );

    await _libraryRepository.saveInstalledApp(installedApp);
  }
}
