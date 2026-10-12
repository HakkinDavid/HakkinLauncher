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
  bool _isHidden = false;
  ValueChanged<bool>? _onHiddenStateChanged;

  void setCloseToTray(bool value) {
    _closeToTray = value;
  }

  bool get closeToTray => _closeToTray;

  /// Indica si el lanzador se encuentra oculto (system tray en Windows, taskbar en macOS, background process en Linux).
  bool get isHidden => _isHidden;

  /// Registra un observador que se invoca cuando cambia el estado de visibilidad (oculto/visible).
  void registerHiddenStateListener(ValueChanged<bool>? listener) {
    _onHiddenStateChanged = listener;
  }

  void _setHidden(bool value) {
    final changed = _isHidden != value;
    _isHidden = value;
    if (changed) {
      _onHiddenStateChanged?.call(value);
    }
  }

  /// Permite configurar el estado oculto directamente en pruebas unitarias.
  @visibleForTesting
  void setHiddenForTesting(bool value) {
    _setHidden(value);
  }

  /// Inicializa la ventana de escritorio.
  static Future<void> initialize({bool startHidden = false}) async {
    instance._isHidden = startHidden;
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      await windowManager.ensureInitialized();

      try {
        final prefs = await SharedPreferences.getInstance();
        instance._closeToTray = prefs.getBool(AppConstants.prefCloseToTrayKey) ?? true;
      } catch (e) {
        debugPrint(AppStrings.logCloseToTrayPrefError(e));
      }

      final windowOptions = WindowOptions(
        size: const Size(1280, 800),
        minimumSize: const Size(AppConstants.windowMinWidth, AppConstants.windowMinHeight),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: startHidden && (Platform.isMacOS || Platform.isLinux),
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
        if (startHidden) {
          await instance.hideToTray();
        } else {
          instance._setHidden(false);
          await windowManager.show();
          await windowManager.focus();
        }
      });

      // Interceptar evento de cierre para permitir minimizar a la bandeja
      await windowManager.setPreventClose(true);
      windowManager.addListener(instance);
    }
  }

  /// Oculta la ventana en la bandeja del sistema, en macOS retira el icono del Dock y en Linux permanece en segundo plano.
  Future<void> hideToTray() async {
    _setHidden(true);
    await windowManager.hide();
    if (Platform.isMacOS || Platform.isLinux) {
      await windowManager.setSkipTaskbar(true);
    }
  }

  /// Restaura la ventana desde la bandeja del sistema y devuelve el icono al Dock en macOS.
  Future<void> restoreWindow() async {
    _setHidden(false);
    if (Platform.isMacOS || Platform.isLinux) {
      await windowManager.setSkipTaskbar(false);
    }
    await windowManager.show();
    await windowManager.focus();
  }

  void onWindowHide() {
    _setHidden(true);
  }

  @override
  void onWindowMinimize() {
    _setHidden(true);
  }

  void onWindowShow() {
    _setHidden(false);
  }

  @override
  void onWindowRestore() {
    _setHidden(false);
  }

  @override
  void onWindowFocus() {
    _setHidden(false);
  }

  @override
  void onWindowClose() async {
    if (_closeToTray && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      await hideToTray();
    } else {
      await windowManager.destroy();
    }
  }
}
