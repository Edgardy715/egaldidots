# 10 · Recomendaciones finales

Leyenda de evidencia: **[V]** verificado (código, captura o documentación) · **[I]** inferencia · **[X]** experimental.

Este documento responde a las preguntas finales del encargo y ordena las 10 mejoras de mayor valor. **No se ha implementado nada.**

---

## 1. Respuestas a las preguntas finales

### 1.1 ¿Qué es lo mejor del diseño actual y debe conservarse?

1. **El motor de forma de la pill.** `PillMorphMotion` es un integrador ω/ζ propio que conserva la velocidad al redirigir y limita dt a 1/30 [V]. Su muelle (~3 % de overshoot, 90 % a ~260 ms) cae en el rango de producto de las mejores referencias (ω 17–26, ζ 0,7–1,0; doc 05) [V/I]. `SpringAnimation` de Qt no llega a ω 22–26 ni se parametriza por ζ [V-código], así que **el integrador propio está justificado y debe quedarse**.
2. **La materia líquida.** El SDF compartido de gota y cuello (`body.frag`, W3/W4) es la firma más original de Eshell. Ninguna de las seis bibliotecas tiene un equivalente [V].
3. **Matugen como única fuente de color.** El acento se lee como un *estado* y no como decoración en la mayoría de surfaces [V captura].
4. **Hit target fijo.** El patrón de `CtrlBtn`, donde la zona de clic no se mueve con la animación, es correcto y debe pasar a regla del kit [V].
5. **Piezas ya accesibles.** `SwiftMediaTimeline` (teclado y `Accessible`), `RollingNumber`, `SurfaceHeader` (9 vistas) y `Theme.concentric()` [V].

### 1.2 ¿Qué componentes se sienten demasiado genéricos?

- **Toggle:** proporción iOS con estado "off" de Material 3 (pulgar gris pequeño y contorno). En conectividad el "off" tiene poco contraste [V captura].
- **Tarjetas del mezclador:** tarjeta dentro de tarjeta y combos con fondo propio. Parece un panel de ajustes cualquiera [V captura].
- **Estados vacíos:** el glifo con raya diagonal de Wi-Fi apagado es un icono de sistema sin acción [V captura].
- **Campo del launcher:** borde de acento tipo M3 `OutlinedTextField` [V captura].
- **Calendario:** rejilla estándar con mayúsculas mezcladas ("DO LU" frente a "vie sáb") [V captura].

### 1.3 ¿Qué elementos muestran influencia de Material You u otras?

| Influencia | Dónde | Evidencia |
|---|---|---|
| Material You (nombres) | Roles de `Theme` (`primaryContainer`, `onSurfaceVariant`, `tonalFill`), `emphasizedDecel/Accel` | [V] |
| Material You (forma) | "Off" del toggle, borde de foco del campo, ripple implícito en algunos botones | [V/I] |
| iOS / Apple | Proporción del switch, pill como Dynamic Island, `scaleHover` 1.03 | [V] |
| Swiftify | Surface de media (excepción aprobada) | [V] |
| Juego retro | Indicador "pacman" del riel de workspaces | [V] |

La dependencia de Matugen es **de compatibilidad, no de identidad**: Eshell puede seguir consumiendo los roles M3 sin parecer M3 si renombra sus tokens (doc 07 §2) y evita las formas M3 (doc 03 §5).

### 1.4 ¿Qué podría reinterpretarse para una identidad más original?

1. **Toggle gota:** la pista se llena desde el pulgar como un líquido y el pulgar lleva una marca de estado (doc 06 §3B).
2. **Slider de tubo:** la pista es el control y el menisco aparece al agarrar (doc 06 §2B).
3. **Indicador "gota viajera":** compartido por pestañas y riel de workspaces (doc 06 §4–5).
4. **Origen espacial:** la surface nace desde el icono de la barra que la abrió, no siempre del centro [X] (doc 09 #18).
5. **Estados vacíos con acción** y una carga de tres puntos que respiran en vez de spinner (doc 06 §10).

### 1.5 ¿Qué componentes tienen las mayores oportunidades de refinamiento?

Por orden: **slider** (4 implementaciones, la propia sin accesibilidad), **botones** (5 familias), **pestañas** (2 implementaciones en línea), **superficies** (anidación) y **toggle** [V].

### 1.6 ¿Qué patrones de las seis bibliotecas encajan de verdad?

Detalle en doc 05 §Síntesis. En resumen:

| Patrón | Fuente | Encaje |
|---|---|---|
| Muelles con nombre por rol + regla de frecuencia | Animate UI | ★ Alto |
| Indicador deslizante que conserva velocidad | Motion Primitives AnimatedBackground, React Bits RubberSegment | ★ Alto |
| Estiramiento por velocidad con conservación de área | React Bits SquishSwitch | Alto |
| Slider: clic animado, arrastre directo, umbral de 3 px | Animate UI | Alto |
| Reduced motion = conservar fundidos, quitar desplazamiento | Animate UI, Apple HIG | ★ Alto |

**No encajan:** spotlights con blur, glow, beams, partículas, tilt 3D, ripple, gooey por filtro, tabs rebotones de Aceternity y estilos de Uiverse. Aceternity y Magic UI son material de landing; casi nada es transferible a una shell [V-código].

### 1.7 ¿Qué animaciones deben mejorar?

1. **Selección / pestañas:** `LiquidSelection` usa Behaviors de `NumberAnimation` por borde y probablemente pierde la velocidad al redirigir [I]. Pasar a `SpringValue`.
2. **Lockscreen:** `OutBack` 1.6 es un rebote fuera del sistema (~3 % aprobado) [V]. Pasar a `spring.standard`.
3. **IslandCompanion:** 63 duraciones y 53 curvas literales que ignoran `Motion.mult` [V]. Tokenizar sin cambiar su carácter.
4. **Movimiento reducido:** `BodyShader` y `DeviceMomentCard` no consultan `reduceMotion` [V]. En `reduceMotion` debe haber fundido, no solo animaciones más cortas.
5. **Hover con escala:** `Theme.scaleHover` 1.03. Animate UI y la HIG desaconsejan animar interacciones muy frecuentes; en escritorio el hover con escala es ruido [I].

### 1.8 ¿Qué interacciones nuevas merecen la pena?

- **Rueda sobre el riel** para cambiar de workspace y sobre cualquier slider [I: hoy no existe en `Slider.qml`, V].
- **Teclado completo en Overview** (hoy 0 `Keys` y 0 `Accessible`) [V].
- **Clic en la pista = salto animado; arrastre = directo** en el slider (Animate UI).
- **Flick en el segmented** (React Bits RubberSegment).
- **Agrupar notificaciones por app** con pila que se abre con muelle (doc 06 §9B).

### 1.9 ¿Qué componentes deberían volverse reutilizables?

Las 12 primitivas del doc 07 §3. Las cinco con más retorno:

1. `IslaSlider`
2. `IslaButton`
3. `SegmentedControl`
4. `ListRow`
5. `StateView`

### 1.10 ¿Qué cambios dan más ganancia visual con menos coste de rendimiento?

| Cambio | Ganancia | Coste |
|---|---|---|
| Regla de un solo nivel de superficie | Alta (limpieza inmediata) | Negativo: menos rectángulos |
| Retirar las 3 capas `MultiEffect` del riel | Media | Negativo: menos texturas offscreen |
| Capa de `NotifCardView` solo al deslizar | Ninguna visible | Negativo: una FBO menos por tarjeta |
| Un solo borde en `PillMaterial` | Media | Negativo leve |
| `SegmentedControl` sobre `SpringValue` | Alta en tacto | Neutro |
| Lockscreen con `spring.standard` | Media | Neutro |

`layer.enabled` y `MultiEffect` crean una textura offscreen cada uno [V-doc Qt]. Por eso quitarlos es la mejora más barata.

### 1.11 ¿Qué decisiones actuales bloquean la coherencia?

1. **No hay kit:** cada vista reimplementa botones, pestañas, sliders y estados [V].
2. **Tokens con nombres M3 y literales:** 19 alfas, radios duplicados (Sm=Md, Lg=Xl) y 106 duraciones literales [V].
3. **`time12h` se aplica solo a calendario y lockscreen:** la pill muestra "9:16 PM" mientras el calendario muestra "21:18" [V]. `Settings.js:37` lo documenta como intencionado, pero se percibe como fallo.
4. **`IslandCompanion` vive fuera de `Motion`** [V].
5. **`Pill.qml` tiene 941 líneas:** la pieza central es la más difícil de tocar sin regresiones [V].

### 1.12 ¿Cómo debe evolucionar Eshell para sentirse un producto diseñado y no una colección de widgets?

1. **Una frase de identidad y cinco principios** que decidan los casos dudosos (doc 07 §1): *materia líquida oscura que toma el color de tu fondo*.
2. **Un vocabulario propio** (`space`, `shape`, `type`, `tone`, `ink`, `signal`, `time`, `spring`, `curve`) sobre los roles de Matugen, con alias primero y retirada después.
3. **Un kit de 12 piezas** en `bar/kit/` con previsualización en tres paletas y un test de literales que falle en CI.
4. **Una sola voz expresiva:** la gota. Todo lo demás es cápsula o rectángulo concéntrico y callado.
5. **Medir antes de embellecer:** fase 0 de memoria y fotogramas (doc 08) y regresiones por primitiva.

Hoy Eshell **se reconoce en movimiento, no en reposo** (doc 03). El objetivo es que una captura fija también se reconozca.

---

## 2. Top 10 por valor de producto

El orden sigue el valor para el producto, no lo llamativo.

| # | Mejora | Por qué ahí | Prior. | Complejidad |
|---|---|---|---|---|
| 1 | **`IslaSlider` accesible** sobre `Controls.Slider` (sustituye a 4) | El control más usado (volumen, brillo). Hoy no tiene teclado, rueda ni lector [V]. Une accesibilidad, coherencia y tacto en una sola pieza | P0 | L |
| 2 | **Formato de hora coherente** | Dos formatos a la vez en pantalla parecen un fallo [V]. Cuesta menos de 2 h y quita confusión diaria | P0 | S |
| 3 | **Capa de `NotifCardView` solo al deslizar + medir memoria** | Una FBO por tarjeta [V]; RSS de 684 MB frente a 515 MB anteriores [V]. Mejora el rendimiento y protege la estabilidad | P0 | S + M |
| 4 | **`SegmentedControl` sobre `SpringValue`** | La mejora de tacto más barata; elimina dos implementaciones en línea [V] y la pérdida de velocidad [I] | P1 | M |
| 5 | **Un solo nivel de superficie + `ListRow`** | La mayor ganancia visual por esfuerzo; reduce el ruido en Sonido, Conectividad, Notificaciones y Portapapeles [V captura] | P1 | M |
| 6 | **Familia `IslaButton`** | Cinco familias con estados distintos [V]; `dim` como opacidad 0.32 hace ilegible el glifo. Base de foco y accesibilidad uniformes | P1 | L |
| 7 | **Overview accesible** | Inutilizable sin ratón (0 `Keys`, 0 `Accessible`) [V]. Bajo riesgo y mucho valor funcional | P0 | M |
| 8 | **Tokens con vocabulario propio + test de literales** | Frena la deriva hacia M3 y hacia los literales; sin esto el kit se degrada [V] | P1 | L |
| 9 | **`IslaSwitch` con marca de estado** | La HIG pide no depender solo del color [V-doc]; el "off" actual tiene poco contraste [V]. Primera pieza con identidad propia en reposo | P1 | M |
| 10 | **Lockscreen con `spring.standard` + `IslandCompanion` tokenizado** | El primer contacto del día rebota fuera del sistema [V]; el companion ignora `Motion.mult` y `reduceMotion` [V] | P1 / P2 | S + M |

**Por qué Overview (P0) va en el puesto 7 y no antes:** su valor es alto para quien usa teclado o lector, pero el slider, la hora y las notificaciones afectan a todas las sesiones de todos los usuarios. Si el usuario depende del teclado, Overview sube al puesto 2.

## 3. Notas técnicas para la implementación futura

- **Mantener el integrador propio.** `SpringAnimation` conserva la velocidad, pero usa Euler con paso fijo de 16 ms y su techo práctico ronda ω 17,7 [V-código, rama dev].
- **Mantener `Flags.reduceMotion` como ajuste propio.** `QAccessibilityHints::motionPreference` existe desde Qt 6.12 [V-doc], pero no se encontró backend para Linux [I]. Como mucho, combinarlo con OR.
- **`BoundaryRule` no conserva la velocidad** [V-doc]. El rubber band propio es mejor; la fórmula sigmoide de React Bits (`2(σ(d/l) − 0,5)·l`) sirve para unificar el de `Slider` y `AudioFader`.
- **Valores de referencia para las primitivas** (Animate UI, convertidos en doc 05): pulsación 0,97 con ω 23,5 / ζ 0,64; pulgar del switch con estiramiento 19/16 y ω 17,3 / ζ 0,72; umbral de arrastre del slider de 3 px.
- **Una pasada de `isla-revisor`** antes de cerrar cualquier cambio en `Pill.qml`, `PillMorphMotion` o `body.frag`.

## 4. Lo que esta auditoría no cubre

- Surfaces no capturadas: Overview, Wallpaper, Clipboard, Notifs, Session, Focus, Recording y Lockscreen. Se auditaron solo por código. Settings se cubre en doc 11 (páginas 6–9 sin capturar).
- Media no se vio en vivo porque no había reproductor activo.
- No se midió el tiempo por fotograma ni la memoria por surface. El doc 08 §A.3 da el método.
- No se vio funcionar en navegador ningún componente de las bibliotecas de referencia.
- No hay pruebas con usuarios ni con lector de pantalla real.
