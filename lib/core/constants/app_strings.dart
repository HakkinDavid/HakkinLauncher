import 'app_technical_strings.dart';

/// Centralized user-facing strings for HakkinLauncher.
///
/// Contains UI text, button labels, screen titles, dialogs, status badges,
/// notification titles and bodies, validation messages, and error messages.
class AppStrings {
  AppStrings._();

  // ---------------------------------------------------------------------------
  // Branding & Navigation
  // ---------------------------------------------------------------------------
  static const appName = 'HakkinLauncher';
  static const brandHakkin = 'HAKKIN';
  static const brandLauncher = 'LAUNCHER';
  static const navStore = 'Tienda';
  static const navLibrary = 'Biblioteca';
  static const navSettings = 'Ajustes';
  static const statusOnline = 'En línea';
  static const badgeNew = 'Nuevo';
  static String statusOs(String os) => 'Plataforma: $os';

  // ---------------------------------------------------------------------------
  // Generic Actions & Buttons
  // ---------------------------------------------------------------------------
  static const cancel = 'Cancelar';
  static const save = 'Guardar';
  static const retry = 'Reintentar';
  static const back = 'Volver';
  static const understood = 'Entendido';
  static const closeNotice = 'Cerrar aviso';
  static const uninstall = 'Desinstalar';
  static const play = 'Jugar';
  static const running = 'En ejecución';
  static const update = 'Actualizar';
  static const updateFull = 'Actualizar completa';
  static const updateLauncher = 'Actualizar lanzador';
  static const updating = 'Actualizando...';
  static const goToStore = 'Ir a la tienda';
  static const viewInStore = 'Ver en la tienda';
  static const savePath = 'Guardar ruta';
  static const selectInstallDirectory = 'Seleccionar carpeta';
  static const openInstallDirectory = 'Abrir carpeta';
  static const restoreDefaultPath = 'Restaurar ruta por defecto';
  static const checkUpdatesNow = 'Buscar actualizaciones ahora';
  static const checkingUpdates = 'Buscando actualizaciones...';
  static const cleanTemporaryFiles = 'Limpiar archivos temporales';

  static String playOrOpenVersion(String version) => 'Jugar v$version';
  static String installVersion(String version) => 'Instalar v$version';
  static String updateToVersion(String version) => 'Actualizar a v$version';
  static String updateFullyVersion(String version) =>
      'Actualizar completa v$version';
  static String cleanInstallVersion(String version) =>
      'Instalación limpia v$version';
  static String installingWithPct(String pct) =>
      pct.isEmpty ? 'Instalando...' : 'Instalando $pct';
  static String availableForPlatform(String platform) =>
      'Disponible para $platform';
  static String switchToPlatform(String platform) => 'Cambiar a $platform';

  // ---------------------------------------------------------------------------
  // Store & Catalog
  // ---------------------------------------------------------------------------
  static const searchCatalogHint = 'Buscar en el catálogo...';
  static const categoryAll = 'Todos';
  static const categoryGames = 'Juegos';
  static const categoryApps = 'Apps';
  static const categoryTools = 'Herramientas';
  static const categoryGameSingular = 'Juego';
  static const categoryAppSingular = 'App';
  static const categoryToolSingular = 'Herramienta';
  static const featured = 'Destacado';
  static const exploreCatalog = 'Explorar catálogo';
  static const notFound = 'No encontrado';
  static const appNotFoundInCatalog =
      'Aplicación no encontrada en el catálogo.';
  static const defaultDeveloper = 'Desarrollador';
  static String errorLoadingCatalog(Object error) =>
      'Error al cargar el catálogo: $error.';

  static String categoryLabel(String category) {
    switch (category.toLowerCase()) {
      case AppTechnicalStrings.categoryGame:
        return categoryGameSingular;
      case AppTechnicalStrings.categoryApp:
        return categoryAppSingular;
      case AppTechnicalStrings.categoryTool:
        return categoryToolSingular;
      default:
        return category;
    }
  }

  // ---------------------------------------------------------------------------
  // Library Screen & Item Actions
  // ---------------------------------------------------------------------------
  static const myLibraryTitle = 'Mi biblioteca';
  static const myLibrarySubtitle = 'Tus aplicaciones listas para abrir.';
  static const emptyLibraryTitle = 'Tu biblioteca está vacía';
  static const emptyLibrarySubtitle =
      'Explora la tienda para instalar aplicaciones.';
  static const manageVersions = 'Ir a la página de la tienda';
  static const autoUpdate = 'Actualización automática';
  static const launchArguments = 'Argumentos de inicio';
  static const createDesktopShortcut = 'Crear acceso directo en el escritorio';
  static const addToStartMenu = 'Añadir al menú de aplicaciones';
  static const desktopShortcutCreated =
      'Acceso directo creado en el escritorio.';
  static const couldNotCreateShortcut =
      'No se pudo crear el acceso directo.';
  static const startMenuEntryCreated =
      'Acceso añadido al menú de aplicaciones.';
  static const couldNotCreateStartMenuEntry =
      'No se pudo añadir al menú de aplicaciones.';
  static const confirmUninstallTitle = '¿Desinstalar aplicación?';
  static const launchArgumentsParamDescription =
      'Parámetros al iniciar la aplicación.';
  static const launchArgumentsHint = 'ej. -windowed -novsync -fps 60';

  static String errorLoadingLibrary(Object error) =>
      'Error al cargar la biblioteca: $error.';
  static String argumentsFor(String title) => 'Argumentos para $title';
  static String confirmUninstallContent(String title) =>
      'Se eliminarán los archivos de $title. Tus partidas guardadas permanecerán protegidas.';
  static String installedVersionLabel(String version) =>
      'Versión instalada: v$version';
  static String installedVersionWithUpdateLabel(
          String installed, String latest) =>
      'Versión instalada: v$installed, actualización v$latest disponible';
  static String anomalyInstalledVersionLabel(
          String installed, String latest) =>
      'Anomalía: v$installed huérfana en catálogo, requiere actualización completa a v$latest';
  static String argumentsDisplay(String args) => 'Argumentos: $args';

  // ---------------------------------------------------------------------------
  // Badges
  // ---------------------------------------------------------------------------
  static const badgeInstalled = 'Instalado';
  static const badgeUpdateAvailable = 'Actualizar';
  static const badgeRunning = 'En ejecución';
  static const badgeAnomaly = 'Anomalía';

  // ---------------------------------------------------------------------------
  // App Detail Screen
  // ---------------------------------------------------------------------------
  static const technicalDetails = 'Detalles de la aplicación';
  static const fieldCategory = 'Categoría';
  static const fieldDeveloper = 'Desarrollador';
  static const fieldActivePlatform = 'Plataforma activa';
  static const fieldAvailablePlatforms = 'Plataformas disponibles';
  static const fieldSelectedVersion = 'Versión seleccionada';
  static const fieldReleaseDate = 'Fecha de versión';
  static const fieldDownloadSize = 'Tamaño de descarga';
  static const downloadOrInstallErrorTitle = 'Error de instalación';
  static const versionAnomalyDetectedTitle = 'Anomalía de versión detectada';
  static const screenshotsTitle = 'Capturas de pantalla';
  static const cleanInstallRequiredTitle = 'Instalación limpia requerida';
  static const proceedWithCleanInstall = 'Proceder con instalación limpia';

  static String versionNotes(String version) => 'Notas de la versión v$version';
  static String versionTagRecent(String version) => 'v$version reciente';
  static String versionTag(String version) => 'v$version';
  static String anomalyExplanation(String installed) =>
      'La versión instalada v$installed ya no está disponible en el catálogo. Debe actualizarse de manera completa.';
  static String cleanInstallWarningMessage(
          String currentVersion, String targetVersion) =>
      'Tienes instalada la versión v$currentVersion.\n\n'
      'Para cambiar a la versión anterior, v$targetVersion, se realizará una instalación limpia desde cero.\n\n'
      'Tus datos de usuario y partidas guardadas permanecerán protegidos.\n\n'
      '¿Deseas proceder?';

  // Platform Display Labels
  static const platformLabelWindowsX64 = 'Windows x64';
  static const platformLabelWindowsX86 = 'Windows 32-bit';
  static const platformLabelMacosArm64 = 'macOS Apple Silicon';
  static const platformLabelMacosX64 = 'macOS Intel';
  static const platformLabelAndroid = 'Android';
  static const platformLabelLinuxX64 = 'Linux x64';
  static const platformLabelIos = 'iOS';

  // ---------------------------------------------------------------------------
  // Settings Screen
  // ---------------------------------------------------------------------------
  static const settingsTitle = 'Configuración';
  static const settingsSubtitle = 'Preferencias generales del lanzador.';
  static const installPathSectionTitle = 'Ruta de instalación';
  static const installPathSectionDescription = 'Carpeta para las aplicaciones.';
  static const installDirectoryLabel = 'Carpeta de instalación';
  static const selectInstallDirectoryPrompt =
      'Selecciona la carpeta de instalación';
  static const installPathSavedSuccess =
      'Ruta de instalación guardada con éxito.';
  static const couldNotOpenDirectory =
      'No se pudo abrir la carpeta en el explorador del sistema.';
  static const backgroundAndUpdatesTitle = 'Sistema';
  static const backgroundAndUpdatesDescription =
      'Comportamiento de la ventana y actualizaciones.';
  static const launchAtStartupTitle =
      'Ejecutar al arranque del sistema';
  static const launchAtStartupSubtitle =
      'Inicia el lanzador automáticamente al encender el equipo.';
  static const minimizeToTrayTitle =
      'Mantener activo al cerrar la ventana';
  static const minimizeToTraySubtitle =
      'Permite recibir avisos cuando haya nuevas versiones disponibles.';
  static const maintenanceTitle = 'Mantenimiento';
  static const maintenanceDescription =
      'Libera espacio eliminando archivos temporales.';
  static const systemInfoTitle = 'Información del sistema';
  static const systemInfoDescription = 'Detalles generales de HakkinLauncher.';
  static const labelBaseDir = 'Carpeta de datos';
  static const labelPlatform = 'Plataforma';
  static const labelLauncherVersion = 'Versión del lanzador';

  static String newLauncherVersionAvailableBanner(
          String appName, String version) =>
      'Nueva versión de $appName disponible: v$version';
  static String currentVersionNotice(String version) =>
      'Tu versión actual es v$version. Pulsa para actualizar y reiniciar automáticamente.';
  static String newLauncherVersionReady(String appName, String version) =>
      '¡Nueva versión de $appName v$version disponible!';
  static String updatesFoundCount(int count) =>
      count == 1
          ? 'Se encontró 1 actualización disponible.'
          : 'Se encontraron $count actualizaciones disponibles.';
  static const allUpToDateLong =
      'Todo al día. Todas tus aplicaciones y el lanzador están en la versión más reciente.';
  static String errorCheckingUpdates(Object error) =>
      'Error al comprobar actualizaciones: $error.';
  static String filesDeletedCount(int count) =>
      'Se eliminaron $count archivos temporales.';

  // ---------------------------------------------------------------------------
  // Tray Menu
  // ---------------------------------------------------------------------------
  static const trayOpenLauncher = 'Abrir HakkinLauncher';
  static const trayCheckUpdates = 'Buscar actualizaciones';
  static const trayExit = 'Salir';

  // ---------------------------------------------------------------------------
  // Component Manager
  // ---------------------------------------------------------------------------
  static const componentNotInstalled = 'No instalado';
  static String componentAvailable(String path) => 'Disponible en $path';

  // ---------------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------------
  static const installationCompletedTitle = 'Instalación completada';
  static const updateCompletedTitle = 'Actualización completada';
  static const updateAvailableTitle = 'Actualización disponible';
  static const updatesFoundTitle = 'Actualizaciones encontradas';
  static const allUpToDateTitle = 'Todo al día';
  static const allUpToDateBody =
      'Todas tus aplicaciones y el lanzador están en la versión más reciente.';

  static String appReadyToRun(String title) =>
      '$title está listo para abrirse.';
  static String updateCompletedBody(String title, String version) =>
      '$title se ha actualizado con éxito a la versión v$version.';
  static String updateAvailableBody(String title, String version) =>
      'Hay una nueva versión v$version disponible para $title.';
  static String newLauncherVersionTitle(String appName) =>
      'Nueva versión de $appName';
  static String newVersionReadyBody(String version) =>
      'La versión v$version está lista para actualizar.';
  static String updatesAvailableFor(String summary) =>
      'Disponibles para: $summary.';

  // ---------------------------------------------------------------------------
  // Downloader & Progress
  // ---------------------------------------------------------------------------
  static const emptyDownloadResponse = 'Respuesta de descarga vacía.';
  static String speedMbPerSec(String speed) => '$speed MB/s';
  static String percentage(double pct) => '${pct.toStringAsFixed(1)}%';
  static String downloadProgressOf(String currentMb, String totalMb) =>
      '$currentMb MB de $totalMb MB';
  static String downloadedMb(String mb) => '$mb MB descargados';
  static String completedMb(String mb) => '$mb MB completados';
  static String speedSeparator(String text) => ', $text';
  static String errorWithPrefix(Object err) => 'Error: $err';
  static String formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  static String megabytes(String mb) => '$mb MB';
  static String percentInt(double pct) => '${pct.toStringAsFixed(0)}%';

  // ---------------------------------------------------------------------------
  // PatchEngine & Lifecycle
  // ---------------------------------------------------------------------------
  static const checkingAppStateAndVersion = 'Preparando instalación...';
  static const appHasNoVersionForPlatform =
      'Esta aplicación no está disponible para tu plataforma actual.';
  static const verifyingPackageChecksum = 'Finalizando descarga...';
  static const checksumMismatchError =
      'El archivo descargado está incompleto o dañado.';
  static const cleaningDirAndExtracting = 'Instalando aplicación...';
  static const verifyingPatchSecurity = 'Preparando actualización...';
  static const runningPreScripts = 'Preparando archivos...';
  static const applyingDeltaPatch = 'Actualizando aplicación...';
  static const deltaUpdateCompletedSuccess =
      'Actualización completada con éxito.';
  static const protectingUserData = 'Resguardando tus datos...';
  static const runningPreInstallScript = 'Preparando instalación...';
  static const extractingAppFiles = 'Instalando archivos...';
  static const runningPostInstallScript = 'Finalizando instalación...';
  static const installationCompletedSuccess =
      'Instalación completada correctamente.';

  static String anomalyDetectedCleanInstallMessage(
          String installedVersion, String targetVersion) =>
      'Anomalía detectada: versión v$installedVersion huérfana o inexistente en catálogo. Procediendo con actualización completa a v$targetVersion y protegiendo datos...';
  static String startingCleanInstallMessage(String targetVersion) =>
      'Iniciando instalación limpia de v$targetVersion y protegiendo datos...';
  static String startingDownloadMessage(String version, String mb) =>
      'Iniciando descarga de v$version de $mb MB...';
  static String downloadingVersionMessage(
          String version, String status, String speed) =>
      'Descargando v$version: $status$speed';
  static String cleanInstallNotificationTitle(String title, String version) =>
      '$title: Instalación limpia v$version';
  static String fullUpdateNotificationVersion(String version) =>
      '$version, actualización completa';
  static String fullUpdateCompletedMessage(String version) =>
      'Actualización completa a v$version completada con éxito y anomalía corregida.';
  static String cleanInstallCompletedMessage(String version) =>
      'Instalación limpia de v$version completada con éxito.';
  static String cleanInstallErrorMessage(Object error) =>
      'Error en instalación limpia: $error.';
  static String startingDeltaDownloadMessage(String mb) =>
      'Iniciando descarga de actualización de $mb MB...';
  static String downloadingPatchMessage(String status, String speed) =>
      'Descargando actualización: $status$speed';
  static String installationErrorMessage(Object error) =>
      'Ocurrió un error durante la instalación: $error.';

  // ---------------------------------------------------------------------------
  // Integrity Verifier & Crypto
  // ---------------------------------------------------------------------------
  static const fileDoesNotExist = 'El archivo no existe.';
  static const appNotRegisteredLocally =
      'Aplicación no registrada.';
  static const executableFileEmpty = 'El archivo de la aplicación está vacío.';
  static const allFilesVerifiedSuccessfully =
      'Todos los archivos verificados correctamente.';
  static String executableNotFoundOnDisk(String path) =>
      'El archivo de la aplicación no existe en disco: $path.';
  static String anomalyOrphanVersionDetected(
          String installed, String latest) =>
      'Anomalía detectada: la versión v$installed es huérfana o inexistente en el catálogo. Requiere actualización completa a v$latest.';

  // ---------------------------------------------------------------------------
  // Self Update
  // ---------------------------------------------------------------------------
  static const selfUpdateChecking = 'Preparando actualización del lanzador...';
  static const selfUpdateNoPlatformPackage =
      'No hay actualización disponible para tu plataforma actual.';
  static const selfUpdateUnsupportedPlatform = 'Plataforma no soportada.';
  static const selfUpdateInvalidDownloadUrl =
      'Dirección de descarga no válida.';
  static const selfUpdateEmptyUrl = 'Dirección vacía.';
  static const selfUpdateVerifyingChecksum =
      'Preparando instalación...';
  static const selfUpdateHashMismatchMessage =
      'El archivo descargado está incompleto o dañado.';
  static const selfUpdatePreparingRestart =
      'Preparando reinicio del lanzador...';
  static const selfUpdateReadyTitle = 'Actualización lista';
  static const selfUpdateReadyBody =
      'HakkinLauncher se reiniciará para aplicar la nueva versión.';
  static const selfUpdateRestarting = 'Reiniciando...';
  static const selfUpdateStarting =
      'Iniciando actualización del lanzador...';
  static const selfUpdateHttp404 =
      'No se encontró la actualización disponible en este momento.';
  static const selfUpdateTimeout =
      'Tiempo de espera agotado al descargar la actualización. Comprueba tu conexión a internet.';
  static const selfUpdateConnectionError =
      'Error de red o sin conexión a internet.';
  static String selfUpdateStartingDownload(String version) =>
      'Iniciando descarga de actualización v$version...';
  static String selfUpdateDownloading(String status, String speed) =>
      'Descargando actualización: $status$speed';
  static String selfUpdateErrorGeneric(Object error) =>
      'Error al actualizar el lanzador: $error.';
  static String selfUpdateNetworkError(String message) =>
      'Error de red durante la descarga: $message.';

  // ---------------------------------------------------------------------------
  // Logs & Debug
  // ---------------------------------------------------------------------------
  static String logDesktopServicesPartialInit(Object error) =>
      'Aviso: Servicios de escritorio inicializados parcialmente: $error.';
  static String logCouldNotInitLocalNotifier(Object error) =>
      'Aviso: No se pudo inicializar local_notifier: $error.';
  static String logErrorEmittingNotification(Object error) =>
      'Error al emitir notificación: $error.';
  static String logErrorCheckingHpatchz(Object error) =>
      'Aviso al buscar hpatchz existente: $error.';
  static String logErrorPermissions(String path, Object error) =>
      'Aviso al asignar permisos a $path: $error.';
  static String logHpatchzReady(String path) =>
      'Componente hpatchz listo en: $path.';
  static String logHpatchzNotFound() =>
      'Componente hpatchz no encontrado. Iniciando descarga automática...';
  static String logHpatchzPlatformNotSupported() =>
      'Plataforma no soportada para descarga automática de hpatchz.';
  static String logDownloadingHpatchz(String url) =>
      'Descargando hpatchz desde: $url.';
  static String logEmptyHpatchzDownload() =>
      'Error: Descarga de hpatchz vacía.';
  static String logHpatchzNotFoundInZip() =>
      'Error: No se encontró el binario hpatchz dentro del archivo ZIP.';
  static String logHpatchzVerified(String out) =>
      'hpatchz instalado y verificado: $out.';
  static String logHpatchzVerifyWarning(Object error) =>
      'Aviso al verificar ejecución de hpatchz: $error.';
  static String logHpatchzInstalled(String path) =>
      'hpatchz instalado exitosamente en: $path.';
  static String logHpatchzDownloadFail(Object error) =>
      'Fallo al descargar o instalar hpatchz: $error.';
  static String logAppAlreadyRunning(String appId, int pid) =>
      'La aplicación $appId ya está en ejecución con PID $pid.';
  static String logExecutableNotFound(String path) =>
      'No se encontró el ejecutable en: $path.';
  static String logAppLaunched(String appId, int pid) =>
      'Aplicación $appId iniciada desacoplada exitosamente con PID $pid.';
  static String logAppLaunchError(String appId, Object error) =>
      'Error al iniciar proceso desacoplado para $appId: $error.';
  static String logAppTerminated(String appId, int pid) =>
      'Aplicación $appId con PID $pid finalizó.';
  static String logScriptError(String path, Object error) =>
      'Error al ejecutar script $path: $error.';
  static String logDesktopShortcutError(Object error) =>
      'Error al crear acceso directo en el escritorio: $error.';
  static String logStartMenuError(Object error) =>
      'Error al registrar en el menú de aplicaciones: $error.';
  static String logRemoveShortcutsError(Object error) =>
      'Aviso al eliminar accesos directos de la aplicación: $error.';
  static String logTrayInitError(Object error) =>
      'Error al inicializar la bandeja del sistema: $error.';
  static String logCloseToTrayPrefError(Object error) =>
      'Aviso al cargar preferencia de bandeja del sistema: $error.';
  static String logWindowIconError(Object error) =>
      'Aviso: No se pudo establecer el icono de ventana: $error.';
  static String logDownloadAttemptFail(int attempt, Object error) =>
      'Intento $attempt de descarga falló: $error.';
  static String logPatchHashMismatch() =>
      'Aviso: La suma de verificación tras aplicar el parche no coincide. Descartando parche diferencial.';
  static String logDeltaPatchError(Object error) =>
      'Fallo al aplicar el parche diferencial: $error. Activando alternativa de respaldo con descarga completa.';
  static String logActivatingFullPackageFallback() =>
      'Activando descarga limpia de paquete completo como alternativa.';
  static String logHpatchzNotAvailable() =>
      'Aviso: hpatchz no está disponible ni se pudo descargar automáticamente.';
  static String logHpatchzDirExitCode(int code) =>
      'Aviso: parche a nivel de directorio retornó $code, reintentando sobre ejecutable...';
  static String logHpatchzExecError(Object error) =>
      'Error al ejecutar hpatchz: $error.';
  static String logDirectoryPickerError(Object error) =>
      'Error al abrir el selector de carpetas: $error.';
  static String logOpenDirectoryError(Object error) =>
      'Error al abrir la carpeta en el sistema: $error.';
  static String logStartupServiceError(Object error) =>
      'Aviso al configurar el inicio automático del sistema: $error.';
  static String logAutoUpdateStarting(String title, String version) =>
      'Iniciando actualización automática de $title a v$version.';
  static String logAutoSelfUpdateStarting(String version) =>
      'Iniciando actualización automática de HakkinLauncher a v$version.';
  static String logAutoUpdateError(Object error) =>
      'Error en actualización automática: $error.';

  // ---------------------------------------------------------------------------
  // macOS Relocation Service
  // ---------------------------------------------------------------------------
  static const macOsRelocationDialogTitle = 'Mover a la carpeta de aplicaciones';
  static const macOsRelocationDialogMessage =
      'Para recibir actualizaciones correctamente, se recomienda mover HakkinLauncher a la carpeta de aplicaciones.';
  static const macOsRelocationDialogConfirm = 'Mover a la carpeta de aplicaciones';
  static const macOsRelocationDialogCancel = 'Continuar aquí';
  static const macOsRelocationSuccessToast =
      'HakkinLauncher se trasladó exitosamente a la carpeta de aplicaciones.';
  static const macOsRelocationErrorToast =
      'No se pudo trasladar automáticamente a la carpeta de aplicaciones.';
  static String logMacOsRelocationSuccess(String path) =>
      'HakkinLauncher se trasladó con éxito a: $path.';
  static String logMacOsRelocationError(Object error) =>
      'Error al trasladar HakkinLauncher a la carpeta de aplicaciones: $error.';
}
