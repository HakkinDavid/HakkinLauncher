import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_technical_strings.dart';

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
      version: json[AppTechnicalStrings.keyVersion] as String? ??
          AppTechnicalStrings.defaultVersion,
      catalogTimestamp:
          json[AppTechnicalStrings.keyCatalogTimestamp] as String? ??
              AppTechnicalStrings.empty,
      launcherMeta: json[AppTechnicalStrings.keyLauncherMeta] != null
          ? LauncherMeta.fromJson(
              json[AppTechnicalStrings.keyLauncherMeta] as Map<String, dynamic>)
          : null,
      apps: (json[AppTechnicalStrings.keyApps] as List<dynamic>? ?? [])
          .map((e) => AppEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        AppTechnicalStrings.keyVersion: version,
        AppTechnicalStrings.keyCatalogTimestamp: catalogTimestamp,
        if (launcherMeta != null)
          AppTechnicalStrings.keyLauncherMeta: launcherMeta!.toJson(),
        AppTechnicalStrings.keyApps: apps.map((e) => e.toJson()).toList(),
      };

  CatalogManifest copyWith({
    String? version,
    String? catalogTimestamp,
    LauncherMeta? launcherMeta,
    List<AppEntry>? apps,
  }) {
    return CatalogManifest(
      version: version ?? this.version,
      catalogTimestamp: catalogTimestamp ?? this.catalogTimestamp,
      launcherMeta: launcherMeta ?? this.launcherMeta,
      apps: apps ?? this.apps,
    );
  }
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
    final rawReleases =
        json[AppTechnicalStrings.keyReleases] as Map<String, dynamic>? ?? {};
    final releasesMap = <String, Map<String, dynamic>>{};
    rawReleases.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        releasesMap[key] = value;
      }
    });

    return LauncherMeta(
      latestVersion: json[AppTechnicalStrings.keyLatestVersion] as String? ??
          AppTechnicalStrings.defaultVersion,
      minRequiredLauncherVersion:
          json[AppTechnicalStrings.keyMinRequiredLauncherVersion] as String?,
      releases: releasesMap,
    );
  }

  Map<String, dynamic> toJson() => {
        AppTechnicalStrings.keyLatestVersion: latestVersion,
        if (minRequiredLauncherVersion != null)
          AppTechnicalStrings.keyMinRequiredLauncherVersion:
              minRequiredLauncherVersion,
        AppTechnicalStrings.keyReleases: releases,
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
    final rawPlatforms =
        json[AppTechnicalStrings.keyPlatforms] as Map<String, dynamic>? ?? {};
    rawPlatforms.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        platformsMap[key] = PlatformRelease.fromJson(value);
      }
    });

    return AppEntry(
      id: json[AppTechnicalStrings.keyId] as String? ??
          AppTechnicalStrings.empty,
      slug: json[AppTechnicalStrings.keySlug] as String? ??
          AppTechnicalStrings.empty,
      title: json[AppTechnicalStrings.keyTitle] as String? ??
          AppTechnicalStrings.empty,
      category: json[AppTechnicalStrings.keyCategory] as String? ??
          AppTechnicalStrings.categoryGame,
      developer: json[AppTechnicalStrings.keyDeveloper] as String? ??
          AppStrings.defaultDeveloper,
      summary: json[AppTechnicalStrings.keySummary] as String? ??
          AppTechnicalStrings.empty,
      descriptionMarkdown:
          json[AppTechnicalStrings.keyDescriptionMarkdown] as String? ??
              AppTechnicalStrings.empty,
      tags: (json[AppTechnicalStrings.keyTags] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      assets: json[AppTechnicalStrings.keyAssets] != null
          ? AppAssets.fromJson(
              json[AppTechnicalStrings.keyAssets] as Map<String, dynamic>)
          : const AppAssets(),
      latestVersion: json[AppTechnicalStrings.keyLatestVersion] as String? ??
          AppTechnicalStrings.defaultVersion,
      platforms: platformsMap,
    );
  }

  Map<String, dynamic> toJson() => {
        AppTechnicalStrings.keyId: id,
        AppTechnicalStrings.keySlug: slug,
        AppTechnicalStrings.keyTitle: title,
        AppTechnicalStrings.keyCategory: category,
        AppTechnicalStrings.keyDeveloper: developer,
        AppTechnicalStrings.keySummary: summary,
        AppTechnicalStrings.keyDescriptionMarkdown: descriptionMarkdown,
        AppTechnicalStrings.keyTags: tags,
        AppTechnicalStrings.keyAssets: assets.toJson(),
        AppTechnicalStrings.keyLatestVersion: latestVersion,
        AppTechnicalStrings.keyPlatforms:
            platforms.map((k, v) => MapEntry(k, v.toJson())),
      };

  bool supportsPlatform(String platformKey) {
    return platforms.containsKey(platformKey);
  }

  PlatformRelease? getPlatformRelease(String platformKey) {
    return platforms[platformKey];
  }

  /// Comprueba si la versión instalada en la plataforma indicada constituye una anomalía
  /// (es decir, una versión huérfana o inexistente en el catálogo actual).
  bool isAnomalousInstalledVersion(String platformKey, String installedVersion) {
    final release = getPlatformRelease(platformKey);
    if (release == null) return false;
    return release.isAnomalousVersion(installedVersion);
  }

  /// Determina si una versión instalada requiere actualización (ya sea por existir una
  /// versión más reciente o por tratarse de una versión anómala/huérfana que debe corregirse).
  bool needsUpdate({
    required String platformKey,
    required String installedVersion,
  }) {
    final release = getPlatformRelease(platformKey);
    if (release == null) return false;
    if (release.isAnomalousVersion(installedVersion)) return true;
    return release.latestVersion != installedVersion;
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
      icon: json[AppTechnicalStrings.keyIcon] as String?,
      poster: json[AppTechnicalStrings.keyPoster] as String?,
      banner: json[AppTechnicalStrings.keyBanner] as String?,
      screenshots:
          (json[AppTechnicalStrings.keyScreenshots] as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (icon != null) AppTechnicalStrings.keyIcon: icon,
        if (poster != null) AppTechnicalStrings.keyPoster: poster,
        if (banner != null) AppTechnicalStrings.keyBanner: banner,
        AppTechnicalStrings.keyScreenshots: screenshots,
      };
}

class PlatformRelease {
  final String latestVersion;
  final List<String> protectedUserPaths;
  final List<AppVersionRelease> versions;

  const PlatformRelease({
    required this.latestVersion,
    this.protectedUserPaths = const [],
    required this.versions,
  });

  factory PlatformRelease.fromJson(Map<String, dynamic> json) {
    final rawVersions =
        json[AppTechnicalStrings.keyVersions] as List<dynamic>? ?? [];
    final versionsList = rawVersions
        .map((e) => AppVersionRelease.fromJson(e as Map<String, dynamic>))
        .toList();

    return PlatformRelease(
      latestVersion: json[AppTechnicalStrings.keyLatestVersion] as String? ??
          (versionsList.isNotEmpty
              ? versionsList.first.version
              : AppTechnicalStrings.defaultVersion),
      protectedUserPaths:
          (json[AppTechnicalStrings.keyProtectedUserPaths] as List<dynamic>? ??
                  [])
              .map((e) => e.toString())
              .toList(),
      versions: versionsList,
    );
  }

  Map<String, dynamic> toJson() => {
        AppTechnicalStrings.keyLatestVersion: latestVersion,
        AppTechnicalStrings.keyProtectedUserPaths: protectedUserPaths,
        AppTechnicalStrings.keyVersions: versions.map((e) => e.toJson()).toList(),
      };

  /// Obtiene la versión más reciente disponible
  AppVersionRelease get latestRelease => versions.firstWhere(
        (v) => v.version == latestVersion,
        orElse: () => versions.isNotEmpty
            ? versions.first
            : const AppVersionRelease.empty(),
      );

  /// Obtiene una versión específica por su identificador
  AppVersionRelease? getRelease(String version) {
    for (final v in versions) {
      if (v.version == version) return v;
    }
    return null;
  }

  /// Lista ordenada de nombres de versión disponibles
  List<String> get availableVersions => versions.map((v) => v.version).toList();

  /// Comprueba si una versión está registrada formalmente en el catálogo para esta plataforma.
  bool hasVersion(String version) {
    return versions.any((v) => v.version == version);
  }

  /// Detecta si una versión dada constituye una anomalía (es decir, una versión
  /// huérfana o inexistente en el catálogo).
  bool isAnomalousVersion(String version) {
    return !hasVersion(version);
  }

  /// Encuentra si hay un parche delta aplicable desde una versión instalada específica hacia una versión destino
  DeltaUpdate? findDeltaFor(String fromVersion, String toVersion) {
    final target = getRelease(toVersion);
    if (target != null) {
      for (final delta in target.deltaPatches) {
        if (delta.fromVersion == fromVersion) {
          return delta;
        }
      }
    }
    return null;
  }

  /// Encuentra la secuencia óptima de parches delta (cadena de parches) desde [fromVersion]
  /// hasta [toVersion] que minimice el tamaño total de transferencia en bytes.
  ///
  /// Si se especifica [maxTransferBytes] (por ejemplo, el tamaño del paquete completo),
  /// la estrategia sólo es seleccionada si el tamaño total de la cadena es estrictamente
  /// menor que dicho límite. Si no existe camino o el costo total es mayor o igual que
  /// [maxTransferBytes], retorna `null`.
  List<DeltaUpdate>? findOptimalDeltaChain(
    String fromVersion,
    String toVersion, {
    int? maxTransferBytes,
  }) {
    if (fromVersion == toVersion) {
      return const [];
    }

    if (!hasVersion(fromVersion) || !hasVersion(toVersion)) {
      return null;
    }

    final allDeltas = <DeltaUpdate>[];
    for (final v in versions) {
      allDeltas.addAll(v.deltaPatches);
    }

    if (allDeltas.isEmpty) {
      return null;
    }

    final adjacency = <String, List<DeltaUpdate>>{};
    for (final delta in allDeltas) {
      if (delta.fromVersion.isEmpty || delta.toVersion.isEmpty) continue;
      adjacency.putIfAbsent(delta.fromVersion, () => []).add(delta);
    }

    if (!adjacency.containsKey(fromVersion)) {
      return null;
    }

    // Algoritmo de Dijkstra para encontrar el camino de menor costo de transferencia (sizeBytes)
    final minCost = <String, int>{fromVersion: 0};
    final minHops = <String, int>{fromVersion: 0};
    final previousEdge = <String, DeltaUpdate>{};
    final previousNode = <String, String>{};
    final visited = <String>{};

    final queue = <String>{fromVersion};

    while (queue.isNotEmpty) {
      String? current;
      int bestCost = 1 << 62;
      int bestHops = 1 << 30;

      for (final node in queue) {
        final c = minCost[node] ?? (1 << 62);
        final h = minHops[node] ?? (1 << 30);
        if (c < bestCost || (c == bestCost && h < bestHops)) {
          bestCost = c;
          bestHops = h;
          current = node;
        }
      }

      if (current == null) break;
      queue.remove(current);
      visited.add(current);

      if (current == toVersion) {
        break;
      }

      final edges = adjacency[current] ?? const [];
      for (final edge in edges) {
        final neighbor = edge.toVersion;
        if (visited.contains(neighbor)) continue;

        final newCost = bestCost + edge.sizeBytes;
        final newHops = bestHops + 1;

        final currentNeighborCost = minCost[neighbor];
        final currentNeighborHops = minHops[neighbor];

        if (currentNeighborCost == null ||
            newCost < currentNeighborCost ||
            (newCost == currentNeighborCost && newHops < currentNeighborHops!)) {
          minCost[neighbor] = newCost;
          minHops[neighbor] = newHops;
          previousEdge[neighbor] = edge;
          previousNode[neighbor] = current;
          queue.add(neighbor);
        }
      }
    }

    if (!minCost.containsKey(toVersion) || !previousEdge.containsKey(toVersion)) {
      return null;
    }

    final totalBytes = minCost[toVersion]!;

    // Si se especificó un límite superior, el costo total de la cadena debe ser estrictamente menor
    if (maxTransferBytes != null && maxTransferBytes > 0 && totalBytes >= maxTransferBytes) {
      return null;
    }

    // Reconstruir la cadena de parches desde toVersion hacia fromVersion
    final chain = <DeltaUpdate>[];
    String? curr = toVersion;
    while (curr != null && curr != fromVersion) {
      final edge = previousEdge[curr];
      if (edge == null) break;
      chain.insert(0, edge);
      curr = previousNode[curr];
    }

    if (chain.isEmpty ||
        chain.first.fromVersion != fromVersion ||
        chain.last.toVersion != toVersion) {
      return null;
    }

    return chain;
  }
}

class AppVersionRelease {
  final String version;
  final DateTime? releaseDate;
  final String changelog;
  final String entryPoint;
  final PackageArtifact package;
  final List<DeltaUpdate> deltaPatches;
  final Scripts scripts;

  const AppVersionRelease({
    required this.version,
    this.releaseDate,
    this.changelog = AppTechnicalStrings.empty,
    required this.entryPoint,
    required this.package,
    this.deltaPatches = const [],
    this.scripts = const Scripts(),
  });

  const AppVersionRelease.empty()
      : version = AppTechnicalStrings.defaultVersion,
        releaseDate = null,
        changelog = AppTechnicalStrings.empty,
        entryPoint = AppTechnicalStrings.empty,
        package = const PackageArtifact.empty(),
        deltaPatches = const [],
        scripts = const Scripts();

  factory AppVersionRelease.fromJson(Map<String, dynamic> json) {
    return AppVersionRelease(
      version: json[AppTechnicalStrings.keyVersion] as String? ??
          AppTechnicalStrings.defaultVersion,
      releaseDate: json[AppTechnicalStrings.keyReleaseDate] != null
          ? DateTime.tryParse(
              json[AppTechnicalStrings.keyReleaseDate].toString())
          : null,
      changelog: json[AppTechnicalStrings.keyChangelog] as String? ??
          AppTechnicalStrings.empty,
      entryPoint: json[AppTechnicalStrings.keyEntryPoint] as String? ??
          AppTechnicalStrings.empty,
      package: PackageArtifact.fromJson(
          json[AppTechnicalStrings.keyPackage] as Map<String, dynamic>? ?? {}),
      deltaPatches:
          (json[AppTechnicalStrings.keyDeltaPatches] as List<dynamic>? ?? [])
              .map((e) => DeltaUpdate.fromJson(e as Map<String, dynamic>))
              .toList(),
      scripts: json[AppTechnicalStrings.keyScripts] != null
          ? Scripts.fromJson(
              json[AppTechnicalStrings.keyScripts] as Map<String, dynamic>)
          : const Scripts(),
    );
  }

  Map<String, dynamic> toJson() => {
        AppTechnicalStrings.keyVersion: version,
        if (releaseDate != null)
          AppTechnicalStrings.keyReleaseDate: releaseDate!.toIso8601String(),
        AppTechnicalStrings.keyChangelog: changelog,
        AppTechnicalStrings.keyEntryPoint: entryPoint,
        AppTechnicalStrings.keyPackage: package.toJson(),
        AppTechnicalStrings.keyDeltaPatches:
            deltaPatches.map((e) => e.toJson()).toList(),
        AppTechnicalStrings.keyScripts: scripts.toJson(),
      };
}

class PackageArtifact {
  final String url;
  final int sizeBytes;
  final String sha256;

  const PackageArtifact({
    required this.url,
    this.sizeBytes = 0,
    required this.sha256,
  });

  const PackageArtifact.empty()
      : url = AppTechnicalStrings.empty,
        sizeBytes = 0,
        sha256 = AppTechnicalStrings.empty;

  factory PackageArtifact.fromJson(Map<String, dynamic> json) {
    return PackageArtifact(
      url: json[AppTechnicalStrings.keyUrl] as String? ??
          AppTechnicalStrings.empty,
      sizeBytes:
          (json[AppTechnicalStrings.keySizeBytes] as num?)?.toInt() ?? 0,
      sha256: json[AppTechnicalStrings.keySha256] as String? ??
          AppTechnicalStrings.empty,
    );
  }

  Map<String, dynamic> toJson() => {
        AppTechnicalStrings.keyUrl: url,
        AppTechnicalStrings.keySizeBytes: sizeBytes,
        AppTechnicalStrings.keySha256: sha256,
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
      fromVersion: json[AppTechnicalStrings.keyFromVersion] as String? ??
          AppTechnicalStrings.empty,
      toVersion: json[AppTechnicalStrings.keyToVersion] as String? ??
          AppTechnicalStrings.empty,
      patchFormat: json[AppTechnicalStrings.keyPatchFormat] as String? ??
          AppTechnicalStrings.defaultPatchFormat,
      url: json[AppTechnicalStrings.keyUrl] as String? ??
          AppTechnicalStrings.empty,
      sizeBytes:
          (json[AppTechnicalStrings.keySizeBytes] as num?)?.toInt() ?? 0,
      patchSha256: json[AppTechnicalStrings.keyPatchSha256] as String? ??
          AppTechnicalStrings.empty,
      targetSha256: json[AppTechnicalStrings.keyTargetSha256] as String? ??
          AppTechnicalStrings.empty,
    );
  }

  Map<String, dynamic> toJson() => {
        AppTechnicalStrings.keyFromVersion: fromVersion,
        AppTechnicalStrings.keyToVersion: toVersion,
        AppTechnicalStrings.keyPatchFormat: patchFormat,
        AppTechnicalStrings.keyUrl: url,
        AppTechnicalStrings.keySizeBytes: sizeBytes,
        AppTechnicalStrings.keyPatchSha256: patchSha256,
        AppTechnicalStrings.keyTargetSha256: targetSha256,
      };
}

class Scripts {
  final String? preInstall;
  final String? postInstall;

  const Scripts({this.preInstall, this.postInstall});

  factory Scripts.fromJson(Map<String, dynamic> json) {
    return Scripts(
      preInstall: json[AppTechnicalStrings.keyPreInstall] as String?,
      postInstall: json[AppTechnicalStrings.keyPostInstall] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (preInstall != null)
          AppTechnicalStrings.keyPreInstall: preInstall,
        if (postInstall != null)
          AppTechnicalStrings.keyPostInstall: postInstall,
      };
}
