# Isla: sistema visual existente

## Overview

Sobriedad, lectura y continuidad. Referencia Apple-like adaptada al escritorio
Linux y a la identidad Fluid Island existente. La autoridad ejecutable reside
en Theme.qml, Motion.qml y bar/fluid/MOTION_LANGUAGE.md; este documento describe
su aplicación, sin duplicar valores de configuración.

## Colors

La paleta deriva de IslaPalette/pywal; no fijar los colores de una captura.
Theme.foreground para contenido principal, Theme.iconSecondary para lectura
secundaria. Theme.dim no garantiza contraste suficiente para texto pequeño.
Theme.accent identifica selección, foco y acciones; los materiales permanecen
neutros. El color de texto sobre un badge claro usa Theme.background.

## Typography

Familias y escalas configurables desde Theme/Config. Títulos compartidos:
fontSizeTitleLg y DemiBold; cuerpo y ayudas usan los tokens existentes.
Cabeceras y contenido largo deben tener límites, elipsis o wrap deliberado.
No imponer una fuente nueva ni depender de un tamaño fijo de contenido.

## Layout

Reutilizar SurfaceHeader, FooterButton, HintKbd y primitivas MotionArea.
Cabeceras separan título, contexto y controles; listas acotadas se desplazan.
La geometría pertenece a los modelos compartidos, no a cálculos duplicados
dentro de las superficies. Escala visual y escala de fuente pueden diferir.

## Shapes

Pill compacta, superficies expandidas y companions continúan la geometría del
motor existente. Radios, espacios y bordes salen de Theme. Evitar contornos
concéntricos decorativos y costuras entre formas que se unen.

## Components

El material compacto conserva glassAlpha. Al crecer protege lectura con mayor
opacidad, reduce halo/sheen y usa una sola definición de borde más sombra.
SurfaceHeader recibe entered desde composición; no sobrescribe esa propiedad.
Los controles conservan hover/pulsación/foco y nombres accesibles pertinentes.
Tab recorre controles de overview/fondos; flechas exploran su contenido.
Las búsquedas sin coincidencias tienen feedback después del debounce.

## Motion

Aplicar MOTION_LANGUAGE.md y el motor Fluid existente: continuidad, origen
coherente, retarget interrumpible y descarga después de cierre. Evitar un motor
paralelo por superficie. reduceMotion resuelve directamente y se valida en
Wayland; capturas irregulares no prueban FPS ni todos los fotogramas.

La revisión del 2026-10-08 y sus límites están en docs/PILL_INTERFACE_AUDIT.md.
