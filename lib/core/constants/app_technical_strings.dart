/// Centralized technical strings and constants for the HakkinLauncher codebase.
///
/// Contains routes, platform keys, JSON keys, SharedPreferences keys,
/// file extensions, shell commands and arguments, HTTP headers, MIME types,
/// regex patterns, environment variables, delimiters, and shell scripts.
class AppTechnicalStrings {
  AppTechnicalStrings._();

  // ---------------------------------------------------------------------------
  // Routes & Navigation
  // ---------------------------------------------------------------------------
  static const routeRoot = '/';
  static const routeLibrary = '/library';
  static const routeSettings = '/settings';
  static const routeAppDetail = '/app/:id';
  static const paramId = 'id';

  static String appDetailPath(String id) => '/app/$id';

  // ---------------------------------------------------------------------------
  // Versioning & Official URLs
  // ---------------------------------------------------------------------------
  static const defaultAppVersion = '26.10.10-09';
  static const envAppVersionKey = 'APP_VERSION';
  static const appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: defaultAppVersion,
  );

  static const defaultCatalogUrl =
      'https://raw.githubusercontent.com/HakkinDavid/HakkinLauncher/master/docs/catalog.json';

  static const defaultHpatchzVersion = 'v5.1.3';
  static const hpatchzDownloadBaseUrl =
      'https://github.com/sisong/HDiffPatch/releases/download/$defaultHpatchzVersion';

  static const backgroundCheckInterval = Duration(hours: 4);

  // ---------------------------------------------------------------------------
  // SharedPreferences Keys
  // ---------------------------------------------------------------------------
  static const prefCatalogUrlKey = 'hakkin_catalog_url';
  static const prefCustomInstallPathKey = 'hakkin_install_path';
  static const prefCloseToTrayKey = 'hakkin_close_to_tray';
  static const prefAutoCheckUpdatesKey = 'hakkin_auto_check_updates';
  static const prefCachedCatalogJson = 'hakkin_cached_catalog_json';
  static const prefInstalledAppsJson = 'hakkin_installed_apps_json';

  // ---------------------------------------------------------------------------
  // Asset Paths
  // ---------------------------------------------------------------------------
  static const appIconPath = 'assets/hakkinlauncher.png';
  static const appIconIcoPath = 'assets/hakkinlauncher.ico';
  static const windowsRunnerAppIconPath = 'windows/runner/resources/app_icon.ico';

  // ---------------------------------------------------------------------------
  // Platforms & Architectures
  // ---------------------------------------------------------------------------
  static const platformWindowsX64 = 'windows-x64';
  static const platformWindowsX86 = 'windows-x86';
  static const platformWindowsArm64 = 'windows-arm64';
  static const platformWindows = 'windows';
  static const platformMacosArm64 = 'macos-arm64';
  static const platformMacosX64 = 'macos-x64';
  static const platformMacosUniversal = 'macos-universal';
  static const platformMacos = 'macos';
  static const platformLinuxX64 = 'linux-x64';
  static const platformLinuxArm64 = 'linux-arm64';
  static const platformLinux = 'linux';
  static const platformAndroid = 'android';
  static const platformIos = 'ios';
  static const platformUnknown = 'unknown';

  static const archArm64 = 'arm64';
  static const archAarch64 = 'aarch64';
  static const archX86_64 = 'x86_64';
  static const archX64 = 'x64';

  // ---------------------------------------------------------------------------
  // Directories & Files
  // ---------------------------------------------------------------------------
  static const dirHakkinLauncher = 'HakkinLauncher';
  static const dirApps = 'Apps';
  static const dirDownloads = 'Downloads';
  static const dirLogs = 'Logs';
  static const dirTools = 'Tools';
  static const dirResources = 'Resources';
  static const dirContents = 'Contents';
  static const dirMacOs = 'MacOS';
  static const dirCodeSignature = '_CodeSignature';
  static const dirToolsBin = 'tools/bin';
  static const dirDesktop = 'Desktop';
  static const dirStartMenu = 'Microsoft/Windows/Start Menu/Programs/Hakkin';
  static const dirLinuxApps = '.local/share/applications';
  static const dirApplicationsSystem = '/Applications';
  static const dirApplicationsUser = 'Applications';
  static const dirVolumes = '/Volumes';
  static const dirDownloadsSystem = 'Downloads';
  static const parentDir = '..';

  static const extExe = '.exe';
  static const extZip = '.zip';
  static const extHdiff = '.hdiff';
  static const extApp = '.app';
  static const extLnk = '.lnk';
  static const extDesktop = '.desktop';
  static const extPs1 = '.ps1';
  static const extDmg = '.dmg';
  static const extMsi = '.msi';
  static const extDeb = '.deb';

  static const fileHpatchz = 'hpatchz';
  static const fileHpatchzExe = 'hpatchz.exe';
  static const fileHdiffz = 'hdiffz';
  static const fileHdiffzExe = 'hdiffz.exe';
  static const fileInfoPlist = 'Info.plist';
  static const keyCFBundleExecutable = 'CFBundleExecutable';

  static const updateHelperSh = 'update_helper.sh';
  static const updateHelperBat = 'update_helper.bat';
  static const selfUpdateZipFileName = 'HakkinLauncher_update.zip';
  static const selfUpdateLogFileName = 'HakkinLauncher_self_update.log';
  static const appContentsMacOs = '.app/Contents/MacOS';
  static const appleQuarantineAttr = 'com.apple.quarantine';
  static const testHakkinWritePrefix = '.test_hakkin_write_';
  static String testHakkinWriteFile(int pid) => '$testHakkinWritePrefix$pid';

  // ---------------------------------------------------------------------------
  // Shell Commands & Arguments
  // ---------------------------------------------------------------------------
  static const cmdChmod = 'chmod';
  static const cmdXattr = 'xattr';
  static const cmdDitto = 'ditto';
  static const cmdUnzip = 'unzip';
  static const cmdCodesign = 'codesign';
  static const cmdTasklist = 'tasklist';
  static const cmdKill = 'kill';
  static const cmdTaskkill = 'taskkill';
  static const cmdPowershell = 'powershell';
  static const cmdCmd = 'cmd';
  static const cmdOpen = 'open';
  static const cmdHdiutil = 'hdiutil';
  static const cmdDpkgDeb = 'dpkg-deb';
  static const cmdPkexec = 'pkexec';
  static const cmdOsascript = 'osascript';
  static const binBash = '/bin/bash';
  static const cmdWhere = 'where';
  static const cmdWhich = 'which';

  static const argPlusX = '+x';
  static const argMinusCr = '-cr';
  static const argMinusR = '-R';
  static const argMinusN = '-n';
  static const argMinusDr = '-dr';
  static const argMinusXk = '-xk';
  static const argMinusQ = '-q';
  static const argMinusO = '-o';
  static const argMinusD = '-d';
  static const argMinusF = '-f';
  static const argMinusV = '-v';
  static const argMinusZero = '-0';
  static const argMinusNine = '-9';
  static const argForce = '--force';
  static const argDeep = '--deep';
  static const argMinusS = '-s';
  static const argMinus = '-';
  static const argSlashNh = '/nh';
  static const argSlashFi = '/fi';
  static const argSlashF = '/F';
  static const argSlashPid = '/PID';
  static const argSlashC = '/c';
  static const argExecutionPolicy = '-ExecutionPolicy';
  static const argBypass = 'Bypass';
  static const argMinusFile = '-File';
  static const argNoProfile = '-NoProfile';
  static const argMinusCommand = '-Command';

  // ---------------------------------------------------------------------------
  // Regex Patterns
  // ---------------------------------------------------------------------------
  static const regexDigits = r'\d+';
  static const regexWhitespace = r'\s+';
  static const regexCFBundleExecutable =
      r'<key>CFBundleExecutable<\/key>\s*<string>([^<]+)<\/string>';

  // ---------------------------------------------------------------------------
  // HTTP & Network
  // ---------------------------------------------------------------------------
  static const headerRange = 'Range';
  static const headerContentRange = 'content-range';
  static const headerContentLength = 'content-length';
  static const headerCacheControl = 'Cache-Control';
  static const headerPragma = 'Pragma';
  static const headerUserAgent = 'User-Agent';
  static const valNoCache = 'no-cache';
  static const valNoCacheFull = 'no-cache, no-store, must-revalidate';
  static const paramCacheBuster = '_t';
  static const schemeHttp = 'http';
  static const schemeAssets = 'assets/';

  static String userAgentHeader(String version) => 'HakkinLauncher/$version';
  static String rangeBytes(int start) => 'bytes=$start-';

  // ---------------------------------------------------------------------------
  // JSON & Model Keys
  // ---------------------------------------------------------------------------
  static const keyVersion = 'version';
  static const keyCatalogTimestamp = 'catalog_timestamp';
  static const keyLauncherMeta = 'launcher_meta';
  static const keyApps = 'apps';
  static const keyLatestVersion = 'latest_version';
  static const keyMinRequiredLauncherVersion = 'min_required_launcher_version';
  static const keyReleases = 'releases';
  static const keyId = 'id';
  static const keySlug = 'slug';
  static const keyTitle = 'title';
  static const keyCategory = 'category';
  static const keyDeveloper = 'developer';
  static const keySummary = 'summary';
  static const keyDescriptionMarkdown = 'description_markdown';
  static const keyTags = 'tags';
  static const keyAssets = 'assets';
  static const keyPlatforms = 'platforms';
  static const keyIcon = 'icon';
  static const keyPoster = 'poster';
  static const keyBanner = 'banner';
  static const keyScreenshots = 'screenshots';
  static const keyProtectedUserPaths = 'protected_user_paths';
  static const keyVersions = 'versions';
  static const keyReleaseDate = 'release_date';
  static const keyChangelog = 'changelog';
  static const keyEntryPoint = 'entry_point';
  static const keyPackage = 'package';
  static const keyDeltaPatches = 'delta_patches';
  static const keyScripts = 'scripts';
  static const keyUrl = 'url';
  static const keySizeBytes = 'size_bytes';
  static const keySha256 = 'sha256';
  static const keyFromVersion = 'from_version';
  static const keyToVersion = 'to_version';
  static const keyPatchFormat = 'patch_format';
  static const keyPatchSha256 = 'patch_sha256';
  static const keyTargetSha256 = 'target_sha256';
  static const keyPreInstall = 'pre_install';
  static const keyPostInstall = 'post_install';
  static const keyInstalledVersion = 'installed_version';
  static const keyExecutablePath = 'executable_path';
  static const keyInstallDirectory = 'install_directory';
  static const keyInstalledAt = 'installed_at';
  static const keyLastLaunchedAt = 'last_launched_at';
  static const keyPlatformKey = 'platform_key';
  static const keyLaunchArguments = 'launch_arguments';
  static const keyIsValid = 'isValid';
  static const keyMessage = 'message';
  static const keyIsAnomalous = 'isAnomalous';

  // ---------------------------------------------------------------------------
  // Delimiters & Symbols
  // ---------------------------------------------------------------------------
  static const empty = '';
  static const space = ' ';
  static const slash = '/';
  static const dash = '-';
  static const colon = ':';
  static const dot = '.';
  static const comma = ',';
  static const commaSpace = ', ';
  static const newline = '\n';
  static const bulletSeparator = ' • ';
  static const globStar = '*';
  static const globDoubleStar = '**';
  static const underscore = '_';
  static const fontFamilyMonospace = 'monospace';

  // ---------------------------------------------------------------------------
  // Tray Menu Keys
  // ---------------------------------------------------------------------------
  static const trayKeyShowWindow = 'show_window';
  static const trayKeyCheckUpdates = 'check_updates';
  static const trayKeyExitApp = 'exit_app';

  // ---------------------------------------------------------------------------
  // Popup Menu Values
  // ---------------------------------------------------------------------------
  static const menuValueVersions = 'versions';
  static const menuValueArgs = 'args';
  static const menuValueShortcut = 'shortcut';
  static const menuValueStartMenu = 'startmenu';
  static const menuValueVerify = 'verify';
  static const menuValueUninstall = 'uninstall';

  // ---------------------------------------------------------------------------
  // Environment Variables
  // ---------------------------------------------------------------------------
  static const envHome = 'HOME';
  static const envUserProfile = 'USERPROFILE';
  static const envAppData = 'APPDATA';

  // ---------------------------------------------------------------------------
  // Categories
  // ---------------------------------------------------------------------------
  static const categoryAll = 'all';
  static const categoryGame = 'game';
  static const categoryApp = 'app';
  static const categoryTool = 'tool';

  // ---------------------------------------------------------------------------
  // Defaults & Fallbacks
  // ---------------------------------------------------------------------------
  static const defaultVersion = '1.0.0';
  static const defaultPatchFormat = 'hdiff';

  // ---------------------------------------------------------------------------
  // Known Launcher IDs
  // ---------------------------------------------------------------------------
  static const launcherId1 = 'dev.bonsanbec.hakkinlauncher';
  static const launcherId2 = 'hakkin_launcher';
  static const launcherId3 = 'HakkinLauncher';

  // ---------------------------------------------------------------------------
  // Error Codes & Technical Tokens
  // ---------------------------------------------------------------------------
  static const errorHashMismatch = 'hash_mismatch';
  static const errorEmptyUrl = 'empty_url';
  static const errorUnsupportedPlatform = 'unsupported_platform';

  // ---------------------------------------------------------------------------
  // Helpers & Formatters
  // ---------------------------------------------------------------------------
  static String pidFilter(int pid) => 'PID eq $pid';

  static String hpatchzDownloadZipName(String version, String suffix) =>
      'hdiffpatch_${version}_bin_$suffix.zip';

  static String getHpatchzDownloadUrl(String platKey) {
    String suffix;
    switch (platKey) {
      case platformWindowsX64:
        suffix = 'windows64';
        break;
      case platformWindowsArm64:
        suffix = 'windows_arm64';
        break;
      case platformMacosArm64:
      case platformMacosX64:
        suffix = 'macos';
        break;
      case platformLinuxX64:
        suffix = 'linux64';
        break;
      case platformLinuxArm64:
        suffix = 'linux_arm64';
        break;
      default:
        if (platKey.startsWith(platformWindows)) {
          suffix = 'windows64';
        } else if (platKey.startsWith(platformMacos)) {
          suffix = 'macos';
        } else if (platKey.startsWith(platformLinux)) {
          suffix = 'linux64';
        } else {
          return empty;
        }
    }
    return '$hpatchzDownloadBaseUrl/hdiffpatch_${defaultHpatchzVersion}_bin_$suffix.zip';
  }

  static String hdiffpatchDownloadTempFileName(int timestamp) =>
      'hdiffpatch_download_$timestamp.zip';

  static String cleanZipFileName(String slug, String version) =>
      '${slug}_v${version}_clean.zip';

  static String fullZipFileName(String slug, String version) =>
      '${slug}_v${version}_full.zip';

  static String updatePatchFileName(String slug) => '${slug}_update.hdiff';
  static String versionWithV(String version) => 'v$version';

  // ---------------------------------------------------------------------------
  // Shell Script Generators
  // ---------------------------------------------------------------------------
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

echo "Esperando a que HakkinLauncher finalice, PID: \$CURRENT_PID..."
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
    echo "ERROR durante la actualización. Activando rollback de seguridad..."
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
TARGET_PARENT="\$(dirname "\$TARGET_APP")"
if ([ -e "\$TARGET_APP" ] && [ ! -w "\$TARGET_APP" ]) || [ ! -w "\$TARGET_PARENT" ]; then
    echo "Permisos de escritura restringidos en \$TARGET_APP. Solicitando autorización administrativa en macOS..."
    osascript -e "do shell script \\"rm -rf '\$TARGET_APP' && mv '\$FOUND_APP' '\$TARGET_APP' && xattr -dr com.apple.quarantine '\$TARGET_APP'\\" with administrator privileges" || rollback
else
    rm -rf "\$TARGET_APP" 2>/dev/null || true
    if ! mv "\$FOUND_APP" "\$TARGET_APP"; then
        echo "Error al mover nueva versión a destino."
        rollback
    fi
    xattr -dr com.apple.quarantine "\$TARGET_APP" 2>/dev/null || true
fi

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
echo ERROR: Fallo durante la actualización. Restaurando desde backup... >> "%LOG_FILE%"
if exist "%BACKUP_DIR%" (
    xcopy "%BACKUP_DIR%" "%APP_DIR%\\" /E /I /H /Y /Q >> "%LOG_FILE%" 2>&1
)
start "" "%CURRENT_EXE%"
rmdir /s /q "%STAGING_DIR%" 2>NUL
exit /b 1
''';
  }

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
    echo "ERROR: Falla al actualizar. Restaurando respaldo de seguridad..."
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
if [ ! -w "\$APP_DIR" ]; then
    echo "Permisos insuficientes en \$APP_DIR. Solicitando autorización administrativa vía pkexec..."
    pkexec env DISPLAY="\$DISPLAY" XAUTHORITY="\$XAUTHORITY" bash -c "cp -a '\$STAGING_CONTENT/.' '\$APP_DIR/' && chmod +x '\$CURRENT_EXE'" || rollback
else
    cp -a "\$STAGING_CONTENT/." "\$APP_DIR/" || rollback
    chmod +x "\$CURRENT_EXE" || true
fi

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

  static String generateWindowsShortcutScript({
    required String shortcutPath,
    required String targetPath,
    required String workingDir,
    String? iconPath,
  }) {
    final iconLine = iconPath != null ? "\$s.IconLocation = '$iconPath'" : "";
    return '''
\$ws = New-Object -ComObject WScript.Shell
\$s = \$ws.CreateShortcut('$shortcutPath')
\$s.TargetPath = '$targetPath'
\$s.WorkingDirectory = '$workingDir'
$iconLine
\$s.Save()
''';
  }

  static String generateLinuxDesktopEntry({
    required String appTitle,
    required String executablePath,
    required String workingDir,
    String? iconPath,
  }) {
    final iconLine = iconPath != null ? "Icon=$iconPath" : "";
    return '''[Desktop Entry]
Type=Application
Name=$appTitle
Exec="$executablePath"
Path=$workingDir
$iconLine
Terminal=false
Categories=Game;Utility;
''';
  }
}
