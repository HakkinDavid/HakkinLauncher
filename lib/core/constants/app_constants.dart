import 'app_strings.dart';
import 'app_technical_strings.dart';

/// Constantes globales de HakkinLauncher centralizadas.
///
/// Todas las cadenas de texto se derivan de [AppStrings] y [AppTechnicalStrings]
/// garantizando que no existan strings literales en el código.
class AppConstants {
  AppConstants._();

  static const String appName = AppStrings.appName;

  /// Versión base sincronizada con el catálogo y releases oficiales.
  static const String defaultAppVersion = AppTechnicalStrings.defaultAppVersion;

  /// Versión activa del lanzador inyectada en tiempo de compilación con `--dart-define=APP_VERSION=...`.
  /// Si no se especifica en la compilación, recurre a [defaultAppVersion].
  static const String appVersion = AppTechnicalStrings.appVersion;

  static const String defaultCatalogUrl = AppTechnicalStrings.defaultCatalogUrl;

  static const String fallbackCatalogUrl = AppTechnicalStrings.fallbackCatalogUrl;

  static const String launcherMetaUrl = AppTechnicalStrings.launcherMetaUrl;

  static const String prefCatalogUrlKey = AppTechnicalStrings.prefCatalogUrlKey;
  static const String prefCustomInstallPathKey =
      AppTechnicalStrings.prefCustomInstallPathKey;
  static const String prefCloseToTrayKey = AppTechnicalStrings.prefCloseToTrayKey;
  static const String prefAutoCheckUpdatesKey =
      AppTechnicalStrings.prefAutoCheckUpdatesKey;
  static const String prefCachedCatalogJson =
      AppTechnicalStrings.prefCachedCatalogJson;
  static const String prefInstalledAppsJson =
      AppTechnicalStrings.prefInstalledAppsJson;

  static const Duration backgroundCheckInterval =
      AppTechnicalStrings.backgroundCheckInterval;

  static const double windowMinWidth = 1080;
  static const double windowMinHeight = 680;

  static const String appIconPath = AppTechnicalStrings.appIconPath;
  static const String appIconIcoPath = AppTechnicalStrings.appIconIcoPath;

  // Componentes externos autogestionados (HDiffPatch / hpatchz)
  static const String defaultHpatchzVersion =
      AppTechnicalStrings.defaultHpatchzVersion;
  static const String hpatchzDownloadBaseUrl =
      AppTechnicalStrings.hpatchzDownloadBaseUrl;
}
