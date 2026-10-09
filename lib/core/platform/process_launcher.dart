import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Servicio para la ejecución y monitorización de procesos.
class ProcessLauncher {
  ProcessLauncher._();

  static final Map<String, int> _runningPids = {};
  static Timer? _monitorTimer;
  static final StreamController<Map<String, bool>> _runningStateController =
      StreamController<Map<String, bool>>.broadcast();

  static Stream<Map<String, bool>> get runningStateStream =>
      _runningStateController.stream;

  /// Indica si una aplicación específica está actualmente en ejecución.
  static bool isAppRunning(String appId) {
    return _runningPids.containsKey(appId);
  }

  /// Retorna el PID de una aplicación en ejecución si está disponible.
  static int? getAppPid(String appId) {
    return _runningPids[appId];
  }

  /// Resuelve la ruta al ejecutable real.
  /// En macOS, si la ruta apunta a un bundle .app o a un nombre interno desactualizado,
  /// inspecciona Info.plist (CFBundleExecutable) o Contents/MacOS para localizar el binario real.
  static String? resolveExecutablePath(String targetPath, [String? installDir]) {
    final directFile = File(targetPath);
    if (directFile.existsSync() && !FileSystemEntity.isDirectorySync(targetPath)) {
      return targetPath;
    }

    if (!Platform.isMacOS) {
      if (installDir != null) {
        final relCandidate = File(p.join(installDir, targetPath));
        if (relCandidate.existsSync() && !FileSystemEntity.isDirectorySync(relCandidate.path)) {
          return relCandidate.path;
        }
      }
      return null;
    }

    // Lógica especializada para macOS y bundles .app
    String? appBundlePath;
    final appIdx = targetPath.indexOf('.app');
    if (appIdx != -1) {
      appBundlePath = targetPath.substring(0, appIdx + 4);
    } else if (installDir != null) {
      final dir = Directory(installDir);
      if (dir.existsSync()) {
        try {
          final entries = dir.listSync(recursive: false);
          for (final entry in entries) {
            if (entry is Directory && entry.path.endsWith('.app')) {
              appBundlePath = entry.path;
              break;
            }
          }
        } catch (_) {}
      }
    }

    if (appBundlePath != null && Directory(appBundlePath).existsSync()) {
      // 1. Intentar leer CFBundleExecutable de Info.plist
      final plistFile = File(p.join(appBundlePath, 'Contents', 'Info.plist'));
      if (plistFile.existsSync()) {
        try {
          final content = plistFile.readAsStringSync();
          final match = RegExp(r'<key>CFBundleExecutable<\/key>\s*<string>([^<]+)<\/string>')
              .firstMatch(content);
          if (match != null) {
            final exeName = match.group(1)!.trim();
            final candidate = p.join(appBundlePath, 'Contents', 'MacOS', exeName);
            if (File(candidate).existsSync()) {
              return candidate;
            }
          }
        } catch (_) {}
      }

      // 2. Fallback: buscar el ejecutable dentro de Contents/MacOS
      final macOsDir = Directory(p.join(appBundlePath, 'Contents', 'MacOS'));
      if (macOsDir.existsSync()) {
        try {
          final macFiles = macOsDir.listSync().whereType<File>().toList();
          if (macFiles.isNotEmpty) {
            return macFiles.first.path;
          }
        } catch (_) {}
      }
    }

    return null;
  }

  /// Ejecuta el binario principal de una aplicación en modo desacoplado (detached process)
  /// y monitoriza su ciclo de vida mediante sondeo del PID.
  static Future<bool> launchApp({
    required String appId,
    required String executablePath,
    List<String> arguments = const [],
    String? workingDirectory,
  }) async {
    if (isAppRunning(appId)) {
      final currentPid = _runningPids[appId]!;
      final isAlive = await isPidAlive(currentPid);
      if (isAlive) {
        debugPrint('La aplicación $appId ya está en ejecución (PID: $currentPid)');
        return false;
      } else {
        _runningPids.remove(appId);
        _notifyStateChange();
      }
    }

    try {
      var resolvedExe = executablePath;
      final file = File(resolvedExe);
      if (!await file.exists() || await FileSystemEntity.isDirectory(resolvedExe)) {
        final autoResolved = resolveExecutablePath(resolvedExe, workingDirectory);
        if (autoResolved != null) {
          resolvedExe = autoResolved;
        } else {
          debugPrint('No se encontró el ejecutable en: $resolvedExe');
          return false;
        }
      }

      final targetFile = File(resolvedExe);

      if (Platform.isMacOS || Platform.isLinux) {
        await Process.run('chmod', ['+x', resolvedExe]);
      }

      if (Platform.isMacOS) {
        // Eliminar atributo de cuarentena de Gatekeeper para el binario y su bundle .app
        await Process.run('xattr', ['-cr', resolvedExe]);
        final appIdx = resolvedExe.indexOf('.app');
        if (appIdx != -1) {
          final bundlePath = resolvedExe.substring(0, appIdx + 4);
          await Process.run('xattr', ['-cr', bundlePath]);
          final macosDir = p.join(bundlePath, 'Contents', 'MacOS');
          await Process.run('chmod', ['-R', '+x', macosDir]);
        }
      }

      final workDir = (workingDirectory != null && await Directory(workingDirectory).exists())
          ? workingDirectory
          : targetFile.parent.path;

      // Lanzamiento desacoplado (spawn detached process): el juego o programa se ejecuta
      // como un proceso independiente del sistema operativo, sin heredar descriptores
      // de pipe (stdin/stdout/stderr) del launcher ni bloquearse si el launcher se cierra.
      final process = await Process.start(
        resolvedExe,
        arguments,
        workingDirectory: workDir,
        mode: ProcessStartMode.detached,
      );

      _runningPids[appId] = process.pid;
      _startMonitoring();
      _notifyStateChange();

      debugPrint('App $appId lanzada desacoplada exitosamente (PID: ${process.pid})');
      return true;
    } catch (e) {
      debugPrint('Error lanzando proceso desacoplado para $appId: $e');
      _runningPids.remove(appId);
      _notifyStateChange();
      return false;
    }
  }

  /// Comprueba si un proceso con el PID dado sigue activo en el sistema operativo.
  static Future<bool> isPidAlive(int pid) async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run('tasklist', ['/nh', '/fi', 'PID eq $pid']);
        if (result.exitCode == 0) {
          final out = result.stdout.toString().trim();
          return out.contains(pid.toString());
        }
        return false;
      } else {
        final result = await Process.run('kill', ['-0', pid.toString()]);
        return result.exitCode == 0;
      }
    } catch (_) {
      return false;
    }
  }

  static void _startMonitoring() {
    _monitorTimer ??= Timer.periodic(const Duration(seconds: 2), (_) async {
      await _checkRunningProcesses();
    });
  }

  static Future<void> _checkRunningProcesses() async {
    if (_runningPids.isEmpty) {
      _monitorTimer?.cancel();
      _monitorTimer = null;
      return;
    }

    final toRemove = <String>[];
    for (final entry in _runningPids.entries) {
      final alive = await isPidAlive(entry.value);
      if (!alive) {
        toRemove.add(entry.key);
      }
    }

    if (toRemove.isNotEmpty) {
      for (final appId in toRemove) {
        debugPrint('App $appId (PID ${_runningPids[appId]}) finalizó.');
        _runningPids.remove(appId);
      }
      _notifyStateChange();
    }

    if (_runningPids.isEmpty) {
      _monitorTimer?.cancel();
      _monitorTimer = null;
    }
  }

  /// Termina un proceso desacoplado si está registrado y activo.
  static Future<bool> killApp(String appId) async {
    final pid = _runningPids[appId];
    if (pid == null) return false;
    try {
      if (Platform.isWindows) {
        await Process.run('taskkill', ['/F', '/PID', pid.toString()]);
      } else {
        await Process.run('kill', ['-9', pid.toString()]);
      }
      _runningPids.remove(appId);
      _notifyStateChange();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Ejecuta un script previo o posterior a la instalación.
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
    for (final key in _runningPids.keys) {
      state[key] = true;
    }
    _runningStateController.add(state);
  }
}
