import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_constants.dart';
import '../models/installed_app.dart';

/// Repositorio para la persistencia del estado de las aplicaciones instaladas.
class LibraryRepository {
  LibraryRepository();

  /// Obtiene la lista de aplicaciones instaladas.
  Future<List<InstalledApp>> getInstalledApps() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(AppConstants.prefInstalledAppsJson);
    if (jsonStr == null || jsonStr.isEmpty) return [];

    try {
      final decoded = jsonDecode(jsonStr) as List<dynamic>;
      return decoded
          .map((e) => InstalledApp.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Obtiene una aplicación instalada específica por su ID.
  Future<InstalledApp?> getInstalledApp(String id) async {
    final apps = await getInstalledApps();
    for (final app in apps) {
      if (app.id == id) return app;
    }
    return null;
  }

  /// Guarda o actualiza una aplicación en el registro de instaladas.
  Future<void> saveInstalledApp(InstalledApp app) async {
    final apps = await getInstalledApps();
    final index = apps.indexWhere((e) => e.id == app.id);
    if (index >= 0) {
      apps[index] = app;
    } else {
      apps.add(app);
    }
    await _persistApps(apps);
  }

  /// Actualiza la fecha del último lanzamiento de la aplicación.
  Future<void> recordAppLaunch(String id) async {
    final apps = await getInstalledApps();
    final index = apps.indexWhere((e) => e.id == id);
    if (index >= 0) {
      apps[index] = apps[index].copyWith(lastLaunchedAt: DateTime.now());
      await _persistApps(apps);
    }
  }

  /// Desinstala una aplicación eliminando sus archivos y removiéndola del registro.
  /// Respeta las rutas definidas por el usuario si se especifican.
  Future<bool> uninstallApp(String id, {bool deleteUserData = false}) async {
    final app = await getInstalledApp(id);
    if (app == null) return false;

    try {
      final dir = Directory(app.installDirectory);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }

      final apps = await getInstalledApps();
      apps.removeWhere((e) => e.id == id);
      await _persistApps(apps);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _persistApps(List<InstalledApp> apps) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = apps.map((e) => e.toJson()).toList();
    await prefs.setString(AppConstants.prefInstalledAppsJson, jsonEncode(raw));
  }
}
