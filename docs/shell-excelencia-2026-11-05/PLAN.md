# Plan: Isla excelente (2026-11-05)

Fuente: docs/PROMPT-shell-excelencia.md. Código actual manda; cambios ajenos sin commit se conservan.

## Entorno verificado

- Shell real: `qs -c bar` (PID 2086, `pgrep -ax qs`). Monitor único DP-1 1920×1080 @ 239.96 Hz, escala 1.
- Disponible: grim, ffmpeg/ffprobe, magick, qmllint, qmlprofiler, hyprctl, kmsgrab.
- `wf-recorder` instalado por el usuario durante la sesión (`/usr/bin/wf-recorder`): grabación
  con tiempos reales por región (`-o DP-1 -g "x,y wxh" -r 240`), análisis con ffprobe y hojas de contacto.
- `find-skills` existe en `~/.agents/skills/find-skills/SKILL.md`. Instalaciones de skills: pendientes;
  se harán sólo si aportan algo que las skills locales no cubran.

## Inventario de superficies (dueño → archivo)

Se ampliará con isla-explorador en Fase 1. Lista inicial según PROJECT_MEMORY y el prompt:

| Superficie | Dueño principal | Transiciones / estados |
|---|---|---|
| Barra superior (rail, módulos, estado, avatar, chip) | bar/components/TopBarModules.qml, TopWorkspaceRail.qml, TopUserStatus.qml | cambio de workspace, hover, foco |
| Pill / isla + Cuerpo | bar/body/PillBody.qml, BodyBrain.js, shaders/body.frag | reposo, abrir/cerrar surfaces, gotas |
| Media | bar/components/IslandMediaCover.qml, MediaView.qml, IslandMediaVisualizer.qml, CrossfadeLabel.qml | pista nueva, pausa, letras, paleta |
| Launcher, wallpaper, overview, portapapeles, calendario, conectividad, ajustes rápidos, utils | bar/windows, SurfaceRouter | abrir/cerrar, swap, Escape, clic fuera |
| OSD, notificaciones, toasts, temporizador, grabación/capturas, actualizaciones, auth, bloqueo, Edots | bar/ (por superficie) | ráfagas, interrupciones |

## Criterios de aceptación (resumen del prompt)

- 0 saltos de 1 frame, costuras, parpadeos o frames en blanco en los recorridos de Fase 2.
- Toda transición interrumpible e invertible sin salto.
- Contraste ≥4.5:1 texto, ≥3:1 iconos y bordes, en ambos temas y con 5 wallpapers.
- Reposo: GPU/CPU ≈0 sin temporizadores ocultos.
- Regresiones: ninguna que pasara en la línea base falla al terminar.
- `reduceMotion` y Reducir transparencia en todas las superficies.

## Riesgos y fallos preexistentes (no confundir con regresiones nuevas)

- `top-workspace-motion-regression`: ya fallaba ("retarget must settle at workspace 2").
- `surface-materialize-regression` con la config del usuario falla por tiempos (preexistente).
- Las regresiones con `ISLA_CONFIG={}` son la referencia de línea base; no con la config personal.
- Offscreen no es QA visual. Un PASS offscreen no certifica aspecto.

## Delegación

- Barridos y búsquedas: isla-explorador.
- Ediciones ya decididas, tests y docs: isla-implementador.
- Revisión del diff de riesgo al cerrar cada fase: isla-revisor.
- Diseño de movimiento, color y juicio visual: hilo principal.

## Fases y estado

1. Fase 0 (contexto, herramientas, plan): **en curso**. Este documento.
2. Fase 1 (inventario y línea base): regresiones PASS/FAIL en `baseline.txt` (en marcha, fondo).
   Capturas en vivo y rendimiento: pendientes.
3. Fase 2 (recorridos frame a frame): pendiente. Requiere sesión en vivo con el usuario delante del escritorio.
4. Fase 3 (corrección P0/P1): pendiente, depende de Fase 2.
5. Fase 4 (elevación visual): pendiente. Diferenciadores a definir tras estudio de referencias.

## Diferenciadores (lo que ninguna otra shell Linux hace junto)

1. Un solo cuerpo líquido: las superficies nacen y vuelven al mismo vidrio SDF (Cuerpo), sin ventanas
   que aparecen encima.
2. Gotas con física: separación con cuello y absorción, un único motor (FluidCompanion).
3. Lenguaje de trazo Tidemark: un acento, un material, bordes nítidos en píxel entero.

Toda elevación visual refuerza uno de los tres; lo que no, se descarta o va a preview.

## Límites declarados de esta sesión

- Sin sudo: no se instalan paquetes del sistema.
- El usuario no está delante: el juicio de gusto dudoso va a `docs/previews/`, no al código.
