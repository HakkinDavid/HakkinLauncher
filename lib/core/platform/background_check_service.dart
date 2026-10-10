import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../features/catalog/data/repositories/catalog_repository.dart';
import '../../features/library/data/repositories/library_repository.dart';
import 'package:hakkin_launcher/features/self_update/services/self_update_service.dart';
import '../constants/app_constants.dart';
import '../constants/app_strings.dart';
import '../constants/app_technical_strings.dart';
import 'notification_service.dart';
import 'os_paths.dart';

/// Servicio en segundo plano para el sondeo periódico de actualizaciones del catálogo,
/// aplicaciones instaladas y del propio HakkinLauncher.
class BackgroundCheckService {
  static final BackgroundCheckService instance = BackgroundCheckService._();
  BackgroundCheckService._();

  Timer? _timer;
  final CatalogRepository _catalogRepository = CatalogRepository();
  final LibraryRepository _libraryRepository = LibraryRepository();

  /// Inicia el temporizador de sondeo periódico en segundo plano con comprobación automática inicial.
  void startPeriodicChecks({Duration interval = AppConstants.backgroundCheckInterval}) {
    _timer?.cancel();
    // Comprobación automática inmediata tras el arranque de la aplicación (3s de gracia)
    Timer(const Duration(seconds: 3), () {
      checkForUpdates(silent: true);
    });
    _timer = Timer.periodic(interval, (_) {
      checkForUpdates(silent: true);
    });
  }

  /// Detiene el temporizador en segundo plano.
  void stopPeriodicChecks() {
    _timer?.cancel();
    _timer = null;
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
