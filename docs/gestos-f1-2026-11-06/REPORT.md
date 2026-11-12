ESTADO: parcial

Corrección 2 implementada y validada en pruebas aisladas. Los puntos 1–3
pasan en ese entorno; la confirmación del bloqueo visual en Wayland sigue
reservada a Claude. No se ha manipulado/reiniciado la shell real, ejecutado
vpointer, tocado Hyprland ni realizado commit/push. Se conservan los cambios
ajenos. Esta es la última ronda solicitada.

La instrumentación temporal distinguió dos hechos: el destino del gesto sí
quedaba obsoleto (420 frente a 182 px medidos para utils), pero el contenido
retenido durante 2 s después de soltar no se reprodujo en offscreen. Antes del
arreglo, el release llegaba y el muelle alcanzaba contentProgress=1,
pullRevealing=false y opacidad=1 dentro de 600 ms. Por tanto, no se atribuye
sin evidencia el fallo nativo a onIntegratingChanged/contentHeld ni se fuerza
artificialmente la opacidad. Se corrige la discrepancia geométrica demostrada
y se protege el criterio de asentamiento con la Pill y el Loader reales.

ARCHIVOS:

Cambios exclusivos de C2 respecto al árbol recibido:

- `bar/Pill.qml`: tamaño planificado del surface activo y umbral válido de Qt.
- `bar/components/PillPullGesture.qml`: actualizar el destino en cada movimiento.
- `bar/pull-gesture-regression.qml`: reproducción de 300 px/30 pasos y 600 ms.
- `docs/gestos-f1-2026-11-06/REPORT.md`: este informe.

PillMorphMotion.qml se instrumentó temporalmente y después se restauró byte
por byte a la copia previa a C2. No cambian el muelle ni sus parámetros.

Registro de archivos de C1 y F1, conservado como historia de la entrega:

Archivos de C1:

- `bar/Pill.qml`
- `bar/shell.qml`
- `bar/windows/IslandOverlay.qml`
- `bar/components/OverlayInputPolicy.qml`
- `bar/components/PillPullGesture.qml`
- `bar/components/PillSurfaceHost.qml`
- `bar/components/SurfaceRouter.qml` (sólo la función pull)
- `bar/components/Slider.qml` (sólo import y delegación de rubber)
- `bar/components/audio/AudioFader.qml` (sólo import y delegación de rubber)
- `bar/components/RubberBand.js` (nuevo)
- `bar/pull-gesture-regression.qml`
- `bar/overlay-input-policy-regression.qml`
- `bar/rolling-elastic-regression.qml`
- `bar/tests/overlay-native-input.py`
- `bar/TESTING.md` (append)
- `docs/gestos-f1-2026-11-06/REPORT.md`

AudioFader está realmente en `bar/components/audio/AudioFader.qml`; se ha
aplicado allí el cambio solicitado para la ruta abreviada del documento.
Se conservan los cambios previos de F1 en PillMorphMotion, SurfaceHeader,
Settings.js, Motion.qml, EdotsWindow e i18n/en.js, y todo el trabajo ajeno.
No se han cambiado los parámetros de Motion.surfaceSpring.

CRITERIOS:

- C2.1 (bloqueante) — probado en QtTest/offscreen; no verificado en Wayland —
  press, 30 movimientos de 10 px, mantener y release abierto. A los 600 ms,
  tanto con 36 pasos manuales a 60 Hz como con FrameAnimation: integración
  parada, pullRevealing=false, contentProgress=1, opacidad del host y de la
  surface=1, sin layer de materialización/blur. El release conserva tamaño
  sin salto. La instrumentación se retiró. La persistencia nativa del fallo
  durante 2 s no se reprodujo aquí, incluso antes del arreglo.
- C2.2 — probado — destinationH ya no queda fijado al máximo inicial de
  IslandGeometry (utils: 360×420 unidades). PillGeometry reduce el objetivo
  al contentHeightHint del contenido cargado; plannedW/plannedH del gesto
  usan ese destino real cuando la surface está activa. Cada move actualiza
  destinationW/H/Radius. La nueva aserción falló antes (420 vs 182); después
  el mismo arrastre publica 360×209.28, incluido rubber de unos 27.28 px,
  y asienta exactamente en 360×182 en este entorno, sin rubber residual.
  Los tamaños nativos dependen de escala, tipografía y controles disponibles;
  no se fija 340×180 como constante ni se confunde el máximo con el destino.
- C2.3 — probado en código/runtime aislado — dragThreshold usa
  Math.max(Motion.pullThreshold * pill.s, 1) con intención vertical y 32766
  en espera. Los logs finales no contienen el aviso del umbral ni warnings
  nuevos de QML. El umbral estricto del gesto y el arbitraje de clic pasan.

C1: la QA real de Claude recogida en CORRECCION-2.md confirma que el arrastre
lento sigue al dedo, no se cancela y el release a 80 px se recoge. Las siguientes
entradas preservan el registro de C1; sus pendientes describen la evidencia
que faltaba al cerrar aquella ronda, no una nueva ejecución nativa en C2.


1 (corrección, bloqueante) — probado en política/QtTest; no verificado en
Wayland real — candidate/active de puntero, excluyendo scrolling, retiene el
foco y maskMode del inicio del press, tanto al abrir como al cerrar. La región
pill ya usa el máximo de tamaño actual y objetivo; la prueba incluye geometría
sobreestirada y comprueba sus cuatro bordes. Soltar abierto activa foco,
full y Escape inmediatamente; cerrar libera la captura modal. Pruebas:
overlay-input-policy y pull-gesture con Pill real. El fixture de política salió
rojo antes del arreglo y verde después. SignalSpy comprueba además cero notificaciones transitorias de foco/máscara
al abrir y cerrar durante el press. La continuidad de los eventos nativos
y la entrega real de Escape/teclas quedan para Claude.

2 (corrección) — probado — se elimina el Slider oculto. RubberBand.js contiene
la función pura compartida por Pill, Slider y AudioFader, con c=0.55; pull pasa
L=40·s/10·s y los controles conservan L=10·s y su fórmula numérica anterior.
rolling-elastic comprueba x=10^12 por debajo de L y próximo a su asíntota,
x=0.001 próximo a c·x, simetría, clamp, estiramiento y retorno de ambos controles.
pull-gesture comprueba además las bandas superior/inferior y la geometría 1:1.

3 (corrección) — probado en propiedades; no verificado visualmente — el host
mantiene el layout de destino, centrado horizontalmente y anclado arriba. Su
opacidad permanece a cero hasta que progreso y espacio disponible en ambos
ejes alcanzan 0.6; llega a uno hacia 0.95. El cierre recorre la misma retirada.
QtTest comprueba contenido cargado oculto a +80 px, opacidad intermedia a 0.8,
completa a 0.96, layout final y contenido retirado antes del cierre geométrico.
El fundido depende del progreso, sin añadir temporizador. Claude debe revisar
el resultado compuesto en Wayland.

4 (corrección) — probado en deltas; no verificado con touchpad físico — Pill
pasa WheelEvent.inverted al estado del gesto; éste deshace la inversión antes
de acumular deltas. Los tests cubren descenso para abrir, ascenso para cerrar
y conservación del scroll de listas fuera del tope con inverted true y false.
La normalización sigue la documentación de
[WheelEvent.inverted](https://doc.qt.io/qt-6/qml-qtquick-wheelevent.html).

5 (corrección) — probado en ruta e integración aislada; no verificado por IPC
nativo — IpcHandler target island expone pull(target). Alterna auto, utils,
media, notifs y calendar en el monitor enfocado con el muelle existente. Auto
captura la visibilidad de media antes de retirar el companion; la disponibilidad,
los destinos inválidos y auth conservan sus guardas. pull-gesture prueba el
router; un fixture temporal usa las funciones de producción extraídas sin
reescribirlas, un IpcHandler y Variants con dos monitores para comprobar el
cableado, todos los destinos, auto, alternancia y cambio/ausencia de monitor.
No se ha enviado el comando a la shell real.

Ejemplo de llamada para la QA de Claude:

```bash
qs -c bar ipc call island pull auto
```

Ejemplo solicitado para Hyprland hyprlang, según la
[wiki versionada](https://wiki.hypr.land/0.52.0/Configuring/Gestures/):

```ini
gesture = 3, down, dispatcher, exec, qs -c bar ipc call island pull auto
```

Para configuración Lua, según la
[wiki actual](https://wiki.hypr.land/configuring/core/binds/gestures/):

```lua
hl.gesture({ fingers = 3, direction = "down", action = function()
    hl.exec_cmd("qs -c bar ipc call island pull auto")
end })
```

Son ejemplos documentados también en bar/TESTING.md, sin editar configuración.
El gesto del compositor dispara el toggle al finalizar; el seguimiento 1:1
pertenece al gesto sobre la pill.

6 (opcional de corrección) — probado sintácticamente; no verificado nativamente
— overlay-native-input.py usa la surface existente focus en lugar de Appearance
eliminada. No se ha ejecutado el script de inyección contra la shell real.

Criterios originales F1 conservados:

- F1.1 — probado — umbral >6·s, predominio vertical, alto 1:1, ancho/radio y bandas;
  el rubber y el revelado anteriores quedan sustituidos por las correcciones 2–3.
- F1.2 — probado — fling de 1000 px/s por debajo de 0.5, velocidad ±10 %, retorno
  lento y primer paso extrapolado sin salto mayor de 1·s.
- F1.3 — probado en QtTest — cierre 1:1, fling negativo y lista fuera del tope;
  arbitraje de controles/dispositivo real pendiente de Claude.
- F1.4 — no verificado nativamente — clic simple y cancelación externa pasan;
  hover/peek/Escape/clic fuera/BodyMessenger/DnD necesitan backend Wayland.
- F1.5 — probado — captura de muelle abriendo/cerrando conserva posición y
  velocidad, detiene integración y continúa desde la posición capturada.
- F1.6 — probado — reduceMotion, desactivación, validación, persistencia,
  discard y Edots español/inglés/búsqueda con configuración temporal.
- F1.7 — probado — reposo sin integrador, timer de gesto ni layer de contenido;
  el timeout de scroll es de una ejecución y se elimina el Slider oculto.
- F1.8 — no verificado en Wayland real — la política y puntero QtTest pasan;
  el agarre implícito nativo debe repetirlo Claude tras esta corrección.

PRUEBAS:

C2 — evidencia actual (fuentes previas copiadas sin stash en
`/tmp/gestos-f1-c2-before/`; informe de C1 conservado allí en REPORT.md):

- `python /tmp/gestos-f1-validate.py c2-before` → 8 PASS, 12 fallos de backend
  previos; 20 fixtures ejecutados antes de editar producción.
- `python /tmp/gestos-f1-validate.py c2-geometry-red bar/pull-gesture-regression.qml`
  → exit 1: destino del gesto 420, objetivo medido 182. Reproducción roja
  con producción anterior al arreglo y nueva aserción.
- `python /tmp/gestos-f1-validate.py c2-clock-red bar/pull-gesture-regression.qml`
  → exit 0 antes del arreglo geométrico: el release y el asentamiento sí
  funcionaban en este backend. No se presenta como reproducción del bloqueo
  visual nativo. La primera exploración `c2-red` falló por comparar dos medidas
  asíncronas sucesivas de utils (179 vs 182); el test definitivo compara con
  el objetivo medido actual y comprueba su origen en contentHeightHint.
- `python /tmp/gestos-f1-validate.py c2 bar/pull-gesture-regression.qml`
  → exit 0, PASS, 4.7 s. Incluye los dos modos de asentamiento a 600 ms,
  además de los contratos F1 y C1 ya existentes.
- `python /tmp/gestos-f1-validate.py c2-policy bar/overlay-input-policy-regression.qml`
  → exit 0, PASS, 0.1 s; se conserva foco/máscara/entrada.
- `/usr/lib/qt6/bin/qmllint bar/Pill.qml bar/components/PillPullGesture.qml bar/pull-gesture-regression.qml`
  → exit 0 antes y después de C2, cero errores y cero avisos en estos tres
  archivos. Comparación de la misma lista contra la copia previa, no git HEAD.
  Logs: `/tmp/gestos-f1/c2-lint-before.log`, `c2-lint-after.log`,
  `c2-lint-summary.json`. Los 89 avisos de C1 corresponden a una lista mayor.
- `rg -n "PULLDBG|console.log" bar/Pill.qml bar/components/PillPullGesture.qml bar/components/PillMorphMotion.qml`
  → limpio (exit 1, ninguna coincidencia). Las trazas históricas permanecen
  sólo en `/tmp/gestos-f1/c2-red/`, `c2-clock-red/`, `c2-geometry-red/` y
  `c2-first-fix/`; no queda instrumentación temporal en producción ni fixture.

- `python /tmp/gestos-f1-validate.py c2-final` → 8 PASS y los mismos 12
  fallos previos de backend; ninguno nuevo. Todos los exit 255 conservan
  `No PanelWindow backend loaded.`; no ejecutan sus aserciones.
- `rtk git diff --check` → PASS.
- Comparación byte a byte de bar/ contra la copia previa: sólo cambian los
  tres archivos C2 enumerados. PillMorphMotion.qml queda idéntico.

| Fixture | Antes C2 | Después C2 |
| --- | --- | --- |
| compact-island | PASS | PASS |
| content-hold | PASS | PASS |
| frame-time | PASS | PASS |
| fullscreen-hide | backend (255) | mismo backend (255) |
| launcher-media-clearance | backend (255) | mismo backend (255) |
| layout-interruptions | backend (255) | mismo backend (255) |
| layout-motion | backend (255) | mismo backend (255) |
| layout-routing | backend (255) | mismo backend (255) |
| media-dock-surfaces | backend (255) | mismo backend (255) |
| notification-breath | PASS | PASS |
| overlay-native-input | backend (255) | mismo backend (255) |
| pill-composition | PASS | PASS |
| pull-gesture | PASS | PASS |
| qml-performance | backend (255) | mismo backend (255) |
| recording-drop | backend (255) | mismo backend (255) |
| settings-layer-picker | backend (255) | mismo backend (255) |
| settings-media-routing | backend (255) | mismo backend (255) |
| settings-surface-switch | backend (255) | mismo backend (255) |
| surface-materialize | PASS | PASS |
| surface-router | PASS | PASS |

Comparación de logs completos: 113/115 líneas WARN antes/después. Las dos
líneas adicionales son peticiones de iconos ausentes en compact-island
(org.xfce.thunar a 100 px y cups a 2 px); ambos mensajes/tamaños ya existen
en `/tmp/gestos-f1/c1-before/compact-island-regression.log`. No son avisos
nuevos del umbral ni de QML introducidos por el cambio. Se conservan los
avisos de servicios/avatar propios del entorno aislado.

Resúmenes y logs: `/tmp/gestos-f1/c2-before/summary.json`,
`/tmp/gestos-f1/c2-final/summary.json`, `/tmp/gestos-f1/c2/`,
`/tmp/gestos-f1/c2-policy/`. Manifest de hashes de las fuentes y resultados
comparados: `/tmp/gestos-f1/c2-evidence.json`. Offscreen no prueba Wayland.


Historia verificable de C1 (no sustituye las ejecuciones C2 anteriores):


Entorno: Arch Linux, Quickshell 0.3.2, qmllint Qt 6.12.0. Fixtures con
QT_QPA_PLATFORM=offscreen, QT_QPA_PLATFORMTHEME vacío, timeout 90 y configuración
inicialmente inexistente, runtime 0700, cache y state independientes bajo /tmp.
Los avisos de IPC/PipeWire/DBus de este entorno se conservan en los logs y no se
presentan como validación de esos servicios.

- `python /tmp/gestos-f1-validate.py c1-before` → 8 PASS y 12 fallos previos de
  backend; ejecutado antes de corregir, sin stash ni modificar la shell real.
- `python /tmp/gestos-f1-validate.py c1-red-exit bar/overlay-input-policy-regression.qml`
  → exit 1, FAIL al cambiar foco/máscara durante el press, antes del arreglo.
- `python /tmp/gestos-f1-validate.py c1-policy-final bar/overlay-input-policy-regression.qml`
  → exit 0, PASS de foco, máscara, sobreestiramiento, cierre y Escape habilitado.
- `python /tmp/gestos-f1-validate.py c1-elastic bar/rolling-elastic-regression.qml`
  → exit 0, PASS numérico y de interacción Slider/AudioFader, 5.1 s.
- `python /tmp/gestos-f1-validate.py c1-final` → 7 PASS, 12 fallos previos de
  backend y una aserción nueva prematura del fundido en pull. Se corrigió el
  fixture para esperar al Loader asíncrono, manteniendo la comprobación de que
  el contenido ya cargado permanece oculto a +80 px. No se cambió producción.
- `python /tmp/gestos-f1-validate.py c1-pull-ready bar/pull-gesture-regression.qml`
  → exit 0, PASS, 2.9 s. Confirmación con cache/config nuevas:
  `python /tmp/gestos-f1-validate.py c1-pull-confirm bar/pull-gesture-regression.qml`
  → exit 0, PASS, 2.4 s. Resultado efectivo de la batería: 8 PASS y los mismos
  12 fallos previos; sólo se repitió el fixture afectado por esa corrección.
- `python /tmp/gestos-f1-validate.py c1-pull-signals bar/pull-gesture-regression.qml`
  → exit 0, PASS, 2.9 s; última versión con SignalSpy para descartar cambios
  transitorios de foco/máscara durante el press, tanto al abrir como al cerrar.
- `python /tmp/gestos-f1-validate.py c1-ipc /tmp/gestos-f1/c1-ipc.qml`
  → exit 0, PASS, integración aislada de IpcHandler/Variants/router, 0.1 s.
  Generador recuperable: `/tmp/gestos-f1-c1-extra.py`; no es una llamada IPC
  a otro proceso ni prueba de una layer surface.

La batería es la unión de los seis fixtures exigidos y
`rg -l 'PillMorphMotion|SurfaceRouter|IslandOverlay' bar/*regression*.qml`.
Todos los fallos de backend salen con exit 255 y `No PanelWindow backend loaded.`
al cargar IslandOverlay, tanto antes como después; no ejecutan sus aserciones.

| Fixture (`bar/*-regression.qml`) | Antes C1 | Resultado efectivo C1 |
| --- | --- | --- |
| compact-island | PASS | PASS |
| content-hold | PASS | PASS |
| frame-time | PASS | PASS |
| fullscreen-hide | backend | mismo fallo |
| launcher-media-clearance | backend | mismo fallo |
| layout-interruptions | backend | mismo fallo |
| layout-motion | backend | mismo fallo |
| layout-routing | backend | mismo fallo |
| media-dock-surfaces | backend | mismo fallo |
| notification-breath | PASS | PASS |
| overlay-native-input | backend | mismo fallo |
| pill-composition | PASS | PASS |
| pull-gesture | PASS | PASS (c1-pull-signals) |
| qml-performance | backend | mismo fallo |
| recording-drop | backend | mismo fallo |
| settings-layer-picker | backend | mismo fallo |
| settings-media-routing | backend | mismo fallo |
| settings-surface-switch | backend | mismo fallo |
| surface-materialize | PASS | PASS |
| surface-router | PASS | PASS |
| overlay-input-policy (adicional) | rojo con aserción nueva | PASS |
| rolling-elastic (adicional) | no ejecutado antes | PASS |

```bash
/usr/lib/qt6/bin/qmllint \
  bar/components/PillMorphMotion.qml bar/components/PillPullGesture.qml \
  bar/Pill.qml bar/components/PillSurfaceHost.qml bar/components/SurfaceHeader.qml \
  bar/components/SurfaceRouter.qml bar/windows/IslandOverlay.qml \
  bar/components/OverlayInputPolicy.qml bar/Singletons/Motion.qml \
  bar/settings/EdotsWindow.qml bar/shell.qml bar/components/Slider.qml \
  bar/components/audio/AudioFader.qml bar/pull-gesture-regression.qml \
  bar/overlay-input-policy-regression.qml bar/rolling-elastic-regression.qml
```

→ exit 0, cero errores y los mismos 89 avisos antes/después, normalizados por
archivo/mensaje sin números de línea. La copia previa de controles conserva
exactamente la fórmula anterior; la comparación no usa git HEAD como base.
Logs: `/tmp/gestos-f1/c1-lint-before.log`, `c1-lint-final.log` y
`c1-lint-summary.json`. La primera fase había validado 71 avisos sobre un conjunto
menor de QML; no se confunden ambos alcances.

- Python `ast.parse` de overlay-native-input.py → PASS; FocusSurface.qml existe.
- `git diff --check` → PASS.

Logs/resúmenes completos por fase bajo `/tmp/gestos-f1/`. Capturas de fuentes
anteriores: `/tmp/gestos-f1-c1-before/` y, para los controles sin cambios de F1,
`/tmp/gestos-f1-lint-base/`. La fase original queda documentada por sus logs
`/tmp/gestos-f1/before/`, `final/`, `final-pull/` y la copia del informe previo en
`/tmp/gestos-f1-c1-before/docs/gestos-f1-2026-11-06/REPORT.md`.
La evidencia de esos logs precede esta corrección: no prueba su runtime actual.

DUDAS:

Claude debe confirmar el punto bloqueante en la shell Wayland real con su
reproducción de 300 px/30 pasos, mantener y soltar: contenido nítido/opaco,
sin integración tras 600 ms y tamaño igual al de utils abierta normalmente.
El atasco tras 2 s no se ha reproducido en offscreen; no puede darse por
cerrado nativamente con esta evidencia. La geometría obsoleta sí se reprodujo
y corrigió. Quedan asimismo los doce fixtures que requieren PanelWindow y
la QA nativa pendiente de controles/touchpad/IPC de C1. No hay decisiones de
implementación que requieran respuesta del usuario.
