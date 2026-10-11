# Directivas de Proyecto: HakkinLauncher

Todas las intervenciones de código en este repositorio deben acatar rigurosamente las siguientes normativas:

1. **Arquitectura de Cadenas y Cero Cadenas Literales**:
   - Está **estrictamente prohibido** utilizar cadenas de texto literales (*hardcoded strings*) en todo el directorio `lib/`.
   - Todas las cadenas visibles para el usuario, notificaciones y logs humanos pertenecen a `AppStrings` (`lib/core/constants/app_strings.dart`).
   - Todas las constantes técnicas, rutas, comandos y claves pertenecen a `AppTechnicalStrings` (`lib/core/constants/app_technical_strings.dart`).
   - Las constantes transversales se exponen a través de `AppConstants` (`lib/core/constants/app_constants.dart`).
   - Puntuación y capitalización normativa:
     - **Capitalización de oración obligatoria**: Está prohibido el uso de *Title Case* (capitalizar palabras principales como si fueran siglas o nombres propios) en títulos, subtítulos, botones, etiquetas y opciones de menú. Solo llevan mayúscula la letra inicial de la cadena y los nombres propios o siglas reales (`HakkinLauncher`, `Windows`, `macOS`, `Linux`, `Android`, `iOS`, `3D`).
     - Los sustantivos comunes de secciones o carpetas (*tienda*, *biblioteca*, *escritorio*, *aplicaciones*, *sistema*) van en minúscula cuando se encuentran dentro de una frase (ej. `"Ir a la tienda"`, `"Ir a la página de la tienda"`, `"Crear acceso directo en el escritorio"`).
     - Frases, descripciones y notificaciones llevan punto final (`.`); botones, títulos y etiquetas nunca llevan punto final.
   - **Prohibición de desdoblamientos y redundancias**: Prohibido desdoblar términos equivalentes (*"juegos y software"*, *"programas y videojuegos"*, *"verificar o descargar"*, *"descargar y extraer"*, *"paquetes y binarios"*) o emplear pleonasmos (*"instalados localmente en este equipo"*).
   - **Opacidad técnica hacia el usuario**: Ninguna cadena de la interfaz debe describir procesos internos ni infraestructura del lanzador (*repositorio remoto*, *motor de parches*, *sondeo automático*, *paquetes y binarios*, *rotación de registros*, *integridad de archivos*, etc.). La interfaz debe centrarse exclusivamente en la utilidad funcional para el usuario.
   - Español profesional sin anglicismos no adaptados (*Tienda*, *Biblioteca*, *Lanzador*, *Juego*, *App*, *Herramienta*, etc.).
   - Prohibición de símbolos visuales embebidos (`+`, `•`, `#`, etc.).
   - Ver especificación completa en `docs/strings.md` y `.agents/rules/strings_architecture.md`.
