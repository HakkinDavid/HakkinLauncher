import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/catalog/data/models/app_entry.dart';
import '../../features/catalog/data/repositories/catalog_repository.dart';
import '../../features/library/data/repositories/library_repository.dart';
import '../../features/updater/services/patch_engine.dart';
import 'package:hakkin_launcher/features/self_update/services/self_update_service.dart';
import '../constants/app_constants.dart';
import '../constants/app_strings.dart';
import '../constants/app_technical_strings.dart';
import 'notification_service.dart';
import 'os_paths.dart';
import 'process_launcher.dart';

typedef AutoUpdateAppHandler = Future<void> Function(
  AppEntry app, {
  String? targetVersion,
});

/// Servicio en segundo plano para el sondeo periódico de actualizaciones del catálogo,
/// aplicaciones instaladas y del propio HakkinLauncher.
class BackgroundCheckService {
  static final BackgroundCheckService instance = BackgroundCheckService._();
  BackgroundCheckService._();

  Timer? _timer;
  Timer? _autoUpdateDebounceTimer;
  bool _isRunningAutoUpdates = false;
  AutoUpdateAppHandler? _onAutoUpdateApp;

  final CatalogRepository _catalogRepository = CatalogRepository();
  final LibraryRepository _libraryRepository = LibraryRepository();

  /// Registra el manejador conectado al estado de la interfaz para reflejar el progreso
  /// y recargar la biblioteca tras completarse cada actualización automática.
  void registerAutoUpdateHandler(AutoUpdateAppHandler handler) {
    _onAutoUpdateApp = handler;
  }

  /// Inicia el temporizador de sondeo periódico en segundo plano con comprobación automática inicial
  /// y un debounce de 5 minutos tras el arranque para ejecutar las actualizaciones automáticas.
  void startPeriodicChecks({
    Duration interval = AppConstants.backgroundCheckInterval,
    Duration autoUpdateDelay = AppConstants.startupAutoUpdateDelay,
  }) {
    _timer?.cancel();
    _autoUpdateDebounceTimer?.cancel();

    // Comprobación automática inmediata tras el arranque de la aplicación (3s de gracia)
    Timer(const Duration(seconds: 3), () {
      checkForUpdates(silent: true);
    });

    // Debounce de 5 minutos tras arrancar el lanzador para actualizar automáticamente
    // todas las aplicaciones marcadas con actualización automática activa.
    _autoUpdateDebounceTimer = Timer(autoUpdateDelay, () {
      runAutoUpdates();
    });

    _timer = Timer.periodic(interval, (_) {
      checkForUpdates(silent: true);
      runAutoUpdates();
    });
  }

  /// Detiene los temporizadores en segundo plano.
  void stopPeriodicChecks() {
    _timer?.cancel();
    _timer = null;
    _autoUpdateDebounceTimer?.cancel();
    _autoUpdateDebounceTimer = null;
  }

  /// Actualiza automáticamente todas las aplicaciones instaladas que tengan
  /// activa la opción de actualización automática y cuenten con una versión nueva.
  Future<void> runAutoUpdates() async {
    if (_isRunningAutoUpdates) return;
    _isRunningAutoUpdates = true;

    try {
      final manifest = await _catalogRepository.fetchCatalog(forceRefresh: true);
      final installedApps = await _libraryRepository.getInstalledApps();

      for (final installed in installedApps) {
        final currentInstalled =
            await _libraryRepository.getInstalledApp(installed.id) ?? installed;
        if (!currentInstalled.autoUpdate) continue;
        if (ProcessLauncher.isAppRunning(currentInstalled.id)) continue;

        final catalogApp =
            manifest.apps.where((a) => a.id == currentInstalled.id).firstOrNull;
        if (catalogApp == null) continue;

        final targetPlatKey = currentInstalled.platformKey.isNotEmpty
            ? currentInstalled.platformKey
            : OsPaths.getCurrentPlatformKey();

        final hasUpdate = catalogApp.needsUpdate(
          platformKey: targetPlatKey,
          installedVersion: currentInstalled.installedVersion,
        );

        if (!hasUpdate) continue;

        final targetVersion =
            catalogApp.getPlatformRelease(targetPlatKey)?.latestVersion ??
                catalogApp.latestVersion;

        debugPrint(
          AppStrings.logAutoUpdateStarting(
            currentInstalled.title,
            targetVersion,
          ),
        );

        if (_onAutoUpdateApp != null) {
          await _onAutoUpdateApp!(
            catalogApp,
            targetVersion: targetVersion,
          );
        } else {
          final prefs = await SharedPreferences.getInstance();
          final customPath =
              prefs.getString(AppConstants.prefCustomInstallPathKey);
          final patchEngine = PatchEngine(libraryRepository: _libraryRepository);

          await for (final _ in patchEngine.installOrUpdate(
            app: catalogApp,
            platformKey: targetPlatKey,
            targetVersion: targetVersion,
            customInstallPath: customPath != null && customPath.isNotEmpty
                ? p.join(customPath, catalogApp.slug)
                : null,
          )) {}
        }
      }
    } catch (e) {
      debugPrint(AppStrings.logAutoUpdateError(e));
    } finally {
      _isRunningAutoUpdates = false;
    }
  }

  /// Comprueba si hay actualizaciones disponibles para las aplicaciones instaladas
  /// o para el lanzador.
  Future<Map<String, String>> checkForUpdates({bool silent = false}) async {
    final updatesFound = <String, String>{};

    try {
      final manifest = await _catalogRepository.fetchCatalog(forceRefresh: true);
      final installedApps = await _libraryRepository.getInstalledApps();

      for (final installed in installedApps) {
        final catalogApp = manifest.apps.where((a) => a.id == installed.id).firstOrNull;
        if (catalogApp != null) {
          final targetPlatKey = installed.platformKey.isNotEmpty
              ? installed.platformKey
              : OsPaths.getCurrentPlatformKey();
          final hasUpdate = catalogApp.needsUpdate(
            platformKey: targetPlatKey,
            installedVersion: installed.installedVersion,
          );
          if (hasUpdate) {
            updatesFound[installed.title] = catalogApp.latestVersion;
            if (silent) {
              await NotificationService.notifyUpdateAvailable(
                installed.title,
                catalogApp.latestVersion,
              );
            }
          }
        }
      }

      if (manifest.launcherMeta != null) {
        final latestLauncher = manifest.launcherMeta!.latestVersion;
        if (SelfUpdateService.isNewerVersion(latestLauncher, AppConstants.appVersion)) {
          updatesFound[AppConstants.appName] = latestLauncher;
          if (silent) {
            await NotificationService.showNotification(
              title: AppStrings.newLauncherVersionTitle(AppConstants.appName),
              body: AppStrings.newVersionReadyBody(latestLauncher),
            );
          }
        }
      }

      if (!silent) {
        if (updatesFound.isNotEmpty) {
          final summary = updatesFound.entries
              .map((e) => e.key + AppTechnicalStrings.space + AppTechnicalStrings.versionWithV(e.value))
              .join(AppTechnicalStrings.commaSpace);
          await NotificationService.showNotification(
            title: AppStrings.updatesFoundTitle,
            body: AppStrings.updatesAvailableFor(summary),
          );
        } else {
          await NotificationService.showNotification(
            title: AppStrings.allUpToDateTitle,
            body: AppStrings.allUpToDateBody,
          );
        }
      }
    } catch (e) {
      debugPrint(AppStrings.errorCheckingUpdates(e));
    }

    return updatesFound;
  }
}
