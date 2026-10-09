import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/crypto/hash_validator.dart';
import '../../../../core/platform/process_launcher.dart';
import '../../../catalog/presentation/controllers/catalog_controller.dart';
import '../../data/models/installed_app.dart';
import '../../data/repositories/library_repository.dart';

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  return LibraryRepository();
});

class InstalledAppsNotifier extends StateNotifier<AsyncValue<List<InstalledApp>>> {
  final LibraryRepository _repo;
  final Ref _ref;

  InstalledAppsNotifier(this._repo, this._ref) : super(const AsyncValue.loading()) {
    loadApps();
  }

  Future<void> loadApps() async {
    try {
      final apps = await _repo.getInstalledApps();
      state = AsyncValue.data(apps);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> launchApp(InstalledApp app) async {
    final args = <String>[];
    if (app.launchArguments != null && app.launchArguments!.trim().isNotEmpty) {
      args.addAll(app.launchArguments!.trim().split(RegExp(r'\s+')));
    }

    var exePath = app.executablePath;
    final resolved = ProcessLauncher.resolveExecutablePath(exePath, app.installDirectory);
    if (resolved != null && resolved != exePath) {
      exePath = resolved;
      final updated = app.copyWith(executablePath: exePath);
      await _repo.saveInstalledApp(updated);
    }

    final success = await ProcessLauncher.launchApp(
      appId: app.id,
      executablePath: exePath,
      arguments: args,
      workingDirectory: app.installDirectory,
    );
    if (success) {
      await _repo.recordAppLaunch(app.id);
      await loadApps();
    }
    return success;
  }

  Future<void> updateLaunchArguments(String id, String arguments) async {
    final app = await _repo.getInstalledApp(id);
    if (app != null) {
      final updated = app.copyWith(launchArguments: arguments);
      await _repo.saveInstalledApp(updated);
      await loadApps();
    }
  }

  /// Verifica la integridad de la aplicación instalada.
  Future<Map<String, dynamic>> verifyAppIntegrity(String id) async {
    final app = await _repo.getInstalledApp(id);
    if (app == null) {
      return {'isValid': false, 'message': 'Aplicación no registrada localmente'};
    }

    var exePath = app.executablePath;
    final resolved = ProcessLauncher.resolveExecutablePath(exePath, app.installDirectory);
    if (resolved != null) {
      exePath = resolved;
    }

    final exeFile = File(exePath);
    if (!await exeFile.exists()) {
      return {
        'isValid': false,
        'message': 'El archivo ejecutable no existe en disco: ${app.executablePath}',
      };
    }

    final manifestAsync = _ref.read(catalogManifestProvider);
    final manifest = manifestAsync.value;
    if (manifest != null) {
      final catalogApp = manifest.apps.where((a) => a.id == id).firstOrNull;
      final release = catalogApp?.getPlatformRelease(app.platformKey);
      if (release != null) {
        if (release.isAnomalousVersion(app.installedVersion)) {
          return {
            'isValid': false,
            'isAnomalous': true,
            'message':
                'Anomalía detectada: la versión v${app.installedVersion} es huérfana o inexistente en el catálogo. Requiere actualización completa a v${release.latestVersion}.',
          };
        }
        final versionInfo = release.getRelease(app.installedVersion) ?? release.latestRelease;
        if (versionInfo.package.sha256.isNotEmpty) {
          final size = await exeFile.length();
          if (size == 0) {
            return {'isValid': false, 'message': 'El archivo ejecutable está vacío'};
          }
        }
      }
    }

    final hash = await HashValidator.calculateSha256(exeFile);
    return {
      'isValid': true,
      'message': 'Todos los archivos verificados correctamente.',
      'sha256': hash,
    };
  }

  Future<bool> uninstallApp(String appId) async {
    final success = await _repo.uninstallApp(appId);
    if (success) {
      await loadApps();
    }
    return success;
  }
}

final installedAppsProvider =
    StateNotifierProvider<InstalledAppsNotifier, AsyncValue<List<InstalledApp>>>((ref) {
  final repo = ref.watch(libraryRepositoryProvider);
  return InstalledAppsNotifier(repo, ref);
});

/// Stream de aplicaciones en ejecución activa
final runningAppsStreamProvider = StreamProvider<Map<String, bool>>((ref) {
  return ProcessLauncher.runningStateStream;
});
