import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/hero_carousel.dart';
import '../../../library/presentation/controllers/library_controller.dart';
import '../controllers/catalog_controller.dart';

class StoreScreen extends ConsumerWidget {
  const StoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manifestAsync = ref.watch(catalogManifestProvider);
    final filteredApps = ref.watch(filteredAppsProvider);
    final installedAppsAsync = ref.watch(installedAppsProvider);
    final runningAppsAsync = ref.watch(runningAppsStreamProvider);

    final installedMap = installedAppsAsync.maybeWhen(
      data: (apps) => {for (var a in apps) a.id: a},
      orElse: () => {},
    );

    final runningMap = runningAppsAsync.value ?? {};

    return Scaffold(
      backgroundColor: AppColors.background,
      body: manifestAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.platinum),
        ),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(
                'Error al cargar el catálogo: $err',
                style: const TextStyle(color: AppColors.platinum),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(catalogManifestProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (manifest) {
          final featured = manifest.apps.isNotEmpty ? manifest.apps.first : null;

          return CustomScrollView(
            slivers: [
              // Barra Superior con Buscador y Filtros
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 28, 32, 20),
                  child: Row(
                    children: [
                      // Buscador
                      Expanded(
                        child: TextField(
                          onChanged: (val) =>
                              ref.read(searchQueryProvider.notifier).state = val,
                          decoration: const InputDecoration(
                            hintText: 'Buscar videojuegos o herramientas...',
                            prefixIcon: Icon(Icons.search, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Chips de Categoría
                      _buildCategoryChip(ref, 'all', 'Todos'),
                      const SizedBox(width: 8),
                      _buildCategoryChip(ref, 'game', 'Juegos'),
                      const SizedBox(width: 8),
                      _buildCategoryChip(ref, 'app', 'Herramientas'),
                    ],
                  ),
                ),
              ),

              // Hero Destacado
              if (featured != null && ref.watch(searchQueryProvider).isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                    child: HeroCarousel(
                      featuredApp: featured,
                      onDetailsPressed: () => context.go('/app/${featured.id}'),
                    ),
                  ),
                ),

              // Cabecera de la Grilla
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 24, 32, 16),
                  child: Row(
                    children: [
                      const Text(
                        'Explorar Catálogo',
                        style: TextStyle(
                          color: AppColors.platinum,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${filteredApps.length}',
                          style: const TextStyle(
                            color: AppColors.platinumMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Grilla de Aplicaciones / Juegos estilo EGS
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 260,
                    mainAxisExtent: 360,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final app = filteredApps[index];
                      final installedApp = installedMap[app.id];
                      final isInstalled = installedApp != null;
                      final hasUpdate = isInstalled &&
                          installedApp.installedVersion != app.latestVersion;
                      final isRunning = runningMap[app.id] ?? false;

                      return AppCard(
                        app: app,
                        isInstalled: isInstalled,
                        hasUpdate: hasUpdate,
                        isRunning: isRunning,
                        onTap: () => context.go('/app/${app.id}'),
                      );
                    },
                    childCount: filteredApps.length,
                  ),
                ),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 40),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCategoryChip(WidgetRef ref, String category, String label) {
    final selected = ref.watch(selectedCategoryProvider);
    final isSelected = selected == category;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        ref.read(selectedCategoryProvider.notifier).state = category;
      },
      selectedColor: AppColors.platinum,
      backgroundColor: AppColors.surface,
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF090C12) : AppColors.platinumMuted,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? Colors.transparent : AppColors.surfaceBorder,
        ),
      ),
    );
  }
}
