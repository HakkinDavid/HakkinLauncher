import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../constants/app_constants.dart';

/// Servicio para el control y ciclo de vida de la ventana en Desktop.
class WindowService with WindowListener {
  static final WindowService instance = WindowService._();
  WindowService._();

  bool _closeToTray = true;

  void setCloseToTray(bool value) {
    _closeToTray = value;
  }

  /// Inicializa la ventana de escritorio.
  static Future<void> initialize() async {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      await windowManager.ensureInitialized();

      const windowOptions = WindowOptions(
        size: Size(1280, 800),
        minimumSize: Size(AppConstants.windowMinWidth, AppConstants.windowMinHeight),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
        title: AppConstants.appName,
      );

      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        if (Platform.isWindows) {
          try {
            await windowManager.setIcon(AppConstants.appIconIcoPath);
          } catch (e) {
            debugPrint('Aviso: No se pudo establecer icono de ventana: $e');
          }
        }
        await windowManager.show();
        await windowManager.focus();
      });

      windowManager.addListener(instance);
    }
  }

  @override
  void onWindowClose() async {
    if (_closeToTray && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      await windowManager.hide();
    } else {
      await windowManager.destroy();
    }
  }
}
