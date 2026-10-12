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
import 'window_service.dart';

typedef AutoUpdateAppHandler = Future<void> Function(
  AppEntry app, {
  String? targetVersion,
});

typedef AutoSelfUpdateHandler = Future<void> Function(
  LauncherMeta launcherMeta,
);

/// Servicio en segundo plano para el sondeo periódico de actualizaciones del catálogo,
/// aplicaciones instaladas y del propio HakkinLauncher.
class BackgroundCheckService {
  static final BackgroundCheckService instance = BackgroundCheckService._();
  BackgroundCheckService._() {
    _bindSystemListeners();
  }

  Timer? _timer;
  Timer? _initialCheckTimer;
  Timer? _autoUpdateDebounceTimer;
  Timer? _navigationDebounceTimer;
  Duration _navigationDebounceDuration =
      AppConstants.selfUpdateNavigationDebounce;
  bool _isRunningAutoUpdates = false;
  bool _isRunningSelfUpdate = false;
  bool _initialDebounceCompleted = false;
  bool _isNavigationIdle = false;
  LauncherMeta? _latestLauncherMeta;
  StreamSubscription<Map<String, bool>>? _runningStateSubscription;
  AutoUpdateAppHandler? _onAutoUpdateApp;
  AutoSelfUpdateHandler? _onAutoSelfUpdate;
  VoidCallback? _onCatalogRefreshed;

  final StreamController<SelfUpdateStatus> _selfUpdateStatusController =
      StreamController<SelfUpdateStatus>.broadcast();

  final CatalogRepository _catalogRepository = CatalogRepository();
  final LibraryRepository _libraryRepository = LibraryRepository();

  /// Indica si ya transcurrió el tiempo de espera inicial tras el arranque.
  bool get isInitialDebounceCompleted => _initialDebounceCompleted;

  /// Indica si el lanzador lleva al menos el tiempo de debounce (1 minuto) sin ser navegado.
  bool get isNavigationIdle => _isNavigationIdle;

  /// Indica si se está ejecutando actualmente la autoactualización del lanzador.
  bool get isRunningSelfUpdate => _isRunningSelfUpdate;

  /// Últimos metadatos conocidos de versión del lanzador.
  LauncherMeta? get latestLauncherMeta => _latestLauncherMeta;

  /// Flujo de estados de progreso de la autoactualización del lanzador.
  Stream<SelfUpdateStatus> get selfUpdateStatusStream =>
      _selfUpdateStatusController.stream;

  void _bindSystemListeners() {
    WindowService.instance.registerHiddenStateListener((isHidden) {
      if (isHidden) {
        unawaited(evaluateAutoSelfUpdate());
      } else {
        recordUserNavigation();
      }
    });
    _runningStateSubscription ??=
        ProcessLauncher.runningStateStream.listen((runningMap) {
      if (runningMap.isEmpty) {
        unawaited(evaluateAutoSelfUpdate());
      }
    });
  }

  /// Registra el manejador conectado al estado de la interfaz para reflejar el progreso
  /// y recargar la biblioteca tras completarse cada actualización automática.
  void registerAutoUpdateHandler(AutoUpdateAppHandler handler) {
    _onAutoUpdateApp = handler;
  }

  /// Registra un manejador personalizado para la autoactualización del propio lanzador.
  void registerAutoSelfUpdateHandler(AutoSelfUpdateHandler? handler) {
    _onAutoSelfUpdate = handler;
  }

  /// Registra el manejador para refrescar el catálogo reactivo en la interfaz
  /// cada vez que el servicio en segundo plano obtiene una versión fresca del catálogo.
  void registerCatalogRefreshHandler(VoidCallback handler) {
    _onCatalogRefreshed = handler;
  }

  /// Registra actividad de navegación del usuario y reinicia el debounce de inactividad (1 minuto).
  /// Cuando transcurre el tiempo de debounce sin navegación, evalúa si debe autoactualizar el lanzador.
  void recordUserNavigation({Duration? debounce}) {
    if (debounce != null) {
      _navigationDebounceDuration = debounce;
    }
    _isNavigationIdle = false;
    _navigationDebounceTimer?.cancel();
    _navigationDebounceTimer = Timer(_navigationDebounceDuration, () {
      _isNavigationIdle = true;
      unawaited(evaluateAutoSelfUpdate());
    });
  }

  /// Actualiza los metadatos conocidos de versión del lanzador y evalúa si procede autoactualizar.
  void updateKnownLauncherMeta(LauncherMeta? launcherMeta) {
    _latestLauncherMeta = launcherMeta;
    if (launcherMeta != null &&
        SelfUpdateService.isNewerVersion(
          launcherMeta.latestVersion,
          AppConstants.appVersion,
        )) {
      unawaited(evaluateAutoSelfUpdate());
    }
  }

  /// Determina si el lanzador cumple las condiciones para ejecutar su autoactualización en automático:
  /// 1. El lanzador no está ejecutando ninguno de sus programas (!ProcessLauncher.hasRunningApps).
  /// 2. Hay una actualización propia disponible.
  /// 3. Cumple alguna de las siguientes:
  ///    a) Está hidden (system tray en Windows, taskbar en macOS, background process en Linux).
  ///    b) No está siendo navegado (debounce de 1 minuto).
  bool shouldAutoSelfUpdate({
    LauncherMeta? launcherMeta,
    String? currentVersion,
  }) {
    if (_isRunningSelfUpdate) return false;
    if (ProcessLauncher.hasRunningApps) return false;

    final meta = launcherMeta ?? _latestLauncherMeta;
    if (meta == null) return false;

    final current = currentVersion ?? AppConstants.appVersion;
    if (!SelfUpdateService.isNewerVersion(meta.latestVersion, current)) {
      return false;
    }

    final isHidden = WindowService.instance.isHidden;
    final isNotBeingNavigated = _isNavigationIdle;

    return isHidden || isNotBeingNavigated;
  }

  /// Evalúa las condiciones de autoactualización del propio lanzador y, si se cumplen,
  /// ejecuta el proceso de autoactualización en automático.
  Future<bool> evaluateAutoSelfUpdate({
    LauncherMeta? launcherMeta,
    String? currentVersion,
  }) async {
    if (launcherMeta != null) {
      _latestLauncherMeta = launcherMeta;
    }
    if (!shouldAutoSelfUpdate(currentVersion: currentVersion)) {
      return false;
    }

    final meta = _latestLauncherMeta!;
    await triggerSelfUpdate(meta);
    return true;
  }

  /// Ejecuta el flujo de autoactualización del propio lanzador evitando ejecuciones concurrentes.
  Future<void> triggerSelfUpdate(LauncherMeta launcherMeta) async {
    if (_isRunningSelfUpdate) return;
    _isRunningSelfUpdate = true;

    debugPrint(AppStrings.logAutoSelfUpdateStarting(launcherMeta.latestVersion));

    try {
      if (_onAutoSelfUpdate != null) {
        await _onAutoSelfUpdate!(launcherMeta);
      } else {
        final selfUpdateService = SelfUpdateService();
        await for (final status
            in selfUpdateService.performSelfUpdate(launcherMeta)) {
          _selfUpdateStatusController.add(status);
        }
      }
    } catch (e) {
      debugPrint(AppStrings.logAutoUpdateError(e));
    } finally {
      _isRunningSelfUpdate = false;
    }
  }

  /// Restablece el estado interno para pruebas unitarias.
  @visibleForTesting
  void resetStateForTesting() {
    stopPeriodicChecks();
    _navigationDebounceDuration = AppConstants.selfUpdateNavigationDebounce;
    _isNavigationIdle = false;
    _isRunningAutoUpdates = false;
    _isRunningSelfUpdate = false;
    _initialDebounceCompleted = false;
    _latestLauncherMeta = null;
    _onAutoSelfUpdate = null;
    _bindSystemListeners();
  }

  /// Refresca el catálogo desde el origen remoto y sincroniza el estado de la interfaz.
  Future<CatalogManifest> refreshCatalog() async {
    final manifest = await _catalogRepository.fetchCatalog(forceRefresh: true);
    if (manifest.launcherMeta != null) {
      _latestLauncherMeta = manifest.launcherMeta;
    }
    _onCatalogRefreshed?.call();
    return manifest;
  }

  /// Inicia el temporizador de sondeo periódico en segundo plano con comprobación automática inicial,
  /// un debounce de 5 minutos tras el arranque y ejecución periódica continua de refresco de catálogo
  /// y actualizaciones automáticas.
  void startPeriodicChecks({
    Duration interval = AppConstants.backgroundCheckInterval,
    Duration autoUpdateDelay = AppConstants.startupAutoUpdateDelay,
    Duration navigationDebounce = AppConstants.selfUpdateNavigationDebounce,
  }) {
    _timer?.cancel();
    _initialCheckTimer?.cancel();
    _autoUpdateDebounceTimer?.cancel();
    _initialDebounceCompleted = false;
    _bindSystemListeners();
    recordUserNavigation(debounce: navigationDebounce);

    // Comprobación y refresco inicial del catálogo tras el arranque de la aplicación (3s de gracia)
    _initialCheckTimer = Timer(const Duration(seconds: 3), () {
      checkForUpdates(silent: true);
    });

    // Debounce de 5 minutos tras arrancar el lanzador para refrescar el catálogo y actualizar
    // en automático todas las aplicaciones marcadas con actualización automática activa.
    _autoUpdateDebounceTimer = Timer(autoUpdateDelay, () async {
      _initialDebounceCompleted = true;
      await _runPeriodicCatalogAndAutoUpdateCycle();
    });

    // Ciclo periódico continuo de refresco del catálogo y actualización automática
    _timer = Timer.periodic(interval, (_) async {
      await _runPeriodicCatalogAndAutoUpdateCycle();
    });
  }

  /// Ejecuta un ciclo completo: refresca el catálogo remoto, comprueba actualizaciones
  /// y actualiza automáticamente las aplicaciones que tengan activa la opción.
  Future<void> _runPeriodicCatalogAndAutoUpdateCycle() async {
    try {
      final manifest = await refreshCatalog();
      await checkForUpdates(silent: true, preloadedManifest: manifest);
      await runAutoUpdates(preloadedManifest: manifest);
    } catch (e) {
      debugPrint(AppStrings.logAutoUpdateError(e));
    }
  }

  /// Detiene los temporizadores en segundo plano.
  void stopPeriodicChecks() {
    _timer?.cancel();
    _timer = null;
    _initialCheckTimer?.cancel();
    _initialCheckTimer = null;
    _autoUpdateDebounceTimer?.cancel();
    _autoUpdateDebounceTimer = null;
    _navigationDebounceTimer?.cancel();
    _navigationDebounceTimer = null;
  }

  /// Actualiza automáticamente todas las aplicaciones instaladas que tengan
  /// activa la opción de actualización automática y cuenten con una versión nueva.
  Future<void> runAutoUpdates({CatalogManifest? preloadedManifest}) async {
    if (_isRunningAutoUpdates) return;
    _isRunningAutoUpdates = true;

    try {
      final manifest = preloadedManifest ?? await refreshCatalog();
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

      if (manifest.launcherMeta != null) {
        await evaluateAutoSelfUpdate(launcherMeta: manifest.launcherMeta);
      }
    } catch (e) {
      debugPrint(AppStrings.logAutoUpdateError(e));
    } finally {
      _isRunningAutoUpdates = false;
    }
  }

  /// Comprueba si hay actualizaciones disponibles para las aplicaciones instaladas
  /// o para el lanzador, refrescando primero el catálogo.
  Future<Map<String, String>> checkForUpdates({
    bool silent = false,
    CatalogManifest? preloadedManifest,
  }) async {
    final updatesFound = <String, String>{};

    try {
      final manifest = preloadedManifest ?? await refreshCatalog();
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
            final latestVersion =
                catalogApp.getPlatformRelease(targetPlatKey)?.latestVersion ??
                    catalogApp.latestVersion;
            updatesFound[installed.title] = latestVersion;
            final willAutoUpdateImmediately =
                _initialDebounceCompleted && installed.autoUpdate;
            if (silent && !willAutoUpdateImmediately) {
              await NotificationService.notifyUpdateAvailable(
                installed.title,
                latestVersion,
              );
            }
          }
        }
      }

      if (manifest.launcherMeta != null) {
        _latestLauncherMeta = manifest.launcherMeta;
        final latestLauncher = manifest.launcherMeta!.latestVersion;
        if (SelfUpdateService.isNewerVersion(latestLauncher, AppConstants.appVersion)) {
          updatesFound[AppConstants.appName] = latestLauncher;
          final willAutoSelfUpdateImmediately =
              shouldAutoSelfUpdate(launcherMeta: manifest.launcherMeta);
          if (silent && !willAutoSelfUpdateImmediately) {
            await NotificationService.showNotification(
              title: AppStrings.newLauncherVersionTitle(AppConstants.appName),
              body: AppStrings.newVersionReadyBody(latestLauncher),
            );
          }
          await evaluateAutoSelfUpdate(launcherMeta: manifest.launcherMeta);
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
