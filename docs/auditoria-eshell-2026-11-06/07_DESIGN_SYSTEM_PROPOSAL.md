# 07 · Propuesta de sistema de diseño: Eshell UI Kit

Leyenda de evidencia: **[V]** verificado · **[I]** inferencia · **[X]** experimental.

**Objetivo:** que cualquier vista nueva se construya con 12 piezas y ~40 tokens, sin literales, y que el resultado se reconozca como Eshell en una captura fija.

**Restricciones:**

- QML nativo.
- Sin romper `Theme`/`Motion` de golpe: los nuevos nombres son alias primero y se retiran los viejos después.

## 1. Identidad en una frase

> **Eshell es materia líquida oscura que toma el color de tu fondo: una gota que se convierte en lo que necesitas y vuelve a ser gota.**

### Principios (5)

1. **Una gota, una voz.** Una sola forma expresiva (la gota o pill); todo lo demás es cápsula o rectángulo concéntrico.
2. **El movimiento es la marca.** La geometría se mueve con muelles que conservan velocidad y la opacidad con curvas. Nunca rebote mayor de ~3 %.
3. **Profundidad por tono.** Dos niveles de superficie como máximo dentro de una surface, sin sombras internas ni bordes anidados.
4. **Un acento por surface.** El color Matugen marca *el* estado activo, no decora.
5. **Ligera por defecto.** Ningún efecto (capa, blur, shader) está activo en reposo si no se ve.

## 2. Tokens (vocabulario propio)

Se mapean desde los actuales; no hace falta cambiar ningún valor de color de Matugen.

### 2.1 Espacio (rejilla de 4)

| Token | Valor | Sustituye |
|---|---|---|
| `space.hair` | 2 | spacingXxs |
| `space.tight` | 4 | — |
| `space.snug` | 8 | spacingSm |
| `space.base` | 12 | spacingMd y el **10** |
| `space.loose` | 16 | spacingLg |
| `space.wide` | 24 | márgenes de surface |

### 2.2 Forma

| Token | Valor | Uso |
|---|---|---|
| `shape.chip` | 8 | chips, teclas |
| `shape.control` | 12 | campos, botones de texto |
| `shape.group` | 16 | grupos de nivel 1 |
| `shape.surface` | derivado | `concentric(outer, inset)` desde la pill |
| `shape.capsule` | altura/2 | botones de icono, pestañas, slider, toggle |

Desaparecen Sm=Md y Lg=Xl duplicados [V]. Todo lo anidado usa `Theme.concentric()` (ya existe).

### 2.3 Tipo (6 pasos, ya aprobados el 2026-11-05)

`type.caption` 11 · `type.body` 13 · `type.label` 15 · `type.title` 20 · `type.display` 28 · `type.hero` 40.

Se retiran 17, 34 y 52 del uso directo. Media conserva su escala como excepción documentada (`type.media.*`).

### 2.4 Material y tono

| Token | Valor | Sustituye |
|---|---|---|
| `tone.level1` | `tonalFill` (0.055) | rellenos de grupo |
| `tone.level1Hover` | 0.07 | — |
| `tone.hover` | +0.04 | `alphaHover` y similares |
| `tone.pressed` | +0.08 | — |
| `tone.disabledInk` | 0.38 | `opacity: 0.32` global |
| `ink.primary` / `ink.secondary` / `ink.tertiary` | roles Matugen | `foreground`, `iconSecondary` |
| `signal.positive` / `signal.warning` / `signal.critical` | `#30d158`, `#ff9f0a`, `error` | literales en BatteryIndicator, PrivacyDots y AuthPromptView [V] |

La escala de alfa pasa de 19 a 7 valores con nombre.

### 2.5 Movimiento

| Token | Valor | Uso |
|---|---|---|
| `time.micro` | 90 | pulsación, hover |
| `time.short` | 180 | fundidos de contenido |
| `time.medium` | 280 | entradas y salidas de elementos |
| `time.breathe` | 3000 | respiración |
| `spring.firm` | ω alta, ζ 1.0 | controles (pulgar, indicador) |
| `spring.standard` | preset `open` actual (~3 % overshoot, 90 % a ~260 ms) | pill, surfaces |
| `spring.soft` | ζ 0.85, ω baja | gotas, companion |
| `curve.enter` / `curve.exit` | `emphasizedDecel` / `emphasizedAccel` | opacidad |

Se retiran `bounceCurve`, `slingCurve` y `OutBack` 1.6. Todos los tokens de tiempo se multiplican por `Motion.mult`.

## 3. Primitivas (12)

| # | Pieza | Sustituye / unifica | Base nativa |
|---|---|---|---|
| 1 | `Interactive` | MotionArea + InteractionMotion | `Item` + `HoverHandler`/`TapHandler`, rol y teclado |
| 2 | `IslaButton` (icon/text/filled/tonal/ghost) | CtrlBtn, MotionButton, EdotsButton, LockButton, AudioButton | `Interactive` |
| 3 | `IslaSlider` (tubo) | Slider, AudioFader, tubo de SettingRow, LockMedia | `Controls.Slider` con delegados propios; **base: extraer `SettingRow.qml:393-482`** (doc 11) |
| 4 | `IslaSwitch` | Toggle | `Controls.Switch` con delegados propios; **base: `SettingRow.qml:196-262`, que ya lleva marca de check** (doc 11) |
| 5 | `SegmentedControl` | pestañas de Mixer y Connectivity, LiquidSelection | `Repeater` + `SpringValue` |
| 6 | `IslaField` | IslaTextField, EdotsTextField | `TextInput` |
| 7 | `IslaMenu` (combo y popover) | EdotsComboBox | `Popup` |
| 8 | `Group` (nivel 1) | GlassCard y tarjetas propias | `Rectangle` concéntrico |
| 9 | `ListRow` | filas de audio, red, portapapeles y notificación | `Interactive` |
| 10 | `SurfaceHeader` | ya existe; extenderlo a las 7 vistas que faltan | — |
| 11 | `StateView` (vacío, carga y error) | estados en línea | — |
| 12 | `IslaTooltip` | ToolTip adjunto | `ToolTip` con estilo |

**Reglas de composición** (ya pedidas en la auditoría del 2026-10-26):

1. Una surface es `SurfaceHeader` + 1..n `Group` + `ListRow` o controles.
2. Un `Group` nunca contiene otro `Group`.
3. Los controles secundarios dentro de un `Group` son `ghost`.
4. Un solo `filled` por surface.

## 4. Organización de archivos propuesta

```
bar/kit/            ← primitivas (12), sin dependencias de servicios
bar/kit/qmldir
bar/components/     ← vistas y adaptadores (las existentes)
bar/Singletons/Theme.qml   ← tokens nuevos como alias de los viejos (fase 1)
```

`bar/kit/` no importa ni `Players` ni `Cava` ni servicios. Los datos entran por propiedades (regla existente en AGENTS.md).

## 5. Gobernanza

1. **Prueba de literales:** un script `rg` en `bar/tests/` falla si aparecen `radius: <número>`, `font.pixelSize: <número>`, `"#…"` o `duration: <número>` fuera de `Singletons/`, `kit/` y la lista de excepciones (media).
2. **Previsualización:** `bar/kit-preview.qml` con todas las primitivas en todos sus estados, sobre 3 paletas Matugen (clara, oscura y saturada). Es la referencia visual y sirve para QA.
3. **Regresión:** cada primitiva lleva su `*-regression.qml`, que comprueba estados, teclado y `reduceMotion`.
4. **Documentación:** una tabla por primitiva (props, estados y accesibilidad) en `bar/kit/README.md`.
