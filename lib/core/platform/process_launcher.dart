import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Servicio para la ejecución y monitorización de procesos (juegos, apps, scripts).
class ProcessLauncher {
  ProcessLauncher._();

  // Registro de procesos activos en ejecución mapeados por ID de app
  static final Map<String, Process> _runningProcesses = {};
  static final StreamController<Map<String, bool>> _runningStateController =
      StreamController<Map<String, bool>>.broadcast();

  static Stream<Map<String, bool>> get runningStateStream =>
      _runningStateController.stream;

  /// Indica si una aplicación específica está actualmente en ejecución.
  static bool isAppRunning(String appId) {
    return _runningProcesses.containsKey(appId);
  }

  /// Ejecuta el binario principal de una aplicación y monitoriza su ciclo de vida.
  static Future<bool> launchApp({
    required String appId,
    required String executablePath,
    List<String> arguments = const [],
    String? workingDirectory,
  }) async {
    if (isAppRunning(appId)) {
      debugPrint('La aplicación $appId ya está en ejecución');
      return false;
    }

    try {
      final file = File(executablePath);
      if (!await file.exists()) {
        debugPrint('No se encontró el ejecutable en: $executablePath');
        return false;
      }

      // Asegurar permisos de ejecución en Unix
      if (Platform.isMacOS || Platform.isLinux) {
        await Process.run('chmod', ['+x', executablePath]);
      }

      final workDir = workingDirectory ?? file.parent.path;

      final process = await Process.start(
        executablePath,
        arguments,
        workingDirectory: workDir,
        mode: ProcessStartMode.normal,
      );

      _runningProcesses[appId] = process;
      _notifyStateChange();

      // Escuchar el cierre del proceso
      process.exitCode.then((exitCode) {
        debugPrint('App $appId finalizó con código: $exitCode');
        _runningProcesses.remove(appId);
        _notifyStateChange();
      });

      return true;
    } catch (e) {
      debugPrint('Error lanzando proceso para $appId: $e');
      _runningProcesses.remove(appId);
      _notifyStateChange();
      return false;
    }
  }

  /// Ejecuta un script pre o post instalación (soporta .bat/.ps1 en Windows, .sh en Unix).
  static Future<bool> runScript({
    required String scriptPath,
    required String workingDirectory,
  }) async {
    try {
      final file = File(scriptPath);
      if (!await file.exists()) return false;

      ProcessResult result;
      if (Platform.isWindows) {
        if (scriptPath.endsWith('.ps1')) {
          result = await Process.run('powershell', ['-ExecutionPolicy', 'Bypass', '-File', scriptPath],
              workingDirectory: workingDirectory);
        } else {
          result = await Process.run('cmd', ['/c', scriptPath],
              workingDirectory: workingDirectory);
        }
      } else {
        await Process.run('chmod', ['+x', scriptPath]);
        result = await Process.run('/bin/bash', [scriptPath],
            workingDirectory: workingDirectory);
      }

      return result.exitCode == 0;
    } catch (e) {
      debugPrint('Error ejecutando script $scriptPath: $e');
      return false;
    }
  }

  static void _notifyStateChange() {
    final state = <String, bool>{};
    for (final key in _runningProcesses.keys) {
      state[key] = true;
    }
    _runningStateController.add(state);
  }
}
