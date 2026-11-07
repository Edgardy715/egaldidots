# 05 · Investigación de referencias

Fecha: 2026-11-06. Entorno: Qt 6.12.0 y Quickshell 0.3.2.

## Evidencia

| Marca | Significado |
|---|---|
| **[V-código]** | Código fuente leído (GitHub raw o JSON del registro) |
| **[V-doc]** | Documentación oficial leída |
| **[I]** | Inferencia |
| **[No cargó]** | La página respondió 403 o solo carga con JS |

**No se vio funcionar ningún componente en un navegador.** Todo comportamiento descrito sale del código o de la documentación. Los parámetros se citan tal como aparecen en el código fuente.

## Conversión de muelles

Fórmula estándar, cálculo propio [I]:

- `ω = √(k/m)`
- `ζ = c / (2√(k·m))`

| Fuente | k / c / m | ω | ζ | Carácter |
|---|---|---|---|---|
| Animate UI `press` | 550/30/1 | 23,5 | 0,64 | pulsación con rebote visible |
| Animate UI `selection` | 300/30/1 | 17,3 | 0,87 | indicador de pestañas |
| Animate UI `highlight` | 500/40/1 | 22,4 | 0,89 | superficie que sigue al puntero |
| Animate UI `slider` | 400/32/1 | 20,0 | 0,80 | pulgar de slider |
| Animate UI `thumb` | 300/25/1 | 17,3 | 0,72 | pulgar de switch |
| Animate UI `morph` | 660/52/1 | 25,7 | 1,01 | redimensionar y mover un popover |
| Animate UI `number` | 90/50/1 | 9,5 | 2,63 | números (sobreamortiguado) |
| Dock (Motion Primitives, Magic UI, Aceternity) | 150/12/0,1 | 38,7 | 1,55 | magnificación |
| Motion Primitives SlidingNumber | 280/18/0,3 | 30,5 | 0,98 | dígitos |
| React Bits SquishSwitch | 170/21,5/0,9 | 13,7 | 0,87 | pulgar |

**Conclusión:** el rango de producto es **ω 17–26, ζ 0,7–1,0**. Las superficies grandes van a ζ ≈ 1 y los números a ζ > 1.

El muelle de la pill (~3 % de overshoot, 90 % a ~260 ms) cae dentro de ese rango. **Se confirma la decisión aprobada.**

---

## 1. Qt 6 (base técnica)

| Tema | Hallazgo | Implicación para Eshell |
|---|---|---|
| `SpringAnimation` | Conserva la velocidad al cambiar `to` (reutiliza el objeto y no reinicia `velocity`). Integra con Euler semiimplícito y paso fijo de 16 ms. `spring: 5` ≈ ω 17,7 [V-código, `qquickspringanimation.cpp`, rama dev] | No alcanza ω 22–26 ni se parametriza por ζ. **El integrador propio de `PillMorphMotion` está justificado** |
| `FrameAnimation` | Desde Qt 6.4; `frameTime` es el dt real [V-doc] | Correcto para integradores propios; mejor un solo `FrameAnimation` para N valores que N animaciones |
| `BoundaryRule` (`Qt.labs.animation`) | Resistencia por curva y retorno con duración; **no conserva velocidad** [V-doc] | El rubber band propio es mejor; sirve como referencia de la fórmula |
| `SmoothedAnimation` | Ease cuadrático con `velocity`, sin overshoot; `reversingMode` [V-doc] | Útil para la selección (sustituto de Behavior + NumberAnimation) |
| `Item.layer` / `MultiEffect` | Ambos crean textura offscreen; `MultiEffect` genera un `ShaderEffectSource` implícito si la fuente no tiene capa [V-doc] | Confirma el coste de `NotifCardView:131` y de las 3 capas del riel |
| **Movimiento reducido** | `QAccessibilityHints::motionPreference` existe **desde Qt 6.12** [V-doc]. No se encontró backend para Linux en `qgenericunixthemes.cpp` [I] | Mantener `Flags.reduceMotion` y, opcionalmente, combinarlo con OR sobre `motionPreference` si algún día lo implementa el backend |

Enlaces:
- https://doc.qt.io/qt-6/qml-qtquick-springanimation.html
- https://doc.qt.io/qt-6/qml-qtquick-frameanimation.html
- https://doc.qt.io/qt-6/qml-qt-labs-animation-boundaryrule.html
- https://doc.qt.io/qt-6/qml-qtquick-smoothedanimation.html
- https://doc.qt.io/qt-6/qml-qtquick-item.html#layer.enabled-prop
- https://doc.qt.io/qt-6/qml-qtquick-effects-multieffect.html
- https://doc.qt.io/qt-6/qaccessibilityhints.html

## 2. Motion Primitives

**Fuentes:** https://motion-primitives.com (**[No cargó]**, 403). Código: https://github.com/ibelick/motion-primitives [V-código].

**Carácter:** primitivas de producto con valores sobrios.

| Patrón | Utilidad | Encaje en QML | Riesgo |
|---|---|---|---|
| **AnimatedBackground** (indicador deslizante con `layoutId`) — /docs/animated-background | **Alta**: pestañas, selector de workspace, lista del launcher | `Rectangle` cuyo x/ancho persigue al hijo activo con muelle; coste mínimo | Bajo |
| **Morphing Popover** (`bounce 0.1`, 0,4 s) — /docs/morphing-popover | **Alta**: es el patrón pill→panel que Eshell ya domina | Ya está hecho mejor: se anima la geometría real y no un `scale` | — |
| **Toolbar Expandable** (`bounce 0.1`, 0,25 s) — /docs/toolbar-expandable | **Alta**: barra de acciones que crece | Muelle sobre `height` | Bajo |
| **Sliding Number** (280/18/0,3; camino más corto con vuelta) — /docs/sliding-number | **Alta** | `RollingNumber` ya existe; **comprobar la regla de camino más corto** | Bajo |
| **Dock** (magnificación por distancia, 150/12/0,1) — /docs/dock | Media: launcher o apps fijadas | `FrameAnimation` que actualiza N anchos | Medio en a11y: mueve objetivos |
| Magnetic, Tilt, Spotlight (con `blur-xl`) | Baja | Spotlight requiere un desenfoque offscreen; evitar | — |

**No tomar:** border-trail, glow-effect, progressive-blur, text-scramble, shimmer ni carousels.

## 3. Animate UI — la referencia más valiosa

**Fuentes:** https://animate-ui.com (no abierta). Código: https://github.com/imskyleen/animate-ui [V-código]. Tiene un **sistema de tokens de movimiento documentado** en `skills/animate-ui/references/tokens.md`, `feel.md` y `rules.md`.

| Patrón | Utilidad | Encaje |
|---|---|---|
| **Muelles con nombre por rol** (press, pop, selection, highlight, morph, thumb, slider, number…) | **Alta**: es exactamente lo que le falta a `Motion.qml` (ver doc 07) | Tabla de presets omega/zeta |
| **Regla de frecuencia:** lo que se usa todo el día (menús, selects) va con tween corto sin rebote; el rebote se reserva a pulsaciones y checks | **Alta** | Regla de gobernanza |
| **Pulsación:** escala 0,97 con `spring.press` y **sin escala en hover** | **Alta** | Eshell usa `scaleHover` 1.03: revisarlo, porque el hover con escala en escritorio es ruido [I] |
| **Switch** con pulgar que se estira (19/16) — /docs/components/base/switch | **Alta** | El `Toggle` ya se estira; comparar factores |
| **Slider:** umbral de 3 px; clic = salto animado, arrastre = directo — /docs/components/base/slider | **Alta**: evita retraso al arrastrar | Aplicable a `IslaSlider` |
| **Menu handoff / morph** (450/43, 660/52): la caja se mueve conservando velocidad, el contenido saliente se desliza en sentido contrario y el entrante entra con retardo | **Alta** para el cambio entre surfaces de la pill | Comparar con `openContentStart 0.12` |
| **Movimiento reducido:** `ReducedMotionConfig`, `transition.instant`, **conserva fundidos** | **Alta** | Confirma que `reduceMotion` debe cambiar a fundido, no solo acortar |

**No tomar:** fondos (gravity-stars, hexagon), partículas ni el liquid button decorativo.

## 4. React Bits

**Fuentes:** https://reactbits.dev (no abierta). Código: https://github.com/DavidHDev/react-bits [V-código].

**Carácter:** en su mayoría marketing, salvo la carpeta **`Micro/`**, que es de producto y usa física explícita.

| Patrón | Utilidad | Encaje |
|---|---|---|
| **SquishSwitch** — /micro/squish-switch: estiramiento = f(velocidad suavizada) con **conservación de área** (`scaleY = h/stretch`), máximo 0,4; respeta reduced motion (ganancia 0) | **Alta** | Mejor que un estiramiento fijo; se calcula desde la velocidad del integrador, coste cero |
| **RubberSegment** — /micro/rubber-segment: segmented con arrastre elástico, flick por velocidad y `velocity` pasada al animar | **Alta** | Modelo directo para `SegmentedControl` |
| **ElasticSlider** — /components/elastic-slider: `rubber(d,l) = 2(σ(d/l) − 0,5)·l`, ω = 2π/periodo, ζ = 1 − 0,9·bounce | **Alta** | Fórmula copiable a JS; la misma parametrización que Eshell |
| **Counter** — /components/counter: desenfoque de movimiento vertical según velocidad | Media | Alternativa barata en QML: estirar el glifo en Y en lugar de desenfocar |
| **VoicePill** — /micro/voice-pill: envolvente attack/release (release 240 ms), `DT_MAX 0.05` | Media | Comparar con la envolvente de Cava |
| GooeyNav | Baja | El filtro gooey es el equivalente caro del SDF de Eshell; el de Eshell es mejor |

**No tomar:** fondos WebGL, cursores con shader ni partículas.

## 5. Aceternity UI

**Fuentes:** https://ui.aceternity.com (las páginas no muestran código). Se leyó el registro JSON [V-código].

**Carácter:** landing y marketing.

- **Floating Dock** (/components/floating-dock): mismos valores que Motion Primitives.
- **Tabs** (/components/tabs): `bounce 0.3`, 0,6 s. **Demasiado lento y rebotón para uso diario.** Sirve como contraejemplo.
- Animated Tooltip: ζ 0,31, muy rebotón. Baja utilidad.

**Conclusión:** casi nada transferible a una shell.

## 6. Magic UI

**Fuentes:** https://magicui.design. Código en https://github.com/magicuidesign/magicui [V-código].

**Carácter:** marketing.

| Patrón | Utilidad |
|---|---|
| **AnimatedList** (/docs/components/animated-list): entrada con muelle 350/40 (ζ 1,07) | Media-alta para el historial de notificaciones |
| **NumberTicker**: interpola el número (ζ 3), no rueda dígitos | Media |
| **Animated Theme Toggler**: revelado circular desde el punto de clic (400 ms) | Baja-media. En QML necesita dos texturas offscreen; podría encajar en el cambio de fondo (`WallpaperApplyFeedback`) **[X]** |
| Ripple Button | Baja: estética Material, contraria a la identidad |

## 7. Uiverse

**Fuentes:** https://uiverse.io (**[No cargó]**, Cloudflare 403). Código en https://github.com/uiverse-io/galaxy (MIT) [V-código; se leyeron 4 switches].

Es HTML y CSS de la comunidad, de calidad desigual, sin física, sin conservación de velocidad y sin accesibilidad.

**Utilidad baja:** solo inspiración visual de formas (por ejemplo, un icono dentro del pulgar del switch, que encaja con la marca de estado propuesta en el doc 06 §3).

## 8. Apple HIG

**Fuentes:** JSON que alimenta las páginas: `developer.apple.com/tutorials/data/design/human-interface-guidelines/{motion,toggles,sliders,materials}.json` [V-doc]. Página: https://developer.apple.com/design/human-interface-guidelines/

**Motion:**
- Movimiento con propósito y opcional.
- Breve y preciso.
- "Generally avoid adding motion to UI interactions that occur frequently".
- Dejar cancelar el movimiento.

**Toggles:**
- No depender solo del color para el estado.
- El switch va en filas de lista; fuera de lista, botón-toggle.

**Sliders:**
- Relleno del mínimo al pulgar.
- Iconos en los extremos.
- Respuesta en vivo y valor visible al pasar el puntero.

**Materials ("Liquid Glass"):**
- Capa funcional sobre el contenido, no en el contenido.
- Los controles transitorios (sliders y toggles) la adoptan al activarse.
- Se adapta a "reducir transparencia" y "aumentar contraste".

**Utilidad alta como criterio.** No da valores numéricos.

**Lectura crítica.** "Liquid Glass" valida la dirección de Eshell (material líquido funcional), pero también fija el riesgo: si la pill copia el aspecto de Liquid Glass (refracción y brillo especular), Eshell pasa a parecer una imitación de iOS 26. La diferencia de Eshell debe ser la **materia** (gotas, cuello, cohesión) y no el **vidrio**.

## 9. Qt Quick Controls

Documentación: https://doc.qt.io/qt-6/qtquickcontrols-index.html y https://doc.qt.io/qt-6/qml-qtquick-behavior.html [V-doc].

- Una propiedad no puede tener más de un Behavior.
- Una `Transition` de estado sustituye al Behavior.
- `Behavior { SpringAnimation }` es la forma idiomática y conserva velocidad.

**Implicación:** el kit (doc 07) debe basarse en `Controls.Slider`, `Controls.Switch` y `Controls.Button` con `background` y `handle` propios. Así se obtienen accesibilidad, teclado y foco nativos; hoy se reimplementan a mano en `Slider.qml` y `Toggle.qml`.

No se extrajeron las duraciones de los estilos Material/Universal.

## 10. KDE Kirigami

Fuente: https://develop.kde.org/frameworks/kirigami/. `Units` en `invent.kde.org/frameworks/kirigami/-/raw/master/src/platform/units.cpp` [V-código].

- Duraciones de 50, 100, 200 y 400 ms con setters.
- Que Plasma las ponga a 0 con su ajuste global de velocidad de animación es [I].

**Qué tomar:**
- Duraciones como **tope** de los tweens.
- El patrón `PlaceholderMessage` para estados vacíos (doc 06 §10, por nombre; no se leyó su código).

**No tomar:** curvas OutCubic genéricas para la pill. Los componentes (Drawer, SwipeListItem) no se evaluaron.

## 11. Motion (motion.dev)

Documentación: https://motion.dev/docs/react-transitions y https://motion.dev/docs/react-layout-animations [V-doc].

- **Los muelles físicos incorporan la velocidad previa; los definidos por `duration` + `bounce` no.** Confirma el modelo de Eshell.
- `layout="position"` evita distorsionar el contenido. En QML ya se anima la geometría real, así que solo hay que asegurar que no se escalan texto ni iconos durante el morph.

## 12. GSAP

Documentación: https://gsap.com/docs/v3/Plugins/Flip/ y https://gsap.com/docs/v3/GSAP/gsap.quickTo()/ [V-doc].

- **Flip** es un patrón de captura y compensación que no hace falta en QML.
- **quickTo** retargetea un tween con duración y curva; **no conserva la velocidad física**.

Es útil como contraejemplo y para timelines; no aporta controles de sistema operativo.

---

## Síntesis: qué patrones encajan de verdad con Eshell

| Patrón | Fuente | Encaje | Dónde aplicarlo |
|---|---|---|---|
| Muelles con nombre por rol + regla de frecuencia | Animate UI | ★ Alto | `Motion.qml` (doc 07 §2.5) |
| Indicador deslizante que conserva velocidad | Motion Primitives AnimatedBackground, React Bits RubberSegment | ★ Alto | `SegmentedControl`, riel de workspaces |
| Estiramiento por velocidad con conservación de área | React Bits SquishSwitch | Alto | `IslaSwitch`, menisco del slider |
| Clic animado / arrastre directo con umbral de 3 px | Animate UI Slider | Alto | `IslaSlider` |
| Fórmula sigmoide de rubber band | React Bits ElasticSlider | Medio | Unificar el rubber band de Slider y AudioFader |
| Handoff de contenido (sale en sentido contrario, entra con retardo) | Animate UI menu handoff | Medio | Cambio entre surfaces de la pill |
| Reduced motion = conservar fundidos y quitar desplazamiento | Animate UI, HIG | ★ Alto | `Motion.mult` |
| No escalar en hover | Animate UI rules | Medio | `Theme.scaleHover` 1.03 |

**Descartados por coste o por identidad:** spotlights con blur, glow, beams, partículas, tilt 3D, ripple, gooey por filtro, tabs rebotones de Aceternity y estilos de Uiverse.

## Límites de la investigación

- No se vio nada funcionando en navegador.
- No cargaron motion-primitives.com, uiverse.io, las páginas HTML de Apple HIG (se leyó el JSON) ni api.kde.org.
- Las URLs de componentes de reactbits y animate-ui son rutas habituales del sitio y **no se comprobaron una a una**.
- Las conversiones ω/ζ son cálculo propio.
- `SpringAnimation` se leyó en la rama `dev` de qtdeclarative, que puede diferir de la 6.12.0 instalada.


## Addendum 2026-11-06

motion-primitives.com y uiverse.io **sí cargan en el navegador integrado**; el 403 era de la herramienta de lectura de páginas. Detalle en [11 §8](11_SETTINGS_APP_AUDIT.md). La interacción con sliders, tabs y segmentados de las seis bibliotecas principales sigue pendiente.
