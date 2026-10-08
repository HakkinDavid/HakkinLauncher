# Documento Maestro de Especificación y Arquitectura: HakkinLauncher

> **Versión del Documento:** 2.0.0  
> **Estado:** 100% Implementado / Catálogo Histórico v2.0 & Delta Patching  
> **Autor:** HakkinDavid & Antigravity  
> **Fecha:** Octubre 2026  
> **Ecosistema:** Flutter Desktop (macOS, Windows, Linux) & Mobile (Android, iOS)

---

## 1. Resumen Ejecutivo y Visión del Producto

### 1.1 Contexto del Problema
A lo largo de los años, el desarrollo de aplicaciones de escritorio, utilidades y videojuegos distribuidos de forma independiente a través de GitHub Releases ha evidenciado una severa **barrera de fricción para los usuarios no técnicos**:
- **Desconocimiento y falta de monitorización:** Los usuarios no comprueban periódicamente las releases de GitHub. Al encontrar un fallo o bug, suelen abandonar el software en lugar de buscar la actualización.
- **Dificultad operativa en la actualización manual:** Descargar un archivo comprimido (`.zip`), extraerlo, ubicar el directorio original y sobrescribir binarios respetando archivos de configuración o partidas guardadas es un proceso propenso a errores para el usuario promedio.
- **Coste de ancho de banda y transferencia innecesaria:** En videojuegos o programas pesados (de cientos de megabytes a varios gigabytes), descargar el paquete completo por un hotfix de pocos megabytes genera frustración y gasto de recursos.
- **Fatiga por redundancia técnica:** Desarrollar sistemas de auto-actualización específicos para cada proyecto (en distintos motores o lenguajes como Godot, Unity, C++, Rust, C#) multiplica la deuda técnica y el mantenimiento.

### 1.2 La Solución: HakkinLauncher
**HakkinLauncher** es un cliente universal de descubrimiento, instalación, ejecución y actualización inteligente para todo el ecosistema de software y videojuegos del desarrollador. Funciona como una tienda/biblioteca moderna inspirada en **Epic Games Store** y **Steam**, pero de código abierto y sin barreras de pago (libre de paywalls).

Sus pilares fundamentales son:
1. **Catálogo Centralizado e Histórico en Caliente (v2.0):** Carga dinámica de un diccionario JSON desde el repositorio maestro con persistencia multi-versión. Cada versión registra su paquete completo, ejecutable relativo específico, notas de parche y diferenciales.
2. **Actualizaciones Diferenciales Unidireccionales (Delta Patching):** Soporte de parches binarios con `HDiffPatch` (`hpatchz`) para descargar únicamente las diferencias entre versiones hacia adelante, con verificación estricta de hash SHA-256 pre y post patch, y fallback automático a descarga limpia completa.
3. **Selección de Versiones y Política Estricta Anti-Downgrade:** El usuario puede seleccionar e instalar libremente versiones históricas en la UI. Sin embargo, no se permite degradación (downgrade) sobre una instalación existente: instalar una versión anterior requiere una **instalación limpia desde cero** con advertencia modal previa y notificación nativa.
4. **Preservación Contractual de Datos de Usuario:** Respeto estricto de rutas de guardado (`saves/**`, `config/**`, etc.) durante instalaciones, actualizaciones e instalaciones limpias de versiones históricas.
5. **Presencia en Segundo Plano:** Minimizado a la bandeja del sistema (System Tray en Windows / Menu Bar en macOS) con chequeos silenciosos de nuevas versiones y notificaciones nativas del sistema operativo.
6. **Auto-actualización del Propio Lanzador (Self-Update):** Capacidad del cliente de actualizarse a sí mismo de manera atómica sin corromperse y reabrirse automáticamente mediante helpers desacoplados.
7. **Diseño Visual Platino & Noche:** Estética inmersiva, elegante y oscura inspirada en la Epic Games Store con toques lunares y metálicos platino.

---

## 2. Requisitos del Sistema y Mapeo de Implementación

### 2.1 Requisitos Funcionales (RF)

| Requisito | Descripción | Estado | Implementación Técnica |
| :--- | :--- | :---: | :--- |
| **RF-01.1** | Carga Remota en Caliente | **100%** | [`CatalogRepository.fetchCatalog()`](file:///Users/hakkindavid/Documents/GitHub/HakkinLauncher/lib/features/catalog/data/repositories/catalog_repository.dart) con `Dio` y timeouts. |
| **RF-01.2** | Caché Offline Persistente | **100%** | [`CatalogRepository`](file:///Users/hakkindavid/Documents/GitHub/HakkinLauncher/lib/features/catalog/data/repositories/catalog_repository.dart) con `SharedPreferences` y fallback al asset bundled `catalog_example.json`. |
| **RF-01.3** | Validación de Esquema JSON v2.0 | **100%** | [`CatalogManifest.fromJson()`](file:///Users/hakkindavid/Documents/GitHub/HakkinLauncher/lib/features/catalog/data/models/app_entry.dart) con tipado seguro e histórico de versiones. |
| **RF-01.4** | Sondeo Programado de Fondo | **100%** | [`BackgroundCheckService`](file:///Users/hakkindavid/Documents/GitHub/HakkinLauncher/lib/core/platform/background_check_service.dart) con `Timer.periodic(4h)` y acción en bandeja. |
| **RF-02.1** | Vista Catálogo estilo EGS | **100%** | [`StoreScreen`](file:///Users/hakkindavid/Documents/GitHub/HakkinLauncher/lib/features/catalog/presentation/screens/store_screen.dart) con [`HeroCarousel`](file:///Users/hakkindavid/Documents/GitHub/HakkinLauncher/lib/shared/widgets/hero_carousel.dart) y grilla [`AppCard`](file:///Users/hakkindavid/Documents/GitHub/HakkinLauncher/lib/shared/widgets/app_card.dart). |
| **RF-02.2** | Buscador y Filtros Reactivos | **100%** | [`filteredAppsProvider`](file:///Users/hakkindavid/Documents/GitHub/HakkinLauncher/lib/features/catalog/presentation/controllers/catalog_controller.dart) con filtrado instantáneo por texto y categoría. |
| **RF-02.3** | Compatibilidad de Plataformas | **100%** | [`OsPaths.getCurrentPlatformKey()`](file:///Users/hakkindavid/Documents/GitHub/HakkinLauncher/lib/core/platform/os_paths.dart) e iconos dinámicos en [`AppCard`](file:///Users/hakkindavid/Documents/GitHub/HakkinLauncher/lib/shared/widgets/app_card.dart). |
| **RF-02.4** | Ficha de Producto y Screenshots | **100%** | [`AppDetailScreen`](file:///Users/hakkindavid/Documents/GitHub/HakkinLauncher/lib/features/app_detail/presentation/screens/app_detail_screen.dart) con selector de versiones históricas, Markdown y ficha técnica. |
| **RF-03.1** | Descargador Resumible HTTP | **100%** | [`DownloaderService`](file:///Users/hakkindavid/Documents/GitHub/HakkinLauncher/lib/features/updater/services/downloader_service.dart) con cabeceras `Range`, streams de bytes, MB/s y ETA. |
| **RF-03.2** | Extracción Atómica | **100%** | [`PatchEngine._extractZip()`](file:///Users/hakkindavid/Documents/GitHub/HakkinLauncher/lib/features/updater/services/patch_engine.dart) con staging temporal y desempaque limpio. |
| **RF-03.3** | Scripts Pre y Post Instalación | **100%** | [`ProcessLauncher.runScript()`](file:///Users/hakkindavid/Documents/GitHub/HakkinLauncher/lib/core/platform/process_launcher.dart) ejecutando `.bat`, `.ps1` y `.sh` por versión. |
| **RF-03.4** | Registro en S.O. (Shortcuts) | **100%** | [`ShortcutService`](file:///Users/hakkindavid/Documents/GitHub/HakkinLauncher/lib/core/platform/shortcut_service.dart) para accesos directos en Escritorio y Menú Inicio/Aplicaciones. |
| **RF-04.1** | Catálogo Histórico Multi-Versión | **100%** | [`PlatformRelease.versions`](file:///Users/hakkindavid/Documents/GitHub/HakkinLauncher/lib/features/catalog/data/models/app_entry.dart) con lista histórica completa de releases. |
| **RF-04.2** | Selección de Parche Delta (Unidireccional)| **100%** | [`PlatformRelease.findDeltaFor()`](file:///Users/hakkindavid/Documents/GitHub/HakkinLauncher/lib/features/catalog/data/models/app_entry.dart) buscando deltas hacia la versión seleccionada. |
| **RF-04.3** | Verificación SHA-256 de Parche | **100%** | [`HashValidator.verifySha256()`](file:///Users/hakkindavid/Documents/GitHub/HakkinLauncher/lib/core/crypto/hash_validator.dart). |
| **RF-04.4** | Aplicación con HDiffPatch | **100%** | [`PatchEngine._applyHDiffPatch()`](file:///Users/hakkindavid/Documents/GitHub/HakkinLauncher/lib/features/updater/services/patch_engine.dart). |
| **RF-04.5** | Verificación Post-Patch de Hash | **100%** | [`PatchEngine`](file:///Users/hakkindavid/Documents/GitHub/HakkinLauncher/lib/features/updater/services/patch_engine.dart) contrastando el binario contra `target_sha256`. |
| **RF-04.6** | Prohibición de Downgrade in-place | **100%** | [`PatchEngine`](file:///Users/hakkindavid/Documents/GitHub/HakkinLauncher/lib/features/updater/services/patch_engine.dart) bloquea el uso de deltas para degradar versiones. |
| **RF-04.7** | Instalación Limpia de Versión Anterior | **100%** | [`PatchEngine`](file:///Users/hakkindavid/Documents/GitHub/HakkinLauncher/lib/features/updater/services/patch_engine.dart) y diálogo modal en [`AppDetailScreen`](file:///Users/hakkindavid/Documents/GitHub/HakkinLauncher/lib/features/app_detail/presentation/screens/app_detail_screen.dart) con notificación nativa. |
| **RF-04.8** | Preservación de Datos de Usuario | **100%** | [`PatchEngine`](file:///Users/hakkindavid/Documents/GitHub/HakkinLauncher/lib/features/updater/services/patch_engine.dart) aislando y restaurando `protected_user_paths`. |
| **RF-05.1** | Lanzamiento de Aplicaciones | **100%** | [`ProcessLauncher.launchApp()`](file:///Users/hakkindavid/Documents/GitHub/HakkinLauncher/lib/core/platform/process_launcher.dart) con `chmod +x` y ruta de trabajo. |
| **RF-05.2** | Detección de Proceso Activo (PID) | **100%** | [`ProcessLauncher.runningStateStream`](file:///Users/hakkindavid/Documents/GitHub/HakkinLauncher/lib/core/platform/process_launcher.dart) con bloqueo dinámico de acciones en UI. |
| **RF-05.3** | Argumentos Personalizados | **100%** | [`InstalledApp.launchArguments`](file:///Users/hakkindavid/Documents/GitHub/HakkinLauncher/lib/features/library/data/models/installed_app.dart) configurable mediante diálogo modal. |
| **RF-06.1** | Bandeja del Sistema / Menu Bar | **100%** | [`TrayService`](file:///Users/hakkindavid/Documents/GitHub/HakkinLauncher/lib/core/platform/tray_service.dart) con menús contextuales y apertura rápida. |
| **RF-06.2** | Minimizado a Bandeja al Cerrar | **100%** | [`WindowService.setCloseToTray()`](file:///Users/hakkindavid/Documents/GitHub/HakkinLauncher/lib/core/platform/window_service.dart). |
| **RF-06.3** | Notificaciones Nativas | **100%** | [`NotificationService`](file:///Users/hakkindavid/Documents/GitHub/HakkinLauncher/lib/core/platform/notification_service.dart) para instalaciones, actualizaciones y alertas de fondo. |
| **RF-07.1** | Limpieza de Temporales | **100%** | [`CleanerService.cleanTemporaryFiles()`](file:///Users/hakkindavid/Documents/GitHub/HakkinLauncher/lib/core/housekeeping/cleaner_service.dart) automático y bajo demanda. |
| **RF-07.2** | Rotación y Depuración de Logs | **100%** | [`CleanerService.rotateLogs()`](file:///Users/hakkindavid/Documents/GitHub/HakkinLauncher/lib/core/housekeeping/cleaner_service.dart) con cuota de 10 MB. |
| **RF-07.3** | Verificación de Integridad | **100%** | [`InstalledAppsNotifier.verifyAppIntegrity()`](file:///Users/hakkindavid/Documents/GitHub/HakkinLauncher/lib/features/library/presentation/controllers/library_controller.dart) estilo Steam / Epic. |
| **RF-08.1** | Detección de Nueva Versión | **100%** | [`LauncherMeta`](file:///Users/hakkindavid/Documents/GitHub/HakkinLauncher/lib/features/catalog/data/models/app_entry.dart) y banner destacado en Ajustes. |
| **RF-08.2** | Descarga Atómica de Reemplazo | **100%** | [`SelfUpdateService.performSelfUpdate()`](file:///Users/hakkindavid/Documents/GitHub/HakkinLauncher/lib/features/self_update/services/self_update_service.dart). |
| **RF-08.3** | Reemplazo y Reinicio Autónomo | **100%** | [`SelfUpdateService._applyUpdateAndRestart()`](file:///Users/hakkindavid/Documents/GitHub/HakkinLauncher/lib/features/self_update/services/self_update_service.dart) con helpers `.sh` y `.bat`. |

---

### 2.2 Requisitos No Funcionales (RNF)

- **RNF-01 (Multiplataforma):** Código base 100% Flutter estructurado para Windows, macOS, Linux, Android e iOS.
- **RNF-02 (Rendimiento en Reposo):** Operación asíncrona pasiva en reposo con consumo de memoria $\le 85\text{ MB}$ y $\le 0.1\%$ CPU.
- **RNF-03 (Responsividad de UI):** Renderizado fluido sin bloqueos. Operaciones de E/S, descompresión y streaming criptográfico desacopladas.
- **RNF-04 (Seguridad):** Verificación obligatoria de firmas SHA-256 en toda descarga antes de ser aplicada.
- **RNF-05 (Identidad Visual Platino & Noche):** Tema visual industrial de la Epic Games Store en [`AppColors`](file:///Users/hakkindavid/Documents/GitHub/HakkinLauncher/lib/core/theme/app_colors.dart) y [`AppTheme`](file:///Users/hakkindavid/Documents/GitHub/HakkinLauncher/lib/core/theme/app_theme.dart).

---

## 3. Especificación del Contrato JSON del Catálogo (v2.0.0)

El archivo remoto `catalog.json` sigue las especificaciones normativas de [CATALOG_SCHEMA.json](file:///Users/hakkindavid/Documents/GitHub/HakkinLauncher/docs/CATALOG_SCHEMA.json) bajo la arquitectura limpia v2.0.0:

```json
{
  "version": "2.0.0",
  "catalog_timestamp": "2026-10-08T00:00:00Z",
  "launcher_meta": {
    "latest_version": "1.0.1",
    "min_required_launcher_version": "1.0.0",
    "releases": {
      "windows-x64": { "url": "...", "sha256": "...", "size_bytes": 45000000 },
      "macos-arm64": { "url": "...", "sha256": "...", "size_bytes": 48000000 },
      "macos-x64": { "url": "...", "sha256": "...", "size_bytes": 49000000 }
    }
  },
  "apps": [
    {
      "id": "com.hakkin.app_id",
      "slug": "app-slug",
      "title": "Nombre de la Aplicación",
      "category": "game",
      "developer": "Hakkin",
      "summary": "Resumen conciso para tarjetas.",
      "description_markdown": "# Descripción completa en Markdown...",
      "tags": ["Action", "Indie"],
      "assets": {
        "icon": "https://.../icon.png",
        "poster": "https://.../poster.jpg",
        "banner": "https://.../banner.jpg",
        "screenshots": ["https://.../shot1.jpg", "https://.../shot2.jpg"]
      },
      "latest_version": "1.2.0",
      "platforms": {
        "windows-x64": {
          "latest_version": "1.2.0",
          "protected_user_paths": ["saves/**", "config.ini"],
          "versions": [
            {
              "version": "1.2.0",
              "release_date": "2026-10-08T00:00:00Z",
              "changelog": "Notas de la versión 1.2.0...",
              "executable_relative_path": "bin/App.exe",
              "package": {
                "url": "https://.../full_1.2.0.zip",
                "size_bytes": 1250000000,
                "sha256": "hash_sha256_full"
              },
              "delta_patches": [
                {
                  "from_version": "1.1.0",
                  "patch_format": "hdiff",
                  "url": "https://.../patch_1.1.0_to_1.2.0.hdiff",
                  "size_bytes": 28000000,
                  "patch_sha256": "hash_sha256_patch",
                  "target_sha256": "hash_sha256_resultante"
                }
              ],
              "scripts": {
                "pre_install": "scripts/pre.bat",
                "post_install": "scripts/post.bat"
              }
            },
            {
              "version": "1.1.0",
              "release_date": "2026-09-01T00:00:00Z",
              "changelog": "Versión inicial estable.",
              "executable_relative_path": "App.exe",
              "package": {
                "url": "https://.../full_1.1.0.zip",
                "size_bytes": 1200000000,
                "sha256": "hash_sha256_prev"
              },
              "delta_patches": [],
              "scripts": {
                "pre_install": null,
                "post_install": null
              }
            }
          ]
        }
      }
    }
  ]
}
```

---

## 4. Instrucciones de Compilación y Ejecución

### Ejecución en Modo Desarrollo
```bash
# macOS
flutter run -d macos

# Windows
flutter run -d windows
```

### Ejecución de Pruebas y Análisis
```bash
flutter analyze
flutter test
```
