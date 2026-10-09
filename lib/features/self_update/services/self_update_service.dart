import 'dart:io';
import 'package:path/path.dart' as p;
import '../../../core/constants/app_constants.dart';
import '../../../core/crypto/hash_validator.dart';
import '../../../core/platform/notification_service.dart';
import '../../../core/platform/os_paths.dart';
import '../../catalog/data/models/app_entry.dart';
import '../../updater/services/downloader_service.dart';

enum SelfUpdateStage {
  idle,
  checking,
  updateAvailable,
  downloading,
  verifyingChecksum,
  readyToRestart,
  error,
}

class SelfUpdateStatus {
  final SelfUpdateStage stage;
  final String message;
  final double progress;
  final String? newVersion;
  final String? error;

  const SelfUpdateStatus({
    required this.stage,
    required this.message,
    this.progress = 0.0,
    this.newVersion,
    this.error,
  });
}

/// Servicio encargado de la auto-actualización autónoma, atómica y con rollback de HakkinLauncher.
class SelfUpdateService {
  final DownloaderService _downloader;

  SelfUpdateService({DownloaderService? downloader})
      : _downloader = downloader ?? DownloaderService();

  /// Compara dos versiones semánticas: retorna true si candidate > current.
  static bool isNewerVersion(String candidate, String current) {
    if (candidate == current) return false;
    final cParts = RegExp(r'\d+').allMatches(candidate).map((m) => int.parse(m.group(0)!)).toList();
    final curParts = RegExp(r'\d+').allMatches(current).map((m) => int.parse(m.group(0)!)).toList();
    final maxLen = cParts.length > curParts.length ? cParts.length : curParts.length;
    for (var i = 0; i < maxLen; i++) {
      final cNum = i < cParts.length ? cParts[i] : 0;
      final curNum = i < curParts.length ? curParts[i] : 0;
      if (cNum > curNum) return true;
      if (cNum < curNum) return false;
    }
    return false;
  }

  /// Comprueba si hay una nueva versión disponible del propio lanzador estrictamente más reciente.
  bool isUpdateAvailable(LauncherMeta? launcherMeta) {
    if (launcherMeta == null) return false;
    return isNewerVersion(launcherMeta.latestVersion, AppConstants.appVersion);
  }

  /// Resuelve la entrada de release adecuada para la plataforma con estrategia de fallback.
  static Map<String, dynamic>? resolveReleaseForPlatform(
    LauncherMeta launcherMeta, [
    String? platformKey,
  ]) {
    final key = platformKey ?? OsPaths.getCurrentPlatformKey();
    final releases = launcherMeta.releases;

    // 1. Coincidencia exacta
    if (releases.containsKey(key)) {
      return releases[key];
    }

    // 2. Fallbacks ordenados según SO y arquitectura
    final candidateFallbacks = <String>[];
    if (key.startsWith('macos')) {
      candidateFallbacks.addAll(['macos-universal', 'macos', 'macos-arm64', 'macos-x64']);
    } else if (key.startsWith('windows')) {
      candidateFallbacks.addAll(['windows-x64', 'windows', 'windows-x86']);
    } else if (key.startsWith('linux')) {
      candidateFallbacks.addAll(['linux-x64', 'linux']);
    }

    for (final fallback in candidateFallbacks) {
      if (releases.containsKey(fallback)) {
        return releases[fallback];
      }
    }

    return null;
  }

  /// Genera el script de actualización para macOS con staging, backup y rollback automático.
  static String generateMacOSUpdateScript({
    required int currentPid,
    required String currentExePath,
    required String targetAppPath,
    required String zipFilePath,
    required String logFilePath,
  }) {
    return '''#!/bin/bash
set -e

CURRENT_PID="$currentPid"
CURRENT_EXE="$currentExePath"
TARGET_APP="$targetAppPath"
ZIP_FILE="$zipFilePath"
BACKUP_APP="\${TARGET_APP}.update_backup"
LOG_FILE="$logFilePath"

mkdir -p "\$(dirname "\$LOG_FILE")"
exec > >(tee -a "\$LOG_FILE") 2>&1
echo "=== HakkinLauncher macOS Auto-Update: \$(date) ==="

echo "Esperando a que HakkinLauncher (PID \$CURRENT_PID) finalice..."
COUNT=0
while kill -0 "\$CURRENT_PID" 2>/dev/null; do
    sleep 0.5
    COUNT=\$((COUNT+1))
    if [ \$COUNT -gt 40 ]; then
        echo "Forzando terminación de PID \$CURRENT_PID..."
        kill -9 "\$CURRENT_PID" 2>/dev/null || true
        break
    fi
done

STAGING_DIR="\$(mktemp -d -t hakkin_staging_XXXXXX)"
echo "Directorio staging: \$STAGING_DIR"

rollback() {
    echo "⚠️ ERROR durante la actualización. Activando ROLLBACK de seguridad..."
    if [ -d "\$BACKUP_APP" ]; then
        rm -rf "\$TARGET_APP" 2>/dev/null || true
        cp -R "\$BACKUP_APP" "\$TARGET_APP" 2>/dev/null || mv "\$BACKUP_APP" "\$TARGET_APP"
        echo "Copia original restaurada desde backup."
    fi
    open -n "\$TARGET_APP" 2>/dev/null || true
    rm -rf "\$STAGING_DIR" 2>/dev/null || true
    echo "Rollback completado. Versión anterior reactivada."
    exit 1
}

echo "Extrayendo archivo en staging..."
if ! unzip -q -o "\$ZIP_FILE" -d "\$STAGING_DIR"; then
    echo "Error al descomprimir archivo ZIP."
    rollback
fi

FOUND_APP="\$(find "\$STAGING_DIR" -name "*.app" -maxdepth 2 | head -n 1)"
if [ -z "\$FOUND_APP" ] || [ ! -d "\$FOUND_APP" ]; then
    echo "No se encontró un bundle .app válido en el paquete extraído."
    rollback
fi
echo "Nuevo bundle localizado: \$FOUND_APP"

echo "Creando copia de respaldo de la versión actual..."
rm -rf "\$BACKUP_APP" 2>/dev/null || true
if [ -d "\$TARGET_APP" ]; then
    cp -R "\$TARGET_APP" "\$BACKUP_APP" || rollback
fi

echo "Sustituyendo aplicación en \$TARGET_APP..."
rm -rf "\$TARGET_APP" 2>/dev/null || true
if ! mv "\$FOUND_APP" "\$TARGET_APP"; then
    echo "Error al mover nueva versión a destino."
    rollback
fi

xattr -dr com.apple.quarantine "\$TARGET_APP" 2>/dev/null || true

echo "Iniciando nueva versión..."
if ! open -n "\$TARGET_APP"; then
    echo "Fallo al iniciar nueva versión. Ejecutando rollback..."
    rollback
fi

echo "Actualización completada exitosamente. Limpiando residuos..."
sleep 2
rm -rf "\$BACKUP_APP" 2>/dev/null || true
rm -rf "\$STAGING_DIR" 2>/dev/null || true
rm -f "\$ZIP_FILE" 2>/dev/null || true
echo "=== Auto-Update Finalizado con Éxito ==="
rm -f "\$0" 2>/dev/null || true
''';
  }

  /// Genera el script de actualización para Windows con staging, backup y rollback automático.
  static String generateWindowsUpdateScript({
    required int currentPid,
    required String currentExePath,
    required String appDir,
    required String zipFilePath,
    required String logFilePath,
  }) {
    return '''@echo off
setlocal enabledelayedexpansion
set CURRENT_PID=$currentPid
set CURRENT_EXE=$currentExePath
set APP_DIR=$appDir
set ZIP_FILE=$zipFilePath
set BACKUP_DIR=%APP_DIR%_backup
set STAGING_DIR=%TEMP%\\hakkin_staging_%RANDOM%
set LOG_FILE=$logFilePath

echo === HakkinLauncher Windows Auto-Update: %date% %time% === > "%LOG_FILE%"

echo Esperando a que el proceso anterior finalice... >> "%LOG_FILE%"
set /a COUNT=0
:wait_loop
tasklist /fi "PID eq %CURRENT_PID%" 2>NUL | find /i "%CURRENT_PID%" >NUL
if not errorlevel 1 (
    timeout /t 1 /nobreak >NUL
    set /a COUNT+=1
    if !COUNT! geq 35 (
        taskkill /f /pid %CURRENT_PID% >NUL 2>&1
        goto proceed
    )
    goto wait_loop
)
:proceed

echo Creando staging en %STAGING_DIR%... >> "%LOG_FILE%"
mkdir "%STAGING_DIR%" 2>NUL

echo Descomprimiendo actualización... >> "%LOG_FILE%"
tar -xf "%ZIP_FILE%" -C "%STAGING_DIR%" >> "%LOG_FILE%" 2>&1
if errorlevel 1 goto rollback

set STAGING_CONTENT=%STAGING_DIR%
for /d %%D in ("%STAGING_DIR%\\*") do (
    if exist "%%D\\HakkinLauncher.exe" set STAGING_CONTENT=%%D
    if exist "%%D\\hakkin_launcher.exe" set STAGING_CONTENT=%%D
)

echo Creando respaldo de la versión actual en %BACKUP_DIR%... >> "%LOG_FILE%"
rmdir /s /q "%BACKUP_DIR%" 2>NUL
xcopy "%APP_DIR%" "%BACKUP_DIR%\\" /E /I /H /Y /Q >> "%LOG_FILE%" 2>&1

echo Copiando archivos de la nueva versión... >> "%LOG_FILE%"
xcopy "%STAGING_CONTENT%" "%APP_DIR%\\" /E /I /H /Y /Q >> "%LOG_FILE%" 2>&1
if errorlevel 1 goto rollback

echo Iniciando nueva versión de HakkinLauncher... >> "%LOG_FILE%"
start "" "%CURRENT_EXE%"
if errorlevel 1 goto rollback

timeout /t 3 /nobreak >NUL
rmdir /s /q "%BACKUP_DIR%" 2>NUL
rmdir /s /q "%STAGING_DIR%" 2>NUL
del /f /q "%ZIP_FILE%" 2>NUL
echo === Auto-Update Windows Exitoso === >> "%LOG_FILE%"
(goto) 2>nul & del "%~f0"
exit /b 0

:rollback
echo ⚠️ ERROR: Fallo durante la actualización. Restaurando desde backup... >> "%LOG_FILE%"
if exist "%BACKUP_DIR%" (
    xcopy "%BACKUP_DIR%" "%APP_DIR%\\" /E /I /H /Y /Q >> "%LOG_FILE%" 2>&1
)
start "" "%CURRENT_EXE%"
rmdir /s /q "%STAGING_DIR%" 2>NUL
exit /b 1
''';
  }

  /// Genera el script de actualización para Linux con staging, backup y rollback automático.
  static String generateLinuxUpdateScript({
    required int currentPid,
    required String currentExePath,
    required String appDir,
    required String zipFilePath,
    required String logFilePath,
  }) {
    return '''#!/bin/bash
set -e

CURRENT_PID="$currentPid"
CURRENT_EXE="$currentExePath"
APP_DIR="$appDir"
ZIP_FILE="$zipFilePath"
BACKUP_DIR="\${APP_DIR}.update_backup"
LOG_FILE="$logFilePath"

mkdir -p "\$(dirname "\$LOG_FILE")"
exec > >(tee -a "\$LOG_FILE") 2>&1
echo "=== HakkinLauncher Linux Auto-Update: \$(date) ==="

echo "Esperando finalización de PID \$CURRENT_PID..."
COUNT=0
while kill -0 "\$CURRENT_PID" 2>/dev/null; do
    sleep 0.5
    COUNT=\$((COUNT+1))
    if [ \$COUNT -gt 40 ]; then
        kill -9 "\$CURRENT_PID" 2>/dev/null || true
        break
    fi
done

STAGING_DIR="\$(mktemp -d -t hakkin_staging_XXXXXX)"

rollback() {
    echo "⚠️ ERROR: Falla al actualizar. Restaurando respaldo de seguridad..."
    if [ -d "\$BACKUP_DIR" ]; then
        rm -rf "\$APP_DIR" 2>/dev/null || true
        cp -a "\$BACKUP_DIR" "\$APP_DIR" 2>/dev/null || mv "\$BACKUP_DIR" "\$APP_DIR"
    fi
    "\$CURRENT_EXE" &
    rm -rf "\$STAGING_DIR" 2>/dev/null || true
    exit 1
}

echo "Extrayendo paquete ZIP en staging..."
if command -v unzip >/dev/null 2>&1; then
    unzip -q -o "\$ZIP_FILE" -d "\$STAGING_DIR" || rollback
else
    tar -xf "\$ZIP_FILE" -C "\$STAGING_DIR" || rollback
fi

STAGING_CONTENT="\$STAGING_DIR"
EXE_NAME="\$(basename "\$CURRENT_EXE")"
if [ ! -f "\$STAGING_DIR/\$EXE_NAME" ]; then
    SUBDIR="\$(find "\$STAGING_DIR" -maxdepth 1 -mindepth 1 -type d | head -n 1)"
    if [ -n "\$SUBDIR" ] && [ -f "\$SUBDIR/\$EXE_NAME" ]; then
        STAGING_CONTENT="\$SUBDIR"
    fi
fi

echo "Creando copia de seguridad en \$BACKUP_DIR..."
rm -rf "\$BACKUP_DIR" 2>/dev/null || true
cp -a "\$APP_DIR" "\$BACKUP_DIR" 2>/dev/null || rollback

echo "Actualizando archivos en \$APP_DIR..."
cp -a "\$STAGING_CONTENT/." "\$APP_DIR/" || rollback
chmod +x "\$CURRENT_EXE" || true

echo "Iniciando nueva versión..."
"\$CURRENT_EXE" &

sleep 2
rm -rf "\$BACKUP_DIR" 2>/dev/null || true
rm -rf "\$STAGING_DIR" 2>/dev/null || true
rm -f "\$ZIP_FILE" 2>/dev/null || true
echo "=== Auto-Update Linux Finalizado con Éxito ==="
rm -f "\$0" 2>/dev/null || true
''';
  }

  /// Ejecuta el flujo completo de auto-actualización del lanzador.
  Stream<SelfUpdateStatus> performSelfUpdate(LauncherMeta launcherMeta) async* {
    yield const SelfUpdateStatus(
      stage: SelfUpdateStage.checking,
      message: 'Comprobando paquetes del lanzador...',
      progress: 0.1,
    );

    final platformKey = OsPaths.getCurrentPlatformKey();
    final releaseData = resolveReleaseForPlatform(launcherMeta, platformKey);

    if (releaseData == null) {
      yield const SelfUpdateStatus(
        stage: SelfUpdateStage.error,
        message: 'No hay paquete del lanzador para tu plataforma actual.',
        error: 'Plataforma no soportada',
      );
      return;
    }

    final downloadUrl = releaseData['url'] as String?;
    final expectedSha256 = (releaseData['sha256'] as String?) ?? '';

    if (downloadUrl == null || downloadUrl.isEmpty) {
      yield const SelfUpdateStatus(
        stage: SelfUpdateStage.error,
        message: 'URL de descarga de la actualización no válida.',
        error: 'URL vacía',
      );
      return;
    }

    // 1. Descarga del paquete de actualización
    final downloadsDir = await OsPaths.getDownloadsDirectory();
    final updateZipPath = p.join(downloadsDir.path, 'HakkinLauncher_update.zip');
    final zipFile = File(updateZipPath);

    // Si ya existía un archivo de descarga con hash mismatch o corrupto, limpiarlo
    if (await zipFile.exists() && expectedSha256.isNotEmpty) {
      final matches = await HashValidator.verifySha256(zipFile, expectedSha256);
      if (!matches) {
        try {
          await zipFile.delete();
        } catch (_) {}
      }
    }

    yield SelfUpdateStatus(
      stage: SelfUpdateStage.downloading,
      message: 'Descargando actualización v${launcherMeta.latestVersion}...',
      progress: 0.2,
      newVersion: launcherMeta.latestVersion,
    );

    try {
      await _downloader.downloadFile(
        url: downloadUrl,
        destinationPath: updateZipPath,
        onProgress: (p) {},
      );

      // 2. Verificación criptográfica
      yield const SelfUpdateStatus(
        stage: SelfUpdateStage.verifyingChecksum,
        message: 'Verificando integridad del nuevo lanzador...',
        progress: 0.6,
      );

      if (expectedSha256.isNotEmpty) {
        final isValid = await HashValidator.verifySha256(zipFile, expectedSha256);
        if (!isValid) {
          try {
            await zipFile.delete();
          } catch (_) {}
          yield const SelfUpdateStatus(
            stage: SelfUpdateStage.error,
            message: 'Error de integridad: el hash SHA-256 no coincide.',
            error: 'Hash mismatch',
          );
          return;
        }
      }

      // 3. Preparación del script de reemplazo y reinicio autónomo
      yield const SelfUpdateStatus(
        stage: SelfUpdateStage.readyToRestart,
        message: 'Preparando reinicio del lanzador...',
        progress: 0.9,
      );

      await NotificationService.showNotification(
        title: 'Actualización lista',
        body: 'HakkinLauncher se reiniciará para aplicar la nueva versión.',
      );

      await _applyUpdateAndRestart(zipFile);

      yield const SelfUpdateStatus(
        stage: SelfUpdateStage.readyToRestart,
        message: 'Reiniciando...',
        progress: 1.0,
      );
    } catch (e) {
      yield SelfUpdateStatus(
        stage: SelfUpdateStage.error,
        message: 'Error durante la auto-actualización: $e',
        error: e.toString(),
      );
    }
  }

  /// Lanza el proceso helper desacoplado y finaliza el proceso actual.
  Future<void> _applyUpdateAndRestart(File zipFile) async {
    final currentPid = pid;
    final currentExePath = Platform.resolvedExecutable;
    final appDir = File(currentExePath).parent.path;
    final downloadsDir = zipFile.parent.path;
    final logFile = p.join(downloadsDir, 'HakkinLauncher_self_update.log');

    if (Platform.isMacOS) {
      String targetAppPath = currentExePath;
      if (currentExePath.contains('.app/Contents/MacOS')) {
        targetAppPath = "${currentExePath.split('.app/Contents/MacOS').first}.app";
      }

      final scriptContent = generateMacOSUpdateScript(
        currentPid: currentPid,
        currentExePath: currentExePath,
        targetAppPath: targetAppPath,
        zipFilePath: zipFile.path,
        logFilePath: logFile,
      );

      final scriptFile = File(p.join(downloadsDir, 'update_helper.sh'));
      await scriptFile.writeAsString(scriptContent);
      await Process.run('chmod', ['+x', scriptFile.path]);

      // Lanzar desacoplado
      await Process.start('/bin/bash', [scriptFile.path], mode: ProcessStartMode.detached);
      exit(0);
    } else if (Platform.isWindows) {
      final scriptContent = generateWindowsUpdateScript(
        currentPid: currentPid,
        currentExePath: currentExePath,
        appDir: appDir,
        zipFilePath: zipFile.path,
        logFilePath: logFile,
      );

      final scriptFile = File(p.join(downloadsDir, 'update_helper.bat'));
      await scriptFile.writeAsString(scriptContent);

      await Process.start('cmd', ['/c', scriptFile.path], mode: ProcessStartMode.detached);
      exit(0);
    } else if (Platform.isLinux) {
      final scriptContent = generateLinuxUpdateScript(
        currentPid: currentPid,
        currentExePath: currentExePath,
        appDir: appDir,
        zipFilePath: zipFile.path,
        logFilePath: logFile,
      );

      final scriptFile = File(p.join(downloadsDir, 'update_helper.sh'));
      await scriptFile.writeAsString(scriptContent);
      await Process.run('chmod', ['+x', scriptFile.path]);

      await Process.start('/bin/bash', [scriptFile.path], mode: ProcessStartMode.detached);
      exit(0);
    }
  }
}
