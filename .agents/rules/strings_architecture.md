# Regla de Arquitectura de Cadenas y Cero Cadenas Literales

## Ámbito y Obligatoriedad
Esta regla aplica a **todo el directorio `lib/`** y a cualquier generación o modificación de código Dart dentro de **HakkinLauncher**. Debe cumplirse de manera estricta y sin excepciones.

Referencia completa de especificación: `docs/strings.md`.

---

## 1. Regla Absoluta de Cero Cadenas Literales (`Zero Hardcoded Strings`)
Está **terminantemente prohibido** escribir cadenas de texto literales (*hardcoded strings*) dentro del directorio `lib/`.

Toda cadena debe obtenerse de:
1. **`AppStrings`** (`lib/core/constants/app_strings.dart`):
   - Todo texto legible por el usuario: títulos, botones, etiquetas, descripciones, distintivos (`badges`), cuadros de diálogo, notificaciones nativas, menús de bandeja (`tray`), estados de descarga y mensajes legibles de excepciones o logs (`debugPrint`).
2. **`AppTechnicalStrings`** (`lib/core/constants/app_technical_strings.dart`):
   - Toda constante técnica: rutas de GoRouter, claves SharedPreferences, claves JSON del catálogo, nombres de ejecutables (`hpatchz`, `hdiffz`), comandos shell (`unzip`, `ditto`, `taskkill`), banderas de procesos, extensiones de archivo y cabeceras HTTP.
3. **`AppConstants`** (`lib/core/constants/app_constants.dart`):
   - Fachada de constantes globales que delega directamente en `AppStrings` y `AppTechnicalStrings`.

Si se necesita un nuevo texto o constante técnica, **primero debe agregarse a `AppStrings` o `AppTechnicalStrings`** y luego referenciarse en el código.

---

## 2. Reglas Normativas de Formato y Puntuación

### 2.1 Puntuación y Capitalización
1. **Oraciones, Notificaciones, Descripciones y Mensajes**:
   - Deben comenzar siempre con mayúscula y **finalizar obligatoriamente con punto (`.`)**.
   - Ejemplo: `"Todas tus aplicaciones y el lanzador están en la versión más reciente."`
2. **Botones, Etiquetas, Títulos y Distintivos**:
   - Deben usar mayúscula inicial (o *Title Case*) y **nunca llevar punto final**.
   - Ejemplo: `"Instalar versión"`, `"En ejecución"`, `"Buscar actualizaciones"`

### 2.2 Español Profesional y Cero Anglicismos en la Interfaz
Se prohíbe el uso de anglicismos crudos en la interfaz de usuario. Utilizar exclusivamente la terminología estandarizada:
- *Store* $\rightarrow$ **Tienda**
- *Library* $\rightarrow$ **Biblioteca**
- *Launcher* (en UI/prosa genérica) $\rightarrow$ **Lanzador** (*HakkinLauncher* solo como marca)
- *Downgrade* $\rightarrow$ **Degradación / Instalación de versión anterior**
- *Delta / Patch* $\rightarrow$ **Parche diferencial / Parche**
- *Full download* $\rightarrow$ **Descarga completa**
- *Clean install* $\rightarrow$ **Instalación limpia**
- *Self-update* $\rightarrow$ **Autoactualización**
- *Background* $\rightarrow$ **Segundo plano**
- *Tray / System tray* $\rightarrow$ **Bandeja del sistema**
- *Shortcut* $\rightarrow$ **Acceso directo**
- *Badge* $\rightarrow$ **Distintivo**
- *Settings* $\rightarrow$ **Configuración / Ajustes**
- *Changelog* $\rightarrow$ **Notas de la versión**
- *Savegames / Saves* $\rightarrow$ **Partidas guardadas**
- *User data* $\rightarrow$ **Datos de usuario**
- *Screenshot* $\rightarrow$ **Captura de pantalla**
- *Fallback* $\rightarrow$ **Alternativa de respaldo**
- *Running* $\rightarrow$ **En ejecución**

### 2.3 Prohibición de Símbolos Visuales Embebidos
No incrustar viñetas, flechas, numerales ni caracteres decorativos (`+`, `-`, `#`, `➔`, `•`, etc.) en las cadenas. Los indicadores visuales pertenecen a los widgets de Flutter (`Icon`, `StatusBadge`, `Row`), no al texto.
- Incorrecto: `'+ Instalar'`, `'• Descargando'`
- Correcto: `'Instalar'`, `'Descargando...'`

### 2.4 Concisión y Eliminación de Paréntesis
Evitar paréntesis explicativos innecesarios y textos redundantes. Las cadenas deben ser directas y precisas.
- Incorrecto: `'Limpiar archivos temporales (caché)'`
- Correcto: `'Limpiar archivos temporales'`

### 2.5 Extensión Normativa de Formato para el Catálogo (`catalog.json`)
El catálogo es una fuente de datos dinámica externa; por tanto:
- **No aplica la regla de *zero hardcoded strings* del código Dart**: Sus cadenas no se trasladan a `AppStrings`.
- **Aplica estrictamente toda la normativa de formato**:
  1. `title`: Title Case, **sin punto final**, sin emojis ni símbolos decorativos.
  2. `summary`: Una o dos oraciones en español técnico con **punto final obligatorio (`.`)**, sin anglicismos.
  3. `description_markdown`: Markdown semántico 100% en español (prohibido inglés residual). Encabezados sin punto final. Párrafos y viñetas (`- **Nombre**: Descripción.`) con **punto final obligatorio (`.`)**.
  4. `changelog`: Resumen legible y formal en español con **punto final (`.`)**. Prohibidos volcados de Git (`Merge branch`, `Update release.yaml`), enlaces (`**Full Changelog**`), tablas Markdown con hashes truncados y notas informales (`meow`).
  5. `tags`: Title Case, **sin punto final**, en español técnico o siglas universales (*3D*, *macOS*, etc.).
  6. `developer`: Nombre institucional o de autor, **sin punto final**.

