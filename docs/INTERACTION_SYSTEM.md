# Interacciones de Isla

Revisión global de controles (2026-09-28). Se conserva Theme/pywal, layout,
radios y servicios. La geometría de las gotas sigue en FluidCompanion.

## Auditoría y cobertura

| Familia | Implementación actual | Respuesta |
| --- | --- | --- |
| Transporte y botones circulares | CtrlBtn, MediaSurface, cabeceras de sesión | Hit target fijo, compresión física, foco/teclado, iconos direccionales y reemplazo solapado. Se conservan paths vectoriales del transporte. |
| Interruptores | Toggle en Connectivity, Utils y Notifs | Hover habilitado, track reactivo, knob suavizado, compresión, teclado, checked y disabled accesibles. |
| Botones Qt | MotionButton en SessionSurface y LockButton | Qt mantiene activación/cancelación/foco; fondo y contenido se comprimen juntos, sin escalar el Button. |
| Launcher | AppItem y limpieza de búsqueda | Entrada en hijo visual, hitbox fijo, icono/contenido coordinados, selección e indicador previos. |
| Wi-Fi / Bluetooth | ConnectivitySurface | Acciones, filas, olvidar/desconectar, scans y diálogo usan MotionArea; se conserva el estado del servicio. Spinners sólo cuando la surface está abierta y sin reduceMotion. |
| Mixer / utilities | MixerSurface y UtilsSurface | Mute, brillo y perfiles usan MotionArea; barras conservan sus handlers de drag. |
| Calendario / escritorios | Calendar, Workspaces y Overview | Navegación direccional, presión sobre icono/preview, selección con dueño existente. |
| Wallpapers | WallpaperSurface | Cierre/refresh/miniaturas/navegación/aplicar con respuesta compartida; icono de aplicar transiciona entre trabajo y éxito. |
| Clipboard / notificaciones | ClipboardSurface, NotifsSurface, NotifCard | Wash de presión, acciones con teclado/nombres cuando corresponde; altura de NotifCard con un solo Behavior. |
| Barra y media compacto | IslandRestStatus, IslandMediaCover, IslandMediaVisualizer | Reloj y visualizador con hit target fijo; carátula recibe el mismo retorno físico. Hover de Pill se expresa en el material, sin transformar su hitbox. |
| Autenticación | AuthSurface | Submit con hit target fijo, flecha semántica y presión del visual. No se cambia el flujo de credenciales. |
| Drag / rueda / contención | Slider, seek, Mixer y capas de scroll | Se mantienen MouseArea y grab existentes; grip usa un token común. No se convierten en botones. |

Duplicaciones corregidas: escalas arbitrarias en padres clicables, toggle sin
hoverEnabled, cambios instantáneos de ligaduras y dos Behavior sobre implicitHeight
de NotifCard. También se corrigieron dos fallos anteriores de carga en Clipboard
(`if` como hijo QML y propiedad `s` inexistente). El grip de Slider se centra con
la altura del control y usa su función existente de conversión con límites del knob.

## Gramática y responsabilidades

- `Motion.qml`: hover 120 ms, press 70 ms, icon swap 190 ms; todos respetan
  motionScale. Compresión pequeña 0.96, habitual 0.975, especial 0.965.
- `InteractionMotion`: recibe hovered/pressed/focused/enabled/extent. NumberAnimation
  corta comprime; SpringAnimation retorna desde el valor actual. Spring 4,
  damping 0.35, mass 0.4 a escala temporal 1; no se reutilizan las constantes
  del motor físico de las gotas. La fixture comprueba retorno acotado.
- `MotionArea`: conserva API, señales y grabs de MouseArea. Expone `motion`, wash
  y foco. `hoverWash: false` evita sumar un segundo hover donde el fondo existente
  ya lo representa; la presión sigue visible. `feedbackEnabled: false` se reserva
  para el material de gotas y GlassCard, con feedback propio.
- `MotionButton`: extiende Button Basic; bindings sobre background/contentItem
  aplican la misma escala. Los fondos conservan sus colores y jerarquía.
- `MaterialIcon`: conserva los nombres existentes y los resuelve al catálogo Lucide.
  `AnimatedSymbol` renderiza paths independientes con Qt Quick Shapes: redibujado
  mediante `ShapePath.trim`, ondas escalonadas, arco/vástago de power, shackle de
  lock, campana/badajo y flecha de salida. Hover/foco y tap disparan una secuencia
  finita de 650 ms × motionScale; al salir retorna desde el progreso actual.
  Los cambios de estado revelan los trazos nuevos y retiran el icono anterior;
  no trasladan ni escalan todo el glifo vectorial. El fallback de fuente conserva
  símbolos personalizados. Lucide usa outline y no aplica el eje FILL.
  Qt >= 6.10 es necesario para trim (entorno comprobado: Qt 6.11.2).


Normal, hover, presión y disabled provienen del hit target; active/selected y
loading/success/error siguen perteneciendo al control y a su servicio. No hay
estado global de botón que duplique esos datos. No se añaden estados de carga
ficticios a acciones síncronas ni ripples, luces siguiendo el cursor o loops
ornamentales. La frecuencia de uso manda: transporte sin expansión en hover,
sesión puede comprimir algo más su composición.

ReduceMotion mantiene wash/color y resuelve escala, viaje, rotación y cambio de
icono directamente. Al ocultarse, el feedback físico y el swap dejan de trabajar.
Las primitivas no añaden timers, shaders, blur ni layers. Los bindings de las
piezas vectoriales se evalúan únicamente mientras cambia su progreso.

## Validación reproducible

Desde la raíz, exigir PASS y ausencia de FAIL/errores de carga, además del exit:

```sh
QT_QPA_PLATFORM=offscreen timeout 8s quickshell -p bar/interaction-regression.qml
QT_QPA_PLATFORM=offscreen timeout 8s quickshell -p bar/interaction-surfaces-regression.qml
QT_QPA_PLATFORM=wayland timeout 8s quickshell -p bar/interaction-performance.qml
QT_QPA_PLATFORM=wayland timeout 10s quickshell -p bar/interaction-preview.qml
```

La primera usa eventos QtTest: hover/clic/cancelación fuera del objetivo, disabled,
foco/teclado, toggles, endpoints del slider, interrupción de iconos y reduced motion.
La segunda carga las 12 surfaces no Auth. Auth no se instancia en esa fixture
porque registra servicios/socket reales. La preview usa acciones falsas de sesión
y guarda estados normal/hover/press/release/swap/final en `/tmp/isla-interaction-*.png`.
Estas fixtures no se importan desde el shell normal.

Wayland stress: 96 controles, 128 frames; media 16.98 ms, máximo 22.61 ms,
escala máxima 1.0000 y cero controles sin asentarse en esta ejecución. Mide
intervalos de FrameAnimation de una fixture, no GPU, FPS de todo el shell ni
latencia desde hardware. No hay afirmación de coste cero o estabilidad universal.

También pasan motion, media-motion, status, wallpaper, overview, session y
lockscreen regressions. Media estaba sin reproducción activa en esta prueba.
QMllint de las primitivas compartidas pasa; sobre Auth/Calendar devuelve 255
sin diagnóstico, limitación ya documentada del lint local para surfaces.
Capturas Wayland revisadas para
composición, hover/press/retorno y solapamiento de transporte; no sustituyen
valoración del usuario ni un uso prolongado de todas las surfaces/dispositivos.

## Referencias estudiadas

- [Motion hover](https://motion.dev/docs/hover), [ejemplos](https://motion.dev/examples)
  y [gestures](https://motion.dev/examples/js-gestures): separar reconocimiento
  del gesto de su representación y retargetear feedback.
- [Magic UI interactive hover](https://magicui.design/docs/components/interactive-hover-button),
  [Hover.dev](https://www.hover.dev/) y [Animations.dev](https://animations.dev/):
  estudiar coordinación de icono/texto/fondo y contención; no importar React/CSS.
- [Qt Animation and Transitions](https://doc.qt.io/qt-6/qtquick-statesanimations-animations.html),
  [SpringAnimation](https://doc.qt.io/qt-6/qml-qtquick-springanimation.html),
  [SmoothedAnimation](https://doc.qt.io/qt-6/qml-qtquick-smoothedanimation.html),
  [Behavior](https://doc.qt.io/qt-6/qml-qtquick-behavior.html) y
  [Transition](https://doc.qt.io/qt-6/qml-qtquick-transition.html): retorno físico
  y seguimiento continuo tienen APIs y parámetros distintos; Behavior no permite
  cambiar su Animation asignada después de construcción.
- [ParallelAnimation](https://doc.qt.io/qt-6/qml-qtquick-parallelanimation.html),
  [SequentialAnimation](https://doc.qt.io/qt-6/qml-qtquick-sequentialanimation.html),
  [HoverHandler](https://doc.qt.io/qt-6/qml-qtquick-hoverhandler.html),
  [TapHandler](https://doc.qt.io/qt-6/qml-qtquick-taphandler.html) y
  [MultiEffect](https://doc.qt.io/qt-6/qml-qtquick-effects-multieffect.html):
  evaluados; conservar MouseArea donde ya tiene grab/scroll evita alterar la
  interacción. Un progreso común sincroniza el swap sin secuencias por icono;
  los botones no necesitan efectos adicionales.

## Cobertura completada tras revisión de Win+M

La primera pasada dejó varias acciones con wash/press pero sin gesto propio en
el icono. Esta revisión conecta explícitamente `MaterialIcon.interaction` con
su dueño en las surfaces: ningún icono consulta servicios para inferir hover.
Iconos de energía, suspensión, reinicio, logout, lock, añadir/quitar y conectividad
comparten el mismo progreso, con escala/viaje/giro según significado. Los iconos
decorativos permanecen quietos en reposo y transicionan al cambiar de estado.
Las etiquetas de acciones acompañan ese progreso sin cambiar el layout.

Win+M: las cuatro tarjetas responden con fondo, icono y etiqueta; el retorno
comprime fondo/contenido y mantiene Button/hitbox fijos. La preview comprueba
los cuatro iconos, hover, presión, retorno y cancelación sin ejecutar energía.
El panel real se abrió mediante el IPC usado por Win+M y se inspeccionó en Wayland;
se cerró después. El atajo físico no se simula durante estas comprobaciones.

También se migró el menú de energía del lockscreen, se conectó hover/press a la
carátula de la gota real (faltaban esos bindings), se animan cambios de glifo de
batería y se cubren botones de la demo Fluid. Fuera del sistema de botones quedan
las capas sin contenido para dismiss, scroll, drag y escritura: conservan sus
gestos y no reciben efectos de botón que pinten toda la pantalla.

Validación final: interaction/session/lockscreen/media-motion y carga de las 12
surfaces no Auth pasan. La preview Wayland comprueba todas las acciones de sesión
con eventos QtTest; lint de primitivas y SessionSurface pasa. Stress Wayland
**aislado**: 127 frames, media16.95ms/max22.09ms, escala máxima1.0000, cero sin
asentar. Una corrida concurrente con la preview dio19.50ms: no se comparan como
benchmark A/B porque competían por render. Estas métricas son de la fixture.


## Referencia Animate UI · iconos vectoriales

La petición posterior de [Animate UI](https://animate-ui.com/docs/icons) sustituye
la interpretación anterior de «icono animado» como glifo completo con hover.
Se usan las geometrías oficiales de [Lucide](https://github.com/lucide-icons/lucide)
y movimiento propio de Isla implementado en QML, inspirado en sus animaciones
por trazos/piezas. No se importa React ni Motion para web. Licencia en
`docs/licenses/lucide.txt`; datos locales en `AnimatedIconData.js`.

Galería verificable: `quickshell -p bar/animated-icons-preview.qml`.
Comprueba 16 familias, piezas individuales activas, asentamiento sin loop,
interrupción por reduceMotion y parada al ocultar. Capturas en
`/tmp/isla-icons-rest.png` y `/tmp/isla-icons-motion.png`.


Catálogo actual: 80 nombres y 267 nodos; incluye las acciones Win+M, toolbar,
lockscreen, estados dinámicos de batería/clima y fuentes multimedia. Pruebas
actualizadas pasan; shell recargado y sesión real inspeccionada. Stress96 después
de retener delegados por cantidad de piezas: media18.31ms, max62.48ms,116frames,
cero controles sin asentarse. Los cambios masivos de vectores cuestan más que
las ligaduras; no se afirma coste igual ni fluidez universal.
