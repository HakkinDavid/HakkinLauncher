import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hakkin_launcher/core/constants/app_constants.dart';
import 'package:hakkin_launcher/core/constants/app_strings.dart';
import 'package:hakkin_launcher/core/constants/app_technical_strings.dart';
import 'package:hakkin_launcher/core/platform/os_paths.dart';
import 'package:hakkin_launcher/core/platform/shortcut_service.dart';
import 'package:hakkin_launcher/core/theme/app_colors.dart';
import 'package:hakkin_launcher/shared/widgets/hakkin_button.dart';
import 'package:hakkin_launcher/shared/widgets/status_badge.dart';
import 'package:hakkin_launcher/features/catalog/data/models/app_entry.dart';
import 'package:hakkin_launcher/features/catalog/presentation/controllers/catalog_controller.dart';
import 'package:hakkin_launcher/features/library/data/models/installed_app.dart';
import 'package:hakkin_launcher/features/library/presentation/controllers/library_controller.dart';

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
            const Text(
              AppStrings.myLibraryTitle,
              style: TextStyle(
                color: AppColors.platinum,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              AppStrings.myLibrarySubtitle,
              style: TextStyle(
                color: AppColors.platinumMuted,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: installedAppsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.platinum),
                ),
                error: (err, _) => Center(
                  child: Text(AppStrings.errorLoadingLibrary(err)),
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
                            AppStrings.emptyLibraryTitle,
                            style: TextStyle(
                              color: AppColors.platinum,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            AppStrings.emptyLibrarySubtitle,
                            style: TextStyle(color: AppColors.platinumMuted),
                          ),
                          const SizedBox(height: 20),
                          HakkinButton(
                            text: AppStrings.goToStore,
                            icon: Icons.storefront,
                            onPressed: () => context.go(AppTechnicalStrings.routeRoot),
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
                      final platformRelease = catalogApp?.platforms[installedApp.platformKey] ??
                          catalogApp?.getPlatformRelease(OsPaths.getCurrentPlatformKey());
                      final isAnomalous = platformRelease != null &&
                          platformRelease.isAnomalousVersion(installedApp.installedVersion);
                      final hasUpdate = isAnomalous || (catalogApp != null &&
                          catalogApp.latestVersion != installedApp.installedVersion);

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.surfaceBorder),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceElevated,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.surfaceBorder),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: _buildAppTileIcon(installedApp, catalogApp),
                              ),
                            ),
                            const SizedBox(width: 16),

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
                                      else if (isAnomalous)
                                        StatusBadge.anomaly()
                                      else if (hasUpdate)
                                        StatusBadge.updateAvailable()
                                      else
                                        StatusBadge.installed(),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isAnomalous
                                        ? AppStrings.anomalyInstalledVersionLabel(
                                            installedApp.installedVersion,
                                            catalogApp?.latestVersion ?? platformRelease.latestVersion,
                                          )
                                        : (hasUpdate
                                            ? AppStrings.installedVersionWithUpdateLabel(
                                                installedApp.installedVersion,
                                                catalogApp?.latestVersion ?? AppTechnicalStrings.empty,
                                              )
                                            : AppStrings.installedVersionLabel(installedApp.installedVersion)),
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
                                      AppStrings.argumentsDisplay(installedApp.launchArguments!),
                                      style: const TextStyle(
                                        color: AppColors.celestialBlue,
                                        fontSize: 11,
                                        fontFamily: AppTechnicalStrings.fontFamilyMonospace,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            if (hasUpdate && catalogApp != null) ...[
                              HakkinButton(
                                text: isAnomalous ? AppStrings.updateFull : AppStrings.update,
                                icon: isAnomalous ? Icons.system_update_alt : Icons.arrow_circle_up,
                                variant: HakkinButtonVariant.primaryPlatinum,
                                onPressed: isRunning
                                    ? null
                                    : () => context.push(AppTechnicalStrings.appDetailPath(catalogApp.id)),
                              ),
                              const SizedBox(width: 10),
                            ],

                            HakkinButton(
                              text: isRunning ? AppStrings.running : AppStrings.play,
                              icon: isRunning ? Icons.hourglass_top : Icons.play_arrow,
                              variant: HakkinButtonVariant.successPlay,
                              onPressed: isRunning
                                  ? null
                                  : () => ref
                                      .read(installedAppsProvider.notifier)
                                      .launchApp(installedApp),
                            ),
                            const SizedBox(width: 10),

                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, color: AppColors.platinumMuted),
                              color: AppColors.surfaceElevated,
                              onSelected: (val) async {
                                if (val == AppTechnicalStrings.menuValueVersions) {
                                  if (catalogApp != null) {
                                    context.push(AppTechnicalStrings.appDetailPath(catalogApp.id));
                                  }
                                } else if (val == AppTechnicalStrings.menuValueArgs) {
                                  _showArgumentsDialog(context, ref, installedApp);
                                } else if (val == AppTechnicalStrings.menuValueShortcut) {
                                  final ok = await ShortcutService.createDesktopShortcut(
                                    appTitle: installedApp.title,
                                    executablePath: installedApp.executablePath,
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(ok
                                            ? AppStrings.desktopShortcutCreated
                                            : AppStrings.couldNotCreateShortcut),
                                      ),
                                    );
                                  }
                                } else if (val == AppTechnicalStrings.menuValueStartMenu) {
                                  final ok = await ShortcutService.createStartMenuEntry(
                                    appTitle: installedApp.title,
                                    executablePath: installedApp.executablePath,
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(ok
                                            ? AppStrings.startMenuEntryCreated
                                            : AppStrings.couldNotCreateStartMenuEntry),
                                      ),
                                    );
                                  }
                                } else if (val == AppTechnicalStrings.menuValueVerify) {
                                  _runIntegrityVerification(context, ref, installedApp);
                                } else if (val == AppTechnicalStrings.menuValueUninstall) {
                                  _confirmUninstall(context, ref, installedApp);
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(
                                  value: AppTechnicalStrings.menuValueVersions,
                                  child: Row(
                                    children: [
                                      Icon(Icons.history, size: 18, color: AppColors.platinum),
                                      SizedBox(width: 8),
                                      Text(AppStrings.manageVersions),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: AppTechnicalStrings.menuValueArgs,
                                  child: Row(
                                    children: [
                                      Icon(Icons.tune, size: 18, color: AppColors.platinum),
                                      SizedBox(width: 8),
                                      Text(AppStrings.launchArguments),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: AppTechnicalStrings.menuValueShortcut,
                                  child: Row(
                                    children: [
                                      Icon(Icons.desktop_windows, size: 18, color: AppColors.platinum),
                                      SizedBox(width: 8),
                                      Text(AppStrings.createDesktopShortcut),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: AppTechnicalStrings.menuValueStartMenu,
                                  child: Row(
                                    children: [
                                      Icon(Icons.apps, size: 18, color: AppColors.platinum),
                                      SizedBox(width: 8),
                                      Text(AppStrings.addToStartMenu),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: AppTechnicalStrings.menuValueVerify,
                                  child: Row(
                                    children: [
                                      Icon(Icons.verified_outlined, size: 18, color: AppColors.platinum),
                                      SizedBox(width: 8),
                                      Text(AppStrings.verifyFileIntegrity),
                                    ],
                                  ),
                                ),
                                const PopupMenuDivider(),
                                const PopupMenuItem(
                                  value: AppTechnicalStrings.menuValueUninstall,
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                      SizedBox(width: 8),
                                      Text(AppStrings.uninstall, style: TextStyle(color: AppColors.error)),
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
    final controller = TextEditingController(text: app.launchArguments ?? AppTechnicalStrings.empty);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(AppStrings.argumentsFor(app.title)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              AppStrings.launchArgumentsParamDescription,
              style: TextStyle(color: AppColors.platinumMuted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: AppStrings.launchArgumentsHint,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              ref
                  .read(installedAppsProvider.notifier)
                  .updateLaunchArguments(app.id, controller.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text(AppStrings.save),
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
      final isValid = result[AppTechnicalStrings.keyIsValid] == true;
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
              Text(isValid ? AppStrings.integrityVerifiedTitle : AppStrings.integrityFailureTitle),
            ],
          ),
          content: Text(
            result[AppTechnicalStrings.keyMessage].toString(),
            style: const TextStyle(color: AppColors.platinumMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(AppStrings.understood),
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
        title: const Text(AppStrings.confirmUninstallTitle),
        content: Text(
          AppStrings.confirmUninstallContent(app.title),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              AppStrings.uninstall,
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

  Widget _buildAppTileIcon(InstalledApp installedApp, AppEntry? catalogApp) {
    if (installedApp.id == AppTechnicalStrings.launcherId1 ||
        installedApp.id == AppTechnicalStrings.launcherId2 ||
        installedApp.id == AppTechnicalStrings.launcherId3) {
      return Image.asset(AppConstants.appIconPath, fit: BoxFit.cover);
    }
    if (catalogApp?.assets.icon != null && catalogApp!.assets.icon!.isNotEmpty) {
      final iconUrl = catalogApp.assets.icon!;
      if (iconUrl.startsWith(AppTechnicalStrings.schemeHttp)) {
        return Image.network(
          iconUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildDefaultCategoryIcon(catalogApp),
        );
      } else if (iconUrl.startsWith(AppTechnicalStrings.schemeAssets)) {
        return Image.asset(iconUrl, fit: BoxFit.cover);
      }
    }
    return _buildDefaultCategoryIcon(catalogApp);
  }

  Widget _buildDefaultCategoryIcon(AppEntry? catalogApp) {
    return Center(
      child: Icon(
        catalogApp?.category == AppTechnicalStrings.categoryGame ? Icons.sports_esports : Icons.apps,
        color: AppColors.celestialBlue,
        size: 28,
      ),
    );
  }
}
