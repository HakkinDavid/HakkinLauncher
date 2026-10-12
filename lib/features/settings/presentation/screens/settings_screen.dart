import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hakkin_launcher/core/constants/app_constants.dart';
import 'package:hakkin_launcher/core/constants/app_strings.dart';
import 'package:hakkin_launcher/core/constants/app_technical_strings.dart';
import 'package:hakkin_launcher/core/housekeeping/cleaner_service.dart';
import 'package:hakkin_launcher/core/platform/background_check_service.dart';
import 'package:hakkin_launcher/core/platform/os_paths.dart';
import 'package:hakkin_launcher/core/platform/startup_service.dart';
import 'package:hakkin_launcher/core/platform/window_service.dart';
import 'package:hakkin_launcher/core/theme/app_colors.dart';
import 'package:hakkin_launcher/features/catalog/presentation/controllers/catalog_controller.dart';
import 'package:hakkin_launcher/features/self_update/services/self_update_service.dart';
import 'package:hakkin_launcher/shared/widgets/hakkin_button.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _installPath = AppTechnicalStrings.empty;
  bool _launchAtStartup = true;
  bool _closeToTray = true;
  String _baseDir = AppTechnicalStrings.empty;
  int _deletedFiles = -1;
  bool _isCheckingUpdates = false;
  String? _selfUpdateStatusMessage;
  bool _isSelfUpdating = false;
  StreamSubscription<SelfUpdateStatus>? _selfUpdateSub;

  @override
  void initState() {
    super.initState();
    _isSelfUpdating = BackgroundCheckService.instance.isRunningSelfUpdate;
    _selfUpdateSub =
        BackgroundCheckService.instance.selfUpdateStatusStream.listen((status) {
      if (!mounted) return;
      setState(() {
        _isSelfUpdating = status.stage != SelfUpdateStage.error &&
            status.stage != SelfUpdateStage.idle;
        _selfUpdateStatusMessage = status.message;
      });
    });
    _loadSettings();
  }

  @override
  void dispose() {
    _selfUpdateSub?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    var customPath = prefs.getString(AppConstants.prefCustomInstallPathKey) ?? AppTechnicalStrings.empty;
    final launchAtStartup = prefs.getBool(AppConstants.prefLaunchAtStartupKey) ?? true;
    final closeToTray = prefs.getBool(AppConstants.prefCloseToTrayKey) ?? true;
    final baseDir = await OsPaths.getAppBaseDirectory();
    final defaultAppsDir = await OsPaths.getDefaultAppsInstallDirectory();

    // Limpiar ruta por defecto heredada si apuntaba a la subcarpeta anidada redundante
    final legacyNestedDefault = p.join(
      baseDir.path,
      AppTechnicalStrings.dirHakkinLauncher,
      AppTechnicalStrings.dirApps,
    );
    if (customPath == legacyNestedDefault || customPath == defaultAppsDir.path) {
      await prefs.remove(AppConstants.prefCustomInstallPathKey);
      customPath = AppTechnicalStrings.empty;
    }

    if (mounted) {
      setState(() {
        _installPath = customPath.isNotEmpty ? customPath : defaultAppsDir.path;
        _launchAtStartup = launchAtStartup;
        _closeToTray = closeToTray;
        _baseDir = baseDir.path;
      });
    }
  }

  Future<void> _selectInstallDirectory() async {
    final selectedPath = await OsPaths.pickDirectory(
      initialDirectory: _installPath,
    );
    if (selectedPath == null || selectedPath.isEmpty) return;

    final defaultDir = await OsPaths.getDefaultAppsInstallDirectory();
    final prefs = await SharedPreferences.getInstance();
    if (selectedPath == defaultDir.path) {
      await prefs.remove(AppConstants.prefCustomInstallPathKey);
    } else {
      await prefs.setString(
        AppConstants.prefCustomInstallPathKey,
        selectedPath,
      );
    }

    if (mounted) {
      setState(() => _installPath = selectedPath);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.installPathSavedSuccess)),
      );
    }
  }

  Future<void> _openInstallDirectory() async {
    final opened = await OsPaths.openDirectory(_installPath);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.couldNotOpenDirectory),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _restoreDefaultInstallPath() async {
    final defaultDir = await OsPaths.getDefaultAppsInstallDirectory();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.prefCustomInstallPathKey);
    if (mounted) {
      setState(() => _installPath = defaultDir.path);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.installPathSavedSuccess)),
      );
    }
  }

  Future<void> _checkForUpdatesNow() async {
    setState(() => _isCheckingUpdates = true);
    try {
      // 1. Refrescar el provider del catálogo para actualizar el estado reactivo de Riverpod
      final manifest = await ref.refresh(catalogManifestProvider.future);
      // 2. Ejecutar la comprobación completa de actualizaciones de aplicaciones y del lanzador
      final updates = await BackgroundCheckService.instance.checkForUpdates(silent: false);

      if (mounted) {
        setState(() => _isCheckingUpdates = false);
        final hasLauncherUpdate = manifest.launcherMeta != null &&
            SelfUpdateService.isNewerVersion(manifest.launcherMeta!.latestVersion, AppConstants.appVersion);

        if (hasLauncherUpdate || updates.isNotEmpty) {
          final summaryMsg = hasLauncherUpdate
              ? AppStrings.newLauncherVersionReady(AppConstants.appName, manifest.launcherMeta!.latestVersion)
              : AppStrings.updatesFoundCount(updates.length);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(summaryMsg),
              backgroundColor: AppColors.celestialBlue,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(AppStrings.allUpToDateLong),
              backgroundColor: AppColors.surfaceElevated,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCheckingUpdates = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.errorCheckingUpdates(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _triggerSelfUpdate() async {
    final manifestAsync = ref.read(catalogManifestProvider);
    final manifest = manifestAsync.value;
    if (manifest == null || manifest.launcherMeta == null) return;

    setState(() {
      _isSelfUpdating = true;
      _selfUpdateStatusMessage = AppStrings.selfUpdateStarting;
    });

    await BackgroundCheckService.instance
        .triggerSelfUpdate(manifest.launcherMeta!);
  }

  Future<void> _runHousekeeping() async {
    final count = await CleanerService.cleanTemporaryFiles();
    await CleanerService.rotateLogs();
    setState(() => _deletedFiles = count);
  }

  @override
  Widget build(BuildContext context) {
    final manifestAsync = ref.watch(catalogManifestProvider);
    final launcherMeta = manifestAsync.value?.launcherMeta;
    final hasLauncherUpdate = launcherMeta != null &&
        SelfUpdateService.isNewerVersion(launcherMeta.latestVersion, AppConstants.appVersion);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              AppStrings.settingsTitle,
              style: TextStyle(
                color: AppColors.platinum,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              AppStrings.settingsSubtitle,
              style: TextStyle(
                color: AppColors.platinumMuted,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 28),

            // Banner de actualización del lanzador si hay una nueva versión
            if (hasLauncherUpdate) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.celestialBlue),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        AppConstants.appIconPath,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.newLauncherVersionAvailableBanner(AppConstants.appName, launcherMeta.latestVersion),
                            style: const TextStyle(
                              color: AppColors.platinum,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selfUpdateStatusMessage ??
                                AppStrings.currentVersionNotice(AppConstants.appVersion),
                            style: const TextStyle(color: AppColors.platinumMuted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    HakkinButton(
                      text: _isSelfUpdating ? AppStrings.updating : AppStrings.updateLauncher,
                      isLoading: _isSelfUpdating,
                      icon: Icons.download_for_offline,
                      variant: HakkinButtonVariant.primaryPlatinum,
                      onPressed: _isSelfUpdating ? null : _triggerSelfUpdate,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],


            _buildSection(
              title: AppStrings.installPathSectionTitle,
              description: AppStrings.installPathSectionDescription,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: _selectInstallDirectory,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.folder_outlined,
                            color: AppColors.celestialBlue,
                            size: 22,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  AppStrings.installDirectoryLabel,
                                  style: TextStyle(
                                    color: AppColors.platinumMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _installPath,
                                  style: const TextStyle(
                                    color: AppColors.platinum,
                                    fontSize: 13,
                                    fontFamily: AppTechnicalStrings.fontFamilyMonospace,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      HakkinButton(
                        text: AppStrings.selectInstallDirectory,
                        icon: Icons.folder_open,
                        variant: HakkinButtonVariant.secondary,
                        onPressed: _selectInstallDirectory,
                      ),
                      HakkinButton(
                        text: AppStrings.openInstallDirectory,
                        icon: Icons.open_in_new,
                        variant: HakkinButtonVariant.secondary,
                        onPressed: _openInstallDirectory,
                      ),
                      HakkinButton(
                        text: AppStrings.restoreDefaultPath,
                        icon: Icons.restore,
                        variant: HakkinButtonVariant.secondary,
                        onPressed: _restoreDefaultInstallPath,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _buildSection(
              title: AppStrings.backgroundAndUpdatesTitle,
              description: AppStrings.backgroundAndUpdatesDescription,
              child: Column(
                children: [
                  SwitchListTile(
                    value: _launchAtStartup,
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: AppColors.celestialBlue,
                    title: const Text(
                      AppStrings.launchAtStartupTitle,
                      style: TextStyle(color: AppColors.platinum, fontSize: 14),
                    ),
                    subtitle: const Text(
                      AppStrings.launchAtStartupSubtitle,
                      style: TextStyle(color: AppColors.platinumMuted, fontSize: 12),
                    ),
                    onChanged: (val) async {
                      setState(() => _launchAtStartup = val);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool(AppConstants.prefLaunchAtStartupKey, val);
                      await StartupService.setLaunchAtStartup(val);
                    },
                  ),
                  SwitchListTile(
                    value: _closeToTray,
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: AppColors.celestialBlue,
                    title: const Text(
                      AppStrings.minimizeToTrayTitle,
                      style: TextStyle(color: AppColors.platinum, fontSize: 14),
                    ),
                    subtitle: const Text(
                      AppStrings.minimizeToTraySubtitle,
                      style: TextStyle(color: AppColors.platinumMuted, fontSize: 12),
                    ),
                    onChanged: (val) async {
                      setState(() => _closeToTray = val);
                      WindowService.instance.setCloseToTray(val);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool(AppConstants.prefCloseToTrayKey, val);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      HakkinButton(
                        text: _isCheckingUpdates
                            ? AppStrings.checkingUpdates
                            : AppStrings.checkUpdatesNow,
                        isLoading: _isCheckingUpdates,
                        icon: Icons.sync,
                        variant: HakkinButtonVariant.secondary,
                        onPressed: _isCheckingUpdates ? null : _checkForUpdatesNow,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _buildSection(
              title: AppStrings.maintenanceTitle,
              description: AppStrings.maintenanceDescription,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HakkinButton(
                    text: AppStrings.cleanTemporaryFiles,
                    icon: Icons.cleaning_services_outlined,
                    variant: HakkinButtonVariant.secondary,
                    onPressed: _runHousekeeping,
                  ),
                  if (_deletedFiles >= 0) ...[
                    const SizedBox(height: 10),
                    Text(
                      AppStrings.filesDeletedCount(_deletedFiles),
                      style: const TextStyle(color: AppColors.success, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            _buildSection(
              title: AppStrings.systemInfoTitle,
              description: AppStrings.systemInfoDescription,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        AppConstants.appIconPath,
                        width: 54,
                        height: 54,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPathRow(AppStrings.labelBaseDir, _baseDir),
                        _buildPathRow(AppStrings.labelPlatform, OsPaths.getCurrentPlatformKey()),
                        _buildPathRow(AppStrings.labelLauncherVersion, AppConstants.appVersion),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String description,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.platinum,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              color: AppColors.platinumMuted,
              fontSize: 13,
            ),
          ),
          const Divider(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _buildPathRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.platinumMuted, fontSize: 12),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                color: AppColors.platinum,
                fontSize: 12,
                fontFamily: AppTechnicalStrings.fontFamilyMonospace,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
