import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import '../constants/app_constants.dart';

/// Servicio para la bandeja del sistema.
class TrayService with TrayListener {
  static final TrayService instance = TrayService._();
  TrayService._();

  VoidCallback? onCheckUpdatesRequested;

  static Future<void> initialize({VoidCallback? onCheckUpdates}) async {
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) return;

    try {
      instance.onCheckUpdatesRequested = onCheckUpdates;
      trayManager.addListener(instance);

      if (Platform.isWindows) {
        final localIco = File('windows/runner/resources/app_icon.ico');
        if (localIco.existsSync()) {
          await trayManager.setIcon(localIco.absolute.path);
        } else {
          await trayManager.setIcon(AppConstants.appIconIcoPath);
        }
      } else {
        await trayManager.setIcon(AppConstants.appIconPath);
      }

      final menu = Menu(
        items: [
          MenuItem(
            key: 'show_window',
            label: 'Abrir HakkinLauncher',
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'check_updates',
            label: 'Buscar Actualizaciones',
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'exit_app',
            label: 'Salir',
          ),
        ],
      );

      await trayManager.setContextMenu(menu);
    } catch (e) {
      debugPrint('Error inicializando bandeja: $e');
    }
  }

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show_window') {
      windowManager.show();
      windowManager.focus();
    } else if (menuItem.key == 'check_updates') {
      onCheckUpdatesRequested?.call();
    } else if (menuItem.key == 'exit_app') {
      windowManager.destroy();
      exit(0);
    }
  }
}
