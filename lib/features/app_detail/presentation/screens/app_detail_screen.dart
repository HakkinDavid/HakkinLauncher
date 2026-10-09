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
import '../../../library/data/models/installed_app.dart';
import '../../../library/presentation/controllers/library_controller.dart';
import '../../../updater/presentation/controllers/update_controller.dart';
import '../../../updater/services/patch_engine.dart';

class AppDetailScreen extends ConsumerStatefulWidget {
  final String appId;

  const AppDetailScreen({super.key, required this.appId});

  @override
  ConsumerState<AppDetailScreen> createState() => _AppDetailScreenState();
}

class _AppDetailScreenState extends ConsumerState<AppDetailScreen> {
  String? _selectedVersion;

  bool _isOlder(String v1, String v2) {
    final p1 = RegExp(r'\d+').allMatches(v1).map((m) => int.parse(m.group(0)!)).toList();
    final p2 = RegExp(r'\d+').allMatches(v2).map((m) => int.parse(m.group(0)!)).toList();
    final maxLen = p1.length > p2.length ? p1.length : p2.length;
    for (var i = 0; i < maxLen; i++) {
      final n1 = i < p1.length ? p1[i] : 0;
      final n2 = i < p2.length ? p2[i] : 0;
      if (n1 < n2) return true;
      if (n1 > n2) return false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
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
            (a) => a.id == widget.appId,
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
          final updateStatus = updateProgressMap[app.id];
          final isUpdating = updateStatus != null &&
              updateStatus.stage != UpdateStage.completed &&
              updateStatus.stage != UpdateStage.failed;

          final platformRelease = app.getPlatformRelease(currentPlatform);
          final isSupported = platformRelease != null && platformRelease.versions.isNotEmpty;

          // Seleccionar versión actual o fallback a la última versión
          final selectedVersionStr = _selectedVersion ??
              (platformRelease != null ? platformRelease.latestVersion : app.latestVersion);
          final selectedRelease = platformRelease?.getRelease(selectedVersionStr) ??
              platformRelease?.latestRelease ??
              const AppVersionRelease.empty();

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
                        tooltip: 'Volver',
                        onPressed: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/');
                          }
                        },
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
                                          const SizedBox(width: 10),

                                          // Selector de Versiones Históricas
                                          if (isSupported && platformRelease.availableVersions.isNotEmpty)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.surfaceElevated.withValues(alpha: 0.9),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: AppColors.surfaceBorder),
                                              ),
                                              child: DropdownButtonHideUnderline(
                                                child: DropdownButton<String>(
                                                  value: selectedVersionStr,
                                                  dropdownColor: AppColors.surface,
                                                  isDense: true,
                                                  icon: const Icon(
                                                    Icons.arrow_drop_down,
                                                    color: AppColors.platinum,
                                                    size: 18,
                                                  ),
                                                  style: const TextStyle(
                                                    color: AppColors.platinum,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  items: platformRelease.availableVersions.map((v) {
                                                    final isLatest = v == platformRelease.latestVersion;
                                                    return DropdownMenuItem<String>(
                                                      value: v,
                                                      child: Text(
                                                        isLatest ? 'v$v - Reciente' : 'v$v',
                                                        style: const TextStyle(
                                                          color: AppColors.platinum,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    );
                                                  }).toList(),
                                                  onChanged: (newV) {
                                                    if (newV != null) {
                                                      setState(() {
                                                        _selectedVersion = newV;
                                                      });
                                                    }
                                                  },
                                                ),
                                              ),
                                            )
                                          else
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
                                  app: app,
                                  selectedVersionStr: selectedVersionStr,
                                  isSupported: isSupported,
                                  isInstalled: isInstalled,
                                  isRunning: isRunning,
                                  isUpdating: isUpdating,
                                  updateStatus: updateStatus,
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
                              Expanded(
                                child: Text(
                                  updateStatus.message,
                                  style: const TextStyle(
                                    color: AppColors.platinum,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 12),
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
                            value: updateStatus.progress.clamp(0.0, 1.0),
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

              // Aviso en caso de fallo en la descarga o instalación
              if (updateStatus != null && updateStatus.stage == UpdateStage.failed)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.7)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.redAccent, size: 28),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Error en la descarga o instalación',
                                  style: TextStyle(
                                    color: AppColors.platinum,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  updateStatus.message,
                                  style: const TextStyle(
                                    color: AppColors.platinumMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          HakkinButton(
                            text: 'Reintentar',
                            icon: Icons.refresh,
                            variant: HakkinButtonVariant.secondary,
                            onPressed: () {
                              ref.read(updateProgressProvider.notifier).clearStatus(app.id);
                              ref.read(updateProgressProvider.notifier).startInstallOrUpdate(
                                    app,
                                    targetVersion: selectedVersionStr,
                                  );
                            },
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.close, color: AppColors.platinumMuted, size: 20),
                            tooltip: 'Cerrar aviso',
                            onPressed: () {
                              ref.read(updateProgressProvider.notifier).clearStatus(app.id);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Aviso de detección de anomalía (versión instalada huérfana o inexistente en el catálogo)
              if (installedApp != null &&
                  platformRelease != null &&
                  platformRelease.isAnomalousVersion(installedApp.installedVersion))
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.warning.withValues(alpha: 0.8)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 28),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Anomalía de versión detectada',
                                  style: TextStyle(
                                    color: AppColors.platinum,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'La versión instalada v${installedApp.installedVersion} es huérfana o inexistente en el catálogo actual. Debe ser actualizada de manera completa.',
                                  style: const TextStyle(
                                    color: AppColors.platinumMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
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
                      // Descripción en Markdown y Notas de Versión
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (selectedRelease.changelog.isNotEmpty) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                margin: const EdgeInsets.only(bottom: 20),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.celestialBlue.withValues(alpha: 0.4)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.history_edu, color: AppColors.celestialBlue, size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Notas de la Versión v${selectedRelease.version}',
                                          style: const TextStyle(
                                            color: AppColors.platinum,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      selectedRelease.changelog,
                                      style: const TextStyle(
                                        color: AppColors.platinumMuted,
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            Container(
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
                          ],
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
                              _buildMetaRow('Versión Seleccionada', 'v${selectedRelease.version}'),
                              if (selectedRelease.releaseDate != null)
                                _buildMetaRow(
                                  'Fecha de Versión',
                                  '${selectedRelease.releaseDate!.day.toString().padLeft(2, '0')}/${selectedRelease.releaseDate!.month.toString().padLeft(2, '0')}/${selectedRelease.releaseDate!.year}',
                                ),
                              if (isSupported) ...[
                                _buildMetaRow(
                                  'Ejecutable Relativo',
                                  selectedRelease.executableRelativePath,
                                ),
                                _buildMetaRow(
                                  'Tamaño de Descarga',
                                  '${(selectedRelease.package.sizeBytes / 1048576).toStringAsFixed(1)} MB',
                                ),
                                _buildMetaRow(
                                  'Soporte Diferencial',
                                  selectedRelease.deltaPatches.isNotEmpty
                                      ? 'Disponible: ${selectedRelease.deltaPatches.length} parches'
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
    required AppEntry app,
    required String selectedVersionStr,
    required bool isSupported,
    required bool isInstalled,
    required bool isRunning,
    required bool isUpdating,
    required UpdateStatus? updateStatus,
    required InstalledApp? installedApp,
    required PlatformRelease? platformRelease,
  }) {
    if (!isSupported) {
      return const HakkinButton(
        text: 'Plataforma No Soportada',
        variant: HakkinButtonVariant.secondary,
        onPressed: null,
      );
    }

    if (isUpdating) {
      final pct = updateStatus != null
          ? ' ${(updateStatus.progress * 100).clamp(0, 100).toStringAsFixed(0)}%'
          : '';
      return HakkinButton(
        text: 'Instalando...$pct',
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

    if (isInstalled && installedApp != null) {
      final isAnomalous = platformRelease != null &&
          platformRelease.isAnomalousVersion(installedApp.installedVersion);

      if (isAnomalous) {
        return HakkinButton(
          text: 'Actualizar Completamente - v$selectedVersionStr',
          icon: Icons.system_update_alt,
          variant: HakkinButtonVariant.primaryPlatinum,
          onPressed: () {
            ref.read(updateProgressProvider.notifier).startInstallOrUpdate(
                  app,
                  targetVersion: selectedVersionStr,
                  isCleanInstall: true,
                );
          },
        );
      }

      if (selectedVersionStr == installedApp.installedVersion) {
        return HakkinButton(
          text: 'Jugar / Abrir - v$selectedVersionStr',
          icon: Icons.play_arrow,
          variant: HakkinButtonVariant.successPlay,
          onPressed: () {
            ref.read(installedAppsProvider.notifier).launchApp(installedApp);
          },
        );
      }

      if (_isOlder(selectedVersionStr, installedApp.installedVersion)) {
        return HakkinButton(
          text: 'Instalación Limpia - v$selectedVersionStr',
          icon: Icons.warning_amber_rounded,
          variant: HakkinButtonVariant.secondary,
          onPressed: () {
            _showCleanInstallWarningDialog(
              app: app,
              currentVersion: installedApp.installedVersion,
              targetVersion: selectedVersionStr,
            );
          },
        );
      }

      return HakkinButton(
        text: 'Actualizar a v$selectedVersionStr',
        icon: Icons.arrow_circle_up,
        variant: HakkinButtonVariant.primaryPlatinum,
        onPressed: () {
          ref.read(updateProgressProvider.notifier).startInstallOrUpdate(
                app,
                targetVersion: selectedVersionStr,
              );
        },
      );
    }

    return HakkinButton(
      text: 'Instalar v$selectedVersionStr',
      icon: Icons.download,
      variant: HakkinButtonVariant.primaryPlatinum,
      onPressed: () {
        ref.read(updateProgressProvider.notifier).startInstallOrUpdate(
              app,
              targetVersion: selectedVersionStr,
            );
      },
    );
  }

  void _showCleanInstallWarningDialog({
    required AppEntry app,
    required String currentVersion,
    required String targetVersion,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.surfaceBorder),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amberAccent),
            SizedBox(width: 8),
            Text(
              'Instalación Limpia Requerida',
              style: TextStyle(color: AppColors.platinum, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'Tienes instalada la versión $currentVersion.\n\n'
          'HakkinLauncher no permite degradar versiones sobre la instalación activa. '
          'Para cambiar a la versión anterior, v$targetVersion, se realizará una instalación limpia desde cero.\n\n'
          'Tus datos de usuario y partidas guardadas serán aislados y restaurados automáticamente.\n\n'
          '¿Deseas proceder?',
          style: const TextStyle(color: AppColors.platinumMuted, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.platinumMuted)),
          ),
          HakkinButton(
            text: 'Proceder con Instalación Limpia',
            variant: HakkinButtonVariant.primaryPlatinum,
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(updateProgressProvider.notifier).startInstallOrUpdate(
                    app,
                    targetVersion: targetVersion,
                    isCleanInstall: true,
                  );
            },
          ),
        ],
      ),
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
