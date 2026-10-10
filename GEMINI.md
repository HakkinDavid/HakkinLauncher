# Directivas de Proyecto: HakkinLauncher

Todas las intervenciones de código en este repositorio deben acatar rigurosamente las siguientes normativas:

1. **Arquitectura de Cadenas y Cero Cadenas Literales**:
   - Está **estrictamente prohibido** utilizar cadenas de texto literales (*hardcoded strings*) en todo el directorio `lib/`.
   - Todas las cadenas visibles para el usuario, notificaciones y logs humanos pertenecen a `AppStrings` (`lib/core/constants/app_strings.dart`).
   - Todas las constantes técnicas, rutas, comandos y claves pertenecen a `AppTechnicalStrings` (`lib/core/constants/app_technical_strings.dart`).
   - Las constantes transversales se exponen a través de `AppConstants` (`lib/core/constants/app_constants.dart`).
   - Puntuación normativa: frases y notificaciones con punto final; botones, títulos y etiquetas sin punto final.
   - Español profesional técnico sin anglicismos no adaptados (*Tienda*, *Biblioteca*, *Lanzador*, *Parche diferencial*, *Instalación limpia*, *Autoactualización*, etc.).
   - Prohibición de símbolos visuales embebidos (`+`, `•`, `#`, etc.).
   - Ver especificación completa en `docs/strings.md` y `.agents/rules/strings_architecture.md`.
