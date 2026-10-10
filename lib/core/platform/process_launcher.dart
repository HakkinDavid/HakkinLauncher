import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../constants/app_strings.dart';
import '../constants/app_technical_strings.dart';

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
    final appIdx = targetPath.indexOf(AppTechnicalStrings.extApp);
    if (appIdx != -1) {
      appBundlePath = targetPath.substring(0, appIdx + AppTechnicalStrings.extApp.length);
      if (!p.isAbsolute(appBundlePath) && installDir != null) {
        appBundlePath = p.join(installDir, appBundlePath);
      }
    }
    if ((appBundlePath == null || !Directory(appBundlePath).existsSync()) && installDir != null) {
      final dir = Directory(installDir);
      if (dir.existsSync()) {
        try {
          final entries = dir.listSync(recursive: false);
          for (final entry in entries) {
            if (entry is Directory && entry.path.endsWith(AppTechnicalStrings.extApp)) {
              appBundlePath = entry.path;
              break;
            }
          }
        } catch (_) {}
      }
    }

    if (appBundlePath != null && Directory(appBundlePath).existsSync()) {
      // 1. Intentar leer CFBundleExecutable de Info.plist
      final plistFile = File(p.join(
        appBundlePath,
        AppTechnicalStrings.dirContents,
        AppTechnicalStrings.fileInfoPlist,
      ));
      if (plistFile.existsSync()) {
        try {
          final content = plistFile.readAsStringSync();
          final match = RegExp(AppTechnicalStrings.regexCFBundleExecutable)
              .firstMatch(content);
          if (match != null) {
            final exeName = match.group(1)!.trim();
            final candidate = p.join(
              appBundlePath,
              AppTechnicalStrings.dirContents,
              AppTechnicalStrings.dirMacOs,
              exeName,
            );
            if (File(candidate).existsSync()) {
              return candidate;
            }
          }
        } catch (_) {}
      }

      // 2. Fallback: buscar el ejecutable dentro de Contents/MacOS
      final macOsDir = Directory(p.join(
        appBundlePath,
        AppTechnicalStrings.dirContents,
        AppTechnicalStrings.dirMacOs,
      ));
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
        debugPrint(AppStrings.logAppAlreadyRunning(appId, currentPid));
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
          debugPrint(AppStrings.logExecutableNotFound(resolvedExe));
          return false;
        }
      }

      final targetFile = File(resolvedExe);

      if (Platform.isMacOS || Platform.isLinux) {
        await Process.run(
          AppTechnicalStrings.cmdChmod,
          [AppTechnicalStrings.argPlusX, resolvedExe],
        );
      }

      if (Platform.isMacOS) {
        // Eliminar atributo de cuarentena de Gatekeeper para el binario y su bundle .app
        await Process.run(
          AppTechnicalStrings.cmdXattr,
          [AppTechnicalStrings.argMinusCr, resolvedExe],
        );
        final appIdx = resolvedExe.indexOf(AppTechnicalStrings.extApp);
        if (appIdx != -1) {
          final bundlePath = resolvedExe.substring(0, appIdx + AppTechnicalStrings.extApp.length);
          await Process.run(
            AppTechnicalStrings.cmdXattr,
            [AppTechnicalStrings.argMinusCr, bundlePath],
          );
          final macosDir = p.join(
            bundlePath,
            AppTechnicalStrings.dirContents,
            AppTechnicalStrings.dirMacOs,
          );
          await Process.run(
            AppTechnicalStrings.cmdChmod,
            [AppTechnicalStrings.argMinusR, AppTechnicalStrings.argPlusX, macosDir],
          );
        }
      }

      final workDir = (workingDirectory != null && await Directory(workingDirectory).exists())
          ? workingDirectory
          : targetFile.parent.path;

      // Lanzamiento desacoplado (spawn detached process)
      final process = await Process.start(
        resolvedExe,
        arguments,
        workingDirectory: workDir,
        mode: ProcessStartMode.detached,
      );

      _runningPids[appId] = process.pid;
      _startMonitoring();
      _notifyStateChange();

      debugPrint(AppStrings.logAppLaunched(appId, process.pid));
      return true;
    } catch (e) {
      debugPrint(AppStrings.logAppLaunchError(appId, e));
      _runningPids.remove(appId);
      _notifyStateChange();
      return false;
    }
  }

  /// Comprueba si un proceso con el PID dado sigue activo en el sistema operativo.
  static Future<bool> isPidAlive(int pid) async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run(
          AppTechnicalStrings.cmdTasklist,
          [
            AppTechnicalStrings.argSlashNh,
            AppTechnicalStrings.argSlashFi,
            AppTechnicalStrings.pidFilter(pid),
          ],
        );
        if (result.exitCode == 0) {
          final out = result.stdout.toString().trim();
          return out.contains(pid.toString());
        }
        return false;
      } else {
        final result = await Process.run(
          AppTechnicalStrings.cmdKill,
          [AppTechnicalStrings.argMinusZero, pid.toString()],
        );
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
        debugPrint(AppStrings.logAppTerminated(appId, _runningPids[appId]!));
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
        await Process.run(
          AppTechnicalStrings.cmdTaskkill,
          [
            AppTechnicalStrings.argSlashF,
            AppTechnicalStrings.argSlashPid,
            pid.toString(),
          ],
        );
      } else {
        await Process.run(
          AppTechnicalStrings.cmdKill,
          [AppTechnicalStrings.argMinusNine, pid.toString()],
        );
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
        if (scriptPath.endsWith(AppTechnicalStrings.extPs1)) {
          result = await Process.run(
            AppTechnicalStrings.cmdPowershell,
            [
              AppTechnicalStrings.argExecutionPolicy,
              AppTechnicalStrings.argBypass,
              AppTechnicalStrings.argMinusFile,
              scriptPath,
            ],
            workingDirectory: workingDirectory,
          );
        } else {
          result = await Process.run(
            AppTechnicalStrings.cmdCmd,
            [AppTechnicalStrings.argSlashC, scriptPath],
            workingDirectory: workingDirectory,
          );
        }
      } else {
        await Process.run(
          AppTechnicalStrings.cmdChmod,
          [AppTechnicalStrings.argPlusX, scriptPath],
        );
        result = await Process.run(
          AppTechnicalStrings.binBash,
          [scriptPath],
          workingDirectory: workingDirectory,
        );
      }

      return result.exitCode == 0;
    } catch (e) {
      debugPrint(AppStrings.logScriptError(scriptPath, e));
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
