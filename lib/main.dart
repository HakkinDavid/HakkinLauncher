import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/housekeeping/cleaner_service.dart';
import 'core/platform/background_check_service.dart';
import 'core/platform/component_manager.dart';
import 'core/platform/notification_service.dart';
import 'core/platform/tray_service.dart';
import 'core/platform/window_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialización de servicios de escritorio
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    try {
      await NotificationService.initialize();
      await WindowService.initialize();
      await TrayService.initialize(
        onCheckUpdates: () => BackgroundCheckService.instance.checkForUpdates(silent: false),
      );
      // Iniciar comprobador en segundo plano
      BackgroundCheckService.instance.startPeriodicChecks();

      // Detección y aprovisionamiento automático de componentes third-party (hpatchz)
      unawaited(ComponentManager.instance.ensureComponentsReady());
    } catch (e) {
      debugPrint('Aviso: Servicios de escritorio inicializados parcialmente: $e');
    }
  }

  // Tarea de mantenimiento e higiene de logs al iniciar
  CleanerService.rotateLogs();

  runApp(
    const ProviderScope(
      child: HakkinLauncherApp(),
    ),
  );
}
