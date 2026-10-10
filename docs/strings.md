# Arquitectura de Cadenas de Texto y Reglas Normativas: HakkinLauncher

> **Versión del Documento:** 1.0.0  
> **Estado:** Normativa Institucional Activa  
> **Ámbito:** Todo el código fuente bajo `lib/` y extensiones de plataforma  
> **Alineación:** Documento Maestro v2.0.0 y Especificación de Dominio

---

## 1. Arquitectura de Centralización

### Única Fuente de Verdad (`Single Source of Truth`)
Todas las cadenas de texto del sistema (legibles por el usuario, técnicas, operativas y de registro) se encuentran estricta y obligatoriamente centralizadas en los siguientes archivos canónicos dentro de `lib/core/constants/`:

```
lib/core/constants/app_strings.dart
lib/core/constants/app_technical_strings.dart
lib/core/constants/app_constants.dart
```

1. **`AppStrings` (`lib/core/constants/app_strings.dart`)**:
   - Centraliza todas las cadenas legibles por el usuario final y mensajes humanos del sistema.
   - Incluye: títulos de pantalla, etiquetas de botones, menús de navegación, textos de tarjetas de catálogo, fichas técnicas, cuadros de diálogo (`AlertDialog`), hojas inferiores (`ModalBottomSheet`), notificaciones locales del sistema operativo (`NotificationService`), opciones de la bandeja del sistema (`TrayService`), distintivos de estado (`StatusBadge`), mensajes de progreso de descargas, avisos de instalación, mensajes de error en excepciones legibles y registros de depuración (`debugPrint`).

2. **`AppTechnicalStrings` (`lib/core/constants/app_technical_strings.dart`)**:
   - Centraliza todas las cadenas operativas, sintácticas y técnicas del lanzador.
   - Incluye: rutas de navegación declarativas (`GoRouter`), claves de persistencia (`SharedPreferences`), claves de serialización del contrato JSON del catálogo (`catalog.json`), identificadores de plataforma (`windows-x64`, `macos-arm64`, etc.), extensiones de archivo (`.zip`, `.hdiff`, `.exe`), ejecutables y herramientas externas (`hpatchz`, `hdiffz`), comandos y utilidades del sistema (`ditto`, `unzip`, `chmod`, `taskkill`), banderas de línea de comandos, expresiones regulares, encabezados HTTP y plantillas de scripts (`update_helper.sh`, `update_helper.bat`).

3. **`AppConstants` (`lib/core/constants/app_constants.dart`)**:
   - Expone la fachada canónica de constantes de alto nivel consumidas transversalmente por la aplicación, delegando directamente sus valores en `AppStrings` y `AppTechnicalStrings`.

---

### Regla Absoluta de Cero Cadenas Literales (`Zero Hardcoded Strings`)
Está **estrictamente prohibido** incrustar cualquier cadena de texto literal (*hardcoded string*) fuera de `app_strings.dart` y `app_technical_strings.dart` dentro de todo el directorio `lib/`.

Esta norma aplica **sin excepción alguna**, incluyendo:
1. **Cadenas Visibles para el Usuario**:
   - Títulos, subtítulos, etiquetas de campos de texto (`InputDecoration.hintText`, `labelText`).
   - Botones de acción (`ElevatedButton`, `HakkinButton`, `OutlinedButton`, `IconButton.tooltip`).
   - Textos de navegación lateral y pestañas de la interfaz.
   - Textos de estado y distintivos (`StatusBadge`).
   - Contenido de cuadros de diálogo modales (`AlertDialog`) y confirmaciones.
   - Títulos y cuerpos de notificaciones nativas de escritorio y móviles.
   - Opciones del menú contextual de la bandeja del sistema (`TrayService`).
   - Textos de estado de descarga y cálculo de porcentaje/velocidad.
2. **Cadenas Internas y No Visibles para el Usuario**:
   - Mensajes de excepciones (`throw Exception(...)`, `throw FileSystemException(...)`).
   - Mensajes en bloques `catch` y fallbacks ante contingencias.
   - Mensajes y plantillas de registros/depuración (`debugPrint(...)`, `AppLogger`).
   - Claves de mapas, atributos JSON de modelos y claves de almacenamiento local.
   - Rutas relativas de directorios de trabajo, ejecutables y binarios.
   - Nombres de utilidades del sistema operativo y argumentos de consola pasados a `Process.run()` o `Process.start()`.

---

## 2. Reglas Normativas para las Cadenas de Texto

### 2.1. Puntuación y Capitalización Uniforme

1. **Mensajes, Descripciones, Avisos y Notificaciones**:
   Toda oración completa, descripción de sección, cuerpo de cuadro de diálogo, mensaje explicativo, notificación nativa o registro de aviso debe comenzar con mayúscula y finalizar obligatoriamente con un punto (`.`).
   - *Correcto*: `"Todas tus aplicaciones y el lanzador están en la versión más reciente."`
   - *Incorrecto*: `"Todas tus aplicaciones y el lanzador están en la versión más reciente"`
   - *Correcto*: `"Se eliminaron los archivos temporales de instalación."`
   - *Incorrecto*: `"se eliminaron los archivos temporales de instalación"`
   - *Correcto*: `"No se pudo verificar o descargar el motor de parches."`
   - *Incorrecto*: `"No se pudo verificar o descargar el motor de parches"`

2. **Etiquetas, Botones, Títulos y Distintivos**:
   Los títulos de sección, nombres de pantallas, etiquetas de botones, elementos de menú, nombres de columnas técnicas y distintivos de estado utilizan mayúscula inicial (o *Title Case* según jerarquía) y **nunca** llevan punto final.
   - *Correcto*: `"Guardar cambios"`, `"Buscar actualizaciones"`, `"Instalación limpia"`, `"Biblioteca"`, `"En ejecución"`
   - *Incorrecto*: `"Guardar cambios."`, `"buscar actualizaciones"`, `"Instalación limpia."`

---

### 2.2. Español Profesional y Eliminación de Anglicismos
Todas las cadenas visibles del sistema se expresan en un español técnico, profesional, neutro y depurado. Se prohíbe el uso de anglicismos crudos o no adaptados en la interfaz de usuario:

| Anglicismo no permitido | Término estandarizado en HakkinLauncher | Justificación y Ámbito |
| :--- | :--- | :--- |
| *Store* | **Tienda** | Vista de descubrimiento y catálogo público. |
| *Library* | **Biblioteca** | Módulo de programas y juegos instalados localmente. |
| *Launcher* (en UI/prosa) | **Lanzador** | Se reserva la palabra *HakkinLauncher* únicamente como nombre propio de marca. En explicaciones o etiquetas genéricas se usa *lanzador*. |
| *Downgrade* | **Degradación / Instalación de versión anterior** | Reemplazo deliberado de una versión superior por una inferior. |
| *Delta / Patch* | **Parche diferencial / Parche** | Archivo `.hdiff` con las diferencias binarias entre dos versiones. |
| *Full download* | **Descarga completa** | Paquete comprimido `.zip` íntegro sin parche diferencial. |
| *Clean install* | **Instalación limpia** | Proceso de despliegue desde cero preservando datos de usuario. |
| *Self-update* | **Autoactualización / Actualización del lanzador** | Mecanismo de actualización autónoma del cliente. |
| *Background (task/polling)* | **Segundo plano** | Procesos y comprobaciones periódicas no bloqueantes. |
| *Tray / System Tray* | **Bandeja del sistema** | Menú residente en el área de notificaciones del sistema operativo. |
| *Shortcut* | **Acceso directo** | Enlace en el Escritorio o Menú de Aplicaciones del SO. |
| *Badge* | **Distintivo** | Indicador visual de estado (`INSTALADO`, `ACTUALIZAR`, etc.). |
| *Header* | **Encabezado** | Componente visual superior o cabecera de sección. |
| *Settings* | **Configuración / Ajustes** | Panel de personalización y preferencias del usuario. |
| *Changelog / Release notes* | **Notas de la versión** | Lista de cambios y correcciones de una entrega histórica. |
| *Savegame / Saves* | **Partidas guardadas / Datos de guardado** | Archivos de progreso del usuario en videojuegos. |
| *User data* | **Datos de usuario** | Configuraciones y archivos preservados en `protected_user_paths`. |
| *Checksum / Hash* | **Suma de verificación / Hash criptográfico** | Código de integridad SHA-256 para validación de paquetes y deltas. |
| *Screenshot* | **Captura de pantalla** | Imágenes ilustrativas en la galería de ficha de producto. |
| *Fallback* | **Alternativa de respaldo** | Mecanismo que activa la descarga completa ante un fallo diferencial. |
| *Staging* | **Área temporal / Directorio de preparación** | Carpeta intermedia antes de la extracción definitiva. |
| *Orphan* | **Huérfana** | Versión local instalada que ha dejado de existir en el catálogo remoto. |
| *Running* | **En ejecución** | Estado de un proceso de juego o aplicación activo. |

---

### 2.3. Estandarización Terminológica
Para garantizar absoluta coherencia semántica en todo el código, mensajes y documentación de HakkinLauncher, los siguientes conceptos institucionales están normados:

- **Lanzador**: La aplicación cliente universal responsable de la gestión del ciclo de vida (distribución, instalación, ejecución y actualización) de aplicaciones y videojuegos.
- **Catálogo**: El manifiesto centralizado (`catalog.json`) distribuido remotamente que actúa como fuente de verdad sobre todas las aplicaciones, plataformas y versiones disponibles.
- **Tienda**: Espacio interactivo dentro del lanzador enfocado en la exploración, filtrado y descubrimiento de títulos del catálogo.
- **Biblioteca**: Espacio dedicado a los programas instalados en la máquina local, con herramientas de gestión de versiones, accesos directos e integridad.
- **Aplicación / Juego**: Entidad lógica del catálogo que posee metadatos descriptivos, soporte multiplataforma e histórico de entregas.
- **Versión / Entrega (`Release`)**: Hito numerado bajo versionado semántico formal (`vX.Y.Z`) que incluye paquetes binarios, notas de versión y deltas opcionales.
- **Parche diferencial (`Delta`)**: Paquete binario generado mediante HDiffPatch que contiene exclusivamente la diferencia entre una versión base previa y la versión objetivo actual.
- **Descarga completa**: Paquete `.zip` integral requerido en la primera instalación, en instalaciones limpias o ante indisponibilidad de deltas válidos.
- **Instalación limpia**: Procedimiento de borrado y despliegue íntegro del paquete que se ejecuta obligatoriamente al retroceder a una versión anterior o ante versiones huérfanas, asegurando el aislamiento y restauración de los datos de usuario.
- **Degradación (`Downgrade`)**: Proceso de instalar una versión histórica anterior a la que está actualmente instalada. Está terminantemente prohibido aplicarlo sobre la instalación activa mediante deltas; requiere siempre una instalación limpia.
- **Anomalía de versión**: Condición anómala detectada cuando la versión registrada localmente no existe en el catálogo activo (versión huérfana).
- **Rutas protegidas / Datos de usuario**: Patrones de archivos y carpetas (`saves/**`, `config.ini`) definidos en `protected_user_paths` que deben ser resguardados y reincorporados sin alteración durante cualquier reemplazo de archivos.
- **Motor de parches (`hpatchz`)**: Componente binario externo desacoplado que HakkinLauncher descarga y aprovisiona autónomamente para procesar parches diferenciales.
- **Bandeja del sistema**: Servicio de integración de sistema operativo que mantiene la aplicación minimizada y activa para el sondeo en segundo plano sin estorbar al usuario.
- **Autoactualización**: Proceso de sustitución del propio ejecutable de HakkinLauncher gestionado mediante scripts desacoplados (`update_helper.sh` / `update_helper.bat`).

---

### 2.4. Prohibición de Símbolos Embebidos en Cadenas
Está **estrictamente prohibido** incrustar caracteres de formateo visual, viñetas, flechas, numerales decorativos o símbolos (`+`, `-`, `#`, `➔`, `•`, etc.) directamente dentro de las constantes de texto.

- **Justificación**: Las señales visuales, iconos de acción y separadores son responsabilidad exclusiva de los componentes gráficos de Flutter (`Icon`, `Chip`, `StatusBadge`, `Row`, `ListTile`). Incrustar glifos en las cadenas rompe la accesibilidad, arruina la estandarización y dificulta la localización.
- **Ejemplos de corrección**:
  - *Antes*: `'+ Instalar'` $\rightarrow$ *Ahora*: `'Instalar'`
  - *Antes*: `'Juego #1'` $\rightarrow$ *Ahora*: `'Juego 1'`
  - *Antes*: `'(v1.0 ➔ v1.2)'` $\rightarrow$ *Ahora*: `'de versión 1.0 a versión 1.2'`
  - *Antes*: `'• Comprobando estado...'` $\rightarrow$ *Ahora*: `'Comprobando estado...'`
  - *Antes*: `'[ACTUALIZAR]'` $\rightarrow$ *Ahora*: `'ACTUALIZAR'` *(el contenedor visual provee el marco y borde)*

---

### 2.5. Concisión y Eliminación de Paréntesis y Explicaciones Embebidas
Todas las cadenas de la aplicación deben ser concisas, precisas, elegantes y directas. Se prohíbe el uso de paréntesis explicativos innecesarios `(...)` y de instrucciones sobre-específicas o redundantes embebidas en los textos.

- **Eliminación de Paréntesis Innecesarios**:
  - *Antes*: `'Actualizar (completa)'` $\rightarrow$ *Ahora*: `'Actualizar completa'`
  - *Antes*: `'Directorio de instalación (ruta local)'` $\rightarrow$ *Ahora*: `'Directorio de instalación'`
  - *Antes*: `'Limpiar archivos temporales (caché)'` $\rightarrow$ *Ahora*: `'Limpiar archivos temporales'`
  - *Antes*: `'Parche diferencial (HDiffPatch)'` $\rightarrow$ *Ahora*: `'Parche diferencial'`
  - *Antes*: `'Verificar integridad (SHA-256)'` $\rightarrow$ *Ahora*: `'Verificar integridad'`

- **Eliminación de Redundancias y Explicaciones Verbosas**:
  - *Antes*: `'Descarga y descomprime el paquete completo de la aplicación desde el servidor remoto sin usar parches.'` $\rightarrow$ *Ahora*: `'Descarga el paquete completo de la aplicación.'`
  - *Antes*: `'La versión actualmente instalada en tu equipo es v1.0.0 pero existe una más nueva disponible.'` $\rightarrow$ *Ahora*: `'Actualización v1.1.0 disponible.'`
  - *Antes*: `'Pulsa este botón para iniciar el juego en una ventana separada desacoplada del lanzador.'` $\rightarrow$ *Ahora*: `'Jugar'`

---

## 3. Patrones de Implementación en Código Dart

### 3.1. Constantes Estáticas vs. Métodos Parametrizados
1. **Cadenas Fijas (`static const String`)**:
   Se declaran como constantes en tiempo de compilación con identificadores descriptivos en `camelCase`:
   ```dart
   static const install = 'Instalar';
   static const cleanTemporaryFiles = 'Limpiar Archivos Temporales';
   ```

2. **Cadenas Dinámicas con Parámetros (`static String metodo(...)`)**:
   Cuando una cadena requiere interpolar valores dinámicos (versiones, títulos, porcentajes, rutas, errores), se define obligatoriamente como un método estático con tipado estricto:
   ```dart
   static String installVersion(String version) => 'Instalar v$version';
   static String cleanInstallWarningMessage(String current, String target) =>
       'Tienes instalada la versión v$current.\n\n'
       'Para cambiar a la versión anterior, v$target, se realizará una instalación limpia desde cero.\n\n'
       'Tus datos de usuario y partidas guardadas permanecerán protegidos.\n\n'
       '¿Deseas proceder?';
   ```

### 3.2. Importación y Consumo en la Capa de Presentación y Servicios
Todo widget, repositorio, controlador o servicio debe importar la fuente canónica correspondiente:
```dart
import 'package:hakkin_launcher/core/constants/app_strings.dart';
import 'package:hakkin_launcher/core/constants/app_technical_strings.dart';
import 'package:hakkin_launcher/core/constants/app_constants.dart';
```

Bajo ningún concepto se admiten cadenas literales en llamadas a:
- `Text(AppStrings.myLibraryTitle)`
- `HakkinButton(label: AppStrings.play)`
- `throw FileSystemException(AppStrings.fileDoesNotExist, path)`
- `debugPrint(AppStrings.logHpatchzReady(path))`
- `context.go(AppTechnicalStrings.routeSettings)`

---

## 4. Normas de Integridad y Verificación Continua

1. **Revisión en Flujo de Trabajo / Pair Programming**:
   - Todo nuevo texto requerido por una funcionalidad o corrección debe agregarse primero a `AppStrings` o `AppTechnicalStrings`.
   - Se prohíbe introducir cadenas literales como soluciones temporales.
2. **Validación con Analizador Estático**:
   - Todo cambio debe superar sin excepciones la verificación estática:
     ```bash
     flutter analyze
     ```
3. **Auditoría de Cadenas Literales**:
   - El equipo y los agentes de IA verificarán periódicamente mediante búsqueda de patrones que no existan cadenas literales desatendidas en la capa `lib/`.
