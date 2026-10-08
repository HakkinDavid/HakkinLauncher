import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/hakkin_button.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../catalog/presentation/controllers/catalog_controller.dart';
import '../controllers/library_controller.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final installedAppsAsync = ref.watch(installedAppsProvider);
    final runningAppsAsync = ref.watch(runningAppsStreamProvider);
    final manifestAsync = ref.watch(catalogManifestProvider);

    final runningMap = runningAppsAsync.value ?? {};
    final catalogAppsMap = manifestAsync.maybeWhen(
      data: (manifest) => {for (var a in manifest.apps) a.id: a},
      orElse: () => {},
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título de la Biblioteca
            const Text(
              'Mi Biblioteca',
              style: TextStyle(
                color: AppColors.platinum,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Programas y videojuegos instalados localmente en este equipo.',
              style: TextStyle(
                color: AppColors.platinumMuted,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),

            // Contenido de la Biblioteca
            Expanded(
              child: installedAppsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.platinum),
                ),
                error: (err, _) => Center(
                  child: Text('Error cargando biblioteca: $err'),
                ),
                data: (apps) {
                  if (apps.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.sports_esports_outlined,
                            size: 64,
                            color: AppColors.surfaceBorder,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Tu biblioteca está vacía',
                            style: TextStyle(
                              color: AppColors.platinum,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Explora la tienda e instala tus primeros programas.',
                            style: TextStyle(color: AppColors.platinumMuted),
                          ),
                          const SizedBox(height: 20),
                          HakkinButton(
                            text: 'Ir a la Tienda',
                            icon: Icons.storefront,
                            onPressed: () => context.go('/'),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: apps.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final installedApp = apps[index];
                      final catalogApp = catalogAppsMap[installedApp.id];
                      final isRunning = runningMap[installedApp.id] ?? false;
                      final hasUpdate = catalogApp != null &&
                          catalogApp.latestVersion != installedApp.installedVersion;

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.surfaceBorder),
                        ),
                        child: Row(
                          children: [
                            // Icono
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceElevated,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.surfaceBorder),
                              ),
                              child: Center(
                                child: Icon(
                                  catalogApp?.category == 'game'
                                      ? Icons.sports_esports
                                      : Icons.apps,
                                  color: AppColors.celestialBlue,
                                  size: 28,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Información de la App
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        installedApp.title,
                                        style: const TextStyle(
                                          color: AppColors.platinum,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      if (isRunning)
                                        StatusBadge.running()
                                      else if (hasUpdate)
                                        StatusBadge.updateAvailable()
                                      else
                                        StatusBadge.installed(),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Versión instalada: v${installedApp.installedVersion}${hasUpdate ? " (Nueva v${catalogApp.latestVersion} disponible)" : ""}',
                                    style: TextStyle(
                                      color: hasUpdate
                                          ? AppColors.warning
                                          : AppColors.platinumMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Acciones
                            if (hasUpdate && catalogApp != null) ...[
                              HakkinButton(
                                text: 'Actualizar',
                                icon: Icons.arrow_circle_up,
                                variant: HakkinButtonVariant.primaryPlatinum,
                                onPressed: isRunning
                                    ? null
                                    : () => context.go('/app/${catalogApp.id}'),
                              ),
                              const SizedBox(width: 10),
                            ],

                            HakkinButton(
                              text: isRunning ? 'En Ejecución' : 'Jugar',
                              icon: isRunning ? Icons.hourglass_top : Icons.play_arrow,
                              variant: HakkinButtonVariant.successPlay,
                              onPressed: isRunning
                                  ? null
                                  : () => ref
                                      .read(installedAppsProvider.notifier)
                                      .launchApp(installedApp),
                            ),
                            const SizedBox(width: 10),

                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppColors.error),
                              tooltip: 'Desinstalar',
                              onPressed: isRunning
                                  ? null
                                  : () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          backgroundColor: AppColors.surface,
                                          title: const Text('¿Desinstalar aplicación?'),
                                          content: Text(
                                            'Se eliminarán los archivos de ${installedApp.title}. Tus datos de partidas guardadas permanecerán protegidos.',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, false),
                                              child: const Text('Cancelar'),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, true),
                                              child: const Text(
                                                'Desinstalar',
                                                style: TextStyle(color: AppColors.error),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (confirm == true) {
                                        await ref
                                            .read(installedAppsProvider.notifier)
                                            .uninstallApp(installedApp.id);
                                      }
                                    },
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
