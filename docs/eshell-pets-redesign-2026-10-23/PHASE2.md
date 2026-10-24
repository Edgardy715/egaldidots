# Eshell Pets · Fase 2: saltos, workspaces, travesuras y eventos

Encargo cerrado para implementar la fase 2 de Mimo. Sigue `PROPOSAL.md` (dirección
aprobada) y el estado real de la fase 1 (`TASK_STATE.md`, secciones «Eshell Pets»).
Si algo de aquí contradice el código, manda el código: anótalo en TASK_STATE.md y
pregunta antes de cambiar de dirección.

Antes de tocar nada, lee:

1. `.agents/skills/fluid-island-motion/SKILL.md` y `bar/fluid/MOTION_LANGUAGE.md`.
2. `TASK_STATE.md`: «Eshell Pets: fase 1 Mimo, runtime y perchas» completa,
   incluida la ronda de revisión.
3. `bar/pets/*.qml`, `bar/components/TopWorkspaceRail.qml`, `bar/components/TopBarModules.qml`,
   `bar/components/IslandRestStatus.qml`, `bar/windows/IslandOverlay.qml` (Loader de la capa).

Reglas de trabajo: no cambies de rama ni hagas commit salvo que el usuario lo pida; el
árbol tiene cambios ajenos sin publicar que hay que conservar. Entrega por bloques
(A → E) y deja cada bloque con sus pruebas en verde antes de empezar el siguiente.

## Alcance

Dentro:

- **A.** Saltos entre perchas (superficies) con parábola, retarget en el aire y salida/entrada sin salto.
- **B.** Estilo de workspaces «Mascota»: Mimo vive en el rail de workspaces y salta al workspace activo.
- **C.** Eventos: programa (terminal/editor enfocado), baila en la barra al empezar música, noche.
- **D.** Travesuras al azar con frecuencia configurable.
- **E.** Paquete: animación `hop` y ajuste de `code`.

Fuera (no implementar): personalización Edots más allá de que los ajustes nuevos aparezcan
en la página existente (fase 3); nuevas perchas en ajustes rápidos, notificaciones,
wallpapers, overview o Edots; «mirar la acción» (tecleo, cambio de pista); accesorios y
paletas; segunda mascota, plantilla y skill creadora (fase 4).

## Estado actual (fase 1, ya hecho)

- `IslandOverlay` crea `PetLayer` en un `Loader` (`active: Config.pets.enabled`), uno por
  monitor. `monitorActive` = monitor enfocado, sin fullscreen, sin cambio de layout.
- `PetPerch` (en `bar/pets/`): `perchId`, `priority`, `available`, `kind`
  (`niche` centra el cuerpo; `line`/`edge` apoyan los pies en `floorY`), `headroom`,
  `minX/maxX/restX`, `avoidFrom/avoidTo`, `reveal` (opacidad), `mood`, `occupied`.
  Se registra en la capa; `closing` evita llamar a una capa que se destruye.
- Perchas actuales: barra `bar` p0 (nicho tras el reloj, en IslandRestStatus, ancho
  `gap + bodyWidth/2 + reachRight + 2s` = 42 px a px 2, sólo abierto si está ocupado),
  media `media` p2 (timeline, `z: -1` bajo el seek, `mood: "music"` mientras suena),
  launcher `launcher` p3 (borde derecho del buscador).
- `PetLayer`: `candidatePerch` (mejor percha disponible) → `settleTimer` (0 ms) →
  `activePerch`. El actor se **reparenta** dentro de `activePerch`: hereda opacidad y
  morph de la superficie. Hoy el cambio de percha es instantáneo (no hay salto).
- `PetActor`: máquina de estados por fotogramas (`play`, `schedule`, `advance`,
  `finish`), `baseAnim()` = sleep | dance (mood music) | idle, paseo (`walkTo`),
  keep-clear, clicks/caricia, sueño con bostezo previo. Timers: `frameTimer` (un
  disparo por fotograma), `brainTimer` (3–7 s en idle), `sleepTimer`. px por percha:
  `min(basePx, floor(headroom / (niche ? bodyRows : reachRows)))`.
- Paquete Mimo: `bar/pets/packs/mimo/pet.json` (idéntico a `design/mimo.pet.json`),
  atlas generado por `bar/pets/tools/petpack.py build`. Animaciones: idle, blink,
  look_left/right/up, walk, sit, sleep, yawn, code, dance, react, happy, wave, twirl,
  sneeze. `events` mapea `nightYawn→yawn`, `coding→code`, `greet→wave`; `mischief` =
  twirl 3, sneeze 2, wave 2. Estos eventos existen pero el cerebro aún no los usa.
- Ajustes `pets` en `bar/Singletons/Settings.js` (9 campos: enabled, pack, name, scale,
  barSurface, launcherSurface, mediaSurface, sleepEnabled, sleepAfter).

## Invariantes (romper uno es un fallo, aunque las pruebas pasen)

1. **Timers armados de forma imperativa.** Nunca `running:` con binding en un timer al
   que también se llama `restart()`/`stop()`: `restart()` rompe el binding en silencio
   (así nacieron los dos bugs de la revisión de fase 1). Todo timer nuevo se arma desde
   una función `armX()` llamada en cada cambio de su condición, como `armBrain()`/`armSleep()`.
2. **Coste.** Desactivada: ningún objeto. Oculta o dormida: ningún timer ni
   FrameAnimation corriendo. Idle ≤ 2 actualizaciones/s. Lo único a 60 fps es un vuelo o
   un brinco en curso (≤ 520 ms), con `FrameAnimation` que se detiene al aterrizar. Nada de
   `Behavior`/`NumberAnimation` permanentes sobre x/y del actor.
3. **Input.** La mascota no cambia ni amplía máscaras de input y nunca roba clics a un
   control. En vuelo no recibe input (`hitArea.enabled = false`). En el rail tampoco (ver B).
4. **Disponibilidad de la barra.** No tocar los umbrales 0.95 de `petAvailable`
   (PillHeaderView) ni el acoplamiento `petNicheAnimating` → `workspaceAnimating` de la pill;
   no añadir histéresis con estado (provocó un binding loop). Un cambio de percha sigue
   pasando por `candidatePerch → settleTimer → activePerch`.
5. **Reduced motion** (`Flags.reduceMotion`): sin vuelos, brincos, paseos ni travesuras;
   aparece/desaparece en su sitio con una pose fija por estado.
6. **Oculta** en fullscreen, en monitores sin foco y sin percha; `Accessible.ignored`.
7. **Composición.** Componentes hoja reciben datos por propiedades; Players/Hyprland/
   Toplevels se conectan desde la composición (overlay/Pill), no desde `bar/pets/` ni desde
   el rail. Ajustes nuevos con default y validación en Settings.js; Flags es sólo lectura.
8. **Sin regresión** en lo que ya hace la fase 1 (lista de pruebas abajo).

## A. Saltos entre perchas

Comportamiento:

- **Relevo directo.** Si `activePerch` pasa de A a B (o de A a nada y a B) en ≤ 400 ms,
  Mimo salta de su posición en A al punto de reposo de B.
- **Sin destino.** Si A desaparece y en 400 ms no hay B, Mimo se queda donde estaba
  (coordenadas de la capa) y se desvanece en 160 ms; después queda oculta, sin timers.
- **Entrada sin relevo.** Si aparece en B sin vuelo (primera vez, tras más de 400 ms, foco
  de monitor), cae desde 6·s por encima con opacidad 0 → 1 en 200 ms (OutCubic) y
  fotograma `land` al tocar. Con reduced aparece sin desplazamiento.
- **Parábola.** Agacharse 80 ms (fotograma `crouch`), vuelo y amortiguación 90 ms (`land`).
  Duración del vuelo `clamp(380 + 0.18·d/s, 380, 520)` ms, con d la distancia en px.
  Altura del ápice sobre el más alto de los dos extremos: `clamp(18·s + 0.12·d, 18·s, 72·s)`.
  Avance horizontal lineal en el tiempo, vertical parabólico (balístico). Mira hacia el
  destino (`mirrored`). Más de 900·s de distancia: no vuela, se comporta como
  «sin destino» + «entrada sin relevo».
- **Destino móvil.** El punto de llegada se recalcula cada fotograma (la superficie puede
  estar en morph). Si el destino cambia en el aire, empieza un vuelo nuevo desde la posición
  y velocidad actuales (sin salto de posición ni de dirección vertical).
- **Píxel.** Vuela con el px de origen y cambia al px del destino en el ápice.
- El brinco del rail (B) usa el mismo motor con otros parámetros.

Implementación orientativa (se puede ajustar si se justifica en TASK_STATE.md):

- En `PetLayer`, un `Item` de vuelo por encima de las superficies. El `Loader` de la capa
  hoy es el primer hijo del overlay y queda por debajo de la pill: dale un `z` por encima
  de las superficies; la capa no pinta nada mientras el actor está en una percha.
- Al asentar (`settleTimer`), antes de cambiar `activePerch`, guarda el punto de los pies
  del actor mapeado a la capa y la hora. Con eso decides relevo, desvanecimiento o entrada.
- Durante el vuelo el actor tiene `parent` = capa de vuelo, `perch` = destino, opacidad 1
  y un estado `flying`; al aterrizar se reparenta al destino. El actor sigue siendo uno
  solo: nada de clones ni fantasmas.
- Una `FrameAnimation` sólo corriendo mientras `flying`; se para al aterrizar y al ocultar.

## B. Estilo de workspaces «Mascota»

- `Settings.js`: añadir `"pet"` a `appearance.workspaceStyle.options` con etiqueta
  `"Mascota"`. Descripción: requiere Eshell Pets activado; sin mascota se ve como «Puntos».
  Actualizar `bar/tests/settings.cjs` (lista de estilos válidos).
- **Dibujo del rail** (`TopWorkspaceRail.qml`): con `style === "pet"` las celdas se dibujan
  como `dots`. Si Mimo está en el rail (`perch.occupied`), el punto del workspace activo
  se desvanece (Mimo lo sustituye, como Pac-Man oculta el suyo). Si no está (monitor sin
  foco, mascota desactivada, otra superficie abierta), el punto activo se ve como en «Puntos».
  Pac-Man y los demás estilos no cambian.
- **Percha del rail.** Un `PetPerch` dentro del rail: `perchId: "rail"`, `priority: 1`,
  `kind: "niche"`, alto el del rail, `headroom` el alto del rail, `minX = maxX = restX` =
  centro de la celda activa (sin paseo). `available` = estilo `pet` && rail visible y
  presentado (`fits`, módulo presentado) && opacidad del rail > 0.95. `petLayer` llega
  por propiedad: overlay → `TopBarModules` → rail.
- **Barra.** Con el rail ocupado, el nicho tras el reloj no se abre (ya sólo se abre si
  está ocupado). Si el rail no cabe o no está presentado, Mimo vuelve al nicho (p0).
- **Brinco de workspace.** Al cambiar `activeId`: brinco con `crouch`/`land` y mirando en la
  dirección del cambio. Duración `200 + 40·min(|Δ|, 6)` ms (≤ 440) y ápice
  `8·s + 2·s·min(|Δ|, 6)`, con Δ el número de celdas. Cambios rápidos (1 → 5 → 2) retargetan
  desde la posición y velocidad actuales y terminan en la celda final, sin brincos
  pendientes. Con reduced se coloca en la celda nueva sin moverse. No sigue al resorte del
  lens: usa su propio brinco, y la `FrameAnimation` del lens no debe correr por culpa de
  Mimo.
- **Hover.** Al pasar el ratón por otra celda (`hoverId`), Mimo mira hacia ella
  (`look_left`/`look_right`, un solo fotograma) y vuelve a idle al salir.
- **Input.** Añadir `property bool interactive: true` a `PetPerch`; el rail lo pone a
  `false` y el actor desactiva su `hitArea`. Clic y hover de las celdas siguen intactos.
- **Layouts.** Funciona en split (rail lateral) y compact (rail integrado en la pill).
  Al cambiar de layout, `monitorActive` ya oculta la mascota; al volver aparece con
  «entrada sin relevo».
- **Saltos.** Desde el rail al launcher (y de vuelta) aplica A con normalidad.

## C. Eventos

Base de estado en `PetActor.baseAnim()`: sleep > dance > code > idle.

- **Programa.** Cuando la ventana enfocada es una terminal o un editor, Mimo programa
  (`coding → code`), pero sólo en perchas de casa (`bar`, `rail`), nunca en launcher ni media.
  - **Fuente:** `ToplevelManager.activeToplevel.appId` (Quickshell.Wayland), conectado
    desde la composición y basado en eventos, sin sondeo ni `hyprctl`. Verifica que en esta
    versión de Quickshell se actualiza al cambiar el foco en Hyprland; si no, usa el evento
    `activewindow` que ya escucha WinMap.
  - **Ventanas que cuentan:** lista fija en un JS de `bar/pets/`, con kitty, foot,
    Alacritty, org.wezfurlong.wezterm, com.mitchellh.ghostty, code, code-oss, codium,
    dev.zed.Zed, neovide y `jetbrains-*`. Compara sin distinguir mayúsculas.
  - **Paso de datos:** la capa recibe `coding: bool` por propiedad.
  - **Coste:** `code` se queda quieto tras 4 vueltas (`settleAfterLoops: 4` en el paquete)
    y el cerebro lo reanuda cada 20–40 s.
  - **Actividad:** cambiar el foco a una de estas ventanas cuenta como actividad (despierta
    y rearma el sueño). Programar sin cambiar de ventana no impide dormirse.
- **Baila en la barra.** Cuando empieza la música (`Players.playing` pasa a true) o cambia
  la pista mientras suena, Mimo baila 8 s en perchas de casa y vuelve a su estado base.
  - La composición avisa con un pulso a la capa (`notify("musicStart")` o una función de
    la capa); `bar/pets/` no importa Players.
  - Un solo timer de un disparo, armado de forma imperativa y con duración configurable
    para pruebas.
  - En media sigue bailando mientras suena, como ahora.
- **Noche (23:00–06:00, hora local).**
  - El sueño llega antes: la mitad de `sleepAfter`, mínimo 1 min, calculado al armar el
    timer.
  - En idle, cada tick del cerebro tiene un 12 % de bostezar (`nightYawn → yawn`), como
    mucho una vez cada 2 min.
  - La hora se lee con `new Date()` en cada tick del cerebro, sin timers nuevos. Inyecta un
    reloj (`property var now: () => new Date()`) para poder probarlo.
- **Saludo.** Si reaparece en una percha de casa tras más de 10 min oculta, saluda una vez
  (`greet → wave`).

## D. Travesuras

- Ajuste `pets.mischief`: `never | rare | normal | frequent` (default `normal`), con
  etiquetas «Nunca», «Rara (~15 min)», «Normal (~6 min)» y «Frecuente (~2 min)».
- Se decide en el tick del cerebro, sin timer nuevo. Cuando llega el momento, elige del
  `mischief` del paquete con pesos y fija el próximo a `media × (0.6…1.4)`.
- Sólo ocurre si:
  - está en idle y sin paseo;
  - no está dormida, en vuelo, con reduced motion ni en el launcher (mientras escribes);
  - no hubo un cambio de percha en los últimos 3 s.
- `twirl`, `sneeze` y `wave` son de un ciclo: terminan y vuelven a `baseAnim()`.

## E. Paquete

- **`hop` en Mimo**, tres fotogramas:
  - `crouch`: cuerpo una fila más bajo y ancho, brote plegado;
  - `air`: estirado, pies recogidos, brote hacia atrás;
  - `land`: aplastado, como `crouch`.
  - Usa `ms: [80, 100, 90]` y `loop: false`; el actor controla qué fotograma se ve en vuelo.
- **Dónde y cómo dibujarlo:**
  - dibuja los fotogramas en `design/src/anims.py`: añade `'hop'` al diccionario `A`
    con los mismos helpers que el resto de poses, y su etiqueta en `LABEL` de `build.py`;
  - ejecuta `python3 build.py` desde `design/src/`: regenera `poses-*.png`, los GIF y
    `frames.json`;
  - `pet.json` no se regenera solo. Copia `frames.json["hop"][i]` como `hop_0..hop_2` en
    `frames` y añade la entrada en `animations` con
    `"frames": ["hop_0", "hop_1", "hop_2"]`. Deja `bar/pets/packs/mimo/pet.json` y
    `design/mimo.pet.json` idénticos;
  - respeta la paleta y la línea de base 18;
  - revisa la silueta en `poses-dark.png` y `poses-light.png`.
- **`code`:** añadir `settleAfterLoops: 4`.
- **Herramienta:** en `petpack.py`, añadir `"hop": "react"` a `FALLBACK`. Después ejecutar
  `python3 bar/pets/tools/petpack.py build bar/pets/packs/mimo` y `validate`.

## Ajustes nuevos (Settings.js, grupo `pets`)

| Clave | Tipo | Default | Etiqueta |
| --- | --- | --- | --- |
| `jumps` | boolean | true | Saltos entre superficies |
| `mischief` | choice | `normal` | Travesuras |
| `codingReaction` | boolean | true | Programa con terminal/editor |
| `musicReaction` | boolean | true | Baila al empezar la música |
| `nightReaction` | boolean | true | Bosteza y duerme antes de noche |

Con `jumps: false` se comporta como reduced sólo en los desplazamientos: sin vuelos ni
brincos. Sí mantiene paseos y animaciones.

Añádelos a `settings.cjs` y a `settings-integration.py`; las claves desconocidas se
siguen conservando.

## Pruebas (criterios de aceptación)

Todas en verde antes de entregar; las nuevas se escriben con cada bloque.

`bar/pets-regression.qml` (offscreen), pasos nuevos:

- **Vuelo:**
  - un relevo A → B en ≤ 400 ms pone `flying`, el actor en la capa de vuelo y la hitArea
    desactivada;
  - aterriza en B en ≤ 600 ms con `parent === B`;
  - al terminar no queda ninguna FrameAnimation ni frameTimer corriendo, salvo el de la
    animación base.
- **Retarget:** cambiar el destino en mitad del vuelo no produce saltos de x mayores que un
  paso de fotograma y termina en el destino nuevo.
- **Sin destino:** se desvanece en 160 ms y queda oculta, sin timers. La entrada sin relevo
  aplica la caída de 6·s, no un vuelo.
- **Reduced y `jumps: false`:** sin vuelo, colocación inmediata.
- **Travesuras:** con reloj inyectado, `frequent` produce una del paquete y `never` ninguna;
  nunca dormida, con reduced ni en el launcher.
- **Programa:**
  - en la barra, `coding` pone `code`; en el launcher, no;
  - tras 4 vueltas `animating` es false.
- **Música:** el pulso hace bailar 8 s (intervalo acortado) y vuelve a idle.
- **Noche:**
  - con hora 01:00 el sueño se arma a la mitad;
  - con hora 15:00, a lo normal.

`bar/pets-rail-regression.qml` (nuevo, offscreen), con TopWorkspaceRail + PetLayer reales y
`activeId` asignable:

- **Ocupación:** con estilo `pet`, Mimo ocupa el rail y el punto activo se desvanece; sin
  mascota, el punto activo se ve.
- **Brincos:**
  - 1 → 3 brinca y aterriza en el centro de la celda 3;
  - 1 → 5 → 2 rápido termina en 2 sin brincos pendientes;
  - con reduced, colocación inmediata.
- **Clic:** sobre la celda que ocupa Mimo, el clic emite `workspaceRequested` (la mascota no
  roba clics).
- **Hover:** mira hacia la celda señalada.
- **Pac-Man:** sin cambios con estilo `pacman`.

`bar/pets-overlay-regression.qml` (Wayland), pasos nuevos:

- **Vuelos:** barra → launcher → barra vuela (se observa `flying` en algún momento) y no
  suelta la mascota (`barDrops === 0`).
- **Rail:** con estilo `pet`, la mascota ocupa el rail, el nicho de la barra queda en 0 y el
  launcher la hace volar del rail al launcher y de vuelta.

Añade los fixtures nuevos a `bar/tests/pets.py`.

Regresiones que deben seguir pasando:

- **Mascota:** `python3 bar/tests/pets.py`.
- **Wayland:** layout-routing, media-dock-surfaces, pill-composition y
  bar-layout-transition.
- **Offscreen:** pill-interface, status, clock-reel, island-status-adapter,
  workspace-styles, pacman-motion, neon, optional-modules, module-composer y
  compact-island.
- **Scripts:** `node bar/tests/settings.cjs`, `bar/tests/settings-integration.py` y
  `bar/tests/overlay-native-input.py`.

Ejecuta cada fixture con un `ISLA_CONFIG` temporal (`{}`), como hace `pets.py`.

## Rendimiento

Medición con `bar/tests/pets-performance.py`; resultados en `perf/phase2/`, comparados
con `perf/after-isolated/results.json`.

- **Escenarios nuevos:**
  - `flying`: un vuelo por segundo;
  - `coding`: medido tras el asentamiento;
  - `rail-idle`: estilo `pet`, sin cambios.
- **Límites:**

  | Escenarios | Límite |
  | --- | --- |
  | disabled, hidden, sleeping | ≤ 1 fps y 0 % CPU, como en fase 1 |
  | idle, rail-idle, coding asentado | ≤ 1.5 fps |
  | flying | CPU media < 2 %; fuera de los vuelos, como idle |

- **Memoria:** PSS idle ≤ fase 1 + 2 MiB.
- **Entorno:** antes de medir, comprueba que no queden procesos quickshell offscreen
  ajenos, porque sesgan los datos.

## QA visual real (DP-1)

Offscreen no basta. Captura con `grim -o DP-1` o con ráfagas `grim -g` en la zona de la
pill y del rail. Guarda hojas de contacto, no cada fotograma, en
`docs/eshell-pets-redesign-2026-10-23/qa-phase2/`. Casos:

- **Vuelos:** barra → launcher → barra. Media → launcher si el layout split lo permite.
- **Rail:**
  - brincos 1 → 2 y 1 → 5, en split y compact;
  - hover sobre otra celda;
  - punto activo oculto bajo Mimo.
- **Programa:** con una terminal enfocada.
- **Música:** baile de 8 s en la barra al reproducir. Para simular un reproductor sin
  música real, sirve un servicio MPRIS falso de prueba.
- **Travesuras:** con `mischief: frequent` y una configuración temporal.
- **Reduced motion:** el mismo recorrido.

Mira cada vuelo fotograma a fotograma. Si hay una superficie a mitad de morph cuando Mimo
aterriza, ajusta y explica el cambio. Usa
`.agents/skills/pill-frame-inspection/SKILL.md`.

## Entrega

- `TASK_STATE.md`: una sección «Eshell Pets: fase 2» con las decisiones, sobre todo las
  desviaciones de este documento. Incluye las pruebas con resultado, el rendimiento antes y
  después, la QA y los límites conocidos.
- `PROJECT_MEMORY.md`: actualiza la línea de Pets.
- **No declarar terminado sin:**
  - todas las pruebas en verde;
  - la medición;
  - la QA en DP-1.
- Distingue lo probado, lo no verificado y lo bloqueado.
- Después habrá una revisión independiente (Claude con isla-revisor) y QA visual propia
  antes de dar la fase por cerrada.
