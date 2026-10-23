# Fluidez, CPU y memoria de Isla · 2026-10-22/23

## Resultado y alcance

P1 y P4 corregidos; P3 mejora medible conservando la deriva. **P2 no está cerrado:**
el crecimiento de PSS se reproduce y no se ha identificado una corrección segura.
No se presenta el ensayo como éxito de estabilidad de memoria.

El usuario confirmó en la pantalla real que espectro, ondas y giro a 60 Hz son
continuos, y posteriormente que el brillo común conserva aspecto y suavidad.
Se inspeccionó la composición final en `final-media.png`. No se afirma una mejora
perceptual de fluidez ni FPS físicos a partir de capturas o logs.

Commits de producto: `f5634a2` Players, `f63ee86` ambiente, `fe6229b` brillo.
No se hizo push. Settings.js, ejemplo y InnerGlow se prepararon por hunks/blobs
para conservar fuera del índice las modificaciones previas del usuario.

Los archivos .log originales quedan también agrupados en `raw-logs.tar.gz` para
no llenar el diff con trazas repetidas. Se conservan descomprimidos localmente;
tras clonar: `tar -xzf docs/performance-2026-10-22/raw-logs.tar.gz -C docs/performance-2026-10-22`.
PROJECT_MEMORY.md y TASK_STATE.md se actualizaron localmente; el repositorio los
ignora y se conserva esa decisión. `git diff --check` del código/prosa pasa; top,
logs y patch crudos conservan su whitespace original.

## Método y base

- Sesión Wayland real DP-1 a 240 Hz; CPU en porcentaje de **un núcleo Linux**.
  Cada muestra principal dura 12 s, con cuatro intervalos de 3 s, leyendo /proc.
  Los archivos `*-top.txt` contienen además cuatro tomas por hilo a intervalos de
  3 s. Se tomaron después de la ventana /proc: no se suman ambas ventanas.
- Instancias limpias, una shell a la vez, copia del árbol local y restauración de
  fuentes previas guardadas, no `git show HEAD` sobre trabajo ajeno. Configuración
  personal copiada a ISLA_CONFIG temporal, estado temporal, sin guardar ajustes
  personales. Se desactiva watchFiles sólo en las copias para fijar fuentes.
- `source-before.tar.gz` conserva la base local de los archivos tocados, incluido
  InnerGlow que **ya tenía Timer de 12 Hz**. El diff Git de ese archivo partía de
  FrameAnimation, pero ninguna cifra P3 se atribuye a esa base antigua de HEAD.
- Spotify reprodujo música real. El contenido musical cambia entre ventanas;
  son comparaciones cortas, no un porcentaje universal de carga o energía.
- La compilación inicial del prototipo se solapó con parte de la primera ronda
  exploratoria. Se conserva esa ronda cruda; la ronda final de base y las rondas A
  sin compilación sostienen la conclusión. `baseline-idle-top.txt` es inventario
  inicial sin arranque limpio y no se usa para atribuir mejoras.

## P1 · Reloj ambiental y selección A/B

**Hipótesis:** CAVA, las dos ondas y el giro invalidaban propiedades a la tasa del
monitor. Compartir cadencia limita JS/bindings y render decorativo.

Se añade AmbientClock y AmbientSubscription; default `appearance.ambientFps=60`,
rango 30–240, validado en Settings, fachada Flags y ejemplo. Timer con dt real
limitado a 50 ms; sólo corre con suscriptores y sin reduceMotion. Hidden, opacity 0,
pausa y drag conservan sus gates. Morph, resortes, rail, hover y respuesta al puntero
mantienen sus motores y su frecuencia. La fase se conserva al suspender/reanudar.

CAVA conserva el array nuevo por publicación: sus consumidores actuales observan
`valuesChanged`; mutar el array sin notificar dejaría barras obsoletas. La mejora
reduce publicaciones a unas 59/s medidas, en vez de hacer una publicación por
fotograma del monitor. No se añade un modelo de 24 QObject sólo para evitar arrays.

| Ronda | Pill con música CPU | Media abierta CPU | PSS pill/media MiB | RSS pill/media MiB |
|---|---:|---:|---:|---:|
| 0: Base exploratoria | 27.75% | 28.08% | 257.35 / 270.87 | 364.20 / 379.28 |
| 1: A compartido | 13.25% | 16.83% | 318.11 / 328.34 | 425.02 / 436.92 |
| 2: A compartido | 13.50% | 16.50% | 320.23 / 330.50 | 426.97 / 438.82 |
| 3: Base limpia | 29.50% | 32.58% | 320.21 / 331.08 | 427.47 / 441.19 |

La base limpia final da 29,50/32,58%; A da 13,25–13,50/16,50–16,83%.
Los top separados muestran render alrededor de 15–17% en base frente a 9–11% en A;
el hilo principal también baja, con variación por contenido. No se atribuye ahorro
PSS: las últimas rondas antes/después tienen memoria parecida; la primera estaba
más fría. Datos completos: `music-comparison.json` y `0–3-*-top.txt`.

### Opción B experimental Rust

Se portaron parse/dB, filtro espacial y ataque65/release210 a una copia aislada del
crate existente. **No se instaló ni cambió el helper de producción.**
El modo `--smooth` emite24 floats normalizados0..1 por línea, nominal60Hz, flush y
cola acotada del helper existente; QML valida y asigna directamente. QML no vuelve
a aplicar Spectrum.parse/advance. El fallback más simple sigue siendo el wrapper
original Python/Rust raw y Spectrum.js con reloj A, sin convertir el fallback Python.

Equivalencia JS/Rust demostrada para82 vectores parse y600 advance con tolerancia
2e-14. PASS:10 unit tests locked, clippy all-targets -Dwarnings, release locked,
5 pruebas lifecycle y protocolo sintético60,033Hz. Sin dependencias nuevas.
Fuentes, protocolo, patch reproducible y logs: `rust-experiment/README.md`.
La equivalencia es para los mismos valores y dt, no sincronía de dos relojes.

ABBA real,12s por ventana, consumidores visibles, `hasFrame/signal/playing=true`:

| Variante | CPU qs | CPU árbol qs+helpers | PSS qs MiB | PSS captura/helper MiB | Actualizaciones/s aprox. |
|---|---:|---:|---:|---:|---:|
| A | 15.99% | 17.86% | 329.26 | 18.33 | 59.12 |
| B | 17.60% | 19.41% | 332.11 | 18.29 | 60.18 |
| B | 19.63% | 21.73% | 330.51 | 18.32 | 60.28 |
| A | 16.03% | 17.83% | 331.26 | 18.27 | 59.11 |

**Decisión: A.** B consume más CPU total en ambas parejas y no demuestra ahorro de
memoria. Sus cuadros llegan en un reloj distinto al de las ondas/giro; mover cálculo
fuera de JS no basta para ahorrar render. Esta explicación de sincronía es una
hipótesis compatible con los datos, no un perfil causal completo de B.
No hay razón para promover esa complejidad. El benchmark mide mismo backend Rust
raw frente a Rust smooth; no sustituye la comparación Python/Rust histórica,
documentada en `../rust-cava-2026-10-21/REPORT.md`.
`helper-cleanup.json` comprueba que los12 PID de helper/CAVA/parec registrados en
las cuatro rondas desaparecieron al terminar sus qs. Nada del prototipo queda vivo.

## P2 · Memoria: crecimiento confirmado, causa nativa pendiente

**Hipótesis:** heap JS, caché de imágenes o instancias de superficies retenidas.
`bar/tests/pss-watch.py` reutiliza sample-process.py y escribe JSONL cada30s,
comprobando PID/starttime. Tiene self-test de muestreo real. El ensayo general hace
**dos tandas de20 repeticiones por cada uno de los seis escenarios**. Las
notificaciones transitorias y sus datos viven en estado temporal. Los cambios de
pista se ejecutaron en Spotify como se anunció al usuario; no se aplicó wallpaper.

PSS en MiB, antes → después de20 acciones → después de gc():

| Escenario | Tanda0 | Tanda1 |
|---|---|---|
| Media | 323.16 → 337.78 → 337.61 | 357.21 → 368.20 → 367.58 |
| Wallpaper picker | 337.61 → 336.87 → 336.67 | 367.58 → 367.35 → 367.30 |
| Launcher | 336.67 → 344.53 → 344.59 | 367.30 → 374.23 → 374.13 |
| Edots | 344.59 → 354.89 → 354.40 | 374.13 → 376.51 → 376.70 |
| Pista/portada nueva | 354.40 → 355.96 → 355.92 | 376.70 → 376.14 → 375.50 |
| Notificaciones | 355.92 → 357.52 → 357.21 | 375.50 → 377.66 → 377.48 |

Sin depurador, inicial323,16MiB PSS/430,13MiB RSS; final tras reposo+gc
381,34MiB PSS/493,77MiB RSS, unos8,6min. **No se estabiliza**. gc recupera
habitualmente menos de0,7MiB y en algunas ventanas el PSS sube pese a recoger.
Eso no demuestra ausencia de garbage JS ni una fuga C++; sólo descarta que gc
por sí solo resuelva el aumento observado. Crudos: `memory-30s.jsonl`,
`memory-batches.json`, `memory-session.log`; reproducción: `memory-scenarios.py`.
Ejecutar ese driver vuelve a abrir superficies y avanzar40 canciones.

Se investigaron dos vías sin aceptar una corrección especulativa:

1. **Heap JS/gc.** Perfil válido con20 aperturas media y20 launcher:6,27MiB de
   RegularItem al inicio y6,29MiB después de gc, mientras PSS crece mucho más.
   HeapPage pasa6,67→7,23MiB. El crecimiento principal no queda explicado por el
   heap JS vivo medido. Los tipos se interpretan según qv4profiling_p.h de Qt6.12
   instalado: HeapPage0, LargeItem1, RegularItem2.
2. **Instancias/imágenes.** Tres tandas de20 aperturas media y20 launcher con
   instrumentación vuelven siempre a2542 nodos visuales y un suscriptor CAVA al
   cerrar; tampoco se acumulan suscripciones. Edots conserva intencionadamente
   una instancia. Las fuentes de imágenes usan tamaños fijos y retiran URLs según
   el contrato existente. El perfil válido contiene44 tipos de eventos PixmapCache,
   pero no permite convertir sus contadores en memoria GPU/caché total fiable.
   No se desactiva cache ni se retienen surfaces adicionales sin causalidad.

Los primeros dos perfiles se cortaron con SIGTERM: sus buffers de memoria no se
volcaron y **son inválidos para heap/pixmaps**. Se corrigió el harness para salir
por Qt.quit y el tercer perfil contiene4207015 eventos de asignación,89597 de
creación y329 de pixmaps. `profiler-validation.json` distingue esos intentos;
`memory-profile-complete.qtd.gz` conserva el crudo válido, `memory-profile-summary.json`
y `profile-memory-summary.py` el resumen reproducible. Los eventos Creating cuentan
creaciones, no objetos vivos; el árbol visual es otra sonda, no un censo de todo C++.

El perfilado añade overhead y retiene buffers; sus PSS no se comparan con los del
ensayo normal. **P2 queda pendiente de atribuir memoria nativa, cachés de render o
fragmentación/compilación.** Se detiene aquí tras las dos vías diagnósticas sin
corrección medible, conforme al límite del encargo. No se declara fuga demostrada,
no se inventa una regresión de estabilización y no se modifica el diseño para
fabricar ahorro. El muestreo aportado permite repetir la investigación nativa.

## P3 · InnerGlow:12Hz comunes, no N relojes desfasados

**Hipótesis y causa medida:** los glows actualizan la misma ventana en instantes
diferentes. Desactivar sólo esos relojes en una copia reduce CPU casi a cero;
conservarlos independientes genera tramos estables de48 renders/s en el log.

GlowClock agrupa las actualizaciones en un Timer83ms y dt real limitado250ms.
AmbientSubscription acepta ese proveedor y libera/cambia el contador correctamente.
La velocidad, gradiente, amplitud, colores y gates de InnerGlow se conservan.
El control sin glow fue exclusivamente diagnóstico; todos los efectos siguen
activos en la versión entregada.

A/B limpio sin música, sin logging de render en las cifras de CPU,12s/4 muestras:

| Orden | Relojes | CPU | PSS MiB | RSS MiB |
|---|---|---:|---:|---:|
| 0 | independent | 4.42% | 317.04 | 423.59 |
| 1 | shared | 2.58% | 317.80 | 424.17 |
| 2 | shared | 2.58% | 318.94 | 425.33 |
| 3 | independent | 4.25% | 318.89 | 425.24 |

Media4,33→2,58% CPU (**40,4% menos**), por debajo del4% pedido. No se atribuye
ahorro de memoria. Ensayo separado con QSG_RENDER_TIMING:578→288 mensajes de
frame renderizado en12s, aproximadamente48→24/s. Son renders de Qt, **no FPS de
presentación física**: el efecto conserva trabajo adicional tras el tick12Hz.
En el control sin glow una ventana de12s no tuvo ningún render y otra tuvo84
transitorios; no se convierte eso en promesa de0FPS permanente con actividad real.
Datos: `idle-comparison.json` (aislamiento) y `glow-alignment.json` (cambio aceptado).

El usuario confirmó que el brillo compartido se ve suave y mantiene el aspecto.
PASS en inner-glow-regression (velocidad, pausa hidden/reduced y resume) y en
registro, cambio de proveedor y destrucción de suscripciones. Revisión independiente
sin defectos sustentados, incluyendo proveedor null y cambios estando inactivo.

## P4 · Bucle Players.active

Causa reproducida: onActiveChanged leía `playing` todavía cacheado del activo
anterior y escribía recent de un player pausado. Consulta directa a active.isPlaying
rompe la reentrada. Prioridad manual vivo → reproduciendo → reciente conservada.
Test rojo en base (dos binding loops exactos), verde corregido. Detalle en
`players.md`; crudos durables `players-before.txt`, `players-after.txt`.

La sesión normal del ensayo de memoria permaneció más de5min con la corrección,
con aperturas,40 cambios de pista y40 notificaciones, sin «Binding loop» en el log.
La prueba sintética cubre además retirada del activo, manual pausado, ciclo y recencia.

## Validación y estado final

- PASS: configuración/boundaries/calculadora; ambient-settings, reloj compartido
  (cadencia/dt/hidden/reduced/resume/destrucción y cambio de proveedor); CAVA envelope
  y los7 tests cava-stream; Players; PSS self-test.
- PASS Wayland: media-timeline, swift-media-timeline, swiftify-media, media-clock,
  media-session, media-motion y motion; inner-glow tras el cambio P3. Logs `validation/`.
- FAIL previo confirmado en qml-performance.py: la instrumentación reemplaza el
  prefijo `id: overlay` también dentro de `id: overlayPets`, produciendo «id is not
  unique». Falla igual en base congelada y versión final, antes de ejecutar sus
  aserciones. No se modifica código ajeno de pets ni se cuenta ese fixture como PASS.
  Logs: `validation/qml-performance-{baseline,final}.txt`.
- Lint qmllint sale255 sin diagnóstico (mismo límite conocido del entorno); **no se
  considera PASS de lint**. La carga real y regresiones sí se verifican.
- La revisión independiente cubrió P1/P4 y luego la ampliación P3. No repitió los
  benchmarks ni sustituye la confirmación visual del usuario.

Comprobación final con ambas mejoras y arranque limpio: pill con música12.50%, media abierta17.83%; cuatro intervalos de3s por estado. PSS316.98/327.44MiB, RSS423.82/435.76MiB. Es un smoke final con otra canción, no sustituye las tablas A/B anteriores. `final-music.json`, `final-media.png`.

### Probado

Reducción CPU con música, reposo2,58%, selección A frente a B, lifecycle de clocks y
helpers, bug Players rojo/verde y sesión prolongada sin loops,240 repeticiones de escenarios del
ensayo general P2, composición por captura y continuidad confirmada por el usuario.
La shell de producción queda reiniciada con el código final y Spotify reanudado.

### No verificado

Estabilidad de PSS (**no lograda**), origen exacto de los bytes nativos, horas de uso,
energía/batería/GPU y presentación física/frame pacing. Las muestras no certifican
esos resultados. Los avisos Qt/fixtures y fallos previos se detallan en los logs.

### Bloqueado

Ningún permiso o acceso pendiente. El límite restante es causal: no hay evidencia
suficiente para corregir P2 con seguridad dentro de los dos caminos evaluados.
No se promueve Rust ni se añade un parche de memoria sin medir.
