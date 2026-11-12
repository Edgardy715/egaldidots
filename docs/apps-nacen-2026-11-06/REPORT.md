# apps-nacen · las apps nacen de la isla

ESTADO: parcial (motor y cableado hechos y probados offscreen; QA Wayland real sin hacer)

## ARCHIVOS
- bar/components/LaunchFlight.qml (nuevo): motor y dibujo del vuelo. `begin` 140, `ingestRaw` 189, `ingestWindow` 212, `startReturn` 233, `startArrive` 244, `breakBond` 253, `step` 276, `lookupWindow` 398.
- bar/components/LaunchFlight.js (nuevo): casado de clase, parseo de openwindow, SDF, tensión del cuello, muelle 2D.
- bar/launch-flight-regression.qml (nuevo)
- bar/Singletons/Motion.qml:~150 tokens `launchFlight`, `launchFade`, `launchCoverMax`, `launchWait`, `launchGeometryWait`, `launchAbsorb`, `launchResidue`.
- bar/Singletons/Settings.js:44 `motion.appLaunchFlight` (true) + sección `motion` en `sectionCatalog`.
- bar/settings/EdotsWindow.qml:77 (página Movimiento), bar/i18n/en.js (4 textos).
- bar/Singletons/Apps.qml:157 `launchAnnounced` / `announceLaunch` (`launch()` no cambia).
- bar/components/LauncherView.qml:51,466 `launchOrigin` / `reportOrigin`; bar/surfaces/LauncherSurface.qml:49 llama a `controller.launch` y luego a `Apps.announceLaunch`.
- bar/windows/IslandOverlay.qml:93-104 (`hyprMonitor`, `workArea`) y :561 instancia `LaunchFlight` (z 3) con `Connections` a `Apps.launchAnnounced`, gateado por `launcherOpen`.
- bar/TESTING.md (append). Sin cambios en Pill.qml, WinMap.qml ni shaders.

## Diseño
- Casado: `StartupWMClass`, id del .desktop (completo y último segmento), binario del Exec y nombre, normalizados (minúsculas, sin separadores) contra la clase del `openwindow`. PID: `DesktopEntry.execute()` no devuelve PID y el evento no lo trae; `launch.pid` queda disponible si un llamador lo conoce.
- Brote: la gota nace en el icono (dentro del cuerpo, oculta por la capa de corte existente) y emerge al retraerse el launcher; cuello con `FluidNeck`, histéresis 1.02/1.30 y microgota residual. Sin shader nuevo.
- Vuelo: un muelle 2D (`Motion.launchFlight`, subpasos a 240 Hz). Retarget al `openwindow` conserva posición y velocidad. Geometría por `Hyprland.toplevels` + `lastIpcObject`, con `refreshToplevels()` cada 30 ms hasta resolverla (máx. 1.5 s).
- Llegada: el vidrio se ensancha al rectángulo de la ventana con el radio de `decoration:rounding` (leído una vez con `hyprctl getoption`, no es `keyword`) y se desvanece en `min(200, 180·mult)` ms.
- Sin ventana en 6 s: espera quieta (sin cuadros, un Timer), luego regresa y es tragada. Foco de ventana existente: casa por `activewindowv2` (ignora los primeros 120 ms y la ventana ya activa). Workspace oculto: indicador de la barra si existe, si no isla. Otro monitor: isla (la gota vive en el overlay del monitor de origen).
- Rendimiento: reposo sin cuadros, Loader del cuello inactivo, `Connections` a Hyprland deshabilitadas; sin manejadores de entrada ni cambios en la máscara.
- Recomendación opcional (no aplicada): `animation = windowsIn, 1, 3, default, popin 90%` combina mejor con la llegada.

## CRITERIOS
1. probado (offscreen) — orden `controller.launch(app)` antes de `Apps.announceLaunch` sin diferidos entre ambos; anuncio y `begin()` síncronos. No se ejecutó un lanzamiento real.
2. probado (con eventos simulados y manualStep) — brote, rotura con residuo, vuelo, retarget (±1 px, ±10 %), llegada y fin.
3. probado (simulado) — 6 s sin ventana -> regreso y tragado; ventana existente enfocada; workspace oculto -> indicador / isla; otro monitor -> isla; geometría que no llega -> isla.
4. probado (tiempo controlado) — cobertura <= 180 ms (< 220), a 220 ms no queda vidrio.
5. probado — reduceMotion, ajuste apagado y pantalla completa no vuelan; apagar el ajuste a media animación cancela.
6. parcial — reposo silencioso y ausencia de manejadores de entrada probados; la máscara de IslandOverlay no cambia (comprobado por texto, IslandOverlay no instancia offscreen). Regresiones: ver PRUEBAS.

## PRUEBAS
- `python /tmp/gestos-f1-validate.py an-after bar/launch-flight-regression.qml` -> 9 PASS, 0 FAIL.
- Regresiones previas (antes y después idénticas): activities 4 PASS, body-drop 1, centered-companion 1, config 1, device-moments 7, launcher-controller/focus/input-safety/pending 1 cada una, notification-drop 1, overlay-input-policy 1, settings 1, settings-motion 1, water-drop 2, compact-island 1, content-hold 1, drop-gesture 2, frame-time 1, pull-gesture 2, surface-materialize 1, surface-router 1, notification-breath 1, pill-composition 1: todas PASS.
- Fallan igual que en la línea base (ambiente: "Type IslandOverlay unavailable / No PanelWindow backend"): fullscreen-hide, launcher-media-clearance, layout-interruptions, layout-motion, layout-routing, media-dock-surfaces, overlay-native-input, qml-performance, recording-drop, settings-layer-picker, settings-media-routing, settings-surface-switch. No es regresión mía.
- `qmllint -I .`: LaunchFlight.qml, launch-flight-regression.qml, Apps.qml, LauncherSurface.qml 0 avisos; IslandOverlay, LauncherView, EdotsWindow y Motion sin avisos nuevos en las líneas tocadas (los existentes son previos).

## No verificado
- QA visual en Wayland (cuello, residuo, vidrio, solapes con la pill y la ventana real, `decoration:rounding`).
- Cableado real de IslandOverlay con Hyprland (eventos, `lastIpcObject`, `reserved`, `activeWorkspace`); sólo qmllint y texto.
- Origen del icono mapeado desde el launcher real y el timing con el cierre del launcher.
- Cierre multimonitor real.

## DUDAS
- ¿Se actualiza PROJECT_MEMORY.md/TASK_STATE.md? No estaban en los archivos permitidos y no se tocaron.
- Si QA muestra que la gota aparece tarde frente al cierre del launcher, ajustar `launcherClosing` como disparador en lugar del anuncio.

## Pasada visual 2026-11-06 (tarde)
- Causa de «se ve rara» (fotogramas de `bar/launch-flight-stage.qml`): la gota era un círculo oscuro mientras la celda
  del lanzador es un cuadrado redondeado; al llegar, la placa translúcida dejaba una meseta gris sobre la ventana.
- Cambios: placa squircle (radio 0,3·d) con `dropSize` = 1,25 × icono; levantamiento de +10 % en 200 ms; icono al 80 %
  de la placa; `Motion.launchFlight` 12/0,9 (antes 10/0,82); disolución de llegada en 0,05–0,65 de `launchFade`;
  `arriveFrom` desde la placa real.
- Probado: `launch-flight-regression.qml` 9 PASS; `qmllint` sin avisos en LaunchFlight.qml y el escenario.
- Offscreen (`QT_QPA_PLATFORM=offscreen quickshell -p bar/launch-flight-stage.qml`): frames revisados a mano.
- No verificado: Wayland real, `windowsIn` de Hyprland (sugerido en este informe: `animation = windowsIn, 1, 3, default, popin 90%`), cierre del launcher a la vez.
