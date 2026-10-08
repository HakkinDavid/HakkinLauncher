import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/platform/process_launcher.dart';
import '../../data/models/installed_app.dart';
import '../../data/repositories/library_repository.dart';

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  return LibraryRepository();
});

class InstalledAppsNotifier extends StateNotifier<AsyncValue<List<InstalledApp>>> {
  final LibraryRepository _repo;

  InstalledAppsNotifier(this._repo) : super(const AsyncValue.loading()) {
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
    final success = await ProcessLauncher.launchApp(
      appId: app.id,
      executablePath: app.executablePath,
      workingDirectory: app.installDirectory,
    );
    if (success) {
      await _repo.recordAppLaunch(app.id);
      await loadApps();
    }
    return success;
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
  return InstalledAppsNotifier(repo);
});

/// Stream de aplicaciones en ejecución activa
final runningAppsStreamProvider = StreamProvider<Map<String, bool>>((ref) {
  return ProcessLauncher.runningStateStream;
});
