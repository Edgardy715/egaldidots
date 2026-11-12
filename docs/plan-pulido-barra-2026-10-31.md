# Plan: pulido de la barra (2026-10-31)

Origen: tras alinear la barra (centro común, botón de cuadrícula 38, aro del chip,
brillo del agua rebajado), el usuario pidió dejar preparados los siguientes pasos
para hacerlos otros días. Cada fase es independiente; el orden es el recomendado.

Estado de partida (ver TASK_STATE.md, entradas del 2026-10-31):
- Todos los módulos de la barra no compacta comparten centro (y≈27 px en DP-1).
- body.frag con lens 0.38, especular 0.42× edge^6, barrido 0.07.
- Avatar con anillo de acento 0.38.

Validación común a todas las fases:
- `ISLA_CONFIG` temporal + `QT_QPA_PLATFORM=offscreen` para las regresiones citadas.
- Offscreen no es QA visual: captura en vivo con `grim -o DP-1` y recorte ampliado de
  la franja superior (0–56 px) en tres zonas: izquierda, centro y derecha.
- `top-workspace-motion-regression` ya fallaba antes («retarget must settle at
  workspace 2»); no confundirlo con una regresión nueva.

---

## Fase 1 · Nitidez de píxel (≈30 min, prioridad alta)

Problema: centros medidos en medios píxeles (26.5). Los bordes de 1 px caen entre
dos filas y se ven borrosos.

Hacer:
1. Medir en vivo el borde superior/inferior de cada módulo (rail, botón, isla,
   gota del chip, estado, avatar) y anotar qué queda en x.5.
2. Redondear posición y tamaño a píxel entero en: `TopBarModules.qml` (topMargin),
   `TopWorkspaceRail.qml` (y de la píldora interior, verticalCenter del botón),
   `IslandOverlay.qml` (topMargin de la pill), `FluidCompanion.qml` (bodyY/yPos de la gota).
   Usar `Math.round(... )` sólo en posiciones de reposo; nunca en valores animados
   (romperían la suavidad del resorte).
3. Revisar que `PillBody` pase `pillCy` entero en reposo (`liveHeight / 2` con altura impar).

Aceptación: en la captura ampliada, los bordes superior e inferior de cada módulo
son una fila nítida, no dos filas a media intensidad. Regresiones: compact-island,
absorption, companion-continuity, water-drop, workspace-width.

## Fase 2 · Un solo material (≈2–3 h, prioridad alta)

Problema: conviven cristal mate lateral (`PillMaterial` mode "lateral"), agua del
shader, degradado de acento del botón de cuadrícula y anillo del avatar.

Hacer:
1. Fijar tokens comunes en `Theme`/`Settings.js`: relleno, línea de borde
   (hairline), reflejo superior y sombra. Los mismos valores que el agua en reposo.
2. `PillMaterial` lateral: aplicar esos tokens (reflejo superior suave como
   `pillMaterialDepthLight`, borde igual al rim del agua en reposo).
3. Botón de cuadrícula (`TopWorkspaceRail.qml` navButton): quitar el degradado de
   acento en reposo; dejarlo sólo en hover.
4. Avatar (`TopUserStatus.qml`): el anillo pasa a hairline neutra; acento sólo en hover/foco.
5. No cambiar el modo compacto ni el centro sin captura comparativa.

Aceptación: en captura, izquierda, centro y derecha parecen el mismo objeto; el
centro sólo se distingue por su movimiento. Regresiones: compact-island,
module-composer, optional-modules, workspace-styles, neon.

## Fase 3 · Un solo acento en reposo (≈45 min, prioridad alta, junto a la 2)

Regla: con música, color de portada (`MediaPalette.accent`) sólo en lo musical;
sin música, Matugen (`Theme.accent`); todo lo demás neutro.

Hacer:
1. Inventariar acentos visibles en reposo: orbe activo del rail (azul claro),
   icono naranja de la bandeja, anillo del avatar, aro y visualizador del chip.
2. Orbe activo del rail: bajar saturación/luminosidad para que no compita.
3. Iconos de bandeja: respetar su color propio pero sin halo ni fondo de acento.

Aceptación: en una captura en reposo con música sólo destaca un color.
Regresiones: media-palette, workspace-styles, neon.

## Fase 4 · Reposo quieto (≈30–60 min + QA visual)

Regla Apple-like: calma total en reposo; movimiento sólo ante eventos con significado
(cambio de canción, notificación, hover, apertura).

Hacer:
1. Revisar animaciones perpetuas: respiración del cuerpo (`BodyEngine.breathe`,
   timers de BodyEngine.qml ~186/192), barrido de luz (`sweep` en body.frag,
   `materialSweep` en PillMaterial), pulsos del visualizador sin audio.
2. Decidir con el usuario si la respiración queda (más lenta/menor) o se apaga en reposo.
3. Medir que en reposo la shell no pide frames (cacheWhenStill debe quedar activo).

Aceptación: tras 10 s sin interacción ni cambios, nada se mueve salvo el reloj
y el visualizador si hay música. Regresiones: water-drop, water-decor, absorption.

## Fase 5 · Laterales con el mismo lenguaje de movimiento (≈medio día)

Hacer:
1. Pulsación: compresión leve con el mismo resorte que el centro (`InteractionMotion`)
   en botón de cuadrícula, rail, estado y avatar.
2. Cambios de valor (volumen, batería, red): transición líquida en vez de salto.
3. Profundidad: al abrir una surface de la isla, los laterales retroceden un poco
   (opacidad ~0.85 o escala 0.98) y vuelven al cerrar; respetar reduceMotion.
4. Leer `.agents/skills/fluid-island-motion/SKILL.md` y `bar/fluid/MOTION_LANGUAGE.md`
   antes de diseñar; añadir prueba de interrupción (abrir/cerrar rápido).

Aceptación: sin saltos en interrupciones; reduceMotion lo desactiva todo.
Regresiones: optional-modules, top-workspace-motion (salvo el fallo previo),
companion-continuity, absorption.
