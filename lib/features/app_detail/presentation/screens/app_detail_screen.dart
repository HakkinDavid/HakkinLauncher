import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/platform/os_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/hakkin_button.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../catalog/data/models/app_entry.dart';
import '../../../catalog/presentation/controllers/catalog_controller.dart';
import '../../../library/presentation/controllers/library_controller.dart';
import '../../../updater/presentation/controllers/update_controller.dart';
import '../../../updater/services/patch_engine.dart';

class AppDetailScreen extends ConsumerWidget {
  final String appId;

  const AppDetailScreen({super.key, required this.appId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manifestAsync = ref.watch(catalogManifestProvider);
    final installedAppsAsync = ref.watch(installedAppsProvider);
    final runningAppsAsync = ref.watch(runningAppsStreamProvider);
    final updateProgressMap = ref.watch(updateProgressProvider);

    final currentPlatform = OsPaths.getCurrentPlatformKey();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: manifestAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.platinum),
        ),
        error: (err, _) => Center(
          child: Text('Error: $err'),
        ),
        data: (manifest) {
          final app = manifest.apps.firstWhere(
            (a) => a.id == appId,
            orElse: () => const AppEntry(
              id: '',
              slug: '',
              title: 'No encontrado',
              category: '',
              developer: '',
              summary: '',
              descriptionMarkdown: '',
              tags: [],
              assets: AppAssets(),
              latestVersion: '',
              platforms: {},
            ),
          );

          if (app.id.isEmpty) {
            return const Center(child: Text('Aplicación no encontrada en el catálogo'));
          }

          final installedApps = installedAppsAsync.value ?? [];
          final installedApp = installedApps.where((a) => a.id == app.id).firstOrNull;
          final isInstalled = installedApp != null;
          final isRunning = (runningAppsAsync.value ?? {})[app.id] ?? false;
          final hasUpdate = isInstalled && installedApp.installedVersion != app.latestVersion;
          final updateStatus = updateProgressMap[app.id];
          final isUpdating = updateStatus != null &&
              updateStatus.stage != UpdateStage.completed &&
              updateStatus.stage != UpdateStage.failed;

          final platformRelease = app.getPlatformRelease(currentPlatform);
          final isSupported = platformRelease != null;

          return CustomScrollView(
            slivers: [
              // Cabecera con botón de retroceso
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: AppColors.platinum),
                        onPressed: () => context.pop(),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        app.title,
                        style: const TextStyle(
                          color: AppColors.platinum,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Banner Hero
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                  child: Container(
                    height: 280,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (app.assets.banner != null &&
                              app.assets.banner!.startsWith('http'))
                            Image.network(
                              app.assets.banner!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: AppColors.surfaceElevated,
                              ),
                            )
                          else
                            Container(color: AppColors.surfaceElevated),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: AppColors.heroGradient,
                            ),
                          ),
                          Positioned(
                            bottom: 24,
                            left: 28,
                            right: 28,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          StatusBadge.tag(app.category),
                                          const SizedBox(width: 8),
                                          Text(
                                            'v${app.latestVersion}',
                                            style: const TextStyle(
                                              color: AppColors.platinumMuted,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        app.title,
                                        style: const TextStyle(
                                          color: AppColors.platinum,
                                          fontSize: 28,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Botón de Acción Principal
                                _buildActionButton(
                                  ref: ref,
                                  app: app,
                                  isSupported: isSupported,
                                  isInstalled: isInstalled,
                                  isRunning: isRunning,
                                  hasUpdate: hasUpdate,
                                  isUpdating: isUpdating,
                                  installedApp: installedApp,
                                  platformRelease: platformRelease,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Barra de Progreso de Actualización/Instalación
              if (isUpdating)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.celestialBlue.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                updateStatus.message,
                                style: const TextStyle(
                                  color: AppColors.platinum,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${(updateStatus.progress * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  color: AppColors.celestialBlue,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          LinearProgressIndicator(
                            value: updateStatus.progress,
                            backgroundColor: AppColors.surfaceElevated,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.celestialBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Galería de Capturas de Pantalla
              if (app.assets.screenshots.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Capturas de Pantalla',
                          style: TextStyle(
                            color: AppColors.platinum,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 170,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: app.assets.screenshots.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 14),
                            itemBuilder: (context, idx) {
                              final shotUrl = app.assets.screenshots[idx];
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  width: 300,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: AppColors.surfaceBorder),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Image.network(
                                    shotUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: AppColors.surfaceElevated,
                                      child: const Icon(Icons.image_not_supported, color: AppColors.surfaceBorder),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Contenido: Markdown y Ficha Técnica
              SliverPadding(
                padding: const EdgeInsets.all(32),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Descripción en Markdown
                      Expanded(
                        flex: 3,
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.surfaceBorder),
                          ),
                          child: MarkdownBody(
                            data: app.descriptionMarkdown.isNotEmpty
                                ? app.descriptionMarkdown
                                : app.summary,
                            styleSheet: MarkdownStyleSheet(
                              p: const TextStyle(color: AppColors.platinumMuted, fontSize: 14),
                              h1: const TextStyle(
                                color: AppColors.platinum,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                              h2: const TextStyle(
                                color: AppColors.platinum,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                              h3: const TextStyle(
                                color: AppColors.platinum,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),

                      // Panel Lateral de Información Técnica
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.surfaceBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Detalles Técnicos',
                                style: TextStyle(
                                  color: AppColors.platinum,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Divider(height: 24),
                              _buildMetaRow('Desarrollador', app.developer),
                              _buildMetaRow('Categoría', app.category.toUpperCase()),
                              _buildMetaRow('Versión Reciente', 'v${app.latestVersion}'),
                              if (platformRelease != null) ...[
                                _buildMetaRow(
                                  'Tamaño de Descarga',
                                  '${(platformRelease.fullPackage.sizeBytes / 1048576).toStringAsFixed(1)} MB',
                                ),
                                _buildMetaRow(
                                  'Soporte de Diff',
                                  platformRelease.deltaUpdates.isNotEmpty
                                      ? 'Disponible (${platformRelease.deltaUpdates.length} parches)'
                                      : 'Solo descarga completa',
                                ),
                                _buildMetaRow(
                                  'Rutas de Usuario',
                                  platformRelease.protectedUserPaths.isNotEmpty
                                      ? '${platformRelease.protectedUserPaths.length} protegidas'
                                      : 'Ninguna',
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActionButton({
    required WidgetRef ref,
    required AppEntry app,
    required bool isSupported,
    required bool isInstalled,
    required bool isRunning,
    required bool hasUpdate,
    required bool isUpdating,
    required dynamic installedApp,
    required dynamic platformRelease,
  }) {
    if (!isSupported) {
      return const HakkinButton(
        text: 'Plataforma No Soportada',
        variant: HakkinButtonVariant.secondary,
        onPressed: null,
      );
    }

    if (isUpdating) {
      return const HakkinButton(
        text: 'Instalando...',
        isLoading: true,
        variant: HakkinButtonVariant.primaryPlatinum,
        onPressed: null,
      );
    }

    if (isRunning) {
      return const HakkinButton(
        text: 'En Ejecución',
        icon: Icons.hourglass_top,
        variant: HakkinButtonVariant.secondary,
        onPressed: null,
      );
    }

    if (hasUpdate) {
      return HakkinButton(
        text: 'Actualizar a v${app.latestVersion}',
        icon: Icons.arrow_circle_up,
        variant: HakkinButtonVariant.primaryPlatinum,
        onPressed: () {
          ref.read(updateProgressProvider.notifier).startInstallOrUpdate(app);
        },
      );
    }

    if (isInstalled) {
      return HakkinButton(
        text: 'Jugar / Abrir',
        icon: Icons.play_arrow,
        variant: HakkinButtonVariant.successPlay,
        onPressed: () {
          ref.read(installedAppsProvider.notifier).launchApp(installedApp);
        },
      );
    }

    return HakkinButton(
      text: 'Instalar',
      icon: Icons.download,
      variant: HakkinButtonVariant.primaryPlatinum,
      onPressed: () {
        ref.read(updateProgressProvider.notifier).startInstallOrUpdate(app);
      },
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.platinumMuted, fontSize: 13)),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.platinum,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
