import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import '../constants/app_constants.dart';
import '../constants/app_strings.dart';

/// Servicio para el control y ciclo de vida de la ventana en Desktop.
class WindowService with WindowListener {
  static final WindowService instance = WindowService._();
  WindowService._();

  bool _closeToTray = true;

  void setCloseToTray(bool value) {
    _closeToTray = value;
  }

  bool get closeToTray => _closeToTray;

  /// Inicializa la ventana de escritorio.
  static Future<void> initialize() async {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      await windowManager.ensureInitialized();

      try {
        final prefs = await SharedPreferences.getInstance();
        instance._closeToTray = prefs.getBool(AppConstants.prefCloseToTrayKey) ?? true;
      } catch (e) {
        debugPrint(AppStrings.logCloseToTrayPrefError(e));
      }

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
            debugPrint(AppStrings.logWindowIconError(e));
          }
        }
        await windowManager.show();
        await windowManager.focus();
      });

      // Interceptar evento de cierre para permitir minimizar a la bandeja
      await windowManager.setPreventClose(true);
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
