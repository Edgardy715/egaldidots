# Fluid Island

Desde la raíz del repositorio, ejecuta la demo sin cargar la shell habitual:

```sh
quickshell -p bar/fluid-demo.qml
```

Después ciérralo con:

```sh
quickshell -p bar/fluid-demo.qml kill
```

El criterio reutilizable para toda futura superficie está en
[`MOTION_LANGUAGE.md`](MOTION_LANGUAGE.md).

## Primera integración real

La pill principal conserva el reloj y
[`FluidMediaCompanion.qml`](../components/FluidMediaCompanion.qml) desprende una
gota circular a su derecha mientras existe una pista activa o pausada. Al
comenzar la reproducción, la gota se ensancha ligeramente para mostrar CAVA.
El título y el artista sólo aparecen al pasar el puntero sobre ella; al salir,
vuelve al ancho compacto correspondiente al estado de reproducción. Un clic
transforma el mismo cuerpo en la `MediaSurface` existente, también a la derecha
del reloj. Al desaparecer el último reproductor válido, la pill absorbe la
gota mediante el cuello fluido. Las demás superficies conservan su morph.

El `PanelWindow` es transparente, no reserva espacio y su máscara de reposo
incluye la pill y la gota. El resto deja pasar el puntero al escritorio.
Los botones prueban nacimiento, separación, expansión, contracción y fusión;
un clic sobre la gota cambia el destino durante el movimiento.

## Diseño

`FluidIslandDemo.qml` contiene una entidad de gota con posición, tamaño,
velocidad y destino persistentes. El integrador de resorte avanza `x`, `y`,
`width` y `height` por separado, sin reiniciar velocidad al retargetear. Con
movimiento reducido salta directamente al estado final. La isla no se mueve;
la gota nace dentro de su extremo y un `ShapePath` de dos Bézier cúbicas forma
el cuello. La unión usa histéresis normalizada: conecta sólo al tocar y se
mantiene hasta un umbral de rotura mayor. Cuando se rompe durante la expulsión,
queda una microgota que se disipa durante 420 ms en el punto de pinzamiento.

La coreografía es deliberadamente asimétrica: antes de salir, la isla cede un
poco de ancho y la gota se presiona desde dentro; después el tirón lento deja
que el cuello adelgace. Al volver, la gota y la isla comparten un único
trayecto: la isla empieza a recibir masa cuando la gota entra en tensión y la
cubre sin una segunda aproximación. La capa de contenido tiene opacidad propia
y no recibe escala ni deformación.

La captura no anima la gota hacia un radio cero. Una vez que el cuello se ha
reconectado, el extremo redondeado de la isla se expande por delante de la
gota, la oculta por completo y vuelve a reposo. Durante una unión se suprimen
los bordes y brillos interiores de las dos piezas para que no aparezcan dos
formas superpuestas dentro de la misma superficie.

Es deliberadamente un puente Bézier, no un SDF ni un filtro gooey: para dos
cuerpos y una sola conexión conserva un contorno inspeccionable, es barato en
Qt Quick y prueba la continuidad requerida antes de introducir un renderer de
campo implícito.

## Arquitectura actual

`components/FluidCompanion.qml` comparte el motor entre ambos lados de la pill.
`FluidMediaCompanion.qml` conecta la gota derecha con los datos multimedia;
`windows/IslandOverlay.qml` compone otra gota temporal a la izquierda para sesión.
El reloj permanece visible y la gota izquierda desaparece después de absorberse.
`SurfaceRouter.qml` coordina navegación y `IslandReserve.qml` reserva espacio.
Los cuerpos comparten el overlay para poder unir sus contornos.

La demo aislada conserva su propio escenario experimental. El contrato de la
shell integrada está en [SHELL_ARCHITECTURE.md](../../docs/SHELL_ARCHITECTURE.md)
y las comprobaciones reproducibles en [TESTING.md](../TESTING.md).

## Referencias verificadas

- [Vídeo de Quickshell Dynamic Island](https://youtu.be/Ob98KFByTec): referencia
  de continuidad, origen espacial y jerarquía de apertura; la paleta y el
  material siguen siendo los de Isla.
- [FluidKit, `tension.ts`](https://github.com/runvendo/fluidkit/blob/main/src/liquid/tension.ts) y [`Droplets.tsx`](https://github.com/runvendo/fluidkit/blob/main/src/components/Droplets.tsx): calcula puentes Bézier con histéresis, usa un resorte de partida más lento que el de coalescencia y deja una gota satélite al romperse el cuello. MIT. Se tomaron esos principios, no su React/CSS.
- [QuickLiquid, `packages/quick-liquid/src/animations/spring.ts`](https://github.com/amarnath3003/quickLiquid/blob/main/packages/quick-liquid/src/animations/spring.ts) y [`gestures.ts`](https://github.com/amarnath3003/quickLiquid/blob/main/packages/quick-liquid/src/animations/gestures.ts): conserva velocidad y aplica el impulso de liberación al resorte. MIT. Informa el retargeting de esta demo; no se incorpora como dependencia ni se copia su Canvas/SVG.
- [GLSL Playground, `metaball-search.html`](https://github.com/aaaa-zhen/glsl-playground/blob/main/metaball-search.html): demo WebGL/GLSL de metaballs. No se adopta ahora: no aporta un host Qt Quick ni interacción funcional para este prototipo. No se encontró licencia en el repositorio, por lo que se usa sólo como referencia visual.
- [Interactive Metaballs, `index.html`](https://github.com/sigco3111/interactive-metaballs/blob/main/index.html): campo SDF en WebGL y estado de velocidad por blob; la demo declarada usa dos pasadas de blur. MIT. Es útil para escalar a varias gotas, pero desproporcionado para el puente único y no se reutilizó código.
- [Apple, “Meet Liquid Glass”](https://developer.apple.com/videos/play/wwdc2025/219/) y [Motion HIG](https://developer.apple.com/design/human-interface-guidelines/motion): se usaron como criterio de diseño, no como código. De ahí se toma que la óptica y el movimiento son una sola respuesta, que la forma responde primero en el origen y que una transición conserva una relación espacial directa; no se imita el material propietario de Apple.

## Validación realizada y límites

`git diff --check` pasó. Quickshell 0.3.1 cargó
`bar/fluid-demo.qml` sin advertencias ni errores QML. Se comprobó la carga del
overlay y un estado de reposo mediante captura local; no se reclama una medida
de FPS. Al probarlo manualmente, comprueba: nacer → separar (el cuello debe
romperse dejando una microgota); expandir → fusionar (contrae, reconecta y luego
es absorbida); expandir mientras aún se separa; y clics fuera de
cuerpos/controles que deben llegar al escritorio.
