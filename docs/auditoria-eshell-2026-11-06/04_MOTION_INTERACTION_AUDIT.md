# 04 · Auditoría de movimiento e interacción

Leyenda de evidencia: **[V]** verificado · **[I]** inferencia · **[X]** experimental.

Todo lo que no se pudo ver en pantalla está marcado. Las capturas de este informe son fotogramas estáticos; **no se grabó ni se midió ninguna transición en esta auditoría**. Los tiempos citados salen del código o de auditorías anteriores con medición (`docs/design-competition-2026-10-26/REPORT.md`).

## 1. Inventario cuantitativo [V]

| Mecanismo | Apariciones | Comentario |
|---|---|---|
| `Behavior on` | 397 | La herramienta dominante |
| `NumberAnimation` | 323 | — |
| `ColorAnimation` | 128 | — |
| `SmoothedAnimation` | 72 | Con `velocity: -1` suele hacer de "muelle barato" |
| `SpringAnimation` | 15 | Poco usado; los muelles reales son propios |
| `FrameAnimation` | 21 | Integradores propios (pill, gotas, LaunchFlight) |
| Animaciones infinitas | 11 | Todas condicionadas a visibilidad y `reduceMotion` salvo las excepciones de §5 |
| `Timer` repetitivos | 33 | 4 siempre activos (§5) |
| `states:` / `transitions:` | **0** | Todo el estado se hace con bindings y Behaviors |
| Duraciones literales frente a tokens | 106 / 350 | El 23 % salta el sistema |
| Curvas literales frente a tokens | 101 / 263 | El 28 % salta el sistema |

## 2. Motores de movimiento

| Motor | Archivo | Modelo | Calidad |
|---|---|---|---|
| **PillMorphMotion** | `components/PillMorphMotion.qml` | Muelle por eje (omega/zeta, `omegaFar`/`zetaFar` para grandes saltos), presets open/resize/close | **Excelente.** Conserva velocidad al redirigir y el overshoot está controlado. Es el corazón de la identidad [V] |
| **SpringValue** | `components/SpringValue.qml` | Muelle escalar reutilizable | Bueno, aunque infrautilizado [V] |
| **FluidCompanion** | 778 L | Muelle analítico (solución cerrada) | Muy bueno; no depende del `dt` [I] |
| **LaunchFlight** | 511 L | Euler semiimplícito, omega 12, zeta 0.9 | Bueno; un integrador más que mantener [V] |
| **InteractionMotion** | 40 L | Compresión con NumberAnimation y recuperación con SpringAnimation | Gramática de pulsación compartida y respetuosa con `reduceMotion` [V] |
| **Behaviors sueltos** | ~400 | Curvas de `Motion` o literales | Dispares; ahí está la deuda |

**Problema estructural:** hay cuatro integradores de muelle distintos (morph, escalar, analítico y Euler). No es un fallo visible, pero sí cuatro sitios donde puede divergir el "tacto" y cuatro sitios que ajustar si cambia la frecuencia de pantalla.

## 3. Calidad por tipo de movimiento

### 3.1 Morph de la pill (núcleo)

- **[V]** Los muelles retargetables permiten interrumpir una apertura con otra sin salto.
- **[V]** Con `dt` limitado a 1/30, a 20 Hz el t90 sube a ~400 ms y a 10 Hz a ~800 ms. Ya está medido en la auditoría del 2026-10-26 y sigue sin cambios en el código actual.
  - Bajo carga, la pill se vuelve "lenta" en vez de "saltar". Es una decisión defendible, pero conviene reflejarla en los criterios.
- **[V]** La entrada del contenido empieza al 12 % del morph (`openContentStart 0.12`) con una ventana de 28 %. Es correcto: el contenido no espera a que termine la forma.
- **[I]** Sin grabación no se puede afirmar si la geometría y el contenido se desincronizan al cerrar.

### 3.2 Selección y pestañas

- **[V]** `LiquidSelection` anima el borde de entrada (0.9 × standardSmall) y el de salida (0.95 × standardLarge) con Behaviors separados. El efecto "estirar y recoger" es bonito.
- **[I]** Un Behavior con `NumberAnimation` reinicia desde la posición actual con velocidad 0. Al pulsar pestañas rápido (Salida → Hardware → Entrada) el indicador frena y vuelve a arrancar. Solución nativa: `SpringValue` o `SmoothedAnimation velocity:-1` por borde.
- **[V]** Las pestañas del mezclador mueven su indicador con `x: page * width/4` (`MixerView.qml:102`). Es otra implementación, distinta de `LiquidSelection`.

### 3.3 Microinteracciones de control

| Control | Lo que hay | Calidad |
|---|---|---|
| Botones (`CtrlBtn`, `MotionArea`) | Compresión a 0.96, recuperación con muelle, pulso de confirmación al hacer clic, lavado de hover 0.035 | Buena y sobria [V] |
| Toggle | Pulgar con estiramiento líquido (`SmoothedAnimation` sobre `travel`) | Bueno; la forma del estiramiento no se pudo ver en vivo [I] |
| Slider propio | "Menisco" en la punta, rubber band con `SpringAnimation`, la pista engorda al agarrar | El más rico de la shell [V]. Con rueda o teclado no hay respuesta visual porque no hay rueda ni teclado |
| AudioFader | Controls.Basic, rubber band con `PointHandler`, `wheelEnabled: false` | Correcto, pero se siente "de otra app": pista de 6 px frente a 12/36 px en los demás [V] |
| Reloj | `ClockReel` (odómetro) y `RollingNumber` | Distintivo [V] |
| Error | `ErrorShake` | Correcto [V] |

### 3.4 Coreografía de notificaciones

`NotificationChoreography` usa colapso 160, expansión 260 y permanencia de 1000–2000 ms; la propuesta pendiente es bajar la permanencia de workspace de 1600 a 1100 [V].

La permanencia escala con la longitud del texto [I].

### 3.5 Lockscreen

`LockSurface.qml:170` usa `Easing.OutBack` con overshoot 1.6 [V]. Es el rebote más fuerte de la shell y contradice el principio aprobado (~3 %). Como es lo primero que se ve al despertar, el contraste es notable.

## 4. Coherencia del sistema temporal

| Token | Valor | Uso |
|---|---|---|
| press | 70 | compresión |
| hover | 120 | — |
| fast | 140 | — |
| standardSmall | 200 | — |
| standard | 250 | — |
| emphasized | 350 | — |
| standardLarge | 400 | — |
| morph | 420 | — |
| emphasizedLarge | 500 | — |
| breathe | 3000 | respiración |

**Diagnóstico:** son 10 duraciones más los presets de muelle. Para una shell bastan **4 duraciones** (micro 90, corta 180, media 280 y respiración) más **3 muelles** (firme, estándar y suave). Hoy conviven tres vocabularios: Material (`emphasized*`), Hyprland (`bounce`/`sling`) y propio (`morph`, `breathe`, `tidemark*`).

## 5. Riesgos de coste y de `reduceMotion`

| Hallazgo | Evidencia | Severidad |
|---|---|---|
| `NotifCardView` con capa y MultiEffect siempre activos | `NotifCardView.qml:131` `layer.enabled: true` [V] | Alta: es una textura extra por cada tarjeta de notificación del historial |
| Riel de workspaces con 3 capas MultiEffect | `TopWorkspaceRail.qml:126,197,267` [V] | Media: siempre visibles en la barra |
| `ConfirmationIndicator` con rotación infinita | `:91`, `running: root.animating` [V] | Baja: está condicionada |
| `BodyShader.qml` sin `reduceMotion` | 0 menciones [V]; falta ver si el tiempo lo congela `BodyEngine` [I] | Media para accesibilidad |
| `DeviceMomentCard.qml` sin `reduceMotion` | 0 menciones [V] | Baja |
| Timers siempre activos | PillContentAdapter:31 (1 s), TopSystemStatus:56 (15 s), Notifs:316, Nmcli:525/559 [V] | Baja; el de 1 s es el del reloj y está justificado |
| `IslandCompanion` con 63 duraciones literales | [V] | Media: no escala con `Motion.mult`, salvo que cada literal lo multiplique a mano [I] |

## 6. Interacción: lo que no se pudo verificar

- Hover, arrastre, gestos de tirar (`PillPullGesture`), rubber band y vuelo de lanzamiento **no se observaron en vivo**. Sin un controlador de entrada sintética fiable para Wayland en esta sesión, no se simularon.
- No se midió la latencia de entrada ni el tiempo de primer fotograma. El P1 abierto en PROJECT_MEMORY es que el primer fotograma del mezclador tarda 25–43 ms.

## 7. Oportunidades de movimiento (priorizadas)

1. **Pestañas y selección con muelle que conserva velocidad.** Un solo `SegmentedControl` sobre `SpringValue` sustituye `LiquidSelection` y los dos indicadores en línea. Es la mejora de tacto más visible por línea de código.
2. **Unificar el rebote.** `OutBack 1.6` del lockscreen pasa al preset de muelle estándar. Se ve en cada desbloqueo.
3. **Slider con respuesta a rueda y teclado** que reutilice el menisco: un paso de rueda produce un "tic" visible de la punta.
4. **`IslandCompanion` dentro de `Motion`.** Mismo carácter, pero con tokens: escala con `reduceMotion` y con el multiplicador global.
5. **[X] Continuidad entre barra y pill.** Al abrir conectividad desde el icono de red de la barra, la pill podría nacer desde la posición del icono (origen espacial), como ya hace `LaunchFlight` con el icono de la app.
6. **[X] "Tensión superficial" al cerrar.** Al soltar cerca del umbral de cierre del gesto de tirar, la pill podría vibrar (un único ciclo amortiguado) antes de decidirse. Hay que medirlo antes; el riesgo es el ruido.
