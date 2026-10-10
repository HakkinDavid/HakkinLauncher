import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_technical_strings.dart';
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

/// Servicio encargado de la auto-actualización autónoma, atómica y con rollback de HakkinLauncher.
class SelfUpdateService {
  final DownloaderService _downloader;

  SelfUpdateService({DownloaderService? downloader})
      : _downloader = downloader ?? DownloaderService();

  /// Compara dos versiones semánticas: retorna true si candidate > current.
  static bool isNewerVersion(String candidate, String current) {
    if (candidate == current) return false;
    final cParts = RegExp(AppTechnicalStrings.regexDigits)
        .allMatches(candidate)
        .map((m) => int.parse(m.group(0)!))
        .toList();
    final curParts = RegExp(AppTechnicalStrings.regexDigits)
        .allMatches(current)
        .map((m) => int.parse(m.group(0)!))
        .toList();
    final maxLen = cParts.length > curParts.length ? cParts.length : curParts.length;
    for (var i = 0; i < maxLen; i++) {
      final cNum = i < cParts.length ? cParts[i] : 0;
      final curNum = i < curParts.length ? curParts[i] : 0;
      if (cNum > curNum) return true;
      if (cNum < curNum) return false;
    }
    return false;
  }

  /// Comprueba si hay una nueva versión disponible del propio lanzador estrictamente más reciente.
  bool isUpdateAvailable(LauncherMeta? launcherMeta, [String? currentVersion]) {
    if (launcherMeta == null) return false;
    final current = currentVersion ?? AppConstants.appVersion;
    return isNewerVersion(launcherMeta.latestVersion, current);
  }

  /// Resuelve la entrada de release adecuada para la plataforma con estrategia de fallback.
  static Map<String, dynamic>? resolveReleaseForPlatform(
    LauncherMeta launcherMeta, [
    String? platformKey,
  ]) {
    final key = platformKey ?? OsPaths.getCurrentPlatformKey();
    final releases = launcherMeta.releases;

    if (releases.containsKey(key)) {
      return releases[key];
    }

    final candidateFallbacks = <String>[];
    if (key.startsWith(AppTechnicalStrings.platformMacos)) {
      candidateFallbacks.addAll([
        AppTechnicalStrings.platformMacosUniversal,
        AppTechnicalStrings.platformMacos,
        AppTechnicalStrings.platformMacosArm64,
        AppTechnicalStrings.platformMacosX64,
      ]);
    } else if (key.startsWith(AppTechnicalStrings.platformWindows)) {
      candidateFallbacks.addAll([
        AppTechnicalStrings.platformWindowsX64,
        AppTechnicalStrings.platformWindows,
        AppTechnicalStrings.platformWindowsX86,
      ]);
    } else if (key.startsWith(AppTechnicalStrings.platformLinux)) {
      candidateFallbacks.addAll([
        AppTechnicalStrings.platformLinuxX64,
        AppTechnicalStrings.platformLinux,
      ]);
    }

    for (final fallback in candidateFallbacks) {
      if (releases.containsKey(fallback)) {
        return releases[fallback];
      }
    }

    return null;
  }

  /// Genera el script de actualización para macOS con staging, backup y rollback automático.
  static String generateMacOSUpdateScript({
    required int currentPid,
    required String currentExePath,
    required String targetAppPath,
    required String zipFilePath,
    required String logFilePath,
  }) {
    return AppTechnicalStrings.generateMacOSUpdateScript(
      currentPid: currentPid,
      currentExePath: currentExePath,
      targetAppPath: targetAppPath,
      zipFilePath: zipFilePath,
      logFilePath: logFilePath,
    );
  }

  /// Genera el script de actualización para Windows con staging, backup y rollback automático.
  static String generateWindowsUpdateScript({
    required int currentPid,
    required String currentExePath,
    required String appDir,
    required String zipFilePath,
    required String logFilePath,
  }) {
    return AppTechnicalStrings.generateWindowsUpdateScript(
      currentPid: currentPid,
      currentExePath: currentExePath,
      appDir: appDir,
      zipFilePath: zipFilePath,
      logFilePath: logFilePath,
    );
  }

  /// Genera el script de actualización para Linux con staging, backup y rollback automático.
  static String generateLinuxUpdateScript({
    required int currentPid,
    required String currentExePath,
    required String appDir,
    required String zipFilePath,
    required String logFilePath,
  }) {
    return AppTechnicalStrings.generateLinuxUpdateScript(
      currentPid: currentPid,
      currentExePath: currentExePath,
      appDir: appDir,
      zipFilePath: zipFilePath,
      logFilePath: logFilePath,
    );
  }

  /// Ejecuta el flujo completo de auto-actualización del lanzador.
  Stream<SelfUpdateStatus> performSelfUpdate(LauncherMeta launcherMeta) async* {
    yield const SelfUpdateStatus(
      stage: SelfUpdateStage.checking,
      message: AppStrings.selfUpdateChecking,
      progress: 0.1,
    );

    final platformKey = OsPaths.getCurrentPlatformKey();
    final releaseData = resolveReleaseForPlatform(launcherMeta, platformKey);

    if (releaseData == null) {
      yield const SelfUpdateStatus(
        stage: SelfUpdateStage.error,
        message: AppStrings.selfUpdateNoPlatformPackage,
        error: AppStrings.selfUpdateUnsupportedPlatform,
      );
      return;
    }

    final downloadUrl = releaseData[AppTechnicalStrings.keyUrl] as String?;
    final expectedSha256 =
        (releaseData[AppTechnicalStrings.keySha256] as String?) ??
            AppTechnicalStrings.empty;

    if (downloadUrl == null || downloadUrl.isEmpty) {
      yield const SelfUpdateStatus(
        stage: SelfUpdateStage.error,
        message: AppStrings.selfUpdateInvalidDownloadUrl,
        error: AppStrings.selfUpdateEmptyUrl,
      );
      return;
    }

    final downloadsDir = await OsPaths.getDownloadsDirectory();
    final updateZipPath =
        p.join(downloadsDir.path, AppTechnicalStrings.selfUpdateZipFileName);
    final zipFile = File(updateZipPath);

    // Si ya existía un archivo de descarga con hash mismatch o corrupto, limpiarlo
    if (await zipFile.exists() && expectedSha256.isNotEmpty) {
      final matches = await HashValidator.verifySha256(zipFile, expectedSha256);
      if (!matches) {
        try {
          await zipFile.delete();
        } catch (_) {}
      }
    }

    yield SelfUpdateStatus(
      stage: SelfUpdateStage.downloading,
      message: AppStrings.selfUpdateStartingDownload(launcherMeta.latestVersion),
      progress: 0.05,
      newVersion: launcherMeta.latestVersion,
    );

    try {
      await for (final dl in _downloader.downloadFileStream(
        url: downloadUrl,
        destinationPath: updateZipPath,
      )) {
        final mappedProgress = 0.05 + (dl.progress * 0.65);
        final speedStr = dl.speedFormatted.isNotEmpty
            ? AppStrings.bulletPrefix(dl.speedFormatted)
            : AppTechnicalStrings.empty;
        yield SelfUpdateStatus(
          stage: SelfUpdateStage.downloading,
          message: AppStrings.selfUpdateDownloading(dl.statusText, speedStr),
          progress: mappedProgress,
          newVersion: launcherMeta.latestVersion,
        );
      }

      yield const SelfUpdateStatus(
        stage: SelfUpdateStage.verifyingChecksum,
        message: AppStrings.selfUpdateVerifyingChecksum,
        progress: 0.6,
      );

      if (expectedSha256.isNotEmpty) {
        final isValid = await HashValidator.verifySha256(zipFile, expectedSha256);
        if (!isValid) {
          try {
            await zipFile.delete();
          } catch (_) {}
          yield const SelfUpdateStatus(
            stage: SelfUpdateStage.error,
            message: AppStrings.selfUpdateHashMismatchMessage,
            error: AppTechnicalStrings.errorHashMismatch,
          );
          return;
        }
      }

      yield const SelfUpdateStatus(
        stage: SelfUpdateStage.readyToRestart,
        message: AppStrings.selfUpdatePreparingRestart,
        progress: 0.9,
      );

      await NotificationService.showNotification(
        title: AppStrings.selfUpdateReadyTitle,
        body: AppStrings.selfUpdateReadyBody,
      );

      await _applyUpdateAndRestart(zipFile);

      yield const SelfUpdateStatus(
        stage: SelfUpdateStage.readyToRestart,
        message: AppStrings.selfUpdateRestarting,
        progress: 1.0,
      );
    } catch (e) {
      String errorMessage = AppStrings.selfUpdateErrorGeneric(e);
      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        if (statusCode == 404) {
          errorMessage = AppStrings.selfUpdateHttp404;
        } else if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          errorMessage = AppStrings.selfUpdateTimeout;
        } else if (e.type == DioExceptionType.connectionError) {
          errorMessage = AppStrings.selfUpdateConnectionError;
        } else {
          errorMessage =
              AppStrings.selfUpdateNetworkError(e.message ?? e.toString());
        }
      }
      yield SelfUpdateStatus(
        stage: SelfUpdateStage.error,
        message: errorMessage,
        error: e.toString(),
      );
    }
  }

  /// Lanza el proceso helper desacoplado y finaliza el proceso actual.
  Future<void> _applyUpdateAndRestart(File zipFile) async {
    final currentPid = pid;
    final currentExePath = Platform.resolvedExecutable;
    final appDir = File(currentExePath).parent.path;
    final downloadsDir = zipFile.parent.path;
    final logFile =
        p.join(downloadsDir, AppTechnicalStrings.selfUpdateLogFileName);

    if (Platform.isMacOS) {
      String targetAppPath = currentExePath;
      if (currentExePath.contains(AppTechnicalStrings.appContentsMacOs)) {
        targetAppPath = currentExePath.split(AppTechnicalStrings.appContentsMacOs).first +
            AppTechnicalStrings.extApp;
      }

      final scriptContent = generateMacOSUpdateScript(
        currentPid: currentPid,
        currentExePath: currentExePath,
        targetAppPath: targetAppPath,
        zipFilePath: zipFile.path,
        logFilePath: logFile,
      );

      final scriptFile =
          File(p.join(downloadsDir, AppTechnicalStrings.updateHelperSh));
      await scriptFile.writeAsString(scriptContent);
      await Process.run(
        AppTechnicalStrings.cmdChmod,
        [AppTechnicalStrings.argPlusX, scriptFile.path],
      );

      // Lanzar desacoplado
      await Process.start(
        AppTechnicalStrings.binBash,
        [scriptFile.path],
        mode: ProcessStartMode.detached,
      );
      exit(0);
    } else if (Platform.isWindows) {
      final scriptContent = generateWindowsUpdateScript(
        currentPid: currentPid,
        currentExePath: currentExePath,
        appDir: appDir,
        zipFilePath: zipFile.path,
        logFilePath: logFile,
      );

      final scriptFile =
          File(p.join(downloadsDir, AppTechnicalStrings.updateHelperBat));
      await scriptFile.writeAsString(scriptContent);

      await Process.start(
        AppTechnicalStrings.cmdCmd,
        [AppTechnicalStrings.argSlashC, scriptFile.path],
        mode: ProcessStartMode.detached,
      );
      exit(0);
    } else if (Platform.isLinux) {
      final scriptContent = generateLinuxUpdateScript(
        currentPid: currentPid,
        currentExePath: currentExePath,
        appDir: appDir,
        zipFilePath: zipFile.path,
        logFilePath: logFile,
      );

      final scriptFile =
          File(p.join(downloadsDir, AppTechnicalStrings.updateHelperSh));
      await scriptFile.writeAsString(scriptContent);
      await Process.run(
        AppTechnicalStrings.cmdChmod,
        [AppTechnicalStrings.argPlusX, scriptFile.path],
      );

      await Process.start(
        AppTechnicalStrings.binBash,
        [scriptFile.path],
        mode: ProcessStartMode.detached,
      );
      exit(0);
    }
  }
}
