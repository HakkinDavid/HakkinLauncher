import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../constants/app_strings.dart';
import '../constants/app_technical_strings.dart';
import 'notification_service.dart';

/// Servicio encargado de asegurar que HakkinLauncher se ejecute desde la
/// carpeta institucional de Aplicaciones en macOS (/Applications o ~/Applications).
///
/// Si la aplicación fue iniciada desde una imagen de disco montada (.dmg en /Volumes/)
/// o desde la carpeta de Descargas, gestiona el traslado y reapertura para evitar
/// problemas de App Translocation y asegurar el funcionamiento de autoactualizaciones.
class MacOsRelocationService {
  MacOsRelocationService._();

  static bool _hasPrompted = false;

  /// Determina si la instancia actual necesita trasladarse a la carpeta de Aplicaciones.
  static bool needsRelocation() {
    if (!Platform.isMacOS) return false;

    final exePath = Platform.resolvedExecutable;
    if (!exePath.contains(AppTechnicalStrings.appContentsMacOs)) {
      return false;
    }

    final currentAppBundle = exePath.split(AppTechnicalStrings.appContentsMacOs).first +
        AppTechnicalStrings.extApp;

    final systemApplications = AppTechnicalStrings.dirApplicationsSystem;
    final home = Platform.environment[AppTechnicalStrings.envHome] ??
        AppTechnicalStrings.empty;
    final userApplications = home.isNotEmpty
        ? p.join(home, AppTechnicalStrings.dirApplicationsUser)
        : AppTechnicalStrings.empty;

    // Si ya reside en /Applications o ~/Applications, no requiere traslado
    if (currentAppBundle.startsWith(systemApplications) ||
        (userApplications.isNotEmpty && currentAppBundle.startsWith(userApplications))) {
      return false;
    }

    return true;
  }

  /// Comprueba la ubicación y ejecuta el traslado automático o solicita confirmación al usuario.
  static Future<void> checkAndRelocateIfNecessary(BuildContext context) async {
    if (!needsRelocation() || _hasPrompted) return;
    _hasPrompted = true;

    final exePath = Platform.resolvedExecutable;
    final currentAppBundle = exePath.split(AppTechnicalStrings.appContentsMacOs).first +
        AppTechnicalStrings.extApp;

    // Si se ejecuta directamente desde una imagen de disco montada (.dmg en /Volumes/):
    // Traslado automático inmediato sin interrumpir con diálogos
    if (currentAppBundle.startsWith(AppTechnicalStrings.dirVolumes)) {
      await _performRelocation(currentAppBundle);
      return;
    }

    // Si se ejecuta desde Descargas u otra ubicación: presentar diálogo de confirmación
    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.macOsRelocationDialogTitle),
        content: const Text(AppStrings.macOsRelocationDialogMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(AppStrings.macOsRelocationDialogCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(AppStrings.macOsRelocationDialogConfirm),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _performRelocation(currentAppBundle);
    }
  }

  /// Ejecuta el traslado atómico del bundle, eliminación de cuarentena y relanzamiento.
  static Future<void> _performRelocation(String sourceBundlePath) async {
    try {
      final appNameWithExt = p.basename(sourceBundlePath);
      final systemAppDir = Directory(AppTechnicalStrings.dirApplicationsSystem);

      String targetDir = systemAppDir.path;
      // Si /Applications no tiene permisos de escritura directa para el usuario, recurrir a ~/Applications
      if (!await _canWriteToDirectory(systemAppDir)) {
        final home = Platform.environment[AppTechnicalStrings.envHome] ??
            AppTechnicalStrings.empty;
        if (home.isNotEmpty) {
          final userAppDir =
              Directory(p.join(home, AppTechnicalStrings.dirApplicationsUser));
          if (!await userAppDir.exists()) {
            await userAppDir.create(recursive: true);
          }
          targetDir = userAppDir.path;
        }
      }

      final destinationBundle = p.join(targetDir, appNameWithExt);

      // Copiar bundle preservando atributos
      await Process.run(
        AppTechnicalStrings.cmdDitto,
        [sourceBundlePath, destinationBundle],
      );

      // Eliminar atributo de cuarentena de Gatekeeper
      await Process.run(
        AppTechnicalStrings.cmdXattr,
        [
          AppTechnicalStrings.argMinusDr,
          AppTechnicalStrings.appleQuarantineAttr,
          destinationBundle,
        ],
      );

      // Emitir notificación del sistema
      await NotificationService.showNotification(
        title: AppStrings.macOsRelocationDialogTitle,
        body: AppStrings.macOsRelocationSuccessToast,
      );

      debugPrint(AppStrings.logMacOsRelocationSuccess(destinationBundle));

      // Relanzar la copia instalada en proceso desacoplado
      await Process.start(
        AppTechnicalStrings.cmdOpen,
        [AppTechnicalStrings.argMinusN, destinationBundle],
        mode: ProcessStartMode.detached,
      );

      // Finalizar la instancia temporal actual
      exit(0);
    } catch (e) {
      debugPrint(AppStrings.logMacOsRelocationError(e));
    }
  }

  static Future<bool> _canWriteToDirectory(Directory dir) async {
    try {
      if (!await dir.exists()) return false;
      final testFile = File(
        p.join(dir.path, AppTechnicalStrings.testHakkinWriteFile(pid)),
      );
      await testFile.writeAsString(AppTechnicalStrings.empty);
      await testFile.delete();
      return true;
    } catch (_) {
      return false;
    }
  }
}
