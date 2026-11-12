# Cuerpo · motor y composición

Motor sin contenido ni servicios multimedia. `BodyEngine` recibe geometría,
ánimo, hora, puntero, música y movimiento reducido; publica pill, brote y luz.
`BodyShader` recibe esos datos y colores de Theme desde la composición.
`PillBody` lo conecta a la pill de producción. Con `appearance.waterBody=false`
(default) conserva la entrega de reposo al material de Fase 3. Con `true`,
`body.frag` recibe geometría y decoraciones de todos los surfaces; `PillMaterial`
descarga sus decoraciones. Morph, contenido e input siguen siendo propiedad
de la pill. W3 incorpora gotas y cuellos; W4 añade arte, recepción y acento.

Geometría en píxeles lógicos, origen superior izquierdo. Reserva 90 ×
`designScale` de margen por lado para aura/sombra; evita recortarlas.
`designScale` y `fusionRadius` corresponden a S y K del HTML (QML exige minúscula).
`wallOrigin` es el origen de la superficie en pantalla; `screenSize` define
el cover centrado. `wallpaperSource` vacío usa el fondo procedural de Theme.
`beatEnvelope: -1` usa 104 bpm; 0..1 sustituye ese reloj.
`manualStep` permite pruebas deterministas sin activar los relojes.
La respiración usa Timer de 33 ms en reposo; active=false/reduceMotion lo detienen.
Inactivo tampoco integra por cambios de geometría/puntero; manualStep permite
refrescos explícitos en fixtures. `outsideOpacity` conserva aura/sombra en demos;
PillBody usa 0 para el aura; en water la sombra tiene exposición independiente
y alfa máxima 0.14, por debajo de ignore_alpha=0.15 del compositor.
Software o error del shader recuperan el material existente.

Desde la raíz del proyecto:
```sh
(cd bar/body/shaders && /usr/lib/qt6/bin/qsb --qt6 -o body.frag.qsb body.frag)
quickshell -p bar/body-demo.qml
node bar/tests/body-brain.cjs
ISLA_CONFIG=/tmp/isla-body-test.json QT_QPA_PLATFORM=offscreen quickshell -p bar/body-regression.qml
ISLA_CONFIG=/tmp/isla-body-test-gl.json QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=rhi QSG_RHI_BACKEND=opengl quickshell -p bar/body-regression.qml
/usr/lib/qt6/bin/qmllint bar/body/*.qml bar/body-demo.qml bar/body-regression.qml
```
Reinicia la demo después de recompilar: reload no invalida la caché qsb.
Offscreen software omite la compilación del shader; OpenGL/Wayland la comprueban.
Offscreen no sustituye QA visual en Wayland.

Teclas: 1–5 ánimo, ←/→ hora, N hora local, M música, B respiración,
R movimiento reducido, Esc salir; clic activa el teclado.
Para capturas reproducibles, `ISLA_BODY_TEST=1` habilita IPC `scene` en
`body-<monitor>`: ánimo, hora, música y atención derecha. No mueve el cursor real.

Fase 2: arrastra `captura.png`; G suelta/llama la gota y D devuelve el archivo.
Entradas: `dropCommand`, `itemPos`, `itemDragging`, `dropTarget`; señal `itemReleased`.
Pruebas: `node bar/tests/body-drop.cjs` y `quickshell -p bar/body-drop-regression.qml`
(usar los entornos offscreen anteriores). Capturas/límites en
`docs/cuerpo-fase2-2026-10-30/REPORT.md`. Archivos reales y capa mínima: Fase 4.

Archivo guardado: BodyMessenger publica `dock` (x, y, radio) y estados de
hover/pulsación; PillBody lo dibuja como gota acoplada en el mismo SDF (brota
del borde inferior, se absorbe con `exposure`). No hay chip aparte.
`storedWidens` ensancha el núcleo con archivo guardado (demo); PillBody lo apaga.
`colBase` es el vidrio en reposo; PillBody usa Theme.cardBot con tema claro.

Integración: `bar/body-pill-regression.qml` comprueba entrega de material,
interrupciones, compact/split, escala, inactividad y accesibilidad. Usar RHI o
Wayland; software comprueba sólo fallback. Informe: `docs/cuerpo-fase3-2026-10-30/REPORT.md`.


## Agua W1 · opt-in

`appearance.waterBody` no depende de personality/liquidSurfaces: éstas sólo
habilitan reposo expresivo. `exposure` vale 1 mientras running, backend soportado,
sin error ni reduceTransparency; no lleva Behavior ni alfa compensada. El shader
sigue liveHeight, radio y captura izquierda/derecha sin otro muelle geométrico.
En reposo mantiene respiración e inclinación acotadas. Un SpringValue de presencia
(Motion.strokeSpring.lift) retira esos offsets, el bulto y la gota al abrir un
surface; conserva posición y velocidad al invertir. No anima geometría de layout.
Radio y fusión del cuello de archivo se retiran juntos para no dejar hinchazón.

`reading` reproduce bodyAlpha y las paradas 0/.46/1 de cardTop/cardBot del material.
El interior `d < -11*s` devuelve ese tinte premultiplicado con dithering antes de normales,
lente y wallpaper. El borde respeta edgeExposure/suppressEdge; las decoraciones
de recepción, barrido, notificación y arte seguían en el envoltorio en W1;
W4 las incorpora al campo (contrato actualizado abajo).
Software, error o reduceTransparency recuperan el material completo, sin sombra
FBO del material mientras el shader esté activo.

Caché: durante el movimiento el ShaderEffect dibuja directamente, sin layer.
Con caché habilitada, BodyShader reúne sus parámetros de render (estado del
shader, tema, geometría, origen y opacidad incluidos). Cada cambio reinicia el
contador; seis cuadros consecutivos sin cambios congelan un ShaderEffectSource
live:false. Su origen y extensión se alinean a píxel físico, con smooth:true.
Durante cambios sourceItem es null; no se redimensiona un FBO por cuadro.
FrameAnimation deja de pedir cuadros tras asentarse. Con caché deshabilitada
renderInputs es null y no construye el array. Respiración activa deshabilita
la caché de forma continua: no alterna con el Timer de 33 ms. Contenta y otros
ánimos en movimiento tampoco activan layer. Al cambiar entradas se muestra la
fuente; al asentarse se captura una vez. La rama legacy no conecta la captura.
Esto requiere comprobación RHI de invalidación, alineación y coste; no se ha
medido ahorro GPU con este entorno.

El dithering water es espacial, sin fract(time). sleepWhenStill hace que puntero
quieto o beat externo fijo dejen de pedir cuadros al asentarse; música sintética,
ánimo contenta y respiración explícita siguen sus relojes. running=false y
reduceMotion paran los relojes; reduceMotion resuelve los muelles a destino.
Fullscreen/lock dependen de que la composición retire running; no se ha probado
la integración con la sesión real.

Sombra water: SDF desplazada 7*s, alfa min(shadowA,0.14)*shadowExposure,
con shadowExposure=reading*edgeExposure (cero en reposo; también cero en auth).
Es independiente de outsideOpacity=0: el aura sigue apagada. El margen de 90*s
conserva espacio para la sombra. El límite de alfa pretende evitar la segunda
placa de blur; hay comprobación de píxeles en el fixture, pendiente de ejecutar
con RHI y de capturas Wayland. Informe y línea base: docs/agua-w1-2026-10-31/.
No activar por defecto antes de QA.

## Agua W3 · gotas y cuellos

La composición conecta cinco `FluidCompanion` (media, sesión, ajustes, grabación
y notificación) a `PillBody`. Cada una publica `fieldBox` (centro y semiejes en
coordenadas del body) y `fieldShape` (radio y fusión en píxeles lógicos).
`body.frag` une sus cajas redondeadas al campo existente antes de calcular
relleno, normales, luz, borde y sombra. Son cinco entradas fijas, sin bucle nuevo.
El dominio incluye todas las cajas y el margen de 90*s; pill, brote y archivo
guardado se trasladan al mismo origen. El borde exterior del campo permanece
expuesto aunque la gota esté unida; no existe borde interior que ocultar.

El cuello conserva los umbrales de histéresis de FluidCompanion. Su fusión sigue
`Motion.strokeSpring.lift`, integrado desde el FrameAnimation existente de la
gota; retarget conserva valor y velocidad. No cambia sus muelles de posición,
captura, tamaño ni fases. `manualStep` permite comprobar interrupciones sin reloj.
Al asentarse paran ambos integradores; las diez entradas también invalidan la
caché W1, que espera seis cuadros quietos y captura una sola textura live:false.
No se habilita el layer de recorte de la gota en este camino.

Con renderer disponible no se cargan `PillMaterial` ni `FluidNeck` de la gota.
Software, error del shader, waterBody=false, reduceTransparency, reduceMotion o
Messenger recuperan ambos Loader con sus bindings anteriores. El contenido y
sus controles siguen en la gota; arte ambiental y recepción alojados antes en
su PillMaterial se incorporan al campo en W4. No se modifica el respaldo FluidNeck.

`bar/water-drop-regression.qml` comprueba Loader, histéresis, continuidad al
invertir, coordenadas izquierda/derecha/centrada, brote, quietud y fallback.
Su rama RHI captura una fila que cruza el cuello y exige variación adyacente de
luminancia <=32/255 (incluye dithering), además de caché e invalidación.
En este entorno esa rama no crea contexto OpenGL: píxeles, sombra/luz continuas
y coste GPU siguen **no verificados**. La inversión no añade salto instantáneo;
el recorrido normal a 60 Hz puede superar 1 px/cuadro. No equivale a una prueba
de saltos <=1 px entre imágenes renderizadas. Evidencia y comandos:
`docs/agua-w3-2026-10-31/REPORT.md`. La QA Wayland corresponde a Claude.


## Agua W4 · decoraciones en el campo

`PillMaterial.shaderActive` descarga el Loader completo de decoraciones. No quedan
instancias de MediaAmbient, ReceptionPulse, halo, franja, velo ni tinte debajo del
shader. La composición envía arte, transición compartida, acento, estado despierto,
respiración de notificación y epoch a `PillBody`; la recepción Fluid se dirige al
body con la caja de la gota. Media ocupa el slot 0; su ambiente sigue el contenido
saliente durante cierre e inversión. La portada y los controles siguen siendo contenido.

`body.frag` mezcla dos imágenes de hasta 256 px, siguiendo slot/blend del reloj
ArtworkImage existente. Cinco muestras fijas por imagen producen ambiente con velo
y máscara suave; no hay FastBlur/FBO decorativo ni movimiento ambiental perpetuo.
No se muestrean imágenes fuera del cuerpo o de la máscara. El acento, la recepción
y el barrido modifican el tinte anterior a la luz; el único borde usa la normal y
la distancia del SDF unido, sin contorno rectangular interior. El aspecto de cada
imagen se envía como uniform compatible con ESSL 100. Las URLs, estados de carga,
aspectos y mezcla invalidan la captura, incluso si la segunda imagen carga tarde.

Recepción y barrido usan `Motion.strokeSpring.wave` y `.tide`, manualStep=true,
conservando posición/velocidad al recibir otro impulso o destino. Los integra el
FrameAnimation de asentamiento ya existente de BodyShader; no se añade reloj ni
bucle de cuadro. El barrido termina en un entero (intensidad cero en el wrap).
Tras asentarse se detiene ese reloj; layer permanece apagado y la captura W1
live:false se actualiza una vez. El arte no mantiene frames en reposo.

Software, error del shader, waterBody=false, reduceTransparency y reduceMotion
recuperan los Loader del material anterior. Al desactivar agua los muelles se
resuelven al destino. No se cambia geometría, muelles de layout ni sus tiempos.
`bar/water-decor-regression.qml` comprueba instancias, cableado, cierre/inversión,
muelles, reposo y fallback. Su rama RHI comprueba cambio de píxeles por portada y
fallo real de shader; la continuidad de cuello se mantiene en water-drop.
En este entorno RHI no crea contexto: píxeles y coste GPU **no verificados**.
Informe: `docs/agua-w4-2026-10-31/REPORT.md`. QA Wayland pendiente de Claude.

## Material vivo · el agua responde al contenido

Reglas puras en `WaterReactive.js`; `PillBody` las alimenta y `body.frag` las dibuja (uniformes al
final del bloque: `tintFrom/tintTo/tintCross/tintPresence`, `rippleT/rippleAmp/rippleOrigin`, `bassGain`).
- Tinte: color de `MediaPalette.extracted`, mezcla <= 12 % con guarda (contraste del texto >= min(actual, 7)
  sobre cardTop/cardBot). Cambio de pista: `SpringValue tintCross` (token `level`), sin temporizador.
  Pausa: `tintPresence` vuelve a 0 en 1,2 s.
- Onda: `PillBody.adjust(kind, value, muted)` desde los OSD de volumen/brillo; amplitud = min(1, 10·|delta|),
  450 ms, un solo anillo (reinicia desde la amplitud visible).
- Graves: `Cava.bass` (banda 0..6) -> envolvente 40/220 ms integrada en `advanceDecor` -> `bassGain` (1..1.08)
  sólo sobre el brillo especular. Ajuste `appearance.waterReactsToMusic`.
- Todo cuelga de `waterActive`: waterBody apagado, shader en error, software o reduceMotion = sin onda,
  graves ni tinte animado. Los cuadros sólo se piden mientras hay datos (`bassMoving`), muelle o anillo.
