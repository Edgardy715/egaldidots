# 08 · Rendimiento y accesibilidad

Leyenda de evidencia: **[V]** verificado · **[I]** inferencia · **[X]** experimental.

## Parte A · Rendimiento

### A.1 Dato medido hoy [V]

| Métrica | Valor | Contexto |
|---|---|---|
| RSS de `qs -c bar` | **684 MB** (`ps -o rss`, PID 29334) | 2026-11-06, tras abrir y cerrar 6 surfaces por IPC |
| Referencia previa | 515 MB | Diagnóstico de `docs/rediseno-2026-11-05/DIRECCION.md` |

Una sola lectura no es tendencia: el aumento puede venir de cachés de imagen, de Loaders que no se descargan o de fragmentación.

**Primera medición que hay que repetir** con `sample-process.py` (PSS y swap), porque zram falsea el RSS.

### A.2 Puntos calientes por inspección de código

| # | Hallazgo | Evidencia | Coste estimado |
|---|---|---|---|
| 1 | `NotifCardView` con `layer.enabled: true` permanente y MultiEffect | `:131` [V] | Una FBO por tarjeta; con 20 notificaciones en el historial son 20 texturas [I] |
| 2 | `TopWorkspaceRail` con 3 capas MultiEffect visibles siempre | `:126,197,267` [V] | La barra siempre visible las paga en cada fotograma sucio [I] |
| 3 | `PillSurfaceHost` materializa con blur 32/14 al abrir | `Motion.materialize*` [V] | Un desenfoque de pantalla parcial en cada apertura; aceptable si se apaga al terminar [I] |
| 4 | Loader de surfaces con `active: displayedSurface.length > 0` | `PillSurfaceHost.qml:151` [V] | No está claro si cada surface se destruye al cerrarse o si conviven en caché [I]; enlaza con el RSS creciente |
| 5 | Primer fotograma del mezclador de 25–43 ms | P1 abierto en PROJECT_MEMORY [V] | A 240 Hz son entre 6 y 10 fotogramas perdidos en la apertura |
| 6 | `PillMorphMotion` limita `dt` a 1/30 | [V] | Bajo carga el movimiento se alarga en vez de saltar; es una decisión de diseño, no un fallo |
| 7 | Timers siempre activos (1 s reloj, 15 s estado, Notifs y Nmcli) | [V] | Bajo |
| 8 | 4 integradores de muelle por `FrameAnimation` | [V] | Bajo si se paran al asentarse; está verificado para la pill en auditorías anteriores |

### A.3 Método de medición reproducible

Todo existe ya en el repo; no hace falta ninguna dependencia nueva.

1. **Memoria por surface.**
   - Lanzar `python bar/tests/sample-process.py --pid $(pgrep -f 'qs -c bar') --seconds 30 --output /tmp/base.json` en reposo.
   - Repetirlo mientras se abre y se cierra cada surface 10 veces por IPC (`qs -c bar ipc call island <surface> DP-1` / `hide`).
   - Comparar PSS+SwapPss. Criterio: menos de 5 MB de crecimiento neto tras 10 ciclos por surface.
2. **Coste de capas.**
   - Ejecutar `QSG_RENDER_TIMING=1 qs -c bar` con 0 y con 20 notificaciones en el historial.
   - Comparar el tiempo de `render` del historial abierto.
   - Criterio: menos de 2 ms de diferencia a 240 Hz.
3. **Primer fotograma.**
   - Medir con `QT_QPA_PLATFORM=wayland python bar/tests/qml-performance.py --output /tmp/isla-qml-performance` (la fixture existente) y añadir el mezclador como caso.
   - Criterio: menos de 8 ms (2 fotogramas a 240 Hz).
4. **Perfil QML.**
   - Usar `qmlprofiler` (skill `qt-qml-profiler`) en una apertura de Wallpaper y de Overview, las vistas más grandes.
   - Buscar bindings con más de 0,5 ms.
5. **Prueba de resistencia.**
   - Ejecutar `session-soak.py` durante 30 minutos con aperturas aleatorias.
   - Criterio: PSS estable (pendiente menor de 1 MB/10 min).

Los intervalos del driver de animación **no son FPS de pantalla** (lo advierte `bar/TESTING.md`). Para FPS reales hay que grabar con `wf-recorder` a la frecuencia del monitor y contar fotogramas distintos.

## Parte B · Accesibilidad

### B.1 Lector de pantalla y foco

| Problema | Evidencia | Impacto |
|---|---|---|
| `Slider.qml` sin `Accessible`, sin `activeFocusOnTab` y sin `Keys` | [V] | Cada slider que no lo compense a mano es invisible para el teclado. QuickControlsView:287 lo compensa; NotifsView y ConnectivityView no se comprobaron [I] |
| `OverviewView` con 0 `Accessible` y 0 `Keys` | [V] | Overview no se puede usar con teclado ni con lector |
| `Pill.qml` con MouseArea y 0 `Accessible` | [V] | La pill en reposo no se anuncia |
| `MotionArea` solo expone rol y tab con `accessibleName` | [V] | Las vistas que no pasan nombre (Wallpaper, NotifCard) quedan mudas [I] |
| `SettingRow` con 21 `Accessible` y 0 `activeFocusOnTab` | [V] | Dependen de controles hijos nativos para el foco; **verificado en doc 11:** rail con `PageTab`, `AlertMessage` al guardar, nombre y descripción en controles; es la referencia de accesibilidad de la shell [V] |
| Indicadores de pestaña sin rol `PageTab` | Mixer usa `Accessible.onPressAction` [V]; falta comprobar el rol | — |

### B.2 Contraste

| Caso | Evidencia | Riesgo |
|---|---|---|
| `CtrlBtn` deshabilitado con `opacity: 0.32` | `CtrlBtn.qml:22` [V] | El icono puede quedar por debajo de 3:1 sobre vidrio oscuro. WCAG exime a los controles deshabilitados, pero entonces debe entenderse que lo están |
| Subtítulos `iconSecondary` sobre vidrio con arte de fondo | Captura del calendario ("Sensación 29°", "Actualizado 21:18") [V] | Bajo arte claro el contraste baja [I]; falta medirlo con píxeles reales |
| Toggle "off": pulgar gris sobre pista tenue | Captura de Conectividad [V] | Es la zona de menos contraste vista; la forma se distingue mal |
| Colores de sistema literales (`#8e8e93` batería, `#ff9f0a` privacidad) | [V] | No se adaptan a la paleta clara si alguna vez la hay [I] |

**Método:** capturar con `grim`, muestrear el texto y el fondo con `magick … -crop 1x1+x+y txt:` y calcular la relación WCAG. Mínimos: 4,5:1 para texto normal y 3:1 para iconos y texto ≥ 18,66 px en negrita.

### B.3 Movimiento reducido

- **[V]** 103 archivos leen `reduceMotion` o `Motion.mult` (0,28). Es una cobertura amplia.
- **[V]** Huecos posibles: `BodyShader.qml` y `DeviceMomentCard.qml` (0 menciones). El rebote `OutBack 1.6` del lockscreen debería desaparecer, no solo acortarse.
- **[I]** `Motion.mult = 0.28` acorta las animaciones pero no las elimina. Para vestibular, lo correcto es sustituir traslación y escala por fundido cruzado y no limitarse a acelerarlas.

### B.4 Objetivos táctiles y de puntero

- `CtrlBtn` usa 40 px por defecto: bien.
- Los puntos del riel de workspaces miden unos 6 px visuales [V, captura]; la zona de clic es la celda. Falta comprobar el tamaño de la celda [I].
- El pulgar del `Toggle` mide 20 px, dentro de una pista de 40×24: aceptable con puntero.

### B.5 Idioma y texto

- **[V]** Mezcla de formato de hora en pantalla (pill 12 h y calendario 24 h).
- **[V]** Mayúsculas inconsistentes (días "DO LU" frente a "vie sáb").
- **[V]** `I18n.tr` en uso. El informe de 2026-10-26 ya señaló mezcla de idioma inglés/español en algunas cadenas.
