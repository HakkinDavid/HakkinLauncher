import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_constants.dart';
import '../models/app_entry.dart';

import '../../self_update/services/self_update_service.dart';

/// Repositorio para la obtención, persistencia en caché y fallback del catálogo de aplicaciones.
class CatalogRepository {
  final Dio _dio;

  CatalogRepository({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
              ),
            );

  /// Obtiene la URL configurada del catálogo.
  Future<String> getCatalogUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.prefCatalogUrlKey) ??
        AppConstants.defaultCatalogUrl;
  }

  /// Guarda una nueva URL de catálogo personalizada.
  Future<void> setCatalogUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefCatalogUrlKey, url);
  }

  /// Consulta directamente los metadatos oficiales del lanzador en GitHub (rama master)
  /// para garantizar la detección de actualizaciones aunque el catálogo JSON remoto sufra desfase.
  Future<LauncherMeta?> fetchLatestLauncherMeta() async {
    try {
      final res = await _dio.get<String>(
        AppConstants.launcherMetaUrl,
        options: Options(
          responseType: ResponseType.plain,
          headers: const {
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
          },
        ),
        queryParameters: {'_t': DateTime.now().millisecondsSinceEpoch.toString()},
      );
      if (res.statusCode == 200 && res.data != null && res.data!.isNotEmpty) {
        final decoded = jsonDecode(res.data!) as Map<String, dynamic>;
        final parsed = LauncherMeta.fromJson(decoded);
        if (parsed.latestVersion.isNotEmpty && parsed.releases.isNotEmpty) {
          return parsed;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Carga el catálogo: intenta en caliente desde la red, con fallback a caché local y asset bundled.
  Future<CatalogManifest> fetchCatalog({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final url = await getCatalogUrl();

    CatalogManifest? networkManifest;

    final requestOptions = Options(
      responseType: ResponseType.plain,
      headers: forceRefresh
          ? const {
              'Cache-Control': 'no-cache, no-store, must-revalidate',
              'Pragma': 'no-cache',
            }
          : null,
    );
    final queryParams = forceRefresh
        ? {'_t': DateTime.now().millisecondsSinceEpoch.toString()}
        : null;

    // 1. Intentar descargar desde la URL principal
    try {
      final response = await _dio.get<String>(
        url,
        options: requestOptions,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data != null) {
        final jsonStr = response.data!;
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
        networkManifest = CatalogManifest.fromJson(decoded);
      }
    } catch (_) {
      // Si la URL principal falla, probar la URL de fallback (catalog_example.json en master)
      if (url != AppConstants.fallbackCatalogUrl) {
        try {
          final fallbackResponse = await _dio.get<String>(
            AppConstants.fallbackCatalogUrl,
            options: requestOptions,
            queryParameters: queryParams,
          );
          if (fallbackResponse.statusCode == 200 && fallbackResponse.data != null) {
            final jsonStr = fallbackResponse.data!;
            final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
            networkManifest = CatalogManifest.fromJson(decoded);
          }
        } catch (_) {}
      }
    }

    CatalogManifest? bundledManifest;
    try {
      final bundledStr = await rootBundle.loadString('docs/catalog_example.json');
      final decoded = jsonDecode(bundledStr) as Map<String, dynamic>;
      bundledManifest = CatalogManifest.fromJson(decoded);
    } catch (_) {}

    CatalogManifest? resultManifest = networkManifest;

    // Si la red no respondió y no es un forceRefresh, intentar con la caché local
    if (resultManifest == null && !forceRefresh) {
      final cached = prefs.getString(AppConstants.prefCachedCatalogJson);
      if (cached != null && cached.isNotEmpty) {
        try {
          final decoded = jsonDecode(cached) as Map<String, dynamic>;
          final cachedManifest = CatalogManifest.fromJson(decoded);
          if (bundledManifest != null) {
            final cachedTime = DateTime.tryParse(cachedManifest.catalogTimestamp);
            final bundledTime = DateTime.tryParse(bundledManifest.catalogTimestamp);
            if (bundledTime != null && (cachedTime == null || bundledTime.isAfter(cachedTime))) {
              resultManifest = bundledManifest;
            } else {
              resultManifest = cachedManifest;
            }
          } else {
            resultManifest = cachedManifest;
          }
        } catch (_) {}
      }
    }

    // Si aún no tenemos manifiesto, usar el bundled o el vacío
    resultManifest ??= bundledManifest ??
        const CatalogManifest(
          version: '1.0.0',
          catalogTimestamp: '',
          apps: [],
        );

    // 2. Consulta y reconciliación resiliente de launcher_meta en los canales oficiales de release
    try {
      final remoteLauncherMeta = await fetchLatestLauncherMeta();
      if (remoteLauncherMeta != null) {
        final currentMeta = resultManifest.launcherMeta;
        if (currentMeta == null ||
            SelfUpdateService.isNewerVersion(remoteLauncherMeta.latestVersion, currentMeta.latestVersion)) {
          resultManifest = resultManifest.copyWith(launcherMeta: remoteLauncherMeta);
        }
      }
    } catch (_) {}

    // Persistir en caché local la última versión obtenida
    try {
      await prefs.setString(AppConstants.prefCachedCatalogJson, jsonEncode(resultManifest.toJson()));
    } catch (_) {}

    return resultManifest;
  }
}
