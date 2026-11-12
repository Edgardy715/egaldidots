# Plan · Lenguaje de trazo para toda la pill (borrador, sin implementar)

2026-10-30. Sesión de plan: no se tocó código. Esperando aprobación.

## 0. Identidad propia: "Tidemark" (nombre de trabajo)

Rasgos que lo hacen Isla y no otra cosa:

- **El trazo es el mismo líquido que la pill.** Se dibuja con una *cabeza* que
  lidera (punta redonda, algo más gruesa que el cuerpo) y deja la cola fina. Se
  traza como un hilo que cae, no como un wipe uniforme. Apple traza con ancho
  constante; Material morfa rellenos. Aquí hay cabeza y cola.
- **Color del acento dinámico del wallpaper** en reposo; color de señal
  (verde/rojo) sólo al resolver. Ningún otro sistema colorea el trazo con el
  fondo del usuario.
- **Respira con la pill.** La espera usa `Motion.easeBreathe` y la fase de
  `ConfirmationIndicator` (1100 ms); no hay otros ritmos de espera.
- **Resolución = cierre + brillo breve + calma.** Un solo brillo por evento.
- **Punta redonda, grosor ~2/24 en iconos y 0.045–0.055 del diámetro en anillos.**
  Nunca esquinas vivas ni rellenos mezclados con trazo.

Prueba "¿parece de otro sistema?": un wipe uniforme, un morph relleno o un
rebote = descartar.

## 1. Inventario (conclusiones; archivo:línea del explorador)

Hecho clave: `ShapePath.trim` ya se usa en `ConfirmationIndicator.qml` (símbolo,
L111–131) y `AnimatedSymbol.qml` (L87). El resto de arcos usa `PathAngleArc`
(IslandMediaCover L89–95, TopWorkspaceRail L204). Qt instalado: 6.12.0
(los docs del repo citan 6.11.2).

| Surface | Hoy | Hueco frente al lenguaje |
| --- | --- | --- |
| VolumeChip / OSD (`VolumeChip.qml:43-107`, `OsdOverlay.qml:49-135`) | barra Rectangle + glifo que *cambia* por umbral (swap) | nivel no es trazo; glifo no conserva el altavoz |
| MediaTransportButton (`:35-106`) | cookie 500 ms + swap de icono | el símbolo play/pause salta |
| FocusTimerView (`:115-125`, `:241`) | barra lineal 1 s + swap play/pause | progreso no es trazo; swap sin morph |
| BatteryIndicator (`:35-83`) | Rectangle de relleno + rayo opacity/scale | rayo no se dibuja |
| ConnectivityView (`:148-230`) | swap wifi/bluetooth | wifi on/off sin des-trazar |
| LockSurface (`:177`) | swap lock/lock_open | el shackle ya existe como pieza: ideal para morph |
| ClipboardEntryRow (`:129`) | swap check/add | morph barato |
| MixerView/AudioEndpoint (`:99`, `:223`) | swap mic/música; medidor sin token | medidor = LevelStroke |
| Notificaciones, Launcher, Calendario, Overview, Wallpapers | iconos fijos / color | sólo hover existente; no tocar |
| Slider, scroll de volumen/brillo/wallpaper/letras, hover, avance de canción | frecuentes | **no animar más** |

Corrección al explorador: dijo "no hay trim en bar/"; es falso (ver arriba).
Cobertura de swaps: todos son crossfade de `MaterialIcon`, salvo el cookie.

## 2. Propuesta por interacción (disparador → reglas → feedback → bucle/modo)

Principios: P1 se dibuja, P2 un objeto/muchos estados, P3 trazo=medida, P4 espera
respira/resultado poco, P5 interrumpible con memoria.

| # | Interacción | Principio | Cómo se ve | Tokens |
| --- | --- | --- | --- | --- |
| 1 | OSD/VolumeChip: glifo de volumen | P2 | altavoz fijo; las ondas se trazan/des-trazan al cruzar umbral; mute = barra diagonal que se dibuja desde la esquina superior | `iconSwap`, `fast` |
| 2 | OSD nivel | P3 | arco/línea de nivel con `trim.end` sobre pista tenue; **sin animar cada paso** (sigue `shownValue`); cabeza sólo al subir | `fast` |
| 3 | FocusTimer play↔pause | P2, P5 | las dos barras de pausa nacen del triángulo conservando el trazo común | `standard` |
| 4 | FocusTimer progreso | P3 | anillo/línea `trim.end` = `session.progress`; en 0 respira; al acabar cierra + brillo | `standard`, `heat` |
| 5 | Lock↔unlock | P2 | cuerpo fijo, shackle sube y se redibuja (ya hay rol `shackle`) | `standard` |
| 6 | Wifi/BT on/off | P1 | ondas se trazan en orden desde el punto; off = des-trazo + barra | `iconSwap` |
| 7 | Batería (rayo, nivel) | P1, P3 | rayo se dibuja al conectar; nivel como relleno trazado bajo umbral bajo | `fast` |
| 8 | Portapapeles guardar (check/add) | P2 | `+` → check por morph | `iconSwap` |
| 9 | Medidor del mezclador | P3 | LevelStroke vertical; sin animar muestras | ninguno |
| 10 | Media play/pause | P2 | el símbolo morfa con la misma pieza; cookie intacto | `emphasizedLarge` ya existe |
| 11 | Resultados (éxito/error/cancelado) | P4 | ya existe: se reutiliza | — |

**No animar:** hover repetido, scroll de volumen/brillo/wallpaper/letras, avance
continuo de canción, teclado de búsqueda, iconos fijos (campana, lupa, cerrar),
cualquier cosa oculta. reduceMotion → estado final directo.

## 3. Piezas reutilizables

1. **`TraceSymbol`** (sobre `AnimatedSymbol`): recibe `iconName`; al cambiar,
   compara partes del catálogo `AnimatedIconData.js`; conserva las comunes
   (misma geometría), des-traza (`trim.end→0`, `fast`) las que sobran y traza
   (`standard`) las nuevas. Sustituye el doble `AnimatedSymbol` actual de
   `MaterialIcon` (old+current) por una instancia → menos Shapes.
2. **`LevelStroke`**: `value 0..1`, `shape: arc|line`, pista tenue + trazo con
   `trim.end`, cabeza opcional. Para OSD, batería, temporizador, mezclador.
3. **Tokens en `Motion`**: `strokeDraw` (=`standard`), `strokeErase` (=`fast`),
   `strokeStagger` (0.06 ya literal en AnimatedSymbol), `strokeGlow` (intensidad).
   **Theme**: `signalSuccess/signalError` (hoy `#32d975/#ff4d61` literales en
   `ConfirmationIndicator`), `strokeWidth` relativo; todo × escala `s`.
4. Datos: ampliar `AnimatedIconData.js` con roles `morph-key` para pares
   (volumen niveles, play/pause, lock, add/check).

## 4. Fases (tiempos para el implementador)

- **Fase 0 · Fundación (~1,5 h):** tokens Motion/Theme, `LevelStroke`, regresión
  nueva `stroke-language-regression.qml` (trim final, interrupción, reduceMotion,
  oculto=quieto).
- **Fase 1 · Piloto visible (~3 h):** (a) glifo de volumen del OSD (#1) con
  `TraceSymbol`; (b) FocusTimer play↔pause + anillo (#3, #4); (c) lock↔unlock (#5).
  Aceptación: ve en vivo los tres; interrumpir a mitad parte del estado actual;
  reposo sin ningún timer nuevo; `confirmation-indicator`, `motion`,
  `interaction-regression`, `lockscreen`, `osd` pasan.
- **Fase 2 · Extender (~3 h):** wifi/BT (#6), portapapeles (#8), batería (#7),
  mezclador (#9), play/pause media (#10). Aceptación por fila + sus regresiones.
- **Fase 3 · Cierre (~1,5 h):** auditoría con `pill-detail-audit`, medición
  `qt-qml-profiler`, texto propuesto para `MOTION_LANGUAGE.md`/skill.
- Revisión independiente (isla-revisor) tras fase 1 y fase 3. Quien escribe no revisa.

## 5. Riesgos y presupuesto

- Reposo: cero Shapes/layers/timers nuevos (todo con `visible`/`exposed`).
- `layer`+`MultiEffect` sólo mientras un trazo resuelve (≤1 vivo por surface),
  nunca en bucle. Ya hay layers permanentes ajenos (NotifCard L131, LockSurface L198)
  y LyricsView por línea: no se tocan, pero se anotan como deuda.
- `MaterialIcon` hoy instancia old+current (≈8–12 Shapes en un swap); `TraceSymbol`
  lo baja.
- Riesgo: `trim` y `PathAngleArc` en la misma pila; el cierre de anillo depende de
  `ringOrigin` (frágil: `resync` ya tuvo un choque de nombre con `update`).
- OSD ya se re-dispara por cada paso de rueda: sólo el glifo-umbral anima, no el nivel.
- No se tocan `PillMorphMotion`, gotas ni respiración.

## 6. Preguntas para ti (gusto/producto)

1. ¿Te gusta el nombre "Tidemark" o prefieres otro?
2. ¿Cabeza más gruesa que la cola (rasgo propio) o trazo de ancho uniforme (más sobrio)?
3. Nivel del OSD: ¿arco alrededor del glifo o línea horizontal como ahora?
4. ¿El piloto de la fase 1 es el que quieres ver (OSD, temporizador, lock)?
