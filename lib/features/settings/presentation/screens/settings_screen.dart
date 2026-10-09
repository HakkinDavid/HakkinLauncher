import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hakkin_launcher/core/constants/app_constants.dart';
import 'package:hakkin_launcher/core/housekeeping/cleaner_service.dart';
import 'package:hakkin_launcher/core/platform/background_check_service.dart';
import 'package:hakkin_launcher/core/platform/component_manager.dart';
import 'package:hakkin_launcher/core/platform/os_paths.dart';
import 'package:hakkin_launcher/core/platform/window_service.dart';
import 'package:hakkin_launcher/core/theme/app_colors.dart';
import 'package:hakkin_launcher/features/catalog/presentation/controllers/catalog_controller.dart';
import 'package:hakkin_launcher/features/self_update/services/self_update_service.dart';
import 'package:hakkin_launcher/shared/widgets/hakkin_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _customInstallPathController = TextEditingController();
  bool _closeToTray = true;
  String _baseDir = '';
  String _toolsDir = '';
  String _hpatchzStatus = '';
  bool _isVerifyingComponents = false;
  int _deletedFiles = -1;
  bool _isCheckingUpdates = false;
  String? _selfUpdateStatusMessage;
  bool _isSelfUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _customInstallPathController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final customPath = prefs.getString(AppConstants.prefCustomInstallPathKey) ?? '';
    final closeToTray = prefs.getBool(AppConstants.prefCloseToTrayKey) ?? true;
    final baseDir = await OsPaths.getAppBaseDirectory();
    final defaultAppsDir = await OsPaths.getDefaultAppsInstallDirectory();
    final toolsDir = await OsPaths.getToolsDirectory();
    final hpatchzStatus = await ComponentManager.instance.getComponentStatus();

    if (mounted) {
      setState(() {
        _customInstallPathController.text = customPath.isNotEmpty ? customPath : defaultAppsDir.path;
        _closeToTray = closeToTray;
        _baseDir = baseDir.path;
        _toolsDir = toolsDir.path;
        _hpatchzStatus = hpatchzStatus;
      });
    }
  }

  Future<void> _verifyOrDownloadComponents() async {
    setState(() => _isVerifyingComponents = true);
    try {
      final success = await ComponentManager.instance.downloadAndInstallHpatchz();
      final newStatus = await ComponentManager.instance.getComponentStatus();
      if (mounted) {
        setState(() {
          _isVerifyingComponents = false;
          _hpatchzStatus = newStatus;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Componentes verificados exitosamente: $newStatus'
                  : 'Aviso: No se pudo verificar o descargar el motor de parches.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isVerifyingComponents = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al verificar componentes: $e')),
        );
      }
    }
  }

  Future<void> _saveInstallPath() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      AppConstants.prefCustomInstallPathKey,
      _customInstallPathController.text.trim(),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ruta de instalación guardada con éxito')),
      );
    }
  }

  Future<void> _checkForUpdatesNow() async {
    setState(() => _isCheckingUpdates = true);
    await BackgroundCheckService.instance.checkForUpdates(silent: false);
    if (mounted) {
      setState(() => _isCheckingUpdates = false);
    }
  }

  Future<void> _triggerSelfUpdate() async {
    final manifestAsync = ref.read(catalogManifestProvider);
    final manifest = manifestAsync.value;
    if (manifest == null || manifest.launcherMeta == null) return;

    setState(() {
      _isSelfUpdating = true;
      _selfUpdateStatusMessage = 'Iniciando actualización del lanzador...';
    });

    final selfUpdateService = SelfUpdateService();
    await for (final status in selfUpdateService.performSelfUpdate(manifest.launcherMeta!)) {
      if (mounted) {
        setState(() {
          _selfUpdateStatusMessage = status.message;
        });
      }
    }
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
              'Configuración',
              style: TextStyle(
                color: AppColors.platinum,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Ajustes del lanzador, repositorio remoto y mantenimiento.',
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
                            'Nueva versión de ${AppConstants.appName} disponible: v${launcherMeta.latestVersion}',
                            style: const TextStyle(
                              color: AppColors.platinum,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selfUpdateStatusMessage ??
                                'Tu versión actual es v${AppConstants.appVersion}. Pulsa para actualizar y reiniciar automáticamente.',
                            style: const TextStyle(color: AppColors.platinumMuted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    HakkinButton(
                      text: _isSelfUpdating ? 'Actualizando...' : 'Actualizar Lanzador',
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
              title: 'Ruta de Instalación de Juegos y Software',
              description:
                  'Carpeta del sistema operativo donde se descargarán y extraerán los paquetes y binarios.',
              child: Column(
                children: [
                  TextField(
                    controller: _customInstallPathController,
                    decoration: const InputDecoration(
                      labelText: 'Directorio de Instalación',
                      prefixIcon: Icon(Icons.folder_open),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      HakkinButton(
                        text: 'Guardar Ruta',
                        icon: Icons.save,
                        variant: HakkinButtonVariant.secondary,
                        onPressed: _saveInstallPath,
                      ),
                      const SizedBox(width: 12),
                      HakkinButton(
                        text: 'Restaurar Ruta por Defecto',
                        variant: HakkinButtonVariant.secondary,
                        onPressed: () async {
                          final defaultDir = await OsPaths.getDefaultAppsInstallDirectory();
                          _customInstallPathController.text = defaultDir.path;
                          _saveInstallPath();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _buildSection(
              title: 'Segundo Plano y Actualizaciones',
              description: 'Opciones de bandeja de sistema y sondeo automático.',
              child: Column(
                children: [
                  SwitchListTile(
                    value: _closeToTray,
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: AppColors.celestialBlue,
                    title: const Text(
                      'Minimizar a la bandeja al cerrar la ventana',
                      style: TextStyle(color: AppColors.platinum, fontSize: 14),
                    ),
                    subtitle: const Text(
                      'El lanzador permanecerá activo en la bandeja del sistema o barra de menú para verificar actualizaciones.',
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
                            ? 'Buscando actualizaciones...'
                            : 'Buscar Actualizaciones Ahora',
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
              title: 'Mantenimiento',
              description:
                  'Limpieza de archivos residuales de descargas y rotación de registros.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HakkinButton(
                    text: 'Limpiar Archivos Temporales',
                    icon: Icons.cleaning_services_outlined,
                    variant: HakkinButtonVariant.secondary,
                    onPressed: _runHousekeeping,
                  ),
                  if (_deletedFiles >= 0) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Se eliminaron $_deletedFiles archivos temporales.',
                      style: const TextStyle(color: AppColors.success, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 12),
                  HakkinButton(
                    text: _isVerifyingComponents
                        ? 'Verificando componentes...'
                        : 'Verificar / Descargar Motor de Parches (hpatchz)',
                    isLoading: _isVerifyingComponents,
                    icon: Icons.build_circle_outlined,
                    variant: HakkinButtonVariant.secondary,
                    onPressed: _isVerifyingComponents ? null : _verifyOrDownloadComponents,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _buildSection(
              title: 'Información del Sistema',
              description: 'Rutas locales utilizadas por HakkinLauncher.',
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
                        _buildPathRow('Directorio Base:', _baseDir),
                        if (_toolsDir.isNotEmpty)
                          _buildPathRow('Herramientas:', _toolsDir),
                        if (_hpatchzStatus.isNotEmpty)
                          _buildPathRow('Motor hpatchz:', _hpatchzStatus),
                        _buildPathRow('Plataforma:', OsPaths.getCurrentPlatformKey()),
                        _buildPathRow('Versión de Lanzador:', AppConstants.appVersion),
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
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
