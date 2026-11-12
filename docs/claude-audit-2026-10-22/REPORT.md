# Auditoría Claude · animaciones, transiciones y bugs (2026-10-22)

Alcance: shell actual con trabajo local ajeno sin commitear (pets, settings,
media…), que se conservó intacto. Etiquetas: **verificado** (fixture, A/B o
captura), **probable** (código, sin reproducir), **no verificable aquí**.

## 1. Mapa

- `shell.qml` → `Variants` sobre pantallas: `IslandReserve` + `IslandOverlay`
  (PanelWindow Overlay, máscara hidden/full/pill vía `OverlayInputPolicy`).
  IPC `island` enruta todo a `SurfaceRouter`.
- `SurfaceRouter`: `openMon/openSurface`, `peekMon`, dock de media
  (`mediaDockPending*` → `finishMediaDock` cuando la gota llega a idle) y cierre
  del launcher en dos fases con timers.
- `IslandOverlay` compone `TopBarModules`, `Pill`, gotas `FluidRecordingCompanion`
  (izq.), `FluidCompanion` session (izq.) y settings (centro, async retenido),
  `FluidMediaCompanion` (der.) y `BarLayoutTransition` (split/compact).
- `Pill`: `PillGeometry` (destinos) → `PillMorphMotion` (único dueño de
  ancho/alto/radio con SmoothedAnimation, `closeness`, `surfaceGrowth`,
  `contentProgress`, respiración) → `PillMaterial` (material único),
  `PillSurfaceHost` (Loader async, swap 140 ms, unload por `morphCloseness`),
  `NotificationChoreography` (máquina de timers), `IslandNotification`, OSD.
- Servicios (Players, Cava, Recording, Clipboard) se conectan desde composición;
  los componentes hoja reciben propiedades.

Puntos de la arquitectura que dificultan una buena animación:

- La exposición del contenido se deriva del cociente geométrico
  (`surfaceGrowth`), así que cualquier redimensionado de la surface abierta se
  interpreta como "aún creciendo". De ahí viene F1.
- Las gotas se posicionan con `body.x/body.y`, que no incluye transforms. Todo
  desplazamiento de la pill hay que replicarlo a mano en las gotas (F3).
- Hay duraciones repartidas entre timers del router, timers de coreografía y
  Behaviors locales con literales; cuesta garantizar "una sola animación por
  valor".

## 2. Hallazgos (por impacto)

### Bugs y casos límite

| # | Hallazgo | Evidencia | Estado |
|---|---|---|---|
| F1 | Al escribir en el launcher, el campo de búsqueda **desaparecía ~200 ms** mientras la pill crecía para los resultados. Pasa con cualquier cambio de tamaño de una surface abierta | `PillMorphMotion.qml` `surfaceGrowth` se mide contra el destino nuevo y cae a ~0.1, con lo que `contentProgress` llega a 0. Captura en vivo `qa/launcher-before-content-hold.jpg` (+24…+198 ms vacía) | **verificado**, corregido |
| F2 | Cerrar con un swap de surface pendiente devolvía `swapOpacity` a 1: la surface anterior reaparecía mientras la pill se contraía | `PillSurfaceHost.qml` rama `else` de `onSurfaceChanged`. Fixture A/B: opacidad 0.765 → 1.000 sin el fix | **verificado** en fixture, corregido. En vivo no se vio fantasma claro porque `reveal` cae a la vez (impacto real bajo) |
| F3 | Costura al entrar o salir de fullscreen: la pill se desliza y desvanece en 420 ms, pero las gotas (media, grabación, session, settings) cambiaban de opacidad de golpe y no se desplazaban. El desplazamiento además no respetaba reduceMotion | `IslandOverlay.qml` (antes: `opacity: monFullscreen ? 0 : 1` sin Behavior en las gotas). Fixture A/B: el original falla "share opacity/lift" | **verificado** en fixture, corregido. En vivo no se probó: requiere poner una ventana tuya en fullscreen |
| F4 | El hold de lectura de una notificación se escalaba con `Motion.mult`: con reduceMotion quedaba en ~420 ms en vez de 1500 ms, y `motionScale` también lo acortaba | `Singletons/Motion.qml` `notifHoldMin/Max` | **verificado** (fixture), corregido |
| F5 | IPC `peek` no tiene efecto visible: `peekMon` → `forcePinned` → `pinned`, que nada consume. `peek("")` tampoco resuelve el monitor enfocado | `SurfaceRouter.qml:134`, `Pill.qml:63`, `IslandOverlay.qml:420` | **verificado** por código. Propuesta P3 |
| F6 | `recording-drop-regression.qml` (TestCase de QtTest) termina con rc=0 **sin imprimir resultado**, también con el overlay original, así que aquí no sirve como evidencia | Ejecución A/B en Wayland | **no verificable aquí**. Lo cubre `fullscreen-hide-regression` nueva |

### Animación

| # | Hallazgo | Evidencia | Estado |
|---|---|---|---|
| A1 | La respiración de la notificación aparecía y desaparecía con saltos: borde de acento 0 → 0.20 al empezar el hold y de ~0.38 → 0 al iniciar collapse-out, y el radio saltaba 2·s. `breath` quedaba congelado al salir. `IslandNotification` añadía Behaviors de 300 ms (literales) encima de un valor ya animado | `PillMorphMotion.qml`, `PillMaterial.qml:193`, `IslandNotification.qml:23-66` | **verificado** (fixture: paso máximo de glow < 0.05/frame), corregido |
| A2 | Doble animación: la altura de la lista del launcher se deriva de la altura de la pill (ya animada) y además tenía su propio `Behavior` NumberAnimation de 420 ms. La lista iba por detrás de la masa y empujaba el hint fuera del borde | `LauncherView.qml` ListView | **verificado** por código y captura, corregido |
| A3 | Alturas internas (calculadora, divisor, hint del launcher; `ClipboardView:669`, `SessionView:180-200`, `SettingRow`) usan NumberAnimation con `morphCurve`. Al retargetear no conservan velocidad | Barrido | **probable**. Propuesta P1 |
| A4 | Duraciones literales fuera de los tokens: WallpaperView 900/850/1200, NotifCardView 1800, ConnectivityView 1000, MediaAmbient 420, MediaTimeline 750, IslandStudio 90/150, IslandCompanion parpadeo 70/150, AudioEndpoint 32 | Barrido | **probable** (no respetan motionScale). Propuesta P2 |
| A5 | El radio de la respiración se suma dos veces: en el destino de `PillGeometry` (suavizado) y en `PillMaterial.bodyRadius` (directo). Amplitud efectiva ≈4·s | `PillGeometry.qml:101`, `PillMaterial.qml:36` | **verificado** por código. Ahora es continuo; la amplitud no se cambió (es una cuestión de gusto) |

### Rendimiento

| # | Hallazgo | Estado |
|---|---|---|
| R1 | `layer.enabled` incondicional: `GlassCard:44`, `PillMaterial:55`, `TopWorkspaceRail:154`, `NotifCardView:75`, `FluidCompanion:330` | **probable**, sin medir. Condicionar a visible/animando requiere un profiler antes de tocarlo |
| R2 | Behaviors dentro de delegates (`AppItem:62,105`, `WorkspacesView:159`) | **probable**, menor |
| R3 | Durante el hold, la respiración retargetea `targetRadius` en cada frame (SmoothedAnimation) | **probable**, coste bajo y acotado a ~1.5 s |

## 3. Correcciones aplicadas

| Cambio | Archivos | Evidencia |
|---|---|---|
| Retención de contenido mientras la misma surface cambia de tamaño (`contentHeld`). Se libera al cerrar, al cambiar de surface, al empezar una notificación o cuando los destinos vuelven a reposo (`releaseHoldAtRest`, fase 2 del cierre del launcher); tras un cambio se reevalúa con `callLater` | `components/PillMorphMotion.qml`, `Pill.qml` (`surfaceName`) | `content-hold-regression` PASS (sin `releaseHoldAtRest`, FAIL "returning to rest must release the hold"). Captura en vivo `qa/launcher-after-content-hold.jpg`: el campo se mantiene y los resultados entran con el borde |
| Cerrar con un swap pendiente mantiene el contenido retirado; `swapOpacity` vuelve a 1 al descargar | `components/PillSurfaceHost.qml` | `surface-swap-close-regression`: FAIL sin el fix y PASS ×3 con él. Capturas en vivo antes/después en `qa/swap-close-*.jpg` |
| Un único progreso `fullscreenHide` / `fullscreenLift` para la pill y las cuatro gotas (opacidad + Translate). Con reduceMotion se resuelve directo | `windows/IslandOverlay.qml` | `fullscreen-hide-regression` (Wayland): PASS; el overlay original FAIL |
| Hold de notificación sin escalar (1000/2000 ms) | `Singletons/Motion.qml` | `notification-breath-regression` PASS |
| Respiración continua: `holdLevel` 0↔1 (duración `notifCollapse`, desactivado con reduceMotion), `breathLevel` hacia `IslandNotification`; se quitan los Behaviors de 300 ms | `PillMorphMotion.qml`, `Pill.qml`, `IslandNotification.qml`, `PillMaterial.qml` | `notification-breath-regression` PASS (paso de glow < 0.05, radio < 0.5 px) |
| La lista del launcher hereda la altura animada de la pill, sin animación propia | `components/LauncherView.qml` | Captura en vivo; launcher-* y pill-interface PASS |

Validación del lote completo (ISLA_CONFIG temporal):

- **PASS offscreen:** content-hold, surface-swap-close, notification-breath,
  motion, notification, surface-choreography, media-motion (playing: false),
  launcher-input-safety, launcher-pending y pill-interface.
- **PASS Wayland:** layout-interruptions, fullscreen-hide, overlay-input-policy,
  companion-continuity, y `tests/pets-surfaces.py`.
- **Otras comprobaciones:** qmllint sin diagnósticos en los archivos tocados,
  `verify-config.sh` PASS, `git diff --check` limpio, y la shell en vivo recargó
  sin errores.

No verificado en vivo:

- La respiración con una notificación real: habría añadido una entrada a tu
  historial.
- El fullscreen real: habría que cambiar tus ventanas.

### Revisión independiente

Un revisor (Opus, sólo el diff) encontró un defecto: durante la fase 2 del
cierre del launcher la surface sigue abierta con destinos en reposo y el latch
`contentHeld` no se soltaba. Si se reabría en esa ventana, el contenido salía
opaco dentro de la pill en tamaño de reposo. Se corrigió con
`releaseHoldAtRest` y se añadió el caso al fixture, con A/B. El revisor no
mantuvo defectos en los demás cambios. Después del arreglo se repitió el
conjunto: las 8 regresiones offscreen y 2 Wayland PASS, qmllint limpio y
`git diff --check` limpio.

## 4. Propuestas (necesitan tu decisión)

- **P1 · Alturas internas con SmoothedAnimation.** Pasar las alturas de
  calculadora, divisor y hint del launcher, Clipboard, Session y SettingRow a
  `SmoothedAnimation { velocity: -1 }`, para que conserven la velocidad al
  retargetear. Riesgo medio: cambia la sensación de esas transiciones.
- **P2 · Tokenizar las duraciones literales de A4.** Usar
  `Motion.*`/`Motion.mult`, para que respeten motionScale y reduceMotion de forma
  coherente. Mecánico, pero algunos loops (wallpaper, notifcard) son decorativos
  y quizá deban pararse con reduceMotion en vez de escalarse.
- **P3 · Semántica de `peek`.** Opciones: (a) que `peek` muestre la pill en
  estado hover (material despierto y cabecera expuesta) y resuelva `""` al
  monitor enfocado; (b) retirar el IPC muerto.
- **P4 · Amplitud de la respiración (A5).** Dejar un solo sumando de radio
  (≈2·s), si la respiración se ve demasiado marcada.

- **P5 · Descarga del launcher tras el cierre en dos fases (preexistente).**
  Tras la fase 2, `lastSurface` queda en reposo y `surfaceGrowth` sigue en 1,
  así que el launcher no se descarga hasta que se abre otra surface. Hay una
  decisión aceptada sobre reabrir el launcher aún cargado (TASK_STATE, cierre
  del launcher), por eso no lo toqué. Opciones: (a) descargarlo tras un tiempo
  en reposo, o (b) mantenerlo cargado a propósito y documentarlo.

## 5. Pendiente

- Arreglar el harness de QtTest en `recording-drop-regression` (no emite
  resultado en este entorno).
- Medir R1 con un profiler antes de condicionar layers.
- QA en vivo de fullscreen y de la respiración con notificación real, cuando
  quieras probarlo.
