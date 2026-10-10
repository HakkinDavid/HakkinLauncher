import '../../../../core/constants/app_technical_strings.dart';

/// Modelo que representa una aplicación o juego instalado localmente en el equipo.
class InstalledApp {
  final String id;
  final String title;
  final String installedVersion;
  final String executablePath;
  final String installDirectory;
  final DateTime installedAt;
  final DateTime? lastLaunchedAt;
  final int sizeBytes;
  final String platformKey;
  final String? launchArguments;

  const InstalledApp({
    required this.id,
    required this.title,
    required this.installedVersion,
    required this.executablePath,
    required this.installDirectory,
    required this.installedAt,
    this.lastLaunchedAt,
    this.sizeBytes = 0,
    required this.platformKey,
    this.launchArguments,
  });

  factory InstalledApp.fromJson(Map<String, dynamic> json) {
    return InstalledApp(
      id: json[AppTechnicalStrings.keyId] as String? ?? AppTechnicalStrings.empty,
      title: json[AppTechnicalStrings.keyTitle] as String? ?? AppTechnicalStrings.empty,
      installedVersion: json[AppTechnicalStrings.keyInstalledVersion] as String? ??
          AppTechnicalStrings.defaultVersion,
      executablePath: json[AppTechnicalStrings.keyExecutablePath] as String? ??
          AppTechnicalStrings.empty,
      installDirectory: json[AppTechnicalStrings.keyInstallDirectory] as String? ??
          AppTechnicalStrings.empty,
      installedAt: json[AppTechnicalStrings.keyInstalledAt] != null
          ? DateTime.tryParse(json[AppTechnicalStrings.keyInstalledAt].toString()) ??
              DateTime.now()
          : DateTime.now(),
      lastLaunchedAt: json[AppTechnicalStrings.keyLastLaunchedAt] != null
          ? DateTime.tryParse(json[AppTechnicalStrings.keyLastLaunchedAt].toString())
          : null,
      sizeBytes:
          (json[AppTechnicalStrings.keySizeBytes] as num?)?.toInt() ?? 0,
      platformKey: json[AppTechnicalStrings.keyPlatformKey] as String? ??
          AppTechnicalStrings.empty,
      launchArguments: json[AppTechnicalStrings.keyLaunchArguments] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        AppTechnicalStrings.keyId: id,
        AppTechnicalStrings.keyTitle: title,
        AppTechnicalStrings.keyInstalledVersion: installedVersion,
        AppTechnicalStrings.keyExecutablePath: executablePath,
        AppTechnicalStrings.keyInstallDirectory: installDirectory,
        AppTechnicalStrings.keyInstalledAt: installedAt.toIso8601String(),
        if (lastLaunchedAt != null)
          AppTechnicalStrings.keyLastLaunchedAt: lastLaunchedAt!.toIso8601String(),
        AppTechnicalStrings.keySizeBytes: sizeBytes,
        AppTechnicalStrings.keyPlatformKey: platformKey,
        if (launchArguments != null)
          AppTechnicalStrings.keyLaunchArguments: launchArguments,
      };

  InstalledApp copyWith({
    String? installedVersion,
    String? executablePath,
    String? installDirectory,
    DateTime? lastLaunchedAt,
    int? sizeBytes,
    String? launchArguments,
  }) {
    return InstalledApp(
      id: id,
      title: title,
      installedVersion: installedVersion ?? this.installedVersion,
      executablePath: executablePath ?? this.executablePath,
      installDirectory: installDirectory ?? this.installDirectory,
      installedAt: installedAt,
      lastLaunchedAt: lastLaunchedAt ?? this.lastLaunchedAt,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      platformKey: platformKey,
      launchArguments: launchArguments ?? this.launchArguments,
    );
  }
}
