import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import '../constants/app_constants.dart';
import '../constants/app_strings.dart';
import '../constants/app_technical_strings.dart';

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
        final localIco = File(AppTechnicalStrings.windowsRunnerAppIconPath);
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
            key: AppTechnicalStrings.trayKeyShowWindow,
            label: AppStrings.trayOpenLauncher,
          ),
          MenuItem.separator(),
          MenuItem(
            key: AppTechnicalStrings.trayKeyCheckUpdates,
            label: AppStrings.trayCheckUpdates,
          ),
          MenuItem.separator(),
          MenuItem(
            key: AppTechnicalStrings.trayKeyExitApp,
            label: AppStrings.trayExit,
          ),
        ],
      );

      await trayManager.setContextMenu(menu);
    } catch (e) {
      debugPrint(AppStrings.logTrayInitError(e));
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
    if (menuItem.key == AppTechnicalStrings.trayKeyShowWindow) {
      windowManager.show();
      windowManager.focus();
    } else if (menuItem.key == AppTechnicalStrings.trayKeyCheckUpdates) {
      onCheckUpdatesRequested?.call();
    } else if (menuItem.key == AppTechnicalStrings.trayKeyExitApp) {
      windowManager.destroy();
      exit(0);
    }
  }
}
