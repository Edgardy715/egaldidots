# Rendimiento visual QML · 2026-10-21

Se eliminan invalidaciones multimedia y trabajo invisible sin cambiar duración,
curvas, geometría, materiales, espectro visible ni retención de Edots.

## Cambios

- `bar/windows/IslandOverlay.qml`: la pill y la gota multimedia pasan a
  `visible: opacity > 0.005`. La pill conserva su fade; al terminar de ocultarse
  en fullscreen, la visibilidad efectiva pausa el brillo y libera el consumidor
  CAVA de la gota. Los resortes finitos conservan su ciclo de vida.
- `bar/surfaces/MediaSurface.qml`: `playback: session` sustituye el objeto JS que
  se reconstruía al actualizar posición/progreso. `MediaSession.qml` expone los
  tres campos faltantes (`length`, `displayTime`, `remainingTime`) como readonly.
  Los bindings de metadatos y capacidades conservan dependencias individuales.
- `bar/components/IslandMediaVisualizer.qml`: energía y cinco bandas comprueban
  visibilidad antes de reducir valores CAVA. Una vista oculta deja de calcular
  aunque otra vista mantenga el servicio activo.

## Medición reproducible

`bar/tests/qml-performance.py` copia las fuentes a un directorio temporal,
inyecta un reproductor y CAVA/MediaPalette simulados, instrumenta llamadas a
`Spectrum.band` y lecturas del título, y ejecuta
`bar/qml-performance-regression.qml`. No inicia el helper CAVA, extracción de
paleta, bloqueo ni reproducción real. La política fullscreen se inyecta en la
copia del overlay. Configuración y estado usan rutas temporales.

```sh
QT_QPA_PLATFORM=wayland python bar/tests/qml-performance.py \
  --source /tmp/isla-perf-20261021-baseline/bar --baseline --output /tmp/isla-qml-baseline
QT_QPA_PLATFORM=wayland python bar/tests/qml-performance.py --output /tmp/isla-qml-patched
```

Baseline: copia congelada por el coordinador antes de los cambios, con hashes
en `baseline-hashes.json`. El par de ejecuciones tabulado usó el mismo fixture,
la misma sesión Wayland y el mismo monitor, consecutivamente, sin otro benchmark
de este agente en paralelo. CAVA publica un frame simulado cada 16 ms; cada
ventana de recuento dura diez ticks de 100 ms. No son mediciones de FPS.

| Recuento/estado | Baseline | Cambio |
| --- | ---: | ---: |
| Cambios de identidad `playback` en ~1 s | 34 | 0 |
| Reevaluaciones de título estático en ~1 s | 34 | 0 |
| `Spectrum.band`, visualizador visible en ~1 s | 378 | 384 |
| `Spectrum.band`, visualizador oculto en ~1 s | 378 | 0 |
| Brillo avanza tras ocultar por fullscreen | Sí | No |
| Consumidor CAVA de la gota durante fullscreen | Activo | Liberado |

La diferencia visible de seis llamadas equivale a un frame del visualizador
(energía y cinco bandas); los intervalos de temporizador no garantizan idéntico
número de publicaciones entre procesos. Se conserva trabajo visible y se elimina
el oculto. El fixture también exige avance de posición, reanudación de brillo,
espectro y consumidor al salir de fullscreen, reduced motion, cambio de título,
seek externo a 75 s y tiempos `1:15`/`2:45`.

## Arranque y memoria del fixture

Una muestra comparable por versión en la tabla; tiempos desde Popen, observados cada 25 ms.
`ready` significa gota multimedia asentada y fixture preparado para medir.
RSS/PSS se leen una vez de `/proc/PID/smaps_rollup` en ese instante.

| Medida | Baseline | Cambio |
| --- | ---: | ---: |
| `Configuration Loaded` | 705 ms | 705 ms |
| Primer estado usable del fixture | 2114 ms | 2139 ms |
| RSS | 434968 KiB | 437696 KiB |
| PSS | 312254 KiB | 314995 KiB |

Estas diferencias están dentro de la variabilidad observada entre ejecuciones.
No demuestran una mejora de arranque o memoria y no miden el arranque global de
Isla. No se midió ahorro CPU/GPU de estas tres modificaciones.

## Validación

- Fixture comparativo Wayland: PASS en baseline y cambio; el modo normal exige
  identidad estable, cero trabajo oculto y liberación del consumidor fullscreen.
- Offscreen con configuración temporal: PASS explícito en `media-clock`,
  `cava-center`, `swiftify-media`, `media-layout`, `swift-media-timeline` y
  `rest-media-transition`.
- Routing Wayland: PASS explícito de `settings-media-routing-regression.qml`
  mediante el driver existente, añadiendo CAVA/MediaPalette simulados en su copia
  temporal. Cubre split/compact, movimiento normal/reducido,
  settings→calendar/media/session/auth, interrupción/reapertura y arte retenido.
- Qt6 qmllint de los cuatro archivos de producción: exit 0 con imports/tipos
  externos sin resolver omitidos y unqualified como info. Permanece el aviso
  conocido de PanelWindow no creable para el analizador; el runtime Wayland sí
  instancia el overlay.
- Capturas Wayland antes/después inspeccionadas: mismo layout, arte, metadatos,
  progreso y controles. Son estados estáticos; no sustituyen una medición de
  presentación o inspección completa de la trayectoria.

Evidencia conservada en `qml/`: JSON de ambas mediciones, capturas
`baseline-media.png`/`patched-media.png`, seis logs de regresión, routing y lint.

## Alcance de la auditoría

Se trazaron overlay por monitor, TopBarModules/OptionalModule, PillSurfaceHost,
FluidCompanion, MediaSession/MediaView/ArtworkImage/MediaAmbient, rail y modelo
de workspaces, Edots y bloqueo. Las búsquedas de timers/FrameAnimation/loops y
capas se limitaron a producción en components/surfaces/fluid/windows/settings
y lockscreen. No se auditó cada línea de toda la shell.

Los Loaders de surfaces liberan contenido al completar la salida; OptionalModule
libera módulos desactivados. Los resortes de gota y lente paran al asentarse.
MediaAmbient usa textura pequeña y SwiftMediaTimeline mueve geometría existente.
No se reemplazaron estos mecanismos ni se eliminaron efectos visibles.

Edots continúa precargado y retenido por monitor: hacerlo lazy antes de primera
apertura supondría otro equilibrio de memoria/latencia y fue excluido por decisión
del coordinador. WorkspaceModel permanece reactivo por eventos; no se introdujo
un caché o servicio nuevo para sus pequeños recorridos.

Límites: sin FPS/presentación, perfiles GPU, CPU comparativa, multimonitor físico,
PAM/hardware ni reproducción personal. El umbral de visibilidad recorta únicamente
la cola de opacidad inferior al 0.5%; las pruebas verifican retorno y reanudación.
