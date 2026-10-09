/// Constantes globales de HakkinLauncher
class AppConstants {
  AppConstants._();

  static const String appName = 'HakkinLauncher';
  static const String appVersion = '1.0.0';

  static const String defaultCatalogUrl =
      'https://raw.githubusercontent.com/HakkinDavid/HakkinLauncher/main/docs/catalog_example.json';

  static const String prefCatalogUrlKey = 'hakkin_catalog_url';
  static const String prefCustomInstallPathKey = 'hakkin_install_path';
  static const String prefCloseToTrayKey = 'hakkin_close_to_tray';
  static const String prefAutoCheckUpdatesKey = 'hakkin_auto_check_updates';
  static const String prefCachedCatalogJson = 'hakkin_cached_catalog_json';
  static const String prefInstalledAppsJson = 'hakkin_installed_apps_json';

  static const Duration backgroundCheckInterval = Duration(hours: 4);

  static const double windowMinWidth = 1080;
  static const double windowMinHeight = 680;

  static const String appIconPath = 'assets/hakkinlauncher.png';
  static const String appIconIcoPath = 'assets/hakkinlauncher.ico';
}
