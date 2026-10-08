import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:local_notifier/local_notifier.dart';

/// Servicio centralizado de notificaciones nativas de escritorio (macOS, Windows, Linux).
class NotificationService {
  NotificationService._();

  static bool _initialized = false;

  /// Inicializa el sistema de notificaciones de escritorio.
  static Future<void> initialize() async {
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) return;
    if (_initialized) return;

    try {
      await localNotifier.setup(
        appName: 'HakkinLauncher',
        shortcutPolicy: ShortcutPolicy.requireCreate,
      );
      _initialized = true;
    } catch (e) {
      debugPrint('Aviso: No se pudo inicializar local_notifier: $e');
    }
  }

  /// Muestra una notificación nativa al usuario.
  static Future<void> showNotification({
    required String title,
    required String body,
    String? subtitle,
    VoidCallback? onClick,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      final notification = LocalNotification(
        title: title,
        subtitle: subtitle,
        body: body,
      );

      if (onClick != null) {
        notification.onClick = onClick;
      }

      await notification.show();
    } catch (e) {
      debugPrint('Error emitiendo notificación: $e');
    }
  }

  /// Notificación de instalación completada.
  static Future<void> notifyInstallCompleted(String appTitle) async {
    await showNotification(
      title: '¡Instalación completada!',
      body: '$appTitle está listo para ejecutarse.',
    );
  }

  /// Notificación de actualización completada.
  static Future<void> notifyUpdateCompleted(String appTitle, String version) async {
    await showNotification(
      title: '¡Actualización completada!',
      body: '$appTitle se ha actualizado con éxito a la versión v$version.',
    );
  }

  /// Notificación de nueva actualización detectada en segundo plano.
  static Future<void> notifyUpdateAvailable(String appTitle, String newVersion) async {
    await showNotification(
      title: 'Actualización disponible',
      body: 'Hay una nueva versión v$newVersion disponible para $appTitle.',
    );
  }
}
