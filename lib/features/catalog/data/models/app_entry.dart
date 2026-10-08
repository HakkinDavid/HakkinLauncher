/// Modelo de datos para el manifiesto del catálogo de HakkinLauncher
class CatalogManifest {
  final String version;
  final String catalogTimestamp;
  final LauncherMeta? launcherMeta;
  final List<AppEntry> apps;

  const CatalogManifest({
    required this.version,
    required this.catalogTimestamp,
    this.launcherMeta,
    required this.apps,
  });

  factory CatalogManifest.fromJson(Map<String, dynamic> json) {
    return CatalogManifest(
      version: json['version'] as String? ?? '1.0.0',
      catalogTimestamp: json['catalog_timestamp'] as String? ?? '',
      launcherMeta: json['launcher_meta'] != null
          ? LauncherMeta.fromJson(json['launcher_meta'] as Map<String, dynamic>)
          : null,
      apps: (json['apps'] as List<dynamic>? ?? [])
          .map((e) => AppEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'catalog_timestamp': catalogTimestamp,
        if (launcherMeta != null) 'launcher_meta': launcherMeta!.toJson(),
        'apps': apps.map((e) => e.toJson()).toList(),
      };
}

class LauncherMeta {
  final String latestVersion;
  final String? minRequiredLauncherVersion;
  final Map<String, Map<String, dynamic>> releases;

  const LauncherMeta({
    required this.latestVersion,
    this.minRequiredLauncherVersion,
    required this.releases,
  });

  factory LauncherMeta.fromJson(Map<String, dynamic> json) {
    final rawReleases = json['releases'] as Map<String, dynamic>? ?? {};
    final releasesMap = <String, Map<String, dynamic>>{};
    rawReleases.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        releasesMap[key] = value;
      }
    });

    return LauncherMeta(
      latestVersion: json['latest_version'] as String? ?? '1.0.0',
      minRequiredLauncherVersion: json['min_required_launcher_version'] as String?,
      releases: releasesMap,
    );
  }

  Map<String, dynamic> toJson() => {
        'latest_version': latestVersion,
        if (minRequiredLauncherVersion != null)
          'min_required_launcher_version': minRequiredLauncherVersion,
        'releases': releases,
      };
}

class AppEntry {
  final String id;
  final String slug;
  final String title;
  final String category; // 'game' | 'app' | 'tool'
  final String developer;
  final String summary;
  final String descriptionMarkdown;
  final List<String> tags;
  final AppAssets assets;
  final String latestVersion;
  final Map<String, PlatformRelease> platforms;

  const AppEntry({
    required this.id,
    required this.slug,
    required this.title,
    required this.category,
    required this.developer,
    required this.summary,
    required this.descriptionMarkdown,
    required this.tags,
    required this.assets,
    required this.latestVersion,
    required this.platforms,
  });

  factory AppEntry.fromJson(Map<String, dynamic> json) {
    final platformsMap = <String, PlatformRelease>{};
    final rawPlatforms = json['platforms'] as Map<String, dynamic>? ?? {};
    rawPlatforms.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        platformsMap[key] = PlatformRelease.fromJson(value);
      }
    });

    return AppEntry(
      id: json['id'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? 'game',
      developer: json['developer'] as String? ?? 'Desarrollador',
      summary: json['summary'] as String? ?? '',
      descriptionMarkdown: json['description_markdown'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      assets: json['assets'] != null
          ? AppAssets.fromJson(json['assets'] as Map<String, dynamic>)
          : const AppAssets(),
      latestVersion: json['latest_version'] as String? ?? '1.0.0',
      platforms: platformsMap,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'slug': slug,
        'title': title,
        'category': category,
        'developer': developer,
        'summary': summary,
        'description_markdown': descriptionMarkdown,
        'tags': tags,
        'assets': assets.toJson(),
        'latest_version': latestVersion,
        'platforms': platforms.map((k, v) => MapEntry(k, v.toJson())),
      };

  bool supportsPlatform(String platformKey) {
    return platforms.containsKey(platformKey);
  }

  PlatformRelease? getPlatformRelease(String platformKey) {
    return platforms[platformKey];
  }
}

class AppAssets {
  final String? icon;
  final String? poster;
  final String? banner;
  final List<String> screenshots;

  const AppAssets({
    this.icon,
    this.poster,
    this.banner,
    this.screenshots = const [],
  });

  factory AppAssets.fromJson(Map<String, dynamic> json) {
    return AppAssets(
      icon: json['icon'] as String?,
      poster: json['poster'] as String?,
      banner: json['banner'] as String?,
      screenshots: (json['screenshots'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (icon != null) 'icon': icon,
        if (poster != null) 'poster': poster,
        if (banner != null) 'banner': banner,
        'screenshots': screenshots,
      };
}

class PlatformRelease {
  final String executableRelativePath;
  final FullPackage fullPackage;
  final List<DeltaUpdate> deltaUpdates;
  final List<String> protectedUserPaths;
  final Scripts scripts;

  const PlatformRelease({
    required this.executableRelativePath,
    required this.fullPackage,
    this.deltaUpdates = const [],
    this.protectedUserPaths = const [],
    this.scripts = const Scripts(),
  });

  factory PlatformRelease.fromJson(Map<String, dynamic> json) {
    return PlatformRelease(
      executableRelativePath: json['executable_relative_path'] as String? ?? '',
      fullPackage: FullPackage.fromJson(json['full_package'] as Map<String, dynamic>? ?? {}),
      deltaUpdates: (json['delta_updates'] as List<dynamic>? ?? [])
          .map((e) => DeltaUpdate.fromJson(e as Map<String, dynamic>))
          .toList(),
      protectedUserPaths: (json['protected_user_paths'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      scripts: json['scripts'] != null
          ? Scripts.fromJson(json['scripts'] as Map<String, dynamic>)
          : const Scripts(),
    );
  }

  Map<String, dynamic> toJson() => {
        'executable_relative_path': executableRelativePath,
        'full_package': fullPackage.toJson(),
        'delta_updates': deltaUpdates.map((e) => e.toJson()).toList(),
        'protected_user_paths': protectedUserPaths,
        'scripts': scripts.toJson(),
      };

  /// Encuentra si hay un parche delta aplicable desde una versión instalada específica
  DeltaUpdate? findDeltaFor(String fromVersion, String toVersion) {
    for (final delta in deltaUpdates) {
      if (delta.fromVersion == fromVersion && delta.toVersion == toVersion) {
        return delta;
      }
    }
    return null;
  }
}

class FullPackage {
  final String version;
  final String url;
  final int sizeBytes;
  final String sha256;

  const FullPackage({
    required this.version,
    required this.url,
    this.sizeBytes = 0,
    required this.sha256,
  });

  factory FullPackage.fromJson(Map<String, dynamic> json) {
    return FullPackage(
      version: json['version'] as String? ?? '1.0.0',
      url: json['url'] as String? ?? '',
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      sha256: json['sha256'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'url': url,
        'size_bytes': sizeBytes,
        'sha256': sha256,
      };
}

class DeltaUpdate {
  final String fromVersion;
  final String toVersion;
  final String patchFormat; // 'hdiff' | 'bsdiff'
  final String url;
  final int sizeBytes;
  final String patchSha256;
  final String targetSha256;

  const DeltaUpdate({
    required this.fromVersion,
    required this.toVersion,
    required this.patchFormat,
    required this.url,
    this.sizeBytes = 0,
    required this.patchSha256,
    required this.targetSha256,
  });

  factory DeltaUpdate.fromJson(Map<String, dynamic> json) {
    return DeltaUpdate(
      fromVersion: json['from_version'] as String? ?? '',
      toVersion: json['to_version'] as String? ?? '',
      patchFormat: json['patch_format'] as String? ?? 'hdiff',
      url: json['url'] as String? ?? '',
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      patchSha256: json['patch_sha256'] as String? ?? '',
      targetSha256: json['target_sha256'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'from_version': fromVersion,
        'to_version': toVersion,
        'patch_format': patchFormat,
        'url': url,
        'size_bytes': sizeBytes,
        'patch_sha256': patchSha256,
        'target_sha256': targetSha256,
      };
}

class Scripts {
  final String? preInstall;
  final String? postInstall;

  const Scripts({this.preInstall, this.postInstall});

  factory Scripts.fromJson(Map<String, dynamic> json) {
    return Scripts(
      preInstall: json['pre_install'] as String?,
      postInstall: json['post_install'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (preInstall != null) 'pre_install': preInstall,
        if (postInstall != null) 'post_install': postInstall,
      };
}
