# 01 · Resumen ejecutivo

Fecha: 2026-11-06. Alcance: shell Quickshell de Eshell / Isla en `/home/zdito/.config/quickshell`.
**No se ha modificado ningún archivo funcional.** Todos los documentos viven en `docs/auditoria-eshell-2026-11-06/`.

Leyenda: **[V]** verificado (código, captura o documentación) · **[I]** inferencia · **[X]** experimental.

## Veredicto

Eshell **se reconoce en movimiento, no en reposo**. La pill, con su integrador ω/ζ propio y su materia líquida (SDF de gota y cuello), es una identidad real y poco común [V]. Fuera de la pill, la shell es una colección de vistas que reimplementan sus propios controles: cuatro sliders, cinco familias de botones, dos sistemas de pestañas y tarjetas dentro de tarjetas [V]. Eso la hace parecer un conjunto de widgets y no un producto diseñado.

## Ajustes (doc 11)

La app de configuración es la surface más madura: controles nativos accesibles, tubo líquido, switch con check, borradores y búsqueda. Fallo principal: campos numéricos sin entero ni unidad ("60.00 fps", paso de teclado 0.01). Su slider y su switch son la base del kit, no hay que rediseñarlos.

## Qué conservar

1. Integrador ω/ζ propio de `PillMorphMotion`. `SpringAnimation` de Qt no llega a ω 22–26 y no se parametriza por ζ [V-código, I].
2. SDF compartido de gota y cuello (`body.frag`).
3. Matugen como única fuente de color.
4. Hit target fijo en `CtrlBtn`.
5. `SwiftMediaTimeline`, `RollingNumber`, `SurfaceHeader` y `Theme.concentric()`.

## Problemas principales

1. **Accesibilidad:** Overview tiene 0 `Accessible` y 0 `Keys` [V]. El slider propio no tiene teclado ni rueda [V].
2. **Coherencia:** la pill muestra formato de 12 h y el calendario de 24 h a la vez [V].
3. **Coste:** `NotifCardView` mantiene una capa offscreen permanente [V]. La memoria medida es 684 MB frente a 515 MB anteriores [V]; la causa no está confirmada [I].
4. **Sistema:** 106 duraciones literales, 19 alfas y nombres de tokens con influencia M3 [V].
5. **Movimiento:** lockscreen con `OutBack` 1.6, IslandCompanion fuera de `Motion`, y `BodyShader` y `DeviceMomentCard` sin consulta de `reduceMotion` [V].

## Influencias

- Material You en nombres de tokens y en el toggle (estado "off" de M3) [V].
- iOS en la proporción del switch y en la pill tipo Dynamic Island [V].
- Swiftify en la surface de media (excepción aprobada) [V].

La dependencia de Matugen es de compatibilidad, no de identidad: Eshell puede seguir consumiendo esos roles sin parecer M3 [I].

## Top 10 (por valor de producto)

1. `IslaSlider` accesible sobre `Controls.Slider`, que sustituye a cuatro implementaciones.
2. Formato de hora coherente en pill, calendario y lockscreen.
3. Capa de `NotifCardView` solo al deslizar, y medición de memoria.
4. `SegmentedControl` sobre `SpringValue`.
5. Regla de un solo nivel de superficie, con `ListRow`.
6. Familia `IslaButton`.
7. Overview accesible (sube al puesto 2 si el usuario depende del teclado).
8. Tokens con vocabulario propio y test de literales.
9. `IslaSwitch` con marca de estado.
10. Lockscreen con `spring.standard` e IslandCompanion tokenizado.

Detalle y justificación: doc 10 §2.

## Límites de esta auditoría

- **Capturas incompletas.** Se capturaron Utils, Sonido, Calendario, Conectividad, Launcher y los paneles izquierdo, central y derecho. No se capturaron Overview, Wallpaper, Clipboard, Notifs, Session, Focus, Recording ni Lockscreen [V]. Settings se añadió después: doc 11 (páginas Hyprland, Actualizaciones e Idioma sin capturar).
- **Media sin ver.** No había reproductor activo [V].
- **Sin medición de fotogramas ni de memoria por surface.** El método está en doc 08 §A.3 [V].
- **Referencias sin ver en marcha.** Ningún componente de las seis bibliotecas se vio funcionar en navegador [V]. motion-primitives.com y uiverse.io devolvieron 403 [V]. Las conversiones ω/ζ son cálculo propio [I].
- **Sin pruebas con usuarios ni con lector de pantalla real** [V].
- **Qt:** el código de `SpringAnimation` se leyó en la rama dev, que puede diferir de Qt 6.12.0 [V].

## Índice de documentos

| Doc | Contenido |
|---|---|
| [02](02_COMPONENT_INVENTORY.md) | Inventario de componentes, familias y duplicados |
| [03](03_DESIGN_LANGUAGE_AUDIT.md) | Lenguaje visual, tokens, influencias |
| [04](04_MOTION_INTERACTION_AUDIT.md) | Animaciones, integradores, costes |
| [05](05_REFERENCE_RESEARCH.md) | Investigación de referencias externas |
| [06](06_COMPONENT_REDESIGN_PROPOSALS.md) | Alternativas A/B/C por componente |
| [07](07_DESIGN_SYSTEM_PROPOSAL.md) | Eshell UI Kit: tokens y 12 primitivas |
| [08](08_PERFORMANCE_ACCESSIBILITY_REVIEW.md) | Rendimiento y accesibilidad |
| [09](09_PRIORITIZED_ROADMAP.md) | Matriz P0–P3 y fases 0–5 |
| [10](10_FINAL_RECOMMENDATIONS.md) | Respuestas finales y top 10 |
| [11](11_SETTINGS_APP_AUDIT.md) | App de configuración (Edots): fallos, propuestas, matriz 21–26 |
