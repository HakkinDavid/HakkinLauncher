import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/app_entry.dart';
import '../../data/repositories/catalog_repository.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepository();
});

/// Proveedor del manifiesto completo del catálogo
final catalogManifestProvider =
    FutureProvider.autoDispose<CatalogManifest>((ref) async {
  final repo = ref.watch(catalogRepositoryProvider);
  return repo.fetchCatalog();
});

/// Filtro de búsqueda por texto
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Filtro de categoría: 'all', 'game', 'app'
final selectedCategoryProvider = StateProvider<String>((ref) => 'all');

/// Lista filtrada reactivamente de aplicaciones según búsqueda y categoría.
final filteredAppsProvider = Provider.autoDispose<List<AppEntry>>((ref) {
  final manifestAsync = ref.watch(catalogManifestProvider);
  final query = ref.watch(searchQueryProvider).toLowerCase().trim();
  final category = ref.watch(selectedCategoryProvider);

  return manifestAsync.maybeWhen(
    data: (manifest) {
      return manifest.apps.where((app) {
        // Filtro por categoría
        if (category != 'all' && app.category != category) {
          return false;
        }

        // Filtro por término de búsqueda
        if (query.isNotEmpty) {
          final titleMatch = app.title.toLowerCase().contains(query);
          final summaryMatch = app.summary.toLowerCase().contains(query);
          final tagMatch = app.tags.any((t) => t.toLowerCase().contains(query));
          if (!titleMatch && !summaryMatch && !tagMatch) {
            return false;
          }
        }

        return true;
      }).toList();
    },
    orElse: () => [],
  );
});
