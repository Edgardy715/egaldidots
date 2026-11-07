# 09 · Matriz priorizada y hoja de ruta

Leyenda de evidencia: **[V]** verificado · **[I]** inferencia · **[X]** experimental.

## 1. Escalas usadas en la matriz

- **Prioridad**
  - **P0** fundamentales.
  - **P1** alto impacto.
  - **P2** refinamiento.
  - **P3** experimentación.
- **Complejidad:** S (< 2 h), M (medio día), L (1–2 días), XL (más de 2 días).
- **Riesgo / Impacto en rendimiento:** bajo, medio o alto. "−" indica que mejora el rendimiento.
- **Confianza:** alta (verificado en código o captura), media (inferencia fuerte) o baja (requiere prototipo).

Las mejoras más llamativas **no** están arriba por serlo: el orden sigue el valor para el producto.

## 2. Matriz

| # | Componente | Estado actual | Problema / oportunidad | Referencia | Solución | Beneficio visual | Beneficio funcional | Viabilidad QML | Complejidad | Riesgo | Rendimiento | Prior. | Confianza |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Slider | 4 implementaciones; la propia sin a11y/teclado/rueda [V] | Inaccesible e inconsistente | Qt `Controls.Slider`; Apple HIG Sliders | `IslaSlider` de tubo sobre `Controls.Slider` | Una sola anatomía | Teclado, rueda y lector | Alta | L | Medio (muchos usos) | Neutro | **P0** | Alta |
| 2 | Overview | 0 `Accessible`, 0 `Keys` [V] | Inutilizable sin ratón | Kirigami (navegación por teclado); WCAG 2.1.1 | Rol, foco y flechas por grupo y celda | — | Teclado y lector | Alta | M | Bajo | Neutro | **P0** | Alta |
| 3 | NotifCardView | `layer.enabled: true` permanente [V] | Una FBO por tarjeta | Qt docs `Item.layer` (coste de capas) | Activar la capa solo al deslizar | — | Menos memoria y GPU | Alta | S | Bajo | **−** | **P0** | Alta |
| 4 | Memoria / Loaders | RSS 684 MB frente a 515 MB [V]; descarga de surfaces sin verificar [I] | Posible crecimiento | `bar/TESTING.md` (sample-process, session-soak) | Medir según el doc 08 §A.3 y descargar surfaces inactivas | — | Estabilidad | Alta | M | Medio | **−** | **P0** | Media |
| 5 | Hora | Pill 12 h y calendario 24 h a la vez [V] | Parece un fallo | Apple HIG (consistencia) | `time12h` aplicado también a la pill, o la pill sigue la configuración regional | Coherencia | Menos confusión | Alta | S | Bajo | Neutro | **P0** | Alta |
| 6 | Pestañas | Implementadas en línea ×2; indicador sin velocidad [V/I] | Tacto irregular | motion.dev `layoutId` (concepto); Apple segmented control | `SegmentedControl` sobre `SpringValue` | Indicador fluido | Teclado y roles de pestaña | Alta | M | Bajo | Neutro | **P1** | Alta |
| 7 | Botones | 5 familias; `dim` = opacidad 0.32 [V] | Estados dispares | Qt Controls `Button`; HIG Buttons | Familia `IslaButton` | Coherencia | Foco y lector uniformes | Alta | L | Medio | Neutro | **P1** | Alta |
| 8 | Superficies | Tarjeta dentro de tarjeta (mezclador) [V] | Ruido visual | Apple HIG (Lists, grouped) | Regla de un solo nivel, controles `ghost` y `ListRow` | Mucho más limpio | Escaneo más rápido | Alta | M | Bajo | **−** leve | **P1** | Alta |
| 9 | Tokens | 19 alfas; radios duplicados; 106 duraciones literales; nombres M3 [V] | Deriva hacia M3 y literales | Diseño de tokens (Kirigami Units; Material roles) | Vocabulario propio (doc 07) con alias y test de literales | Coherencia a largo plazo | Mantenimiento | Alta | L | Bajo | Neutro | **P1** | Alta |
| 10 | Lockscreen | `OutBack` 1.6 [V] | Rebote fuera de sistema | Principio aprobado ~3 % | `spring.standard` | Primer contacto más refinado | — | Alta | S | Bajo | Neutro | **P1** | Alta |
| 11 | Toggle | Híbrido iOS/M3, "off" de bajo contraste [V] | Genérico y poco legible | HIG Toggles; WCAG 1.4.11 | `IslaSwitch` gota con marca de estado | Más propio | Legible sin color | Alta | M | Bajo | Neutro | **P1** | Alta |
| 12 | IslandCompanion | 63 duraciones y 53 curvas literales [V] | Fuera de `Motion` y de `mult` | — | Tokenizar sin cambiar el carácter | — | `reduceMotion` real | Alta | M | Medio (carácter) | Neutro | **P2** | Alta |
| 13 | Estados vacío/carga/error | En línea por vista [V] | Inconsistentes | Kirigami `PlaceholderMessage` | `StateView` | Coherencia | Acción de recuperación | Alta | M | Bajo | Neutro | **P2** | Alta |
| 14 | Riel de workspaces | 3 MultiEffect; puntos de ~6 px [V] | Coste fijo y objetivo pequeño | — | Retirar capas y estilo "gota viajera" compartido con #6 | Más propio | Rueda y objetivo mayor | Alta | M | Bajo | **−** | **P2** | Media |
| 15 | Calendario | Mayúsculas mezcladas [V] | Detalle | — | Una sola convención | Pulido | — | Alta | S | Bajo | Neutro | **P2** | Alta |
| 16 | Pill.qml | 941 líneas [V] | Mantenibilidad | AGENTS.md (componentes por propiedades) | Dividir en State/Rest/Notify sin cambio visual | — | Menos regresiones | Alta | L | **Alto** (núcleo) | Neutro | **P2** | Media |
| 17 | `PillMaterial` | 3 bordes (propuesta pendiente) [V] | Ruido en el borde | `docs/previews/shell-minimal-2026-11-05.md` | Un solo borde | Más limpio | — | Alta | S | Bajo | **−** leve | **P2** | Alta |
| 18 | Origen espacial | Solo LaunchFlight lo usa [V] | Las surfaces nacen siempre del centro | Apple (zoom transitions); motion.dev shared layout | La pill nace desde el icono de barra que la abrió | Continuidad | Orientación | Media | L | Medio | Bajo | **P3** | Baja |
| 19 | Toggle/slider con gota | — | Firma propia | FluidCompanion | Microgota al cambiar o en overdrag | Muy distintivo | — | Media | L | Medio | Medio | **P3** | Baja |
| 20 | Miniaturas de workspace | — | Previsualización | Hyprland screencopy | Gota con miniatura en hover | Rico | Navegación | Media | XL | Alto | **Alto** | **P3** | Baja |
| 21 | Fila numérica de Ajustes | Sin entero ni paso: "60.00 fps" | `11_SETTINGS_APP_AUDIT.md` | Esquema con `integer`, `step`, `unit` | Entero + unidad + teclado útil | Rico | Ajustes | Alta | S | Bajo | Neutro | **P0** | Alta |
| 22 | Búsqueda y rail de Ajustes | "1 resultados", vacío contradictorio, rail obsoleto | `11_SETTINGS_APP_AUDIT.md` | Plural, conteo de páginas especiales, rail atenuado | Estados coherentes | Rico | Ajustes | Media | S | Bajo | Neutro | **P1** | Alta |
| 23 | Controles de Ajustes | Fuente de verdad sin extraer; hover con escala | `11_SETTINGS_APP_AUDIT.md` | Extraer a `bar/kit` | Un solo juego de controles | Rico | Todas | Alta | M | Medio | Neutro | **P1** | Alta |
| 24 | Arquitectura de Ajustes | "Avanzado" cajón de sastre | `11_SETTINGS_APP_AUDIT.md` | 7 páginas | Mapa claro | Rico | Ajustes | Media | M | Bajo | Neutro | **P2** | Media |
| 25 | Rail de Ajustes | Relleno lila tipo M3 | `11_SETTINGS_APP_AUDIT.md` | Gota viajera | Identidad propia | Rico | Ajustes | Baja | M | Bajo | Neutro | **P2** | Media |
| 26 | Nombre del producto | Edots / Isla / Eshell | `11_SETTINGS_APP_AUDIT.md` | Decisión de producto | Una identidad | — | Ajustes | Media | S | Bajo | Neutro | **P2** | Alta |

## 3. Hoja de ruta por fases

Cada fase se cierra con estos criterios. **No empieza ninguna sin aprobación explícita del usuario**: esta auditoría no implementa nada.

### Fase 0 · Medir (½ día). Depende de: nada

1. Aplicar el método del doc 08 §A.3 (memoria por surface, coste de capas y primer fotograma).
2. Guardar la línea base en `docs/performance-2026-11-XX/`.

**Aceptación:** un JSON por medición, repetible en dos ejecuciones con menos del 10 % de varianza.

### Fase 1 · P0 (2–3 días). Depende de: Fase 0

1. NotifCardView sin capa permanente (#3).
2. Formato de hora unificado (#5).
3. Overview accesible (#2).
4. Descarga de surfaces o corrección de memoria según la medición (#4).
5. `IslaSlider` (#1) que sustituye a los 4.

**Aceptación:**
- Las regresiones existentes pasan.
- Hay `slider-regression.qml` con teclado, rueda y `reduceMotion`.
- Overview se recorre entero con Tab y flechas.
- El PSS tras 10 ciclos por surface crece menos de 5 MB.
- La hora es coherente en pill, calendario y lockscreen.

### Fase 2 · Kit base (3–4 días). Depende de: Fase 1

1. `bar/kit/` con `Interactive`, `IslaButton`, `SegmentedControl` e `IslaSwitch`.
2. Alias de tokens (doc 07) en `Theme`/`Motion`.
3. `kit-preview.qml` con tres paletas.

**Aceptación:**
- Cada primitiva tiene su regresión.
- La previsualización se ve correcta con 3 paletas Matugen (captura revisada).
- Hay cero literales en `bar/kit/`.

### Fase 3 · Migración de surfaces (4–5 días). Depende de: Fase 2

1. Regla de un solo nivel y `ListRow` en Sonido, Conectividad, Notificaciones y Portapapeles.
2. `SurfaceHeader` en las 7 vistas que faltan (o una excepción documentada).
3. `StateView`.
4. Lockscreen con `spring.standard`.

**Aceptación:**
- Capturas antes/después por surface.
- El test de literales baja al menos un 60 %.
- El primer fotograma del mezclador es menor de 8 ms.

### Fase 4 · Refinamiento (continuo). Depende de: Fase 3

1. IslandCompanion tokenizado.
2. Riel de workspaces "gota viajera".
3. Un solo borde en la pill.
4. Calendario.
5. División de `Pill.qml`, con revisión `isla-revisor` porque es el núcleo.

### Fase 5 · Experimentos (con prototipo y prueba de percepción)

Origen espacial, controles con microgota y miniaturas. Cada uno se prototipa en `*-preview.qml` y se decide con una grabación a 240 Hz y otra a 60 Hz, más un presupuesto de fotograma medido.
