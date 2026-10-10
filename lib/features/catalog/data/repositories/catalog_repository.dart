import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_technical_strings.dart';
import '../models/app_entry.dart';

/// Repositorio para la obtención dinámica y persistencia en caché del catálogo de aplicaciones.
///
/// Implementa Single Source of Truth basado exclusivamente en el catálogo remoto
/// y caché local (SharedPreferences), sin empaquetar JSONs dentro de los activos de la aplicación.
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

  /// Obtiene la URL configurada del catálogo (Single Source of Truth).
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

  /// Carga el catálogo de forma dinámica desde la red con persistencia y fallback en caché local.
  ///
  /// No incluye ni depende de archivos JSON bundled dentro del binario.
  Future<CatalogManifest> fetchCatalog({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final url = await getCatalogUrl();

    final requestOptions = Options(
      responseType: ResponseType.plain,
      headers: forceRefresh
          ? const {
              AppTechnicalStrings.headerCacheControl:
                  AppTechnicalStrings.valNoCacheFull,
              AppTechnicalStrings.headerPragma:
                  AppTechnicalStrings.valNoCache,
            }
          : null,
    );
    final queryParams = forceRefresh
        ? {
            AppTechnicalStrings.paramCacheBuster:
                DateTime.now().millisecondsSinceEpoch.toString()
          }
        : null;

    // 1. Obtención dinámica en caliente desde la red (Single Source of Truth)
    try {
      final response = await _dio.get<String>(
        url,
        options: requestOptions,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data != null && response.data!.isNotEmpty) {
        final jsonStr = response.data!;
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
        final manifest = CatalogManifest.fromJson(decoded);

        // Persistir en caché local inmediatamente
        await prefs.setString(AppConstants.prefCachedCatalogJson, jsonStr);
        return manifest;
      }
    } catch (_) {
      // Red no disponible o error HTTP: fallback transparente a caché local
    }

    // 2. Fallback a caché local persistente
    final cached = prefs.getString(AppConstants.prefCachedCatalogJson);
    if (cached != null && cached.isNotEmpty) {
      try {
        final decoded = jsonDecode(cached) as Map<String, dynamic>;
        return CatalogManifest.fromJson(decoded);
      } catch (_) {}
    }

    // 3. Fallback no-nulo seguro para arranque en frío sin conexión previa
    return const CatalogManifest(
      version: AppTechnicalStrings.defaultVersion,
      catalogTimestamp: AppTechnicalStrings.empty,
      apps: [],
    );
  }
}
