# Azog · sistema de nombres

Decidido el 2026-11-06. Base para el README final y el vídeo de presentación.

## Idea

Azogue es el nombre antiguo del mercurio: un metal líquido cuyas gotas se
funden en una sola. Es lo que hace la pill con su gota y su cuello. Todos los
nombres salen de esa imagen (mercurio, alquimia, metal líquido) y van en inglés.

| Nombre | Qué es | Por qué |
|---|---|---|
| **Azog** | La shell completa | Raíz de *azogue*; corta y sin idioma |
| **Bead** | La pill (gota principal y compacta) | Una perla de mercurio |
| **Amalgam** | Motor de cuerpo líquido (`bar/body`) | Mercurio fundido con otro metal, como las gotas al unirse |
| **Crucible** | App de ajustes (antes Edots) | El recipiente donde se funde y afina el metal |
| **Cinnabar** | Selector de fondos y color de acento | Mineral rojo del que sale el mercurio; Matugen saca el color del fondo |

## Estado

- Textos visibles renombrados: commits `5dc702c` y `b29451f`.
- Pendiente de commit por mezclarse con trabajo ajeno sin publicar:
  `bar/i18n/en.js` (sin seguimiento) y el título Cinnabar de `WallpaperView.qml`.
- Sin renombrar a propósito: archivos, tipos QML (`EdotsWindow`, `IslaSwitch`),
  `objectName`, ids de notificación (`isla:updates`), variables de entorno
  (`ISLA_CONFIG`) y registros. Cambiarlos rompe tests y configuración existente;
  hacerlo en una fase propia si se quiere.

## Para la presentación final

- **README:** abrir con la idea del mercurio, luego la tabla de nombres con una
  captura o GIF por pieza (Bead fundiéndose, Amalgam reaccionando a música,
  Crucible, Cinnabar cambiando el acento).
- **Vídeo:** una gota de mercurio que se divide en las piezas y vuelve a
  fundirse en Bead; cada nombre aparece cuando su pieza se muestra.
