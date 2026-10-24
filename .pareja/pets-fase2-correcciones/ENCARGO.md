# Eshell Pets fase 2: correcciones de revisión

Lee AGENTS.md y PROJECT_MEMORY.md. Recupera sólo lo pertinente: la sección
«Eshell Pets: fase 2 (2026-10-23, Codex)» de TASK_STATE.md (la tuya) y
docs/eshell-pets-redesign-2026-10-23/PHASE2.md (contrato). Es la ronda 1 de 2.

## Objetivo
Corregir los hallazgos de la revisión independiente de Claude sobre tu fase 2,
cada uno con una prueba que falle antes del arreglo y pase después.

## Archivos permitidos
bar/pets/*, bar/windows/IslandOverlay.qml (sólo la conexión con la capa),
bar/components/TopWorkspaceRail.qml (sólo la percha/brinco de la mascota),
bar/pets-regression.qml, bar/pets-rail-regression.qml, bar/pets-overlay-regression.qml,
bar/tests/pets.py, docs/eshell-pets-redesign-2026-10-23/REPORT-PHASE2.md y tu sección
de TASK_STATE.md (añade una subsección «Correcciones de revisión»).
No toques nada más ni reviertas cambios ajenos. En TopWorkspaceRail.qml NO cambies
`mouthAngle` (Motion.hover), `occupiedLevel`, `hoverLevel` ni `accentLevel`: son de
otra sesión, anteriores a tu trabajo.

## Fuera de alcance
Umbrales 0.95 y petNicheAnimating/workspaceAnimating, geometría de perchas,
tope de ápice (desviación ya autorizada), nuevas perchas o ajustes.

## Hallazgos y criterios de aceptación
1. **Brinco del rail durante `land` (MEDIO).** `PetLayer.qml:301` `detached: transit && phase !== "land"`:
   en los 90 ms de aterrizaje el actor cuelga de la percha y toma `centerX` del rail, que
   ya apunta a la celda nueva; `hop()` ve `transit` y no toma la posición visual de origen,
   así que salta a la celda nueva y brinca en el sitio. También hay un fotograma en reposo
   en que el actor aparece en la celda nueva antes de que dispare `hopTimer`.
   Criterio: en 1→2 y →3 dentro del `land`, y en 1→3 desde reposo, la x de los pies en
   coordenadas de la capa nunca salta más que el avance de un fotograma de vuelo
   (muestreo en cada tick y en el cambio de activeId) y el brinco termina en la celda final.
2. **Bajón de opacidad en la entrada al nicho (MEDIO).** `enter()` sube flightOpacity a 1
   en 200 ms y en `land` la opacidad pasa a `perch.reveal` (~0.25 a los 220 ms, nicho de
   420 ms). Criterio: durante una entrada sin relevo la opacidad efectiva es monótona no
   decreciente hasta 1 (p. ej. producto rampa·reveal en todo el recorrido, sin cambio
   brusco al reparentar). Prueba: entrada a la barra con nicho aún abriéndose; muestrear
   la opacidad efectiva y exigir monotonía (tolerancia 0.02) y valor final 1.
3. **Reabrir el launcher durante su cierre (BAJO, decisión de Claude).** Hoy
   `cancelHomeReturn()` agota la gracia (lostAt viejo) y siempre funde y cae.
   Decisión: al cancelar, Mimo se queda visible donde está y espera a la percha que
   aparezca (launcher reabierto u hogar) con el mismo tope de 2500 ms; cuando aparece,
   vuela. Al vencer el tope, fundido. Criterio: cierre normal → reapertura a mitad →
   se observa `flight` hacia el launcher, sin `fade`, y termina con parent = percha del
   launcher.
4. **Rebote de opacidad del fundido (BAJO).** Si la percha destino desaparece a mitad de
   `fade`, `loseTarget()` pone `wait` sobre la opacidad parcial y luego `fade()` reinicia
   en 1. Criterio: el fundido continúa desde la opacidad actual; la opacidad nunca sube
   durante una salida. Prueba con la percha que desaparece a mitad de fundido.
5. **`homeReturnPending` obsoleto (BAJO).** `holdForHome()` sólo mira `shown`. Criterio:
   sólo retiene si el actor está en la percha del launcher (o en vuelo hacia/desde ella);
   el flag se limpia en attach, silence, ocultar y cualquier transfer que no sea el
   regreso. Prueba: split, `launcherSurface=false`, Mimo en el rail, abrir y cerrar el
   launcher, quitar luego la percha: fundido tras 400 ms, no espera de 2500 ms.
6. **Mimo opaco sobre una superficie que se abre (BAJO, decisión de Claude).** Al abrir
   una superficie sin percha, `loseTarget()` deja a Mimo 400 ms a opacidad 1 en pose `air`
   sobre la superficie. Decisión: en `wait` sin retención de regreso, pose base (no `air`)
   y opacidad hacia 0.4 en 160 ms; si llega un relevo, el vuelo recupera opacidad 1 en sus
   primeros 120 ms; si vence la gracia, el fundido sigue desde la opacidad actual hasta 0.
   La retención del cierre del launcher (hallazgo 3 y tu desviación) no cambia: ahí sigue
   opaco. Criterio: prueba que abre una superficie sin percha y comprueba opacidad ≤ 0.45
   a los 200 ms y oculta tras ≤ 560 ms; los vuelos barra↔launcher siguen pasando.
7. **Brinco plano a escala grande (BAJO).** Se acepta como límite de la desviación del
   ápice; sólo documéntalo en el informe y en TASK_STATE.

Invariantes del brief intactos: timers imperativos, sin restart() sobre timers con
binding, driver sólo en flight/entry/fade (y lo nuevo que lo necesite, parado al
terminar), coste cero oculta/dormida, hitArea desactivada en tránsito, sin máscaras de
input nuevas.

## Validación
- `python3 bar/tests/pets.py` (con los pasos nuevos).
- Los 4 fixtures Wayland y 10 offscreen del brief, `node bar/tests/settings.cjs`,
  `python3 bar/tests/settings-integration.py`, `python3 bar/tests/overlay-native-input.py`.
- Rendimiento: repite sólo `flying`, `idle` y `rail-idle` de `bar/tests/pets-performance.py`
  y guarda en `perf/phase2-fixes/`; mismos límites del brief.
- No hagas QA en DP-1: la hará Claude. No dejes procesos quickshell de prueba vivos.

## Informe final (obligatorio, en este orden)
ESTADO: completo | parcial | bloqueado
ARCHIVOS: <lista>
CRITERIOS: <n> — probado/no verificado/bloqueado — <evidencia>
PRUEBAS: <comando → resultado>
DUDAS: <preguntas para Claude o "ninguna">
No hagas commit ni push. Subagentes sólo si ahorran: economy_worker o
economy_researcher; nunca economy_architect.
