import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:local_notifier/local_notifier.dart';
import '../constants/app_strings.dart';

/// Servicio centralizado de notificaciones nativas de escritorio.
class NotificationService {
  NotificationService._();

  static bool _initialized = false;

  /// Inicializa el sistema de notificaciones de escritorio.
  static Future<void> initialize() async {
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) return;
    if (_initialized) return;

    try {
      await localNotifier.setup(
        appName: AppStrings.appName,
        shortcutPolicy: ShortcutPolicy.requireCreate,
      );
      _initialized = true;
    } catch (e) {
      debugPrint(AppStrings.logCouldNotInitLocalNotifier(e));
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
      debugPrint(AppStrings.logErrorEmittingNotification(e));
    }
  }

  /// Notificación de instalación completada.
  static Future<void> notifyInstallCompleted(String appTitle) async {
    await showNotification(
      title: AppStrings.installationCompletedTitle,
      body: AppStrings.appReadyToRun(appTitle),
    );
  }

  /// Notificación de actualización completada.
  static Future<void> notifyUpdateCompleted(String appTitle, String version) async {
    await showNotification(
      title: AppStrings.updateCompletedTitle,
      body: AppStrings.updateCompletedBody(appTitle, version),
    );
  }

  /// Notificación de nueva actualización detectada en segundo plano.
  static Future<void> notifyUpdateAvailable(String appTitle, String newVersion) async {
    await showNotification(
      title: AppStrings.updateAvailableTitle,
      body: AppStrings.updateAvailableBody(appTitle, newVersion),
    );
  }
}
