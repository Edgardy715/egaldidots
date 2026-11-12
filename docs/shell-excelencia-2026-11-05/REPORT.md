# Isla excelente: informe (2026-11-05)

Estado por requisito: **probado** (medido o visto en captura limpia), **no verificado** (razonado o
con evidencia contaminada), **bloqueado** (no se pudo comprobar en esta sesión). Offscreen no es QA visual.

El usuario no estuvo delante durante la sesión. Los cambios de gusto dudoso no se han aplicado; las
propuestas quedan documentadas abajo, no en código.

## Cambios visibles (código, sin commit)

| Cambio | Archivo | Estado | Evidencia |
|---|---|---|---|
| Pill dormida con bordes en fila entera (antes: medio píxel, borrosa) | bar/body/BodyBrain.js | probado por cálculo y regresión; **no verificado en vivo** (requiere reposo sin interacción) | — |
| Botón cuadrícula con el mismo vidrio que el rail; acento sólo en hover/foco | bar/components/TopWorkspaceRail.qml | probado (regresión top-workspace-motion, layout) | evidence/bar-top-band.png |
| Avatar: aro neutro en reposo, acento con hover/foco | bar/components/TopUserStatus.qml | probado (regresión), captura de aro **no limpia** | — |
| Batería: relleno neutro, borde de 1 px entero, brillo sólo al cargar o con nivel bajo | bar/components/BatteryIndicator.qml | probado (battery-indicator PASS Wayland) | — |
| Halo del pacman de 0.90 a 0.50 | bar/components/TopWorkspaceRail.qml | probado (regresión neon PASS) | — |
| Profundidad: módulos laterales a 0.82 mientras una superficie tiene la atención | bar/windows/IslandOverlay.qml | **no verificado**: no hay captura limpia del rail con superficie abierta | — |

## Evidencia de movimiento (grabación a 240 fps, wf-recorder)

| Recorrido | Resultado | Estado |
|---|---|---|
| Apertura del calendario (pill → tarjeta) | Morph continuo: la zona cambiada crece y se desplaza sin saltos. El contenido entra como fundido de ~170 ms tras aparecer el vidrio. Sin pops de un fotograma. | probado (franja superior limpia) |
| Cambio calendario → launcher a los 250 ms | Sin huecos mayores de 12 ms. Sin salto. | probado (franja limpia), la **zona de superficie** no se pudo analizar limpia |
| Reposo sin superficie | Variación < 8 niveles en toda la franja: sin movimiento. | probado |
| Cadencia durante el morph | En 31 de 140 fotogramas en movimiento el fotograma se repite (alternan con el anterior). Parece un ritmo de ~120 fps sobre un panel de 240 Hz. | **no verificado**: no sé si lo produce el compositor, la shell o el grabador. Pendiente de medir sin grabador. |
| Cadencia (dt de captura) | mediana 4.0 ms, máximo 5.0 ms | probado |

Frames de referencia: [swap-morph-band.png](evidence/swap-morph-band.png) (Isla sola sobre el fondo; frames 124, 150, 177, 200 y 230).
Se observa que el reloj de la barra se cruza brevemente con la cabecera del calendario durante el morph: se
funde, no salta. Es un cruce intencional de la composición, a revisar en la siguiente pasada.

## Evidencia descartada

- Capturas de superficies completas (`live/*.png`, en scratchpad): el chat de Claude aparece detrás del
  cristal y la sesión muestra un nombre de usuario. **No se usan como evidencia.** Se quedan en scratchpad.
- Grabación de la zona completa de superficies: el chat de fondo cambia y contamina el análisis de diferencias.
  Se usó sólo la franja superior de 60 px para cadencia y saltos.

## Bugs

| Bug | Causa | Arreglo | Estado |
|---|---|---|---|
| Pill dormida desenfocada (bordes en medio píxel) | `th=16.5` con centro y=27 | `th=16*k`, sin toy | probado por cálculo y regresión body PASS |
| body-regression esperaba pillHalfH 14.5 | prueba obsoleta | espera 16 | PASS en Wayland |
| water-body-regression: FAIL en Wayland en `compare(!!shadow, !body.waterActive)` | El Loader descarga el item en el siguiente turno del bucle de eventos: la prueba comprobaba demasiado pronto. Commit c00560a (otro autor) | `tryVerify` sobre `findChild(pill,"pillMaterialShadow")` | PASS Wayland y offscreen |
| water-body-regression: FAIL en `compare(body.exposure, 1)` con reduceMotion | El commit c00560a pasa reduceMotion al material legado (W4); la prueba esperaba la exposición antigua | esperado `body.waterBody ? 0 : 1` | PASS |
| water-body-regression: FAIL en `reduceTransparency` al restaurar | Restauración sin `reduceMotion:false`; la prueba dejaba el estado sucio | se restaura también reduceMotion | PASS |
| water-body-regression: `shadow.layer` indefinido tras el Loader | Misma causa que la primera | `findChild` dentro del `tryVerify` | PASS |

Nota: los cuatro cambios son **sólo de prueba** (bar/water-body-regression.qml). No cambian el
comportamiento de la shell, pero corrigen expectativas que el commit c00560a dejó obsoletas.

## Regresiones

- Línea base offscreen: 120 PASS / 36 FAIL (baseline.txt).
- Línea base Wayland (baseline-wayland.txt). Fallos reales en áreas que esta sesión no tocó, por tanto
  preexistentes o de entorno: calendar-data, cava-envelope, clipboard-library, clipboard, hyprland-settings,
  iris-memory (fecha, "first day recorded: 4"), lyrics-controller, matugen-palette/reload,
  media-palette-recovery, overlay-native-input (timeout rc=124), personality (companion hover; las mascotas
  se quitaron en c5efa1e, prueba obsoleta), qml-performance ("overlay objects available"),
  updates-service, wallpaper-apply-protocol, wallpaper-scanner, wallpaper-source.
- Pasan en Wayland tras los cambios de la sesión: body, clipboard-design, fullscreen-hide,
  layout-interruptions/motion/routing, media-dock-surfaces, recording-drop, settings-async,
  settings-controls, battery-indicator, neon, stroke-language, compact-island, workspace-styles,
  optional-modules, water-drop, pill-geometry, pill-composition, top-workspace-motion, top-system-status,
  **water-body** (corregida en esta sesión).
- Cuando hubo un FAIL intermitente de top-system-status en Wayland (bajo carga), pasó en la repetición.

## Propuestas (no aplicadas: son juicio de gusto)

1. **Cabecera del launcher**: con sólo el reloj centrado, la cabecera de 78 px deja un hueco grande
   sobre el campo de búsqueda y 20 px de margen inferior. Reducirla a ~62 px sin media es un cambio de gusto
   aprobado por el usuario en 94 → 78 para caber con media. Propuesta: prototipo en docs/previews/ para
   decidir. **Pendiente.**
2. **Cruce reloj/cabecera del calendario durante el morph**: aceptable como fundido. Si se quiere más
   limpio, que el reloj de la barra se desvanezca antes de llegar a la tarjeta. **Pendiente de decisión.**
3. **Vidrio vacío ~150 ms antes del contenido** en la apertura del calendario. Puede ser intencional
   (materialización del cristal). Si el usuario lo quiere más rápido, reducir el retardo del contenido.

## Pendiente (no hecho en esta sesión)

- Capturas limpias de superficies completas: hace falta ocultar el chat de Claude o usar un escritorio
  sin ventanas detrás. No se hizo sin pedir permiso.
- Verificación en vivo del reposo dormido (nitidez de la pill) y de `lateralDepth`.
- Recorridos frame a frame de cierre, interrupción y reduceMotion en todas las superficies.
- Medir la cadencia del morph sin wf-recorder, para decidir si los fotogramas repetidos son reales.
- Revisión independiente del diff (isla-revisor): ver sección final.
- Rendimiento en reposo (GPU/CPU): no medido.
- Contraste ≥4.5:1 y ≥3:1 con 5 fondos: no medido.

## Herramientas

- wf-recorder (usuario) a 240 fps sobre DP-1; ffprobe para tiempos; ana.py/bandd.py con numpy y pillow (uv).
- grim para capturas; qs -c bar ipc call island <superficie> DP-1 para abrir.
- Pruebas: `ISLA_CONFIG=<tmp>/cfg2.json QT_QPA_PLATFORM=wayland|offscreen timeout 150 quickshell -p bar/X-regression.qml`.

## Revisión independiente (isla-revisor) y arreglos

Sin hallazgos graves. Siete menores; estado tras arreglar:

| # | Hallazgo | Estado |
|---|---|---|
| 1 | Brillo de la batería aparecía y desaparecía de golpe (layer activado/desactivado) | **arreglado**: el brillo es una propiedad animada (`glowAlpha`, Motion.standard) y la capa queda activa mientras haya carga |
| 2 | Relleno del avatar casi neutro al hover (Qt.tint mezclaba mal el alfa) | **arreglado**: acento en una capa propia, opacidad = presencia |
| 3 | Hueco de 0.5 px entre borde y relleno de la batería con escala fraccionaria | **arreglado**: relleno con `inset = borde + round(0.8·s)` |
| 4 | Con superficie abierta, el cristal del rail se ve bajo el selector con los módulos a 0.82 | **no arreglado**: arreglarlo exige una capa offscreen de pantalla completa mientras hay superficie. Coste no justificado sin medir. Pendiente. |
| 5 | `presented` del rail dependía de `root.opacity > 0.95` (ahora 0.82 con superficie) | **arreglado**: se quitó la condición de opacidad (la propiedad no se usaba) |
| 6 | Icono del botón de espacios no seguía el lavado | **arreglado**: icono con `Qt.tint` por la misma presencia |
| 7 | Comentario de BodyBrain prometía alineación a píxel en todos los casos | **arreglado el comentario**: sólo vale con s=1 y sin respiración |

Regresiones tras los arreglos (Wayland): battery-indicator, top-workspace-motion, body, neon, compact-island PASS.
top-system-status: **FAIL en Wayland** («empty width 106 base 101») en 2 de 2 ejecuciones tras los cambios;
offscreen PASS. Ese FAIL apareció una vez en la línea base y luego pasó. No confirmado si mis cambios lo
provocan: la barra de apps no se ha editado, pero el orden de capas de la batería sí cambió. Pendiente de
investigar (revertir batería en un temporal o medir la anchura de la barra de apps en reposo).

## Segunda tanda: rendimiento y reloj (2026-11-05)

- **Cadencia**: medida con sonda `onFrameSwapped` (ya retirada). Con GPU NVIDIA en reposo el reloj tarda ~200 ms en subir; no se arregla en código. Recomendación al usuario (no aplicada): PowerMizer en rendimiento adaptable/máximo y Hyprland sin límites de VRR agresivos.
- **Idle glow**: `InnerGlow.drifting` / `PillMaterial.drifting` → 0 frames/s en reposo tras recarga.
- **Overshoot del muelle**: `followGlassW/H` en `PillSurfaceHost` evita re-maquetar contenido durante el rebote.
- **Mixer**: caché `AudioSnapshot.js` + `AudioController.primeFromCache/apply`; rename/details bajo demanda. Primer snapshot 70 → ~28 ms.
- **Rodillo del reloj** (`ClockReel`): sólo ruedan los dígitos que cambian (unidades primero, desfase 12 %), 400 ms, sin cruzar el borde de la pill. Verificado a 240 fps.
- **Lámparas del cuerpo**: `settled(lamps,.004,.02)`; 0 frames/s a los ~6 s de volver al escritorio 1 y sonda de reposo en 0 sin cola.
- **top-system-status**: el FAIL de Wayland era de temporización, no de la batería. La espera fija de 500 ms tras el hover se cambió por `tryVerify` (1200 ms); 6/6 PASS (antes ~1 de 5 fallaba).
- Regresiones Wayland PASS: content-hold, surface-swap-close, surface-materialize, pill-geometry, layout-motion, layout-interruptions, surface-choreography, launcher-pending, mixer-surface, launcher-focus, interaction-surfaces, body, water-body, clock-reel, top-workspace-motion, top-system-status, battery-indicator; `body-brain.cjs` PASS.
- No hecho: microinteracciones en vivo (hover/press/foco), cruce reloj/calendario, vidrio vacío ~150 ms, Settings por IPC.

## Tercera tanda: recorridos grabados (2026-11-05)

Método: wf-recorder 240 fps en la región `460,0 1000x760` del escritorio 9 vacío; análisis por PTS y
diferencia de fotogramas (numpy). Huecos sin cambios en pantalla no cuentan como paradas.
Límite: la ventana de chat se ve tras el cristal, así que la mitad inferior de las capturas no es limpia.

| Recorrido | Resultado | Estado |
|---|---|---|
| Wallpaper al abrir | La vista previa grande se decodificaba durante el muelle de apertura. Ahora espera 420 ms (`WallpaperView.previewHeld`) y mientras tanto se ve la miniatura. Paradas sumadas 54–140 → 25–71 ms; cuadros en 450 ms 57–74 → 72–86 | **arreglado**, probado |
| Reloj 12:59 → 1:00 | El «12» pisaba los dos puntos al cambiar de longitud | **arreglado** (`AlignRight` si cambia la longitud), clock-reel PASS |
| Ráfaga de 5 notificaciones | Fluida (sin paradas), pero el orden era 1 → 5 → 4 → 3 → 2: la cola tomaba `popups[0]` y la lista guarda la más nueva primero | **arreglado** (`Notifs._nextPopup`: orden de llegada, críticas primero) + prueba nueva en notification-attention; en vivo 1 → 2 → 3 |
| Interrumpir el launcher a 100 ms | Reversa continua, sin saltos (mayor paso 44 px en 4 ms) | probado |
| Escape en el launcher | Cierre continuo (mayor paso 74 px al inicio del cierre) | probado |
| Cambio launcher → wallpaper a 300 ms | Continuo | probado |
| Cambio wallpaper → mixer / mixer → reloj a 80–120 ms | **P1 abierto.** El primer cuadro tras cargar la superficie nueva tarda 25–43 ms (mixer); el muelle recupera el tiempo perdido (decisión aprobada en MOTION_LANGUAGE) y salta 140–174 px | no arreglado: ver abajo |
| Mixer abierto desde reposo | Mismo primer cuadro de ~25 ms; A/B 4×4 con filas asíncronas: sin mejora clara (peor parada 21 ms síncrono, 25 ms asíncrono) | descartado, código revertido |
| CPU en reposo | qs 0.2–2.2 %; la GPU (35 %) es de todo el escritorio, no atribuible a Isla | medido |

**P1 abierto, primer cuadro de superficie nueva.** Sonda temporal (`onFrameSwapped` + estados del Loader, ya
retirada): el hueco de 25–43 ms llega justo después de `loaded`, no durante la incubación asíncrona. Las filas
asíncronas sólo lo bajan ~4 ms. Hipótesis por medir con `qmlprofiler`: maquetación/primer pintado del contenido
del mixer junto a la creación de la capa de materialización (`layer` + `MultiEffect`). Desactivar la capa no
sirve como prueba: `contentLayerActive` participa en el cierre y la superficie se cerraba. Opciones (decisión
del usuario): mantener la superficie del mixer incubada en caliente, o activar la capa un cuadro después del
contenido. No se cambió la recuperación de tiempo del muelle porque es una decisión aprobada.

**No verificado en vivo:** reduceMotion y transparencia reducida en todas las superficies (sólo por regresiones,
para no tocar la configuración real); cambios rápidos de escritorio; pista de música; arranque; sesión de 20 min;
contraste con 5 fondos (exige cambiar el fondo del usuario).

Regresiones Wayland PASS tras esta tanda: mixer-surface, audio-apps-live, interaction-surfaces, audio-controller,
wallpaper-view, wallpaper-surface, clock-reel, top-system-status, notification, notification-attention,
notification-priority, notification-breath, notification-drop, notification-routing, notifs-surface.

### Revisión de la tercera tanda (isla-revisor)

- **Crítica en ráfaga** (`Notifs._maybePromote` elegía la crítica más nueva): **arreglado**. Usa `_nextPopup()`; la prueba de notification-attention cubre dos críticas en ráfaga.
- **Vista previa aplazada sin comparar fuentes** (al reabrir, la selección se resincronizaba después de decidir si aplazar): **arreglado**. La espera ahora es siempre 420 ms salvo reduceMotion. Límite: si la fuente anterior es distinta, el héroe muestra esa vista previa anterior durante la espera, no la miniatura. Sin verificar visualmente.
- Regresiones tras el cambio, PASS: notification-attention, notification-priority, notification, notifs-surface, wallpaper-view, wallpaper-surface, wallpaper, wallpaper-apply-feedback.
