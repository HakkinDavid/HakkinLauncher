import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/platform/shortcut_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/hakkin_button.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../catalog/presentation/controllers/catalog_controller.dart';
import '../../data/models/installed_app.dart';
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
                                  if (installedApp.launchArguments != null &&
                                      installedApp.launchArguments!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Argumentos: ${installedApp.launchArguments}',
                                      style: const TextStyle(
                                        color: AppColors.celestialBlue,
                                        fontSize: 11,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
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

                            // Menú de opciones avanzadas
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, color: AppColors.platinumMuted),
                              color: AppColors.surfaceElevated,
                              onSelected: (val) async {
                                if (val == 'args') {
                                  _showArgumentsDialog(context, ref, installedApp);
                                } else if (val == 'shortcut') {
                                  final ok = await ShortcutService.createDesktopShortcut(
                                    appTitle: installedApp.title,
                                    executablePath: installedApp.executablePath,
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(ok
                                            ? 'Acceso directo en el Escritorio creado'
                                            : 'No se pudo crear el acceso directo'),
                                      ),
                                    );
                                  }
                                } else if (val == 'startmenu') {
                                  final ok = await ShortcutService.createStartMenuEntry(
                                    appTitle: installedApp.title,
                                    executablePath: installedApp.executablePath,
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(ok
                                            ? 'Acceso añadido al Menú de Aplicaciones'
                                            : 'No se pudo registrar en el Menú'),
                                      ),
                                    );
                                  }
                                } else if (val == 'verify') {
                                  _runIntegrityVerification(context, ref, installedApp);
                                } else if (val == 'uninstall') {
                                  _confirmUninstall(context, ref, installedApp);
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(
                                  value: 'args',
                                  child: Row(
                                    children: [
                                      Icon(Icons.tune, size: 18, color: AppColors.platinum),
                                      SizedBox(width: 8),
                                      Text('Argumentos de lanzamiento'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'shortcut',
                                  child: Row(
                                    children: [
                                      Icon(Icons.desktop_windows, size: 18, color: AppColors.platinum),
                                      SizedBox(width: 8),
                                      Text('Crear acceso en Escritorio'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'startmenu',
                                  child: Row(
                                    children: [
                                      Icon(Icons.apps, size: 18, color: AppColors.platinum),
                                      SizedBox(width: 8),
                                      Text('Añadir al Menú Inicio'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'verify',
                                  child: Row(
                                    children: [
                                      Icon(Icons.verified_outlined, size: 18, color: AppColors.platinum),
                                      SizedBox(width: 8),
                                      Text('Verificar integridad de archivos'),
                                    ],
                                  ),
                                ),
                                const PopupMenuDivider(),
                                const PopupMenuItem(
                                  value: 'uninstall',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                      SizedBox(width: 8),
                                      Text('Desinstalar', style: TextStyle(color: AppColors.error)),
                                    ],
                                  ),
                                ),
                              ],
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

  void _showArgumentsDialog(BuildContext context, WidgetRef ref, InstalledApp app) {
    final controller = TextEditingController(text: app.launchArguments ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Argumentos para ${app.title}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Parámetros o flags de línea de comandos al iniciar el juego/app:',
              style: TextStyle(color: AppColors.platinumMuted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'ej. -windowed -novsync -fps 60',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              ref
                  .read(installedAppsProvider.notifier)
                  .updateLaunchArguments(app.id, controller.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _runIntegrityVerification(BuildContext context, WidgetRef ref, InstalledApp app) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.platinum),
      ),
    );

    final result = await ref.read(installedAppsProvider.notifier).verifyAppIntegrity(app.id);
    if (context.mounted) {
      Navigator.pop(context); // cerrar loader
      final isValid = result['isValid'] == true;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Row(
            children: [
              Icon(
                isValid ? Icons.check_circle : Icons.warning_amber,
                color: isValid ? AppColors.success : AppColors.error,
              ),
              const SizedBox(width: 8),
              Text(isValid ? 'Integridad verificada' : 'Fallo de integridad'),
            ],
          ),
          content: Text(
            result['message'].toString(),
            style: const TextStyle(color: AppColors.platinumMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    }
  }

  void _confirmUninstall(BuildContext context, WidgetRef ref, InstalledApp app) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('¿Desinstalar aplicación?'),
        content: Text(
          'Se eliminarán los archivos de ${app.title}. Tus datos de partidas guardadas permanecerán protegidos.',
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
      await ref.read(installedAppsProvider.notifier).uninstallApp(app.id);
    }
  }
}
