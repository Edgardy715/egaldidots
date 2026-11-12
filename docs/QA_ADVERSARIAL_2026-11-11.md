# QA adversarial de Azog — 2026-11-11 (rondas 1 a 4, cerrado)

Estado: **cerrado por el usuario tras 4 rondas**. 15 hallazgos: 1 Crítico, 2 Alto, 4 Medio, 8 Bajo. Rondas 2 y 3 aportaron hallazgos; la 4 no (no se alcanzaron 3 sin hallazgos). Sin pasadas de 30 min ni ratón real.
Evidencia y scripts: `docs/qa-evidence/2026-11-11/` (`fuzz.py`, `relaunch.sh`, `r1b.sh`, `r2.sh`, capturas `l1–l3.png`).

## Resumen

- **Control usado**: IPC de Quickshell (`qs -c bar ipc call …`), `wtype` (teclado), `notify-send`, `grim` (capturas), `hyprctl`. Computer use concedido, pero sus capturas enmascaran la shell (sólo muestra apps aprobadas) y no pulsa sobre layer-surfaces; no sirvió. No hay `ydotool`/`wlrctl`, `/dev/uinput` es 600 root y no hay sudo: **sin clics de ratón reales**.
- **Instalado**: nada.
- **Aislamiento**: copia de la config real en `/tmp/claude-1000/qa/isla-backup`; Azog corrió con `ISLA_CONFIG` temporal. Config real comparada con `cmp` al final: intacta. Azog relanzado con la config real (`qs -c bar`, pid actual).
- **Cubierto**: abrir/cerrar en bucle de launcher, overview, calendario, mezclador, portapapeles, notifs, wallpaper, conectividad, workspaces; fuzz aleatorio IPC+notify (≈2200 operaciones en 3 semillas); 100 notificaciones, título/cuerpo de 20 000 caracteres, vacías, con markup, icono inexistente y PNG corrupto; `activity` y `settings update` con JSON basura; launcher con 10 000 caracteres, comillas/`${}`/emoji/RTL, 30×Esc, 40×Tab, Enter/flechas.
- **No cubierto**: ratón (clic/arrastre/hover/sliders), Crucible con teclado, media/MPRIS, portapapeles con datos extremos, calendario/zona horaria, monitores/escala, Wi-Fi/BT/audio, grabación, foco/timer, config corrupta al arrancar, estrés de 30 min, fotogramas de animación, lockscreen, Fondos con carpetas raras.

## Hallazgos

| ID | Sev. | Superficie | Título | Cat. | Frecuencia |
|---|---|---|---|---|---|
| QA-01 | **Crítico** | Global (descarga de superficies con `Shape`) | SIGSEGV al desmontar una superficie que contiene un `QQuickShape`: `QQuickShape::itemChange → _q_shapePathChanged → boundingRect → QQuickPath::path → QPainterPath(const&)` | funcional | 4 de ~20 sesiones de abuso (wallpaper en bucle; fuzz semilla 9; spam global; ronda 2: recargas + ciclos de launcher/overview, coredump 51279). Más 3 coredumps previos del 09-nov. |
| QA-02 | Medio | PillSurfaceHost | `island page <mon> files` y `audio` fallan: «failed to load 'files'» / `FilesSurface.qml` y `AudioSurface.qml` «File not found»; un nombre desconocido devuelve igualmente `true`/no avisa | funcional | 100 % |
| QA-03 | Medio | WallpaperView | «Object or context destroyed during incubation» y «QQmlVMEMetaObject: Internal error – attempted to evaluate a function in an invalid context» al cerrar el picker durante la incubación (precursor probable de QA-01) | funcional | 4+3 veces en 3 fuzz |
| QA-04 | Bajo | Focus/Qt text-input | `disableSurface … 0x0 is focused` 347 veces y `enableSurface … has focus` 11 veces: el foco de entrada se desincroniza al conmutar superficies | funcional | constante bajo spam |
| QA-05 | Bajo | Launcher | Con U+202E (RTL override) el cursor y el texto se desordenan («rtl» queda como `|tr`) | visual | 1/1 |
| QA-06 | Bajo | Launcher | 10 000 caracteres: el campo recorta bien, pero no hay límite ni aviso y el estado vacío dice «Sin resultados» sin distinguir entrada absurda | hueco | 1/1 |
| QA-07 | Bajo | Settings IPC | `settings update` acepta con `ok:true` secciones desconocidas (`island`, `theme`) y valores extremos (`scale:-1`, `1e308`) sin errores ni descarte | funcional | 100 % |
| QA-08 | Bajo | Launcher | Tab×40 + Enter con consulta vacía lanza la primera app (ChatGPT) sin confirmación; la ventana aparece en ws 1 aunque el foco estuviera en ws 9 | hueco | 1/1 |
| QA-09 | Alto | Shell / DeviceMoments | Procesos huérfanos: tras cada caída de la shell queda un `isla-device-storage` (python) y su `udisksctl monitor` vivos para siempre (51 python + 114 `udisksctl` acumulados tras ~15 caídas/reinicios; no se limpian en recarga normal: 55→55) | rendimiento/fuga | 100 % tras QA-01 |
| QA-10 | Alto | Recarga en caliente (`island reload`) | Ráfaga de recargas (60 seguidas): el hilo principal queda al 100 % de CPU durante minutos y el IPC no responde (`hide` agota 20 s); log «There are still "8" items in the process of being created at engine destruction». Se recupera solo al cesar | rendimiento/cuelgue | 2/2 |
| QA-11 | Medio | Global (memoria) | RSS sube 540 MB → 620 MB tras 25 recargas + 9×40 ciclos y llega a 930 MB tras ~90 recargas; no vuelve a bajar en reposo (fd estables 111–117, hilos 22–29). Reposo sin actividad: 4 ticks/10 s (ok) | fuga | 2/2 |
| QA-12 | Medio | WallpaperView | Con archivos no imagen o corruptos en la carpeta (vacío `.jpg`, `.png` de texto, `.webp` aleatorio) el picker los lista como elegibles con marcador roto y deja **«Aplicar fondo» activo**; solo hay warning «Error decoding… Unsupported image format». Con 304 fondos abre sin caer | funcional/hueco | 3/3 (`wp_1.png`, `wp_2.png`) |
| QA-13 | Bajo | Settings IPC | `settings save` sobre archivo de solo lectura: la 1.ª llamada devuelve `true` y el error llega después (`Could not save settings (3)`), la 2.ª `false`; `dirty` queda `True` sin aviso visible por IPC | funcional | 2/2 |
| QA-14 | Bajo | MediaView | `mpris:length` enorme (2^62 µs) muestra tiempo restante absurdo «−76861433640:24» y la barra queda en 0; sin saneo de duración (con 0 oculta la barra, correcto) | visual | 2/2 (`mm_huge.png`) |
| QA-15 | Bajo | Portapapeles (preview) | U+202E en el texto copiado invierte el trozo visible de la fila («aenií s%{x}$»): los controles bidi no se neutralizan (misma causa que QA-05) | visual | 2/2 (`cb2.png`) |

### Detalle QA-01 (el importante)

- Pasos: arrancar con cualquier config; `for i in 1..60: qs -c bar ipc call island wallpaper DP-1; qs -c bar ipc call island hide`. En 1 de 4 tandas cayó. Con `fuzz.py 9 40` volvió a caer. El spam global de 10 superficies × 60 también lo hizo.
- Esperado: abrir/cerrar sin caer. Obtenido: la shell muere y el escritorio se queda sin barra hasta relanzar.
- Traza (coredumps 10582, 14093, 32957; `coredumpctl info <pid>`): hilo principal, `QQuickItemPrivate::derefWindow` (recursivo) → `QQuickShape::itemChange` → `_q_shapePathChanged` → `boundingRect` → `QQuickPath::path()` → copia de `QPainterPath` con SEGV (path ya destruido). Variante: `QQuickShapePrivate::sync` durante `polishItems`.
- Hipótesis: un `Shape` en una superficie descargada por `Loader` se queda con un `ShapePath` destruido antes que él (orden de destrucción) o un path mutado desde un binding mientras el item sale de la ventana. Ficheros con `QtQuick.Shapes`: `WallpaperApplyFeedback.qml`, `ConfirmationIndicator.qml`, `LevelStroke.qml`, `MediaView.qml`, `LockGlyph.qml`, `PlusCheckGlyph.qml`, `RadioGlyph.qml`, `VolumeGlyph.qml`, `PlayPauseGlyph.qml`, `TopWorkspaceRail.qml`, `AnimatedSymbol.qml`, `IslandMediaCover.qml`, `BatteryIndicator.qml` (en `bar/components/`). No bisecado cuál es.
- Mitigación a evaluar en la fase de corrección: `visible:false`/`enabled:false` y vaciar el path antes de descargar, `Loader.active=false` diferido con `Qt.callLater`, o sustituir `Shape` por `Canvas`/`ShaderEffect` en glifos pequeños.

### Detalle ronda 2

- **QA-09**: `DeviceMoments.qml:369-374` lanza `python3 scripts/isla-device-storage` con `Process`; el script (`bar/scripts/isla-device-storage:94-120`) lanza `udisksctl monitor` y no detecta la muerte del padre (sin lectura de stdin/EOF ni `PR_SET_PDEATHSIG`). Al caer la shell, ambos reparentan a systemd. Comprobar: `pgrep -fc isla-device-storage` (hoy 54 antes de limpiar). Los limpié al terminar la prueba.
- **QA-10**: `r4.sh` (`island reload` ×60, 0,3 s). Hilo principal en estado R a 298 ticks/3 s; `island hide` tarda 20 s. Tras detener el bucle volvió a 3 ticks/4 s. Sospecha: recarga encadenada sin cancelar la anterior (engine destruido con ítems en incubación).
- **QA-11**: `r3.sh` (base 540 628 kB, tras 25 recargas 621 008, tras 360 ciclos 628 348, medido tras ráfaga 930 852).
- **QA-12**: carpeta `wallpaperDir` temporal con 300 PNG + 4 archivos basura; con `wallpaperApplyScript` real, «Aplicar fondo» sobre un archivo roto lo ejecutaría (no lo pulsé).
- **Config corrupta al arrancar** (8 archivos en `cfg/`: vacío, truncado, array, `null`, tipos, extremos, binario, solo lectura): **sin fallo**; arranca con valores por defecto y muestra errores claros por IPC. Riesgo no probado: guardar sobre un archivo corrupto lo sobrescribe con defaults.
- **`settings update` ×975 valores basura** (`setfuzz.py`, 75 claves × 13): 0 valores inválidos aceptados, sin caída.

### Detalle ronda 3

- **Media/MPRIS** (`fakeplayer.py`, 6 reproductores falsos: normal, sin metadatos, duración 0, texto de 3000 caracteres, duración negativa, carátula inexistente): 30 ciclos media/peek, play/pause cruzado, reproductores que desaparecen con la superficie abierta: **sin caída ni errores de log** (sólo `textinput` repetido, QA-04). Sin metadatos muestra «Sin título / Artista desconocido»; títulos largos se truncan con «…». Único fallo: QA-14.
- **Portapapeles** (texto de 1 MB, PNG 6000×6000, binario de 300 kB, 25 aperturas, scroll con teclado): sin caída, 218 entradas, RSS estable (≈610 MB). Binario `octet-stream` no se guarda (correcto). Sólo QA-15. Restauré tu portapapeles y borré mis dos entradas de cliphist.

## Detalle ronda 4 (actividades, notificaciones, explorador, grabación, foco, recarga animada)

**Sin hallazgos nuevos confirmados.**

- Validación de `activity start/update/end` (id, título vacío/RTL/control/400 car., progreso fuera de rango o string, `end` doble, id `../../x`): rechazos correctos. Evidencia: `qa-evidence/2026-11-11/r5.sh`.
- 150 actividades + 15 notificaciones + DND alternado: shell viva, RSS 599 896 → 606 888 kB, 0 coredumps, sin errores de log (`act1.png`, `act2.png`, `act5.png`).
- `activity start` con un id ya en marcha devuelve `true` dos veces (2/2 ejecuciones). No se observa efecto visible; comportamiento (sustituye o duplica) no verificado → nota, no hallazgo.
- `files open` con 3000 ficheros, symlinks en bucle/colgantes, rutas con `"`, `'`, `${}`, `%s`, `/proc`, `/sys`, `/dev`, binarios, ruta de 4000 car.: sin fallo (`files_big.png`). Rutas inexistentes/vacías/largas/relativas devuelven `false`. Único ruido: `/root` devuelve `true` y el log da `WARN inotify_add_watch(/root) failed` (Bajo/cosmético, 1 vez; no se registra como hallazgo).
- 40 ciclos `island recording`+`island focus` y 5 ciclos de recarga con media/launcher/overview abiertos: 0 coredumps, instancia única.
- **No confirmado**: `RangeError: Maximum call stack size exceeded` en `IslandOverlay.qml` tras recargar con la pill animándose. Visto 1 vez en la primera pasada; 0 de 2 pasadas posteriores (12 recargas cada una). Intermitente, sin reproducción → vigilar.

## Top «vergüenzas»

1. QA-01: caída de la shell por abrir y cerrar superficies deprisa.
2. QA-09: cada caída deja procesos huérfanos para siempre.
3. QA-10: ráfaga de recargas congela la shell.
4. QA-12: «Aplicar fondo» activo con archivos rotos.
5. QA-02: páginas `files`/`audio` rotas por IPC.

## Patrones

- Falta de guardas al desmontar: superficies con `Shape` y bindings de path que sobreviven a su `Loader`.
- IPC sin validación de destino: devuelve `true`/silencio ante páginas inexistentes y ajustes desconocidos.
- Entrada de texto: foco de input de Qt desfasado al conmutar superficies (347 avisos).

## Observado sin fallo

- Reposo y memoria: la medición salió inválida (la shell había caído en esa tanda); **sin dato fiable**.
- 100 notificaciones, textos de 20 000 caracteres, markup, imagen rota/corrupta: sin caída ni error de log.
- `activity` con JSON inválido: responde `false`, sin caída. `settings update` con JSON roto o `__proto__`: rechazado con mensaje claro.
- Launcher con 10 000 caracteres y 30×Esc: estable.

## No verificado / bloqueado

Todo lo de «No cubierto» arriba, salvo config corrupta y estrés de recarga (hechos en ronda 2). Sigue sin cubrir: ratón, Crucible, media/MPRIS (no hay reproductor activo; `mpv` existe), portapapeles extremo, calendario/zona horaria, grabación, foco/timer, monitores, estrés de 30 min, fotogramas. Razón principal: sin entrada de ratón real y sesión corta. Incidente propio: un script mío tecleó texto basura en tu caja de mensaje de Claude (corregido con guarda de workspace vacío) y lancé ChatGPT sin querer con el Enter del launcher; cerré ese proceso.

## Para corregir primero

QA-01 (bisecar qué `Shape`), QA-09 (muerte del padre en el script), QA-10 (serializar recargas), luego QA-12, QA-02/QA-03 y validación de IPC (QA-07, QA-13).

## Correcciones aplicadas (2026-11-11)

- QA-01 (SIGSEGV): causa en `AnimatedSymbol.qml` (Repeater de `Shape` con CurveRenderer destruidos al desmontar la surface). Fix: `model: root.exposed ? root.parts.length : 0`. Medido con 30 ciclos wallpaper/hide por arranque en frío: 7/8 caídas antes, 0/12 después.
- QA-12: «Aplicar fondo» y `commitSelection` deshabilitados si la imagen no decodifica (`heroImage.status === Image.Error`).
- QA-10: `island reload` con debounce de 400 ms; 10 reloads seguidos → 1 instancia, 0 caídas.
- QA-03: sin avisos de incubación tras 20 ciclos.
- QA-02, 05–09, 13–15: corregidos (Settings/Config, shell.qml `page`, Launcher, Clipboard, MediaSession, isla-device-storage).
- QA-04: avisos `qt.qpa.wayland.textinput` son de Qt/compositor; sin cambio en QML.
- QA-11 (RSS en reloads): no corregido, sospecha de Qt; pendiente de medir.
- `clipboard-design-regression` («Escape returns focus to destination») es intermitente (1 de 2 pasadas), dependiente del foco del compositor.
- Cierre: revisión independiente aplicada (guard de Aplicar exige `previewSource === desiredPreview`; `auth-transport.py` ajustado al debounce). QA-11 medido: ~+8 MB RSS por `island reload`, lineal; no resuelto.
