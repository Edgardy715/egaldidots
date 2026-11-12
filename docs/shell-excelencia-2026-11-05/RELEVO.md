# Relevo: shell excelente (2026-11-05)

Retomar con: leer este archivo, `docs/PROMPT-shell-excelencia.md`, `REPORT.md` (misma carpeta) y `PROJECT_MEMORY.md`.
Mismo plan, mismas reglas: sin commit/push, sin tocar ajustes del sistema (PowerMizer/Hyprland sólo se recomiendan),
evidencia recortada sin datos personales, grabar en escritorio 9 vacío y volver al 1, regresiones con `ISLA_CONFIG` temporal.

## Hecho (sin commit)
- Cadencia medida con sonda onFrameSwapped. GPU fría NVIDIA tarda ~200 ms en subir reloj: no se arregla en código; recomendar al usuario.
- Idle glow (`InnerGlow.drifting`, `PillMaterial.drifting`): 0 frames/s en reposo tras recarga.
- Overshoot del muelle ya no re-maqueta contenido (`followGlassW/H` en `PillSurfaceHost.qml`).
- Mixer: caché `AudioSnapshot.js` + `AudioController.primeFromCache/apply` + rename/details cargados bajo demanda (`AudioEndpoint.qml`). Primer snapshot 70 → ~28 ms. Regresiones pasaron.
- **Nuevo, esta hora:** `bar/components/ClockReel.qml` reescrito: sólo ruedan los dígitos que cambian (unidades primero, desfase 12 %), recorrido media línea, 400 ms lineal con curvas por glifo; ya no cruza el borde de la pill. `clock-reel-regression` PASS en Wayland; verificado en vivo a 240 fps (cambio 1:22→1:23, ~180 ms visibles, sin saltos).
- **Nuevo:** `BodyEngine.qml` línea ~141: tolerancia de las lámparas `settled(lamps,.004,.02)` (antes .001/.01) para que no sigan 1 s a 240 fps. Tras el cambio, medición: 0 frames/s a los 6 s de volver al escritorio 1. **Falta** confirmar la cola de ~3 s justo tras el cambio y correr `node bar/tests/body-brain.cjs` + body-regression.

## Pendiente (orden)
1. Confirmar cola tras cambio de escritorio (sonda "PROBE idle" cada segundo; esperar 0 en <1.5 s). La ráfaga de ~2 s en x 950-1026 era el rodillo del reloj al cambiar de minuto (legítimo).
2. **Quitar sondas temporales** (marcadas PROBE-TEMP / GLOWPROBE): `PillSurfaceHost.qml` bloque ~207-236; `BodyEngine.qml` dos Timers BODYPROBE (~línea 189-192); `InnerGlow.qml` Timer GLOWPROBE e `id: sub`. Buscar con `grep -rn "PROBE" bar`.
3. Regresiones Wayland con ISLA_CONFIG temporal (`$S/cfg2.json` → `$S/cfgt.json`): content-hold, surface-swap-close, surface-materialize, pill-geometry, layout-motion, layout-interruptions, surface-choreography, launcher-pending, mixer-surface, launcher-focus, interaction-surfaces, body, water-body, clock-reel, top-workspace-motion, top-system-status, battery-indicator; `node bar/tests/body-brain.cjs`.
4. Microinteracciones (hover, press, foco), cruce reloj/calendario, vidrio vacío ~150 ms, Settings por IPC (buscar cómo abrirlo), reduceMotion en todo lo nuevo (ClockReel ya cubre).
5. `top-system-status` FAIL en Wayland («empty width 106 base 101»): investigar (¿batería?).
6. Revisión `isla-revisor` del diff nuevo (ClockReel, AudioController/Snapshot, lazy folds, BodyEngine).
7. Actualizar `REPORT.md` (método de cadencia, GPU fría, idle glow, overshoot, mixer, rodillo del reloj, lámparas), `PROJECT_MEMORY.md`, `TASK_STATE.md`.

## Herramientas (scratchpad de esta sesión; pueden no existir en otro chat)
`S=/tmp/claude-1000/-home-zdito--config-quickshell/ecebbdf2-35e1-46fe-8e4d-af64b8df1f96/scratchpad`: `ws.sh N`, `rec2.sh NAME OPEN GEOM SECS CLOSE` (wf-recorder 240 fps), `bbox.py DIR`, `dd.py`, `gaps.py`, `cad3.py`; ejecutar con `uv run -q --with numpy --with pillow python`.
IPC: `qs -c bar ipc call island <surface> DP-1` / `hide`; log: `qs -c bar log | sed 's/\x1b\[[0-9;]*m//g'`.
