import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/housekeeping/cleaner_service.dart';
import 'core/platform/tray_service.dart';
import 'core/platform/window_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialización de servicios de escritorio si aplica
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    try {
      await WindowService.initialize();
      await TrayService.initialize();
    } catch (e) {
      debugPrint('Aviso: Servicios de escritorio inicializados parcialmente: $e');
    }
  }

  // Tarea de mantenimiento en segundo plano al iniciar
  CleanerService.rotateLogs();

  runApp(
    const ProviderScope(
      child: HakkinLauncherApp(),
    ),
  );
}
