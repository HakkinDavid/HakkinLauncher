import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../features/catalog/data/repositories/catalog_repository.dart';
import '../../features/library/data/repositories/library_repository.dart';
import '../../features/self_update/services/self_update_service.dart';
import '../constants/app_constants.dart';
import 'notification_service.dart';

/// Servicio en segundo plano para el sondeo periódico de actualizaciones del catálogo,
/// aplicaciones instaladas y del propio HakkinLauncher.
class BackgroundCheckService {
  static final BackgroundCheckService instance = BackgroundCheckService._();
  BackgroundCheckService._();

  Timer? _timer;
  final CatalogRepository _catalogRepository = CatalogRepository();
  final LibraryRepository _libraryRepository = LibraryRepository();

  /// Inicia el temporizador de sondeo periódico en segundo plano.
  void startPeriodicChecks({Duration interval = AppConstants.backgroundCheckInterval}) {
    _timer?.cancel();
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
        if (catalogApp != null && catalogApp.latestVersion != installed.installedVersion) {
          updatesFound[installed.title] = catalogApp.latestVersion;
          if (silent) {
            await NotificationService.notifyUpdateAvailable(
              installed.title,
              catalogApp.latestVersion,
            );
          }
        }
      }

      if (manifest.launcherMeta != null) {
        final latestLauncher = manifest.launcherMeta!.latestVersion;
        if (SelfUpdateService.isNewerVersion(latestLauncher, AppConstants.appVersion)) {
          updatesFound[AppConstants.appName] = latestLauncher;
          if (silent) {
            await NotificationService.showNotification(
              title: 'Nueva versión de ${AppConstants.appName}',
              body: 'La versión v$latestLauncher está lista para actualizar.',
            );
          }
        }
      }

      if (!silent) {
        if (updatesFound.isNotEmpty) {
          final summary = updatesFound.entries
              .map((e) => '${e.key} v${e.value}')
              .join(', ');
          await NotificationService.showNotification(
            title: 'Actualizaciones encontradas',
            body: 'Disponibles para: $summary',
          );
        } else {
          await NotificationService.showNotification(
            title: 'Todo al día',
            body: 'Todas tus aplicaciones y el lanzador están en la versión más reciente.',
          );
        }
      }
    } catch (e) {
      debugPrint('Error en comprobación de actualizaciones: $e');
    }

    return updatesFound;
  }
}
