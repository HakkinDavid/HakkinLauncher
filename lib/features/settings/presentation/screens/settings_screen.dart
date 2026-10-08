import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/housekeeping/cleaner_service.dart';
import '../../../../core/platform/os_paths.dart';
import '../../../../core/platform/window_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/hakkin_button.dart';
import '../../../catalog/presentation/controllers/catalog_controller.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _catalogUrlController = TextEditingController();
  bool _closeToTray = true;
  String _baseDir = '';
  int _deletedFiles = -1;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(AppConstants.prefCatalogUrlKey) ??
        AppConstants.defaultCatalogUrl;
    final closeToTray = prefs.getBool(AppConstants.prefCloseToTrayKey) ?? true;
    final baseDir = await OsPaths.getAppBaseDirectory();

    setState(() {
      _catalogUrlController.text = url;
      _closeToTray = closeToTray;
      _baseDir = baseDir.path;
    });
  }

  Future<void> _saveCatalogUrl() async {
    final repo = ref.read(catalogRepositoryProvider);
    await repo.setCatalogUrl(_catalogUrlController.text.trim());
    ref.invalidate(catalogManifestProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL del catálogo actualizada y recargada')),
      );
    }
  }

  Future<void> _runHousekeeping() async {
    final count = await CleanerService.cleanTemporaryFiles();
    await CleanerService.rotateLogs();
    setState(() => _deletedFiles = count);
  }

  @override
  Widget build(BuildContext context) {
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

            // Sección 1: Catálogo Remoto
            _buildSection(
              title: 'Catálogo y Diccionario Remoto',
              description:
                  'URL pública de consulta desde donde se descargan las definiciones de aplicaciones y versiones.',
              child: Column(
                children: [
                  TextField(
                    controller: _catalogUrlController,
                    decoration: const InputDecoration(
                      labelText: 'URL del Manifiesto JSON',
                      prefixIcon: Icon(Icons.link),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      HakkinButton(
                        text: 'Guardar y Recargar',
                        icon: Icons.refresh,
                        variant: HakkinButtonVariant.primaryPlatinum,
                        onPressed: _saveCatalogUrl,
                      ),
                      const SizedBox(width: 12),
                      HakkinButton(
                        text: 'Restablecer por Defecto',
                        variant: HakkinButtonVariant.secondary,
                        onPressed: () {
                          _catalogUrlController.text = AppConstants.defaultCatalogUrl;
                          _saveCatalogUrl();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Sección 2: Comportamiento en Segundo Plano
            _buildSection(
              title: 'Comportamiento en Segundo Plano',
              description: 'Opciones de bandeja de sistema y minimizado.',
              child: SwitchListTile(
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
            ),

            const SizedBox(height: 24),

            // Sección 3: Housekeeping y Mantenimiento
            _buildSection(
              title: 'Mantenimiento y Housekeeping',
              description:
                  'Limpieza de archivos residuales de descargas (.zip, .tmp, .hdiff) y rotación de registros.',
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
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Sección 4: Información de Rutas
            _buildSection(
              title: 'Información del Sistema',
              description: 'Rutas locales utilizadas por HakkinLauncher.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPathRow('Directorio Base:', _baseDir),
                  _buildPathRow('Plataforma:', OsPaths.getCurrentPlatformKey()),
                  _buildPathRow('Versión de Lanzador:', AppConstants.appVersion),
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
