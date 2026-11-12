# Prompt de relevo: mejoras P1 de movimiento (Isla)

Pega esto como primer mensaje de una sesión nueva en `/home/zdito/.config/quickshell`.

---

Continúa el QA visual de Isla (2026-10-30). Los P0 ya están corregidos; ahora toca implementar las mejoras P1 de movimiento.

## Lee primero (en este orden, sin cargar todo)
1. `PROJECT_MEMORY.md` (entrada "QA visual shell completa").
2. `docs/shell-visual-qa-2026-10-30/REPORT.md` (propuestas P1 y tabla de correcciones).
3. `.agents/skills/fluid-island-motion/SKILL.md` y `bar/fluid/MOTION_LANGUAGE.md`.
4. Sólo si analizas fotogramas: `.agents/skills/pill-frame-inspection/SKILL.md`.

## Estado heredado
- Corregido y probado: iconos del launcher (pragma IconTheme quitado de `bar/shell.qml`), OSD en blanco (`restResizing` en `PillHeaderView.qml`), avisos efímeros fuera del historial (`NotifData.ephemeral`; `transient` es palabra reservada QML), caché de clima en disco (`CalendarData.qml`), Utils sin brillo/energía sin hardware, icono Ethernet en estado.
- Sin verificar: parpadeo de contenido al cancelar; icono Ethernet en vivo.
- Pendiente aparte: alto dinámico de Utils (fijo 420 px en `IslandGeometry.qml`), icono de batería de periférico sin etiqueta.
- ~667 cambios sin commitear ajenos a esto: conservarlos. No commitear salvo petición.

## Alcance P1 (uno por uno, en este orden)
1. Gramática de movimiento: el contenido llega junto con la forma (no después).
2. Cierre del launcher más corto.
3. Crossfade al intercambiar contenido de surface.
4. Rampa de blur coherente.
5. Notificación entrando como gota.
6. Hover que revela; cristal adaptativo.

## Criterios por cada mejora
- Cambio acotado y reversible; sin romper decisiones aceptadas de `MOTION_LANGUAGE.md`.
- Regresión relevante en verde antes de pasar a la siguiente.
- Captura en vivo con ráfaga grim (sirve para tiempos relativos, no prueba de FPS).
- Registrar en `TASK_STATE.md` lo probado, no verificado y bloqueado.

## Reglas de entorno
- Capturas en el workspace 8 vacío y volver al 1: `hyprctl dispatch 'hl.dsp.focus({ workspace = N })'`.
- No cambiar wallpaper, reproducción ni espacios del usuario; restaurar lo tocado.
- IPC: `qs -c bar ipc call island <fn> DP-1` (`hide` sin argumentos).
- Los pragmas sólo aplican al reiniciar: `qs -c bar kill` y luego `setsid nohup scripts/start-isla.sh > <scratch>/qs.log 2>&1 < /dev/null &`. Comprobar con `qs -c bar log`.
- Tests: `ISLA_CONFIG=/tmp/isla-t.json QT_QPA_PLATFORM=offscreen timeout 150 quickshell -p bar/<nombre>-regression.qml | grep PASS\|FAIL`. `layout-interruptions` y `motion` necesitan `QT_QPA_PLATFORM=wayland`.
- Rutas absolutas siempre (un `mkdir` relativo creó una carpeta suelta en el repo).
- Modo respuesta: acción primero, pasos numerados, máximo 5 ítems por lista, sin preámbulo.

## Delegación
- Búsquedas amplias: `isla-explorador`. Cambios ya decididos: `isla-implementador`. Revisión de un cambio de riesgo: `isla-revisor`. Diseño de movimiento y decisiones: hilo principal.

## Cierre
Actualizar `REPORT.md` (tabla de correcciones), `PROJECT_MEMORY.md` (breve) y `TASK_STATE.md`.
