# QA visual y de movimiento de la shell completa — 2026-10-30

Auditoría de todas las superficies de Isla en vivo (DP-1, 1920×1080 a 240 Hz).
El objetivo es que el sistema se sienta premium, limpio, cómodo y propio.
Todo lo de aquí son **propuestas**: no se ha cambiado código.

## Veredicto en una línea

La forma es buena y ya tiene identidad: la isla brota, las gotas tienen peso
y el cierre es rápido. Lo que rompe la sensación premium es el **orden del
contenido**. La geometría llega antes que la información y durante 100–250 ms el
usuario ve un cristal vacío. A eso se suman siete defectos visibles que se pueden
arreglar en poco tiempo.

## Método y alcance

- **Ráfagas grim.** Cada superficie se capturó abriendo y cerrando por IPC
  (`qs -c bar ipc call island <fn> DP-1`), en ráfagas de 1,5 s, en el espacio 8
  vacío. Se capturaron unos 12,6 ms por fotograma, con muestreo irregular: sirve
  para ver orden y fases, **no prueba FPS**.
- **Superficies:** calendario, conectividad, mixer, media, notificaciones,
  portapapeles, ajustes rápidos, sesión, foco, grabación, espacios, launcher,
  overview, wallpaper y Edots.
- **Interacciones:** hover sobre la pill, popup de notificación, OSD de volumen,
  cambio calendario→mixer, cancelar 160–200 ms después de abrir y escritura en el
  launcher.
- **Auditoría estática** de tokens de movimiento, color y espaciado.
- **Estado restaurado:**
  - El volumen se subió y bajó un 2 % y volvió a 1,00.
  - El fondo no se tocó.
  - Se dejó una notificación de prueba («Isla QA / Copia completada») en el
    centro de notificaciones.
- **Sin verificar:**
  - Pantalla de bloqueo (no se bloqueó la sesión real).
  - Ruta reduce-motion.
  - Tema claro.
  - Multi-monitor.
  - Rendimiento real (FPS o frame time).
- **Skill find-skills (Vercel):** no está instalada. Las skills locales
  (fluid-island-motion, pill-frame-inspection, apple-inspired-ui y ui-animation)
  cubrieron la auditoría.

Las evidencias están en `evidence/`, recortadas al espacio vacío y sin ventanas
personales. Las tiras muestran el tiempo desde la llamada IPC.

## Mediciones (aproximadas)

| Superficie | Contenido legible | Movimiento termina | Cierre |
|---|---|---|---|
| Calendario | ~300 ms | ~400 ms | ~130 ms |
| Mixer | ~450 ms | ~560 ms | ~130 ms |
| Notificaciones | ~330 ms | ~450 ms | ~140 ms |
| Launcher | ~250 ms | ~340 ms | **~600 ms** |
| Overview | ~300 ms | ~450 ms | ~150 ms |
| Edots | ~390 ms (translúcido), ~590 ms nítido | ~600 ms | ~190 ms |
| Popup de notificación | **~600–700 ms** | ~700 ms | — |
| OSD de volumen (2.º cambio) | **~700 ms** | — | — |

Las mediciones automáticas por caja envolvente se contaminan porque los elementos
laterales se desvanecen al abrir. Las cifras salen de leer las tiras a mano y
tienen un margen de ±1 fotograma de ráfaga.

---

## P0 — Defectos visibles (arreglar primero)

1. **Los iconos del launcher salen como textura «faltante»**
   ([evidencia](evidence/01-launcher-iconos.jpg)).
   - **Qué se ve:** Firefox, Yazi, Micro, Zen, Discord, Wireshark, Qt Assistant y
     Btrfs Assistant salen con el damero magenta y negro. ChatGPT sí se ve.
   - **Dónde:** `bar/components/AppItem.qml:90` usa
     `Quickshell.iconPath(icon, "app-no-icon")`, junto con
     `//@ pragma IconTheme "hicolor"` en `bar/shell.qml:5`. TopAppStrip y
     PillContentAdapter usan en cambio la forma con comprobación,
     `iconPath(x, true)`.
   - **Pista, sin confirmar:** las apps que fallan tienen su PNG en
     `/usr/share/icons/hicolor/*/apps/`, y ChatGPT no está ahí.
   - **Propuesta:**
     1. Resolver con `iconPath(name, true)`.
     2. Si sale vacío, probar con `/usr/share/pixmaps`.
     3. Si sigue vacío, mostrar un monograma redondo (la inicial sobre el acento
        del sistema), nunca el damero.
   - **Tiempo:** unos 30 min con diagnóstico más una regresión.
   - **Por qué es P0:** el launcher es lo que más se usa, y un icono roto destruye
     la percepción de calidad al instante.

2. **El OSD se queda en blanco al repetirse**
   ([evidencia](evidence/02-osd-reactivacion.jpg)).
   - **Qué se ve:** un segundo cambio de volumen con el OSD visible deja la pill
     borrosa y vacía unos 450 ms. El chip «100 %» aparece hacia los 700 ms.
   - **Propuesta:** si el OSD ya está visible, actualizar el valor en su sitio, sin
     reentrar ni volver a difuminar. Añadir además una barra de nivel continua (la
     LevelStroke de Tidemark, hoy sólo probada offscreen) que siga al valor con un
     resorte corto.
   - **Tiempo:** 1–2 h.

3. **Al cancelar se ve contenido un instante**
   ([evidencia](evidence/03-cancelar-destello.jpg)).
   - **Qué se ve:** si se llama a `hide` 160–200 ms después de abrir, la superficie
     sigue creciendo, enseña contenido hacia los +288 ms y luego colapsa hacia los
     +438 ms.
   - **Propuesta:** el cierre invierte el resorte desde el estado actual. La
     opacidad del contenido tiene un umbral de compromiso: si se cancela antes de
     comprometerse, no llega a mostrarse.
   - **Estado:** plausible; falta repetirlo varias veces con pill-frame-inspection.
   - **Tiempo:** 2–3 h.

4. **Ruido en el centro de notificaciones.**
   - **Qué se ve:** 24 avisos repetidos de cambio de teclado («Español (ES)» /
     «Inglés (US)»).
   - **Propuesta:** el cambio de distribución va como OSD transitorio en la pill y
     no se guarda. Además, agrupar notificaciones repetidas de una misma app con un
     contador.
   - **Tiempo:** 1 h.

5. **El clima no usa caché.** Al reabrir el calendario sale «Consultando clima… /
   —» aunque ya había un dato (29°).
   - **Propuesta:** mostrar el último dato al instante (stale-while-revalidate),
     con un punto tenue mientras se actualiza.
   - **Tiempo:** 30 min.

6. **Ajustes rápidos muestra controles que no existen en un escritorio**
   ([evidencia](evidence/13-utils-escritorio.jpg)).
   - **Qué se ve:** «Brillo 0 %» sin retroiluminación, y «Energía: No se pudo leer
     el perfil» con chips desactivados.
   - **Propuesta:** ocultar cada control cuando su servicio no existe; no mostrarlo
     desactivado. Una superficie de ajustes sólo debe ofrecer lo que funciona.
   - **Tiempo:** 1 h.

7. **El área de estado da señales falsas.**
   - **Qué se ve:** un icono de wifi apagado en un equipo con cable, y un icono de
     batería sin etiqueta (probablemente los auriculares).
   - **Propuesta:** con Ethernet activo, mostrar el icono de cable o nada. La
     batería de un periférico lleva un glifo de dispositivo y un porcentaje en el
     tooltip.
   - **Tiempo:** 1 h.

---

## P1 — Gramática de movimiento: «el contenido llega con la forma»

Éste es el cambio con más impacto en la sensación de calidad. Hoy, cada apertura
pasa por tres fases ([calendario](evidence/04-calendario-apertura.jpg),
[mixer](evidence/05-mixer-apertura.jpg)):

1. Crece un cristal vacío (sólo los ojos de Iris y un brillo), de ~70 a ~200 ms.
2. El contenido aparece fantasmal y borroso.
3. El contenido es legible hacia los 300–450 ms.

El cerebro lee la fase vacía como «está cargando». Un sistema premium da la
sensación contraria: lo que pides ya estaba ahí, sólo se despliega.

### Reglas propuestas

1. **El contenido viaja dentro de la forma.**
   - El contenido se pinta desde el primer fotograma, recortado por la geometría
     que crece. No espera a que la geometría termine.
   - Arranca con escala 0,96 y opacidad 0,6, y llega a 1 con el mismo resorte.
   - Si hay desenfoque, se limita a los primeros 80 ms.
   - **Meta:** legible a ≤ 200 ms y asentado a ≤ 350 ms.

2. **La salida vuelve a su origen y dura la mitad.**
   - Toda superficie se cierra hacia el lugar del que brotó, con aceleración, en
     120–160 ms.
   - El launcher (~600 ms, porque viaja desde media pantalla
     ([evidencia](evidence/08-launcher-cierre.jpg))) debe bajar a ~180 ms.
     Opciones: encogerse y desvanecerse en el sitio mientras la isla «lo absorbe»,
     o que su viaje sea más corto.

3. **El cambio entre superficies es un morph con fundido cruzado.**
   - De calendario a mixer hoy se pasa por un cristal vacío hacia los +195 ms
     ([evidencia](evidence/06-swap-calendario-mixer.jpg)).
   - **Propuesta:** el contenido saliente se va en 90 ms. El entrante empieza al
     40 % del morph, alineado arriba a la izquierda, sin centrar ni saltar.

4. **Interrumpir siempre funciona.** Cualquier gesto invierte desde el estado
   actual (ver P0-3). No hay animaciones que haya que «dejar terminar».

5. **El desenfoque se introduce gradualmente.**
   - El fondo del overview pasa de nada a desenfoque completo en un salto, entre
     +34 y +71 ms ([evidencia](evidence/09-overview-apertura.jpg)).
   - **Propuesta:** atar el radio y el oscurecimiento al progreso, con una rampa de
     180 ms. Así el fondo «se aleja» en vez de taparse de golpe.

6. **La información urgente llega en ≤ 250 ms.**
   - Hoy el popup de notificación difumina la pill, la encoge a un punto (~250 ms)
     y después hace crecer la tarjeta, que es legible hacia los 600–700 ms
     ([evidencia](evidence/07-notificacion-popup.jpg)).
   - **Propuesta:** la notificación brota como gota junto a la isla, igual que
     media y sesión ([sesión](evidence/14-sesion-gota.jpg)). La pill conserva su
     contenido. El título se lee a ≤ 250 ms.
   - Es el mismo lenguaje que ya funciona y además es el más propio del sistema.

7. **El hover revela; nunca quita.**
   - Hoy, al pasar el ratón por la pill, el «8» del espacio desaparece y la pill
     encoge tras 400–800 ms ([evidencia](evidence/10-hover-pill.jpg)). Eso se lee
     como un error.
   - **Propuesta:** el hover agranda la pill 2–4 px y añade información, por
     ejemplo el nombre del espacio o la próxima acción. No retira nada.

### Tokens resultantes (propuesta)

| Uso | Token | Valor orientativo |
|---|---|---|
| Entrada de superficie | `Motion.surfaceSpring` (ya existe) | ~3 % de rebote, asentado a ≤ 350 ms |
| Contenido en entrada | `Motion.contentReveal` | 0,96→1 y opacidad 0,6→1, mismo resorte |
| Salida | `Motion.exit` | 140 ms, curva acelerada única |
| Fundido cruzado de contenido | `Motion.crossfade` | sale en 90 ms, entra al 40 % |
| Hover | `Motion.hover` (único) | 120 ms |
| Rampa de desenfoque | `Motion.blurRamp` | 180 ms ligada al progreso |

---

## P1 — Material y legibilidad

1. **El cristal deja pasar demasiado color.**
   - Sobre fondos saturados (el sol magenta del fondo actual), el color atraviesa
     el calendario, el mixer y las notificaciones. Los números y el texto
     secundario pierden contraste.
   - Edots se ve igual durante su entrada
     ([evidencia](evidence/11-edots-apertura.jpg)).
   - **Propuesta, «cristal adaptativo»:**
     1. Muestrear la luminancia y el croma del fondo bajo la superficie al cambiar
        de fondo (una vez, no por fotograma).
     2. Subir la opacidad del tinte hasta asegurar 4,5:1 para el texto.
     3. Desaturar el desenfoque en zonas de croma alto.
   - El cristal debe dejar ver que hay fondo, nunca qué color tiene detrás de una
     cifra.

2. **El texto en tránsito no debe verse fantasmal.** Con la regla P1-1 de
   movimiento, la opacidad del contenido alcanza 1 antes que la geometría. Esto
   elimina la fase de fantasma.

3. **Una sola profundidad.** Las superficies que brotan de la isla comparten
   sombra y borde. Edots, que es una ventana mayor, puede tener un nivel más de
   sombra, pero el mismo borde interior.

---

## P2 — Arquitectura de información

1. **El launcher abre vacío.**
   - Hoy es una barra de búsqueda a 1/3 de altura y no muestra nada hasta que se
     escribe.
   - **Propuesta:** al abrir, enseñar 6–8 apps recientes o frecuentes y 2–3
     acciones (fondo, ajustes, foco). Así abrirlo ya es útil, sin teclear.

2. **Media vacío ocupa 720×440 para decir «Ningún medio disponible»**
   ([evidencia](evidence/12-media-vacio.jpg)).
   - **Propuesta:** un estado compacto (una gota pequeña) con «Reanudar <último
     reproductor>» o un acceso a la app de música. Un estado vacío nunca debe ser
     la superficie más grande del sistema.

3. **El espacio de trabajo se indica dos veces:** el carril de puntos a la
   izquierda y el «8» en la pill.
   - **Propuesta:** elegir uno. Recomendación: el carril de puntos, que es espacial;
     la pill queda para el contexto (la app activa o media).

4. **Los elementos laterales se desvanecen al abrir cualquier superficie**
   (launcher, carril y estado). Desorienta, porque el sistema «se apaga» cada vez.
   - **Propuesta:** atenuarlos al 60 % en vez de ocultarlos, o dejarlos fijos.

5. **El centro de notificaciones necesita jerarquía.**
   - Agrupar por app.
   - Mostrar lo más reciente arriba y expandido; lo demás plegado.
   - Ofrecer «Borrar todo» en el encabezado.

---

## P2 — Coherencia de tokens (auditoría estática)

1. **Curvas.**
   - Hay 4 familias de entrada (emphasizedDecel, morphCurve, easeStandard y
     OutBack).
   - Las salidas no son coherentes: InCubic en Lock, standardAccel en
     EdotsComboBox y OutCubic en el resto. **Una salida no debe usar una curva
     Out.**
   - IslandCompanion tiene 67 duraciones y 53 curvas literales fuera de `Motion`.
   - **Propuesta:** dos familias, entrada por resorte y salida acelerada, más los
     tokens de la tabla anterior.

2. **Hover:** `Motion.fast` tiene 167 usos y `Motion.hover` 59. Hay que dejar sólo
   `Motion.hover`.

3. **Escalas:** `Theme.scaleHover` y `Theme.scaleActive` no tienen ningún uso, y
   los archivos escriben sus propios valores (1,025, 1,24, 0,97). Hay que usar los
   tokens.

4. **Colores duplicados:**

   | Rol | Valores en uso | Unificar en |
   |---|---|---|
   | Éxito (verde) | #32d975 (Theme), #30d158 (BatteryIndicator), #34c759 (WallpaperApplyFeedback) | `Theme.success` |
   | Peligro (rojo) | #b83249 y #ff8896 (AuthPromptView), #ff4d61 (Theme) | `Theme.danger` |

5. **Edots y otros puntos:**
   - Los archivos de Edots usan su propio espaciado y radios, y 104 tamaños de
     fuente literales tienen un token equivalente que no se usa.
   - ReceptionPulse lee `Flags.motionScale` e ignora reduceMotion.
   - «⇪» es un icono unicode (`IslandRestStatus:101`).
   - Varias MouseArea no tienen estados de hover ni de pulsación:
     `LockSurface:155`, `QuickControlsView:38`, `LyricsView:235` y el TapHandler
     de `UpdateSourceCard`.

---

## P3 — Identidad propia (ideas, sin copiar a nadie)

Lo propio del sistema ya está ahí: **la isla es el único origen**. Todo brota de
ella y vuelve a ella, y las gotas tienen masa. Las propuestas refuerzan esa idea en
vez de añadir adornos.

1. **«Todo brota de la isla» como ley.**
   - Hoy media y sesión son gotas, y el resto crece desde la pill.
   - Las notificaciones, el OSD y los avisos de teclado también deberían brotar.
     Nada aparece de la nada en otro punto de la pantalla.

2. **Marea de contexto.**
   - El tinte del cristal toma, muy desaturado, el color dominante de lo que hay
     dentro: la portada en media, el fondo en reposo.
   - Cambia despacio (~600 ms) cuando cambia el contexto.
   - Da una firma reconocible sin logos ni mascotas.

3. **Peso según importancia.**
   - Lo informativo (OSD, cambio de teclado) brota como gota pequeña y ligera, con
     poco rebote.
   - Lo que pide acción (autenticación, batería crítica) es más grande, con más
     masa y una pulsación lenta.
   - El usuario aprende a distinguir lo urgente por el movimiento, antes de leer.

4. **Silencio por defecto, sonido opcional.** Un set mínimo de 3 sonidos (abrir,
   confirmar, alerta), apagado de fábrica y configurable en Edots.

5. **Iris en segundo plano.** Hoy sus ojos están en la esquina de todas las
   superficies y son lo único visible durante la fase vacía, así que se vuelven la
   cara del sistema por accidente.
   - **Propuesta:** sacarla de las superficies y dejarla como compañera opcional en
     reposo, mientras se decide su forma definitiva.
   - El sistema no debe depender de ella para sentirse vivo.

---

## Hoja de ruta propuesta

| Fase | Contenido | Tiempo orientativo |
|---|---|---|
| 1 | P0-1 a P0-7 (defectos) | 1–2 días |
| 2 | Gramática de movimiento (contenido con la forma, salidas, fundido, rampa de desenfoque) | 3–4 días con QA fotograma a fotograma |
| 3 | Notificación y OSD como gotas, y hover que revela | 2 días |
| 4 | Cristal adaptativo y arquitectura de información (launcher, media vacío, espacio duplicado) | 2–3 días |
| 5 | Unificación de tokens (curvas, hover, colores, Edots) | 1–2 días, mecánico (delegable) |
| 6 | Experimentos de identidad (marea de contexto, peso según importancia, sonido) | iterativo |

## Pendiente de verificar

- **Pantalla de bloqueo:** hace falta una vista previa o un fixture para no
  bloquear la sesión real.
- **Ruta reduce-motion:** probar con un `ISLA_CONFIG` temporal.
- **Tema claro y fondos claros:** comprobar el contraste del cristal.
- **Rendimiento:** medir el frame time con qmlprofiler, no con ráfagas.
- **P0-3 (destello al cancelar):** repetirlo para confirmarlo.

## Correcciones aplicadas (2026-10-30)

| Defecto | Estado | Prueba |
|---|---|---|
| Iconos del launcher vacíos (pragma IconTheme hicolor) | Corregido (`bar/shell.qml`) | Captura en vivo tras reinicio |
| OSD en blanco al re-disparar | Corregido (`PillHeaderView.qml`, `restResizing`) | Ráfaga grim: contenido estable |
| Avisos efímeros de teclado persistían en historial | Corregido (`NotifData.ephemeral`, `Notifs.qml`) | Contador Teclado estable tras 2 cambios |
| Clima "Consultando…" en cada apertura | Corregido (`CalendarData.qml`, caché en disco `weather-last.json`) | Captura a 350 ms: clima visible + "Actualizando…" |
| Utils: brillo 0% con panel interno apagado y perfil de energía deshabilitado | Corregido (`Brightness.qml` exige bl_power=0 y re-detecta al abrir; `showProfile` oculta Energía sin daemon). Queda alto fijo 420 px con huecos | Captura en vivo + quick-controls y calendar-data PASS |
| Barra de estado: wifi-off en equipo cableado | Corregido en código (`TopSystemStatus` sondea Ethernet, `TopNetworkStatus` muestra `lan`) | No verificado en vivo (zona no visible en reposo); regresiones PASS |
| Icono de batería de periférico sin etiqueta | No localizado (TopSystemStatus ya exige batería de portátil) | — |
| Parpadeo de contenido al cancelar | **No verificado** | — |

Skill find-skills instalada (`~/.agents/skills/find-skills`); búsquedas quickshell/qml sin resultados útiles, ninguna instalada.

## P1 de movimiento (2026-10-30, segunda pasada)

| Mejora | Estado | Cambio | Prueba |
|---|---|---|---|
| P1.1 Contenido llega con la forma | Aplicado | `Motion.openContentStart/Span` (revelado 12–40 % del crecimiento, antes 45–80 %); `materializeScale` 0,96; `materializeBlur` 0,4 | motion, layout-interruptions, compact-island, surface-materialize PASS. Ráfaga grim: calendario legible mientras la forma aún crece (fotograma 7); quedan ~3 fotogramas de cristal vacío por la carga asíncrona del Loader |
| P1.2 Cierre del launcher más corto | Aplicado | `Motion.launcherCloseResults` 120 ms + `launcherCloseReturn` 250 ms (antes 250 + 420), enlazados en `ShellRuntime.qml` | surface-router, launcher-controller, launcher-pending, content-hold, pill-composition PASS. Sin ráfaga en vivo del cierre |
| P1.3 Crossfade en swap | Aplicado (parcial) | `Motion.crossfadeOut` 90 ms para el contenido saliente (`PillSurfaceHost`) | motion + surface-materialize PASS. Ráfaga calendario→mixer: persisten ~3 fotogramas de cristal vacío (carga asíncrona + `loadReveal` 200 ms) |
| P1.4 Rampa de desenfoque | No aplicable por ahora | El blur lo aplica Hyprland 0.57 (`layer_rule blur`, `ignore_alpha`) con intensidad fija; no hay primitiva para rampar su radio por capa. Subir/bajar `decoration:blur:size` con `hyprctl keyword` por pasos sería global (afecta a todas las ventanas) y costaría un proceso por paso: descartado | — |
| P1.5 Notificación | Aplicado | La notificación informativa brota como gota bajo la pill con `FluidCompanion` (`notificationCompanion`, `centered`+`below`, `springRate` 1,5): la pill conserva su contenido y la superficie abierta no se suspende. Las críticas conservan el morph que interrumpe. Flag `appearance.notificationDrop` (Settings.js, defecto `true`); en `false` vuelve al ciclo círculo→píldora. Cola, DND y `NotificationChoreography` sin cambios | notification-attention/breath/priority/regression/routing, notifs-surface, companion-continuity, centered/settings/session-companion, config, settings*, layout-interruptions, motion y nueva `notification-drop-regression` PASS (legible en 201 ms simulado). Ráfaga grim en ws 8 (~22 ms/fotograma): gota visible a 25 ms y título legible en ~150–175 ms; retorno recoge→sube→absorbe sin artefactos. No verificado: crítica en vivo, DND en vivo, monitor secundario ni apertura de superficie durante la gota |
| P1.6 Hover | Descartado como defecto | El «8» que desaparecía era `workspaceFlash` (aviso de workspace, 1,6 s), no el hover. Verificado en vivo: con el cursor sobre la pill (tras 3,5 s en ws 8) la pill no cambia ni quita nada | Ráfaga grim con cursor sobre la pill |
| P1.6 Cristal adaptativo | Aplicado | `Theme.glassChromaLift` (0–0,10 según saturación del acento del wallpaper) suma a `PillMaterial.bodyAlpha` (40 % en reposo, 100 % al leer) | pill-interface PASS (esperados ajustados a la nueva fórmula). No verificado el contraste 4,5:1 ni tema claro |
