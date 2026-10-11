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

### 2.1. Puntuación y Capitalización de Oración en Español Estándar

1. **Prohibición Absoluta de *Title Case* Anglosajón**:
   En español estándar únicamente se escribe con mayúscula inicial la primera palabra de un texto, título, subtítulo, etiqueta o botón, además de los nombres propios y siglas reales (`HakkinLauncher`, `Windows`, `macOS`, `Linux`, `Android`, `iOS`, `3D`).
   - Está **estrictamente prohibido** capitalizar sustantivos y adjetivos intermedios como si fueran siglas (*Title Case*).
   - Los sustantivos comunes que designan vistas, secciones o carpetas del sistema (*tienda*, *biblioteca*, *configuración*, *escritorio*, *aplicaciones*, *sistema*) deben escribirse **siempre con minúscula inicial** cuando forman parte de una frase u oración.
   - *Correcto*: `"Mi biblioteca"`, `"Detalles de la aplicación"`, `"Ruta de instalación"`, `"Ir a la tienda"`, `"Ir a la página de la tienda"`, `"Crear acceso directo en el escritorio"`, `"Buscar actualizaciones"`
   - *Incorrecto*: `"Mi Biblioteca"`, `"Detalles Técnicos"`, `"Ruta de Instalación de Juegos y Software"`, `"Ir a la Tienda"`, `"Crear acceso directo en el Escritorio"`, `"Buscar Actualizaciones"`

2. **Mensajes, Descripciones, Avisos y Notificaciones**:
   Toda oración completa, descripción de sección, cuerpo de cuadro de diálogo, mensaje explicativo, notificación nativa o registro de aviso debe comenzar con mayúscula inicial, mantener capitalización normal de oración y finalizar obligatoriamente con un punto (`.`).
   - *Correcto*: `"Todas tus aplicaciones y el lanzador están en la versión más reciente."`
   - *Incorrecto*: `"Todas tus aplicaciones y el lanzador están en la versión más reciente"`
   - *Correcto*: `"Se eliminaron los archivos temporales."`
   - *Incorrecto*: `"se eliminaron los archivos temporales"`
   - *Correcto*: `"Carpeta para las aplicaciones."`
   - *Incorrecto*: `"Carpeta para las aplicaciones"`

3. **Etiquetas, Botones, Títulos y Distintivos**:
   Los títulos de sección, nombres de pantallas, etiquetas de botones, elementos de menú, nombres de campos y distintivos de estado utilizan **exclusivamente capitalización de oración** (mayúscula solo en la primera letra y nombres propios) y **nunca** llevan punto final.
   - *Correcto*: `"Guardar cambios"`, `"Buscar actualizaciones"`, `"Instalación limpia"`, `"Biblioteca"`, `"En ejecución"`, `"Sistema"`
   - *Incorrecto*: `"Guardar cambios."`, `"buscar actualizaciones"`, `"Instalación Limpia"`, `"Segundo Plano y Actualizaciones"`

---

### 2.2. Español Profesional y Eliminación de Anglicismos
Todas las cadenas visibles del sistema se expresan en un español claro, natural y depurado. Se prohíbe el uso de anglicismos crudos o no adaptados en la interfaz de usuario, incluyendo las categorías del catálogo:

| Anglicismo no permitido | Término estandarizado en HakkinLauncher | Justificación y Ámbito |
| :--- | :--- | :--- |
| *Store* | **Tienda** | Vista de descubrimiento y catálogo. |
| *Library* | **Biblioteca** | Módulo de aplicaciones instaladas. |
| *Launcher* (en UI/prosa) | **Lanzador** | Se reserva la palabra *HakkinLauncher* únicamente como nombre propio de marca. En explicaciones o etiquetas genéricas se usa *lanzador*. |
| *game / app / tool* (categorías) | **Juego / App / Herramienta** | Categorías visibles en tarjetas, filtros y fichas de la tienda. |
| *Downgrade* | **Instalación de versión anterior** | Reemplazo deliberado de una versión superior por una inferior. |
| *Clean install* | **Instalación limpia** | Proceso de instalación desde cero preservando datos de usuario. |
| *Self-update* | **Actualización del lanzador** | Mecanismo de actualización autónoma del cliente. |
| *Tray / System Tray* | **Bandeja del sistema** | Área de notificaciones del sistema operativo. |
| *Shortcut* | **Acceso directo** | Enlace en el escritorio o menú de aplicaciones del sistema. |
| *Badge* | **Distintivo** | Indicador visual de estado (`INSTALADO`, `ACTUALIZAR`, etc.). |
| *Settings* | **Configuración / Ajustes** | Panel de preferencias del usuario. |
| *Changelog / Release notes* | **Notas de la versión** | Lista de cambios de una versión. |
| *Savegame / Saves* | **Partidas guardadas** | Archivos de progreso del usuario. |
| *User data* | **Datos de usuario** | Configuraciones y archivos del usuario preservados entre versiones. |
| *Screenshot* | **Captura de pantalla** | Imágenes ilustrativas en la galería de la ficha. |
| *Running* | **En ejecución** | Estado de una aplicación activa. |

---

### 2.3. Prohibición de Desdoblamientos y Redundancias Léxicas
El lenguaje de la interfaz debe ser directo, económico y libre de desdoblamientos artificiales o pleonasmos:

1. **Cero Desdoblamientos**:
   Está prohibido duplicar sustantivos o verbos equivalentes cuando un único concepto general abarca la acción o entidad:
   - *Incorrecto*: `"Ruta de instalación de juegos y software"` $\rightarrow$ *Correcto*: `"Ruta de instalación"`
   - *Incorrecto*: `"Programas y videojuegos"` $\rightarrow$ *Correcto*: `"Aplicaciones"`
   - *Incorrecto*: `"Buscar videojuegos o herramientas..."` $\rightarrow$ *Correcto*: `"Buscar en el catálogo..."`
   - *Incorrecto*: `"Carpeta del sistema operativo donde se descargarán y extraerán los paquetes y binarios."` $\rightarrow$ *Correcto*: `"Carpeta para las aplicaciones."`
   - *Incorrecto*: `"Error en la descarga o instalación"` $\rightarrow$ *Correcto*: `"Error de instalación"`

2. **Cero Redundancias y Pleonasmos Contextuales**:
   No se deben repetir condiciones implícitas en el contexto de la pantalla ni pleonasmos espaciales:
   - *Incorrecto*: `"Programas y videojuegos instalados localmente en este equipo."` (en la Biblioteca ya todo está instalado, y *"este equipo"* siempre es local).
   - *Correcto*: `"Tus aplicaciones listas para abrir."`

---

### 2.4. Opacidad Técnica (Principio de Caja Negra hacia el Usuario)
La interfaz de usuario **jamás debe desnudar el proceso interno de la aplicación**. El usuario no tiene por qué enterarse de la arquitectura interna, protocolos, herramientas auxiliares ni operaciones de bajo nivel del lanzador:

1. **Ocultación de Infraestructura y Procesos Internos**:
   - Está **prohibido** mencionar en textos visibles para el usuario conceptos internos como: *repositorio remoto*, *motor de parches*, *hpatchz*, *sondeo automático*, *paquetes y binarios*, *extracción de paquetes*, *rotación de registros*, *suma de verificación*, *hash SHA-256*, *scripts pre/post-instalación*, *ejecutable relativo*, *punto de entrada* o *soporte diferencial*.
2. **Orientación Funcional en Configuración y Acciones**:
   - Las secciones y descripciones deben nombrarse por su propósito funcional para el usuario, no por su mecanismo técnico:
     - Usar **`"Sistema"`** en lugar de `"Segundo plano y actualizaciones"`.
     - Explicar qué sucede funcionalmente para el usuario (ej. `"Mantener activo al cerrar la ventana"` / `"Permite recibir avisos de nuevas versiones disponibles."`) en lugar de hablar de *"bandeja del sistema y sondeo automático"*.
   - Las acciones deben reflejar con honestidad lo que hacen para el usuario:
     - En la Biblioteca, usar **`"Ir a la página de la tienda"`** en lugar de `"Gestionar versiones"`.
   - No exponer botones ni opciones de diagnóstico interno que no competen al usuario (como *"Verificar o descargar motor de parches"* o *"Verificar integridad de archivos"*).

---

### 2.5. Prohibición de Símbolos Embebidos en Cadenas
Está **estrictamente prohibido** incrustar caracteres de formateo visual, viñetas, flechas, numerales decorativos o símbolos (`+`, `-`, `#`, `➔`, `•`, etc.) directamente dentro de las constantes de texto.

- **Justificación**: Las señales visuales, iconos de acción y separadores son responsabilidad exclusiva de los componentes gráficos de Flutter (`Icon`, `Chip`, `StatusBadge`, `Row`, `ListTile`). Incrustar glifos en las cadenas rompe la accesibilidad, arruina la estandarización y dificulta la localización.
- **Ejemplos de corrección**:
   - *Antes*: `'+ Instalar'` $\rightarrow$ *Ahora*: `'Instalar'`
   - *Antes*: `'Juego #1'` $\rightarrow$ *Ahora*: `'Juego 1'`
   - *Antes*: `'(v1.0 ➔ v1.2)'` $\rightarrow$ *Ahora*: `'de versión 1.0 a versión 1.2'`
   - *Antes*: `'• Comprobando estado...'` $\rightarrow$ *Ahora*: `'Preparando...'`
   - *Antes*: `'[ACTUALIZAR]'` $\rightarrow$ *Ahora*: `'ACTUALIZAR'` *(el contenedor visual provee el marco y borde)*

---

### 2.6. Concisión y Eliminación de Paréntesis y Explicaciones Embebidas
Todas las cadenas de la aplicación deben ser concisas, precisas, elegantes y directas. Se prohíbe el uso de paréntesis explicativos innecesarios `(...)` y de instrucciones sobre-específicas o redundantes embebidas en los textos.

- **Eliminación de Paréntesis Innecesarios**:
  - *Antes*: `'Actualizar (completa)'` $\rightarrow$ *Ahora*: `'Actualizar completa'`
  - *Antes*: `'Directorio de instalación (ruta local)'` $\rightarrow$ *Ahora*: `'Carpeta de instalación'`
  - *Antes*: `'Limpiar archivos temporales (caché)'` $\rightarrow$ *Ahora*: `'Limpiar archivos temporales'`

- **Eliminación de Redundancias y Explicaciones Verbosas**:
  - *Antes*: `'Carpeta del sistema operativo donde se descargarán y extraerán los paquetes y binarios.'` $\rightarrow$ *Ahora*: `'Carpeta para las aplicaciones.'`
  - *Antes*: `'La versión actualmente instalada en tu equipo es v1.0.0 pero existe una más nueva disponible.'` $\rightarrow$ *Ahora*: `'Actualización v1.1.0 disponible.'`
  - *Antes*: `'Pulsa este botón para iniciar el juego en una ventana separada desacoplada del lanzador.'` $\rightarrow$ *Ahora*: `'Jugar'`

---

### 2.7. Extensión Normativa de Formato para el Catálogo (`catalog.json`)

#### 2.7.1. Ámbito de Aplicación: Formato vs. Cero Cadenas Literales (*Hardcoding*)
El catálogo (`docs/catalog.json`) y sus manifiestos remotos constituyen fuentes de datos dinámicas externas consumidas por el cliente en tiempo de ejecución. Por su naturaleza desacoplada del código fuente del lanzador:
- **No aplica la regla de *zero hardcoded strings* del código Dart**: Las cadenas textuales de los títulos, descripciones y notas de versión no se trasladan a constantes dentro de `lib/core/constants/app_strings.dart` (hacerlo acoplaría datos dinámicos como código estático compilado).
- **Aplica estrictamente toda la normativa de formato y estilo**: Todas las cadenas legibles por el usuario dentro del catálogo (`title`, `summary`, `description_markdown`, `changelog`, `tags`, `developer`) deben cumplir rigurosamente las reglas de puntuación, capitalización de oración, español profesional, concisión y prohibición de símbolos visuales embebidos.

#### 2.7.2. Reglas Específicas por Atributo del Catálogo

1. **Título de la Aplicación (`title`)**:
   - **Capitalización**: Nombre propio de la obra, sin punto final.
   - **Símbolos**: Prohibido el uso de emojis, numerales decorativos o símbolos (`#`, `+`, `•`, etc.).
   - *Correcto*: `"Tecate Simulator"`, `"Platinum World Management System"`, `"CAT Helper"`
   - *Incorrecto*: `"Tecate Simulator."`, `"Juego #1: Tecate"`

2. **Resumen de Tarjeta (`summary`)**:
   - **Estructura**: Una o dos oraciones completas, gramaticalmente depuradas y directas que definan el propósito primordial de la aplicación.
   - **Puntuación**: Comienza obligatoriamente con mayúscula, sigue capitalización normal de oración y **finaliza siempre con punto (`.`)**.
   - **Español Profesional**: Sin anglicismos crudos ni términos no adaptados.
   - *Correcto*: `"Simulación y renderizado 3D de rayos y arcos eléctricos siguiendo trayectorias de menor resistencia y autosimilitud fractal."`
   - *Incorrecto*: `"Simulación 3D de rayos y arcos eléctricos"` *(sin punto final)*

3. **Descripción Detallada en Markdown (`description_markdown`)**:
   - **Estructura Semántica**: Estructura Markdown clara y profesional.
   - **Encabezados (`#`, `##`, `###`)**: Capitalización de oración (solo mayúscula inicial y nombres propios) y **estrictamente sin punto final**.
   - **Párrafos de Prosa**: Oraciones completas que inician con mayúscula y **concluyen con punto final (`.`)**.
   - **Listas de Características (`- **Nombre de característica**: Descripción.` )**:
     - Cada elemento de lista debe contar con un título destacado en negrita con **capitalización de oración** (sin *Title Case*) y sin punto previo a los dos puntos (`- **Soporte multiplataforma**:`).
     - La explicación posterior a los dos puntos debe comenzar con mayúscula y **finalizar obligatoriamente con punto (`.`)**.
   - **Español Profesional Integral (Prohibición de Inglés Residual)**: Queda terminantemente prohibido incorporar párrafos, introducciones o fragmentos en inglés importados directamente desde repositorios externos. Todo texto descriptivo debe redactarse en español profesional.

4. **Notas de la Versión (`changelog`)**:
   - **Propósito**: Comunicar con claridad los cambios de cada entrega histórica para el usuario final.
   - **Puntuación**: Toda nota o elemento descriptivo debe comenzar con mayúscula, usar capitalización de oración y **finalizar obligatoriamente con punto final (`.`)**.
   - **Prohibición Absoluta de Residuos de Git o GitHub**:
     - **Prohibido el volcado directo de mensajes de commits**: Cadenas crudas como `"- Merge branch 'master' into stable"`, `"- Update release.yaml"`, `"- versionado visible"` o historiales no curados de Git están prohibidos. Deben sintetizarse en notas descriptivas redactadas formalmente.
     - **Prohibidos enlaces de comparación de Git**: Cadenas como `"**Full Changelog**: https://github.com/..."` deben reemplazarse por la síntesis en español de los cambios introducidos.
     - **Prohibidas tablas Markdown crudas de GitHub Releases**: Tablas de descargas con códigos criptográficos SHA-256 truncados (`a5ff201a1cfc...`) o enlaces markdown dentro de la nota deben reemplazarse por una descripción textual limpia de la entrega.
     - **Prohibidas notas informales, bromas o cadenas vacías**: Textos como `"meow"`, `"meow 2"`, `"test"` o cadenas de depuración deben sustituirse por notas formales de entrega.
   - *Correcto*: `"Lanzamiento de Tecate Simulator versión 26.10.08-13 con soporte optimizado para Windows y macOS."`
   - *Incorrecto*: `"**Full Changelog**: https://github.com/Bonsanbec/tecate-simulator/commits/latest"`

5. **Etiquetas Temáticas (`tags`)**:
   - **Formato**: Cada etiqueta se redacta con capitalización de oración (mayúscula solo en la primera palabra y nombres propios).
   - **Puntuación**: **Nunca llevan punto final**.
   - **Estandarización Lingüística**: Se redactan en español (*Simulación*, *Mundo abierto*, *Ciencia*, *Física*, *Educación*, *Herramienta*, *Juego*, *Solidaridad*, *Emergencias*, *Atención médica*), salvo siglas o nombres propios universales (*3D*, *Drift*, *SQLite*, *macOS*, *Android*, *Windows*, *AutoHotkey*, *HID*).
   - *Correcto*: `["Simulación", "Física", "Electricidad", "Fractales", "Ciencia", "3D"]`
   - *Incorrecto*: `["Simulation.", "3d", "game", "Mundo Abierto"]`

6. **Desarrollador (`developer`)**:
   - **Formato**: Nombre propio o institucional del autor u organización responsable.
   - **Puntuación**: **Sin punto final**.

---

## 3. Patrones de Implementación en Código Dart

### 3.1. Constantes Estáticas vs. Métodos Parametrizados
1. **Cadenas Fijas (`static const String`)**:
   Se declaran como constantes en tiempo de compilación con identificadores descriptivos en `camelCase` y capitalización de oración:
   ```dart
   static const install = 'Instalar';
   static const cleanTemporaryFiles = 'Limpiar archivos temporales';
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
