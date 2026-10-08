import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hakkin_launcher/core/constants/app_constants.dart';
import 'package:hakkin_launcher/core/platform/os_paths.dart';
import 'package:hakkin_launcher/features/catalog/data/models/app_entry.dart';
import 'package:hakkin_launcher/features/library/presentation/controllers/library_controller.dart';
import 'package:hakkin_launcher/features/updater/services/patch_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

final patchEngineProvider = Provider<PatchEngine>((ref) {
  final libraryRepo = ref.watch(libraryRepositoryProvider);
  return PatchEngine(libraryRepository: libraryRepo);
});

class UpdateProgressNotifier extends StateNotifier<Map<String, UpdateStatus>> {
  final Ref _ref;

  UpdateProgressNotifier(this._ref) : super({});

  Future<void> startInstallOrUpdate(AppEntry app) async {
    final patchEngine = _ref.read(patchEngineProvider);
    final platformKey = OsPaths.getCurrentPlatformKey();

    final prefs = await SharedPreferences.getInstance();
    final customPath = prefs.getString(AppConstants.prefCustomInstallPathKey);

    await for (final status in patchEngine.installOrUpdate(
      app: app,
      platformKey: platformKey,
      customInstallPath: customPath?.isNotEmpty == true ? customPath : null,
    )) {
      state = {...state, app.id: status};

      if (status.stage == UpdateStage.completed) {
        // Refrescar biblioteca tras completar
        _ref.read(installedAppsProvider.notifier).loadApps();
      }
    }
  }

  void clearStatus(String appId) {
    final updated = Map<String, UpdateStatus>.from(state)..remove(appId);
    state = updated;
  }
}

final updateProgressProvider =
    StateNotifierProvider<UpdateProgressNotifier, Map<String, UpdateStatus>>((ref) {
  return UpdateProgressNotifier(ref);
});
