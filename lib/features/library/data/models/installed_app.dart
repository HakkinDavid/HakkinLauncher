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
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      installedVersion: json['installed_version'] as String? ?? '1.0.0',
      executablePath: json['executable_path'] as String? ?? '',
      installDirectory: json['install_directory'] as String? ?? '',
      installedAt: json['installed_at'] != null
          ? DateTime.tryParse(json['installed_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      lastLaunchedAt: json['last_launched_at'] != null
          ? DateTime.tryParse(json['last_launched_at'].toString())
          : null,
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      platformKey: json['platform_key'] as String? ?? '',
      launchArguments: json['launch_arguments'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'installed_version': installedVersion,
        'executable_path': executablePath,
        'install_directory': installDirectory,
        'installed_at': installedAt.toIso8601String(),
        if (lastLaunchedAt != null)
          'last_launched_at': lastLaunchedAt!.toIso8601String(),
        'size_bytes': sizeBytes,
        'platform_key': platformKey,
        if (launchArguments != null) 'launch_arguments': launchArguments,
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
