import 'dart:async';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../constants/app_constants.dart';
import 'os_paths.dart';

/// Estado operativo de un componente externo.
enum ComponentStatus {
  ready,
  downloading,
  missing,
  error,
}

/// Administrador central de detección, descarga automática bajo demanda y resolución de rutas
/// para binarios y componentes third-party (ej. hpatchz para parches diferenciales).
class ComponentManager {
  Dio _dio;
  Future<bool>? _activeProvisioning;
  String? _cachedHpatchzPath;

  ComponentManager({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 60),
                followRedirects: true,
                maxRedirects: 5,
                headers: {
                  'User-Agent': 'HakkinLauncher/${AppConstants.appVersion}',
                },
              ),
            );

  /// Instancia compartida (Singleton) del administrador de componentes.
  static final ComponentManager instance = ComponentManager();

  @visibleForTesting
  void setDio(Dio dio) {
    _dio = dio;
  }

  /// Retorna la ruta ejecutable activa de `hpatchz`.
  /// Si el componente no existe localmente, dispara su descarga y aprovisionamiento automático.
  Future<String?> getHpatchzPath() async {
    // 1. Validar si ya tenemos una ruta en caché válida
    if (_cachedHpatchzPath != null) {
      if (_cachedHpatchzPath == 'hpatchz' || await File(_cachedHpatchzPath!).exists()) {
        return _cachedHpatchzPath;
      }
      _cachedHpatchzPath = null;
    }

    // 2. Verificar si ya se encuentra instalado localmente
    final existingPath = await findExistingHpatchz();
    if (existingPath != null) {
      _cachedHpatchzPath = existingPath;
      return existingPath;
    }

    // 3. Si no existe, asegurar aprovisionamiento
    final ready = await ensureComponentsReady();
    if (ready) {
      final path = await findExistingHpatchz();
      if (path != null) {
        _cachedHpatchzPath = path;
        return path;
      }
    }

    return null;
  }

  /// Busca si hpatchz ya está disponible en:
  /// 1) Directorio de Tools gestionado por HakkinLauncher.
  /// 2) Bundle o directorio local del ejecutable de la app.
  /// 3) PATH global del sistema operativo.
  Future<String?> findExistingHpatchz() async {
    try {
      // 1. Directorio de Tools gestionado por el launcher
      final localToolFile = await OsPaths.getToolFile('hpatchz');
      if (await localToolFile.exists() && await localToolFile.length() > 0) {
        if (!Platform.isWindows) {
          await _ensureExecutablePermissions(localToolFile.path);
        }
        return localToolFile.path;
      }

      // 2. Junto al ejecutable de la app (en caso de bundle empaquetado)
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final bundledExe = File(p.join(exeDir, Platform.isWindows ? 'hpatchz.exe' : 'hpatchz'));
      if (await bundledExe.exists() && await bundledExe.length() > 0) {
        if (!Platform.isWindows) {
          await _ensureExecutablePermissions(bundledExe.path);
        }
        return bundledExe.path;
      }

      // En macOS, verificar dentro de Contents/MacOS o Contents/Resources
      if (Platform.isMacOS) {
        final macResource = File(p.join(exeDir, '..', 'Resources', 'hpatchz'));
        if (await macResource.exists() && await macResource.length() > 0) {
          await _ensureExecutablePermissions(macResource.path);
          return macResource.path;
        }
      }

      // 3. PATH del sistema operativo
      final inPath = await _checkSystemPath('hpatchz');
      if (inPath != null) {
        return inPath;
      }
    } catch (e) {
      debugPrint('Aviso buscando hpatchz existente: $e');
    }
    return null;
  }

  /// Verifica la presencia del binario en la variable de entorno PATH.
  Future<String?> _checkSystemPath(String command) async {
    try {
      final checkCmd = Platform.isWindows ? 'where' : 'which';
      final res = await Process.run(checkCmd, [command]);
      if (res.exitCode == 0) {
        final firstLine = res.stdout.toString().trim().split('\n').first.trim();
        if (firstLine.isNotEmpty && File(firstLine).existsSync()) {
          return firstLine;
        }
        return command;
      }
    } catch (_) {}
    return null;
  }

  /// Asigna permisos de ejecución en sistemas Unix y elimina cuarentena de Gatekeeper en macOS.
  Future<void> _ensureExecutablePermissions(String filePath) async {
    try {
      await Process.run('chmod', ['+x', filePath]);
      if (Platform.isMacOS) {
        await Process.run('xattr', ['-d', 'com.apple.quarantine', filePath]);
      }
    } catch (_) {}
  }

  /// Asegura que todos los componentes requeridos estén descargados y listos.
  /// Previene descargas concurrentes duplicadas mediante un bloqueo de tarea activa.
  Future<bool> ensureComponentsReady() {
    if (_activeProvisioning != null) {
      return _activeProvisioning!;
    }
    _activeProvisioning = _performProvisioning();
    return _activeProvisioning!.whenComplete(() {
      _activeProvisioning = null;
    });
  }

  Future<bool> _performProvisioning() async {
    // Solo aplica para plataformas de escritorio
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
      return true;
    }

    final existing = await findExistingHpatchz();
    if (existing != null) {
      _cachedHpatchzPath = existing;
      debugPrint('Componente hpatchz listo en: $existing');
      return true;
    }

    debugPrint('Componente hpatchz no encontrado. Iniciando descarga automática...');
    return await downloadAndInstallHpatchz();
  }

  /// Descarga el paquete oficial de HDiffPatch para la plataforma actual y extrae hpatchz.
  Future<bool> downloadAndInstallHpatchz() async {
    final downloadUrl = getHpatchzDownloadUrl();
    if (downloadUrl.isEmpty) {
      debugPrint('Plataforma no soportada para descarga automática de hpatchz');
      return false;
    }

    final toolsDir = await OsPaths.getToolsDirectory();
    final downloadsDir = await OsPaths.getDownloadsDirectory();
    final tempZip = File(p.join(
      downloadsDir.path,
      'hdiffpatch_download_${DateTime.now().millisecondsSinceEpoch}.zip',
    ));

    try {
      debugPrint('Descargando hpatchz desde: $downloadUrl');
      final response = await _dio.get<List<int>>(
        downloadUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        debugPrint('Error: Descarga de hpatchz vacía.');
        return false;
      }

      await tempZip.writeAsBytes(bytes, flush: true);

      // Descomprimir paquete ZIP
      final archive = ZipDecoder().decodeBytes(bytes);
      final isArm64 = Platform.version.toLowerCase().contains('arm64') ||
          Platform.version.toLowerCase().contains('aarch64');

      ArchiveFile? bestHpatchzFile;
      ArchiveFile? bestHdiffzFile;

      for (final file in archive) {
        if (!file.isFile) continue;
        final baseName = p.basename(file.name);
        final fullPath = file.name.toLowerCase();

        if (baseName == 'hpatchz' || baseName == 'hpatchz.exe') {
          if (bestHpatchzFile == null) {
            bestHpatchzFile = file;
          } else {
            if (isArm64 && fullPath.contains('arm64')) {
              bestHpatchzFile = file;
            } else if (!isArm64 && (fullPath.contains('x86_64') || fullPath.contains('x64'))) {
              bestHpatchzFile = file;
            }
          }
        } else if (baseName == 'hdiffz' || baseName == 'hdiffz.exe') {
          if (bestHdiffzFile == null) {
            bestHdiffzFile = file;
          } else {
            if (isArm64 && fullPath.contains('arm64')) {
              bestHdiffzFile = file;
            } else if (!isArm64 && (fullPath.contains('x86_64') || fullPath.contains('x64'))) {
              bestHdiffzFile = file;
            }
          }
        }
      }

      if (bestHpatchzFile == null) {
        debugPrint('Error: No se encontró el binario hpatchz dentro del archivo ZIP.');
        return false;
      }

      final targetExt = Platform.isWindows ? '.exe' : '';
      final hpatchzTarget = File(p.join(toolsDir.path, 'hpatchz$targetExt'));
      final hpatchzBytes = _getArchiveBytes(bestHpatchzFile);
      await hpatchzTarget.writeAsBytes(hpatchzBytes, flush: true);

      // Si también incluye hdiffz, lo preservamos en la carpeta Tools
      if (bestHdiffzFile != null) {
        final hdiffzTarget = File(p.join(toolsDir.path, 'hdiffz$targetExt'));
        final hdiffzBytes = _getArchiveBytes(bestHdiffzFile);
        await hdiffzTarget.writeAsBytes(hdiffzBytes, flush: true);
      }

      // Conceder permisos de ejecución en Unix
      if (!Platform.isWindows) {
        await _ensureExecutablePermissions(hpatchzTarget.path);
        if (bestHdiffzFile != null) {
          final hdiffzTarget = File(p.join(toolsDir.path, 'hdiffz$targetExt'));
          await _ensureExecutablePermissions(hdiffzTarget.path);
        }
      }

      // Verificación de ejecución
      try {
        final verifyRes = await Process.run(hpatchzTarget.path, ['-v']);
        debugPrint('hpatchz instalado y verificado: ${verifyRes.stdout.toString().trim()}');
      } catch (e) {
        debugPrint('Aviso al verificar ejecución de hpatchz: $e');
      }

      _cachedHpatchzPath = hpatchzTarget.path;
      debugPrint('hpatchz instalado exitosamente en: ${hpatchzTarget.path}');
      return true;
    } catch (e) {
      debugPrint('Fallo al descargar o instalar hpatchz: $e');
      return false;
    } finally {
      if (await tempZip.exists()) {
        try {
          await tempZip.delete();
        } catch (_) {}
      }
    }
  }

  List<int> _getArchiveBytes(ArchiveFile file) {
    return file.content as List<int>;
  }

  /// Retorna la URL de descarga oficial de GitHub Releases según el S.O. y la arquitectura detectados.
  static String getHpatchzDownloadUrl() {
    final platKey = OsPaths.getCurrentPlatformKey();
    switch (platKey) {
      case 'windows-x64':
        return '${AppConstants.hpatchzDownloadBaseUrl}/hdiffpatch_${AppConstants.defaultHpatchzVersion}_bin_windows64.zip';
      case 'windows-arm64':
        return '${AppConstants.hpatchzDownloadBaseUrl}/hdiffpatch_${AppConstants.defaultHpatchzVersion}_bin_windows_arm64.zip';
      case 'macos-arm64':
      case 'macos-x64':
        return '${AppConstants.hpatchzDownloadBaseUrl}/hdiffpatch_${AppConstants.defaultHpatchzVersion}_bin_macos.zip';
      case 'linux-x64':
        return '${AppConstants.hpatchzDownloadBaseUrl}/hdiffpatch_${AppConstants.defaultHpatchzVersion}_bin_linux64.zip';
      case 'linux-arm64':
        return '${AppConstants.hpatchzDownloadBaseUrl}/hdiffpatch_${AppConstants.defaultHpatchzVersion}_bin_linux_arm64.zip';
      default:
        if (Platform.isWindows) {
          return '${AppConstants.hpatchzDownloadBaseUrl}/hdiffpatch_${AppConstants.defaultHpatchzVersion}_bin_windows64.zip';
        } else if (Platform.isMacOS) {
          return '${AppConstants.hpatchzDownloadBaseUrl}/hdiffpatch_${AppConstants.defaultHpatchzVersion}_bin_macos.zip';
        } else if (Platform.isLinux) {
          return '${AppConstants.hpatchzDownloadBaseUrl}/hdiffpatch_${AppConstants.defaultHpatchzVersion}_bin_linux64.zip';
        }
        return '';
    }
  }

  /// Devuelve el estado actual del componente para mostrarlo en interfaces como la pantalla de Ajustes.
  Future<String> getComponentStatus() async {
    final path = await findExistingHpatchz();
    if (path != null) {
      return 'Disponible ($path)';
    }
    return 'No instalado (se descargará al iniciar o requerir)';
  }
}
