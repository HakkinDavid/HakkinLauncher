import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_constants.dart';
import '../models/app_entry.dart';

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

  /// Carga el catálogo: intenta en caliente desde la red, con fallback a caché local y asset bundled.
  Future<CatalogManifest> fetchCatalog({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final url = await getCatalogUrl();

    // 1. Intentar descargar en caliente
    try {
      final response = await _dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );

      if (response.statusCode == 200 && response.data != null) {
        final jsonStr = response.data!;
        // Validar que sea JSON parseable
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
        final manifest = CatalogManifest.fromJson(decoded);

        // Guardar en caché local
        await prefs.setString(AppConstants.prefCachedCatalogJson, jsonStr);
        return manifest;
      }
    } catch (_) {
      // Si falla la red, continuamos al fallback
    }

    // 2. Fallback a caché local persistente
    final cached = prefs.getString(AppConstants.prefCachedCatalogJson);
    if (cached != null && cached.isNotEmpty) {
      try {
        final decoded = jsonDecode(cached) as Map<String, dynamic>;
        return CatalogManifest.fromJson(decoded);
      } catch (_) {}
    }

    // 3. Fallback a asset local precargado
    try {
      final bundledStr = await rootBundle.loadString('docs/catalog_example.json');
      final decoded = jsonDecode(bundledStr) as Map<String, dynamic>;
      return CatalogManifest.fromJson(decoded);
    } catch (e) {
      // Manifiesto vacío de emergencia
      return const CatalogManifest(
        version: '1.0.0',
        catalogTimestamp: '',
        apps: [],
      );
    }
  }
}
