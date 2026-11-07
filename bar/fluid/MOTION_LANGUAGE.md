# Lenguaje de movimiento — Fluid Island

Este documento es el contrato visual de las superficies Fluid Island. Debe
guiar cualquier nueva superficie, estado o integración con la isla principal.

## Principio rector

Una transición representa **una misma superficie que cambia de estado**. No se
deben animar objetos independientes que aparecen, se encogen o se desvanecen
para simular esa relación.

## Reglas de coreografía

1. **El origen reacciona primero.** Una gota nace como abultamiento dentro del
   borde de la isla; nunca aparece colocada sobre ella.
2. **Un gesto, una trayectoria.** Una acción visible tiene un impulso continuo.
   No encadenar acercamientos, pausas ni correcciones si un mismo resorte puede
   llevar el estado hasta su destino.
3. **La tensión depende de la geometría.** El cuello conecta cuando los cuerpos
   se tocan, se estira y rompe con histéresis; no se programa por tiempo fijo.
4. **La salida conserva un residuo.** Al romperse un cuello se permite una
   microgota breve en el pinzamiento. No usar partículas decorativas.
5. **La llegada es captura, no reducción.** La gota conserva su volumen hasta
   que el casquete de la isla la cubre. Después el cuerpo vuelve a reposo; no
   se anima un círculo hacia tamaño cero a la vista.
6. **Sin costuras interiores.** Mientras dos cuerpos están unidos, se eliminan
   los bordes y brillos que revelarían figuras superpuestas.
7. **El contenido no es la masa.** Texto, controles y arte mantienen su propia
   legibilidad; su transición acompaña el recipiente sin deformarse.
8. **Interrumpible siempre.** Un nuevo destino conserva posición y velocidad
   actuales. La opción de movimiento reducido debe resolver directamente el
   estado, sin efectos de tensión ni residuos.

## Valores actuales del prototipo

- Unión: `stretch < 1.02`; rotura: `stretch >= 1.30`.
- Expulsión: resorte más lento para mostrar la tensión.
- Regreso: un único resorte de retorno. La isla empieza a envolver al superar
  la cercanía `stretch < 1.10`; no existe una segunda aproximación.

## Ajuste de la gota multimedia (2026-09-26)

- El origen flexiona `6 * s` y deja 32 ms para presentar el nacimiento antes
  de separar la gota. No se añade esa tensión con movimiento reducido.
- La carátula y el aro se revelan según la posición del centro y la separación
  del cuello, no mediante un temporizador. Se ocultan antes de invadir el reloj
  durante el regreso.
- El casquete de captura alcanza `20 * s`; sombra y halo siguen su extensión.
  Los bordes del satélite se suprimen mientras está unido para evitar dobles aros.
- Al interrumpir un retorno se restablece el destino del casquete a cero,
  conservando las velocidades del movimiento. Un casquete residual mantenía
  antes la gota visualmente pegada a la pill.
- Con movimiento reducido, la salida termina en `companion` y la entrada en
  `idle`, sin casquete residual.

## Referencias de criterio

- [Apple Motion HIG](https://developer.apple.com/design/human-interface-guidelines/motion)
- [Meet Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/219/)
- [Animate with springs](https://developer.apple.com/videos/play/wwdc2023/10158/)
- Referencia visual de Fluid Island proporcionada para este proyecto.

Estas fuentes son criterios de comportamiento y jerarquía visual. No se usa
código, material ni recursos propietarios de Apple.

## Pill y cambio de surfaces (2026-09-26)

- Radio y desplazamiento vertical usan `SmoothedAnimation` con inversión suave y
  duración `Motion.morph`. Ancho y alto de las surfaces usan, desde 2026-10-25,
  el muelle físico de «Materialización» (más abajo); `SmoothedAnimation` queda
  para notificaciones (duración semántica existente), el aviso de workspace y el
  reposo. Al retargetear ambos conservan velocidad; ninguno reinicia una curva
  Bézier desde reposo. Referencia: [Qt SmoothedAnimation](https://doc.qt.io/qt-6/qml-qtquick-smoothedanimation.html).
- El contenido necesita espacio en ambos ejes para revelarse. Entre surfaces,
  el contenido saliente se retira en `Motion.fast`, se sustituye y reaparece;
  la geometría continúa su recorrido. Una nueva petición sustituye el destino
  pendiente y cerrar cancela ese intercambio.
- Movimiento reducido resuelve directamente la geometría y el cierre del
  launcher; no inicia barridos de luz ni respiración de notificaciones.
- El fondo difuminado decodifica la carátula a 256 px constantes. Nunca cambiar
  `sourceSize` según el tamaño animado: causa recargas durante el morph.

## Controles y microinteracciones (2026-09-28)

El hit target permanece fijo. Sólo fondo/contenido/ícono comprimen; el retorno
corto usa SpringAnimation con tokens propios, independientes del motor de gotas.
Hover no expande universalmente los controles. Flechas y chevrons indican dirección;
los cambios de ligadura solapan salida/entrada. ReduceMotion elimina viaje y
compresión. Ver `docs/INTERACTION_SYSTEM.md` para cobertura, tokens y pruebas.

### Iconos por trazos (referencia Animate UI)

MaterialIcon resuelve los nombres existentes a geometría Lucide local y delega
las piezas en AnimatedSymbol. Animar arco/vástago, ondas, shackle, campana/badajo
y flecha interior conserva la caja 24×24. Secuencia finita al hover/foco/tap,
retorno desde progreso actual al salir; sin loops ornamentales. Estado nuevo
revela sus strokes; reduceMotion y ocultar completan inmediatamente. Theme
sigue siendo dueño del color y el control sigue siendo dueño del hit target.

## Cambios de contenido (2026-10-04)

Limpiar retira contenido antes de mostrar el estado vacío: ContentMotion comparte
opacidad/escala discreta/traslado corto, sin sombra adicional ni frames en reposo.
Clipboard inicia la salida sólo tras éxito del proceso; el fallo conserva filas.
AnimatedLabel desvanece etiquetas discretas y metadatos hacia el último valor,
conservando los números de sliders/tiempos como Text inmediato. MotionList usa
transiciones nativas add/remove/displaced y ScriptModel mantiene identidad.
MotionArea confirma activación con un wash breve, sin transformar el hit target.
ReduceMotion elimina traslados/escala y resuelve texto/geometría; el color sigue
siendo una señal suave. Ocultar detiene feedback y swaps pendientes.

## Coreografía compartida revisada (2026-10-05)

La carga asíncrona revela el contenido en Motion.standardSmall con traslado de
4·s; el morph conserva el control del espacio disponible. PillSurface aplica
smoothstep a su exposición, sin temporizador adicional. Los cambios sucesivos
de panel conservan la retirada en curso y toman el último destino; volver al
actual cancela el intercambio. Movimiento reducido completa ambas transiciones.

StaggerItem comparte un único progreso para opacidad, escala y traslado6·s, con
inversión suave, entrada Motion.standard y salida Motion.fast. El retraso total
se limita a Motion.standardSmall; calendario, workspaces y ajustes esperan a
contentReady. Escalas discretas evitan deformar los rótulos durante la entrada.

El cursor de IslaTextField usa comportamiento nativo inmediato; foco y placeholder
conservan transiciones accesibles. Las alas del lockscreen dependen de expansión
central, y su media inferior se retira al presentar la vista de acceso.

## Escritura compartida (2026-10-05)

InputCaret deja posición, altura, scroll y composición en manos de TextInput.
Durante escritura/navegación queda sólido y pasa suavemente de1.5 a2px; al
reposar alterna opacidad1↔0.25 con Motion.hover y la cadencia cursorFlashTime
del sistema. Selección, readOnly, ocultación, pérdida de foco o cierre detienen
el ciclo; reduceMotion mantiene cursor sólido. No hay retraso horizontal,
animación de caracteres ni copias del texto para pintar el cursor.

InputPlaceholder comparte la ayuda entre búsqueda, Apariencia, WiFi, Auth y
lockscreen. Se retira inmediatamente al escribir/componer y vuelve en Motion.fast
al vaciar. El rótulo flotante conserva font.pixelSize y transforma escala/posición
para evitar reflujo tipográfico. Lockscreen usa puntos con entrada140ms base,
sin giro ni rebote; los rangos de borrado se acotan al modelo y se conserva
únicamente identidad numérica.

Referencia API: https://doc.qt.io/qt-6.10/qml-qtquick-textinput.html#cursorDelegate-prop
Qt posiciona el delegate según cursorRectangle; no asignar x/y desde otro motor.


## Composición compacta (2026-10-09)

Un cuerpo central de56px reúne espacios/música/reloj/estado/perfil. El ancho
suma los grupos reales, padding y separaciones; el reloj queda entre música
y estado, y el cuerpo completo permanece centrado. Las gotas conservan38px. Los
módulos comparten el material exterior y se retiran cuando el ancho real del
morph no deja espacio al reloj. El ancho disponible para estado reserva avatar
por lifetime, sin depender de su exposición visual. Los paneles pueden encoger
el cuerpo: exposición usa progreso con signo tanto para ancho como altura.
Retorno de notificación restaura todo el ancho de reposo. Composición densa ajustada a la referencia del usuario; pruebas y límites en TASK_STATE.md.


### Dos composiciones y música integrada (2026-10-09)

barLayout compact mantiene música dentro del cuerpo (portada, resumen acotado,
visualizador, sin botones de transporte); split conserva laterales y gota. Ambos usan los mismos
servicios y MediaSurface. Cambiar diseño conserva la ruta abierta; la reserva
vertical sigue la composición. El host difiere la descarga tras evaluar progreso
de morph para evitar que destruir una surface cambie su altura dentro del binding.
La reapertura cancela esa descarga mediante comprobación del estado actual.


### Propuesta de acabado compacto (2026-10-09)
Ancho natural de metadatos, portada36 sin aro y título/artista13/11. Selección
de workspace integrada más tenue,28px sin sombra; split conserva su diseño.
En ancho insuficiente, portada accesible sin fragmento de título. Propuesta
pendiente de valoración del usuario, no diseño aprobado.


### Transiciones de composición y origen de Configuración (2026-10-09)
Retirada de contenido → commit de modo → morph existente → revelado cuando
la geometría se asienta. Esperar absorción de media incluso si Escape cambia
la ruta durante la retirada; el estado de navegación se conserva. Reloj de
launcher/auth también se retira antes del commit. Inversión retargetea desde
el estado actual y reduceMotion resuelve sin espera.
Configuración nace en el centro de la pill y viaja al centro de pantalla;
puente y absorción comparten ese eje. No hereda captura del borde derecho.

### Configuración y contexto musical (2026-10-11)
Configuración conserva la gota musical en split y el resumen de reposo en compact.
No necesita absorber media antes de abrir. Al salir hacia otra tarjeta, termina
su absorción con la pill en reposo antes de desplegar el destino; reabrir retargetea
el mismo companion. Reduced motion resuelve directamente. Auth tiene prioridad
inmediata y se dibuja por encima del retorno. Calendario integra un resumen
musical fijo bajo el clima y absorbe la gota externa al desplegarse, evitando
duplicar el contexto. Su resumen abre la surface media.

### Iconos y navegación alternativa (2026-10-11)
El gesto de icono combina hover y engagement del control: foco por Tab y
selección semántica por flechas reciben la misma respuesta finita. MotionButton
incluye highlighted en InteractionMotion.focused; Session enlaza su selección
a highlighted. Bindings locales de hover no excluyen el foco del control.
Movimiento reducido y controles deshabilitados mantienen sus límites existentes.


## Continuidad de expulsión y captura (2026-10-12)

FluidCompanion integra el resorte amortiguado con su solución exacta y el tiempo
real del frame, conservando los parámetros y velocidades existentes. Reposo
requiere posición y velocidad asentadas; reabrir durante absorción retargetea
sin reiniciar nacimiento. Activar reduceMotion durante el viaje resuelve destino.

El cuello se pinza por smoothstep entre stretch1.02 y1.30 hasta grosor cero;
al retornar nace en1.30 y crece hacia1.02. Borde/brillo de ambos cuerpos siguen
ese mismo progreso. El cuello es GPU (`FluidNeck`, `shaders/fluid_neck.frag`):
unión smin de las dos SDF de rounded box (k=neckBlend, 32→10·s según la
cintura), pintada sólo fuera de ambos cuerpos y recortada al casco convexo
exacto de ambos rounded box (búsqueda ternaria sobre la interpolación); smin no
infla lados convexos, no cuadra el extremo con la gota dentro y una tarjeta
centrada ancha recibe menisco a todo el ancho de la pill, no una columna. Cada
extremo del cuello lleva el vidrio de su cuerpo (alfa por readingExposure,
degradado y banda de acento) y se funde por d1/(d1+d2). Mientras la gota solapa
al cuerpo receptor (unida o en nacimiento/separación/retorno/absorción, no
asentada), `fluid_cut.frag` recorta esa parte con la misma SDF. Los bordes AA
contiguos compensan el alfa del vecino, x=(1-c)/(1-c·a): sin vidrio doble ni
línea de fondo. Halo, borde y brillo de la gota se apagan en los 7·s previos al
contacto (edgeClearance), así el layer del recorte nunca los corta. Sin
CurveRenderer ni teselado CPU; FluidMetaballBridge queda sólo para FluidIslandDemo.
La ocultación exige contención en la cápsula completa con tolerancia0.08·s.

Regresión: companion-continuity, absorption, centered/session/settings-companion.
Capturas nativas y límites de medición: informe shell-smooth de2026-10-12.

### Configuración: carga y contracción sin reflow (2026-10-12)
El editor retenido se prepara asíncronamente en reposo; sólo se expone una
instancia Ready. Conserva su tamaño de tarjeta y escala uniforme dentro del
recorte durante el morph: los controles no reorganizan filas por fotograma.
Radio de tarjeta limitado a24·s y a media dimensión, sin inflar esquinas a
mitad de la absorción. El resorte y el retarget conservan sus tiempos/velocidades.
El contenido escalado acompaña el tamaño hasta fracción0.06 (exposición completa
a0.70), evitando un rectángulo vacío durante la mayor parte de la contracción.
Las surfaces que hacen layout dinámico conservan su ventana anterior0.45–0.80.


## Captura de panel centrado (2026-10-12)

(Sustituido 2026-10-22, ver «Brote y recogida».) El editor volvía como cápsula
inscrita en la pill receptora. Seguir ancho y alto derivados
al cambiar layout sin reiniciar velocidades. Al contacto, recortar del módulo
la región recibida por la pill; apilar vidrios translúcidos no oculta ese contenido.
El recorte se activa sólo durante retorno unido y se retira al retargetear.

## Bloqueo: lectura y coste de composición (2026-10-13)

La pill de estado se convierte en una tarjeta de acceso centrada sin alas.
El contenido espera espacio suficiente; error, éxito, retirada e inversión
conservan el motor existente. Música en reposo acompaña el reloj; al escribir
se retira y sólo reaparece debajo del acceso cuando cabe completa.
El fondo usa la imagen y un velo estático: no animar blur a pantalla completa
ni volver a muestrear el wallpaper bajo cada tarjeta. LockGlass conserva
PillMaterial como material único; tipografía desde Theme y fecha en español.
Movimiento reducido resuelve geometría y elimina el recoil de rechazo.
Pruebas: bar/lockscreen-entrance-regression.qml y bar/lockscreen-motion-regression.qml; no sustituyen PAM real ni pruebas físicas.

## Material y recambio multimedia (2026-10-17)

La profundidad del material añade luz direccional fija y absorción interior tenue;
no sigue el puntero. materialDepth controla intensidad y cero elimina ambas. Las
capas siguen edgeExposure para no dibujar costuras al unir o absorber cuerpos.

ArtworkImage conserva la portada saliente hasta decodificar la nueva. El panel y
su ambiente comparten barrera de carga y progreso, con decodes fijos416·s y256px.
El dueño vive en la composición de cada layout y conserva las URLs durante la
retirada del panel. Las peticiones rápidas terminan el fundido en curso y toman
la última pendiente. Error o fuente vacía retiran el arte obsoleto. Ocultación,
mediaTransitions desactivado y movimiento reducido resuelven sin animación.

Los metadatos discretos funden dos capas de glifos sin blur ni estiramiento.
El título expandido reserva dos líneas completas, redondeadas hacia arriba para
no recortar la segunda por fracciones de métricas tipográficas. No animar ancho
ni usar este componente para reloj, sliders o tiempos continuos.

## Ambiente y letras musicales (2026-10-17)

El ambiente multimedia difumina un campo192×128 antes de ampliar, con decode256px
fijo y el mismo reloj de fundido de portada. Su deriva lenta conserva fase al
pausar; sólo avanza con reproducción y panel asentado/visible. Reduced motion y
mediaTransitions desactivado lo fijan; composición entrega estado a la hoja.

Las letras centran el viewport lógico y compensan el desplazamiento por fila:
retardo por distancia limitado80ms y asentamiento Motion.standardLarge. Retarget
parte del offset actual; navegación manual, ocultación y reducido limpian offsets.
Saltos mayores al85% del viewport resuelven directamente. Métricas fijas, énfasis
por color/escala discreta y seek sólo con tiempo sincronizado/capacidad real.
Botón principal cambia de círculo a esquinas17·s al reproducir, sin girar el icono;
portada pausada0.94→reproducción1. Las cajas e hit targets permanecen estables.

### Reproductor rediseñado (2026-10-17, sustituye acabado anterior)

Usuario prefiere iconos Material Rounded rellenos y formas de Swiftify a Lucide
para este reproductor. MediaTransportButton/MediaSymbol limitan esa elección a
media: glifos locales con rasterización nativa, hit target nativo estable y forma
principal sinusoidal5→9lóbulos (500ms por Motion). Giro16°/s conserva fase y sólo
avanza en reproducción visible/habilitada con mediaMotionAllowed; reduced/hidden
lo detienen. No gira el símbolo. Portada circular con CAVA radial real en música;
preview16:9 para fuentes generales. Fondoalfa0.32; no añade motor de material.
Metadatos de altura natural viven en espacio exterior estable: transporte/timeline
no se desplazan entre una/dos líneas. Letras coexisten junto a portada, sin duplicar
superficie. Detalles/pruebas: docs/swiftify-2026-10-17/redesign/REPORT.md.

### Afinado de respuesta y seguimiento (2026-10-17)

El diseño aprobado permanece. Espectro expandido48radios3.5·s con recorrido3→31·s
y compresión perceptual local de señal; silencio sigue quieto y CAVA compacto
conserva su tratamiento. Letras activas emiten desde glifos con acento y énfasis
interrumpible; al reabrir retoman posición actual y la navegación manual cede al
seguimiento tras3.2s de reposo. No introducir desfases temporales sin evidencia.

SwiftMediaTimeline sustituye sólo la barra del panel: trazo4→6·s al interactuar,
onda34·s y amplitud1.6→2.4·s; fase viaja una onda/1.6s. Tirador4×18·s aparece al
hover/foco/drag, cola atenuada y separada. Tiempo viene de MediaSession; el reloj
visual sólo mueve fase. Hidden/reduced/drag detienen fase; pausa aplana la onda.
Validación y límites: docs/swiftify-2026-10-17/refinement/REPORT.md.

### Exactitud y emisión interior (2026-10-18)

La barra no interpola por segunda vez el progreso de MediaSession: pinta su valor
actual inmediatamente, incluido seek/cambio de pista. La onda y hover conservan
sus animaciones y la fase sigue tiempo real; no usar un reset cosmético que
compita con MPRIS. Arrastres se cancelan al perder duración/visibilidad/actividad.

Botón principal conserva forma/giro aprobados y comparte musicAccent; símbolo
blanco/negro según luminancia del relleno efectivo. La surface emite luz radial
interior desde el disco, más tenue al pausar, sin borde exterior ni loop adicional.
La paleta cancela trabajos obsoletos y reintenta fallos de forma finita.

### CAVA pequeño y aro compacto (2026-10-18)

CompactMediaStatus recibe progreso de MediaSession desde composición y lo entrega
al aro de portada. El CAVA pequeño compartido emite neón con el acento musical
y energía real sobre una única capa de las cinco barras; sin reloj adicional
ni cambio de alturas/eje. Pausa, falta de señal, ocultación y movimiento reducido
desactivan la capa. El recorte existente conserva la separación con portada.

### Cambio de pista en reposo (2026-10-18)

Por petición del usuario, portadas de reposo compacto/split acompañan cambios
de título/artista con compresión discreta (máximo7%; impulso Motion.press y
respuesta Motion.standardSmall desde valor actual). No transforma aro ni hit
target; misma portada de álbum también recibe señal. Nueva portada conserva
decodificación/fundido existentes y entra4·s desde abajo, sobre imagen retenida.
Metadatos funden con traslado4·s de salida/entrada en Motion.standardSmall.
ArtworkImage/CrossfadeLabel tienen desplazamiento0 por defecto; opt-in de reposo
no cambia panel, calendario, overview ni fondos. Expanded, hidden, reduced y
mediaTransitions desactivado cancelan compresión; reapertura no repite cambios
antiguos. No se anima progreso MPRIS ni se añade reloj continuo.

## Respuesta semántica y compañero (2026-10-21)

La recepción se expresa mediante un lavado radial finito dentro de PillMaterial,
con color Theme/Matugen, sin mover ni estirar texto. El pulso sigue confirmaciones
reales de servicios; clicks no equivalen a éxito. Eventos consecutivos durante
una onda se agrupan sin reset de radio. Hidden/reduced terminan el efecto.

El compañero original junto al reloj mira dentro de la pill y cambia expresión
por actividad/resultado. Parpadea sólo ante interacción con cooldown, sin loop idle
ni lectura global de cursor. Movimiento reducido elimina mirada, blink y viaje;
la actividad conserva texto. appearance.personality lo desactiva. Carga es aviso
compacto sin apertura/foco; info ordinaria no interrumpe surfaces activas.

La petición de Shelf se retiró: esta gramática se aplica a surfaces existentes.
Evidencia: docs/personality-2026-10-21/REPORT.md; fixtures personalidad/focus y
notificaciones, además de compacta/motion. No sustituye contratos Fluid previos.

### Afinado por valoración del usuario (2026-10-21)

El pulso anterior resultaba demasiado intenso. La recepción queda como luz tenue
acotada al borde inferior, sin aro expansivo ni invasión de todo el panel. Entrada
y salida sinusoidales. El hover de los ojos no muestra tooltip: luz local y
expresión acompañan la presión del control, con foco visible y target fijo.

### El compañero es la cara de la isla (prototipo, 2026-10-25)

**PROTOTIPO — no es la implementación final.** Un solo personaje vectorial junto
al reloj, del mismo material de la pill. Sin nicho, viajes ni cambios de ancho.
Carácter tranquilo, atento y un poco curioso. Ojos ligeramente asimétricos,
punto interior que sigue la mirada con retardo, párpados independientes y alegría
teñida con el acento de Theme. Mirada con resorte y deriva interior más lenta.

El roce horizontal o vertical cierra los ojos progresivamente y acompaña la mano;
la presión se acumula sin depender del refresco y se libera al parar. Tres
inversiones suaves en 1,4 s dejan alegría (mínimo 1,8 s entre caricias). Por encima
de 550 unidades/s el roce provoca cosquillas. Clic/teclado: curiosidad, juego y
«ya, ya»; la secuencia se reinicia tras 1,1 s sin clics. Después de una caricia
recuerda afecto durante 30 s y saluda con más calidez, sin persistencia ni puntos.
Hover prolongado (750 ms) despierta curiosidad; al salir conserva la mirada 850 ms.
La superficie acompaña el roce con compresión horizontal/estiramiento vertical
del 8 %, luz local y desplazamiento de hasta 1,1 unidades; comparte la presión
continua de los ojos y su liberación, conservando layout y target de interacción.
Un cuarto clic descubre una historia de 1,74 s: contiene un estornudo y guiña.
Cancela la sonrisa del tercer clic para conservar la anticipación visible.
Quinto clic: una luciérnaga cruza el hueco de la cara durante 2,6 s, seguida por
los ojos. La mirada y la luz comparten progreso y envolvente de entrada/salida;
el resorte habitual se desactiva durante el recorrido para evitar retraso por
retarget continuo. Halo y núcleo usan el acento de Theme y no salen del slot.
Ambas historias reutilizan la oportunidad existente de travesura; acercarse o
tocarlo interrumpe la escena. Sin temporizador ni loop de actividad adicional.
Seguimiento desactivado elimina también inclinación por roce y mirada de salida.
La cara no abre surfaces. Enfoque y Grabación: Super+U → Ajustes rápidos →
Actividades. REC y el texto informativo quedan fuera de su zona de interacción.

Cada momento es finito y exclusivo: anticipación, expresión y asentamiento;
confirmación → guiño; final de sesión/grabación → dos saltos; inicio de música →
dos vaivenes; sueño → bostezo y cierre; regreso corto → reconocimiento,
regreso tras al menos 60 s dormido → estiramiento y saludo. A veces de noche
intenta mantenerse despierto antes de bostezar (2,5 % por oportunidad de 2 min).
El parpadeo responde a interacción/estado y se interrumpe al comenzar otro gesto.
Atención importante usa ojos grandes y mirada abajo hacia la notificación central,
respetando la ocultación normal de la cabecera durante la expansión.
Sin loop idle ni respiración continua: la respiración acompaña un gesto puntual.
Reduced, ocultación o desactivación cortan los momentos y dejan el cuerpo quieto.

`CompanionBehavior` recibe contexto desde composición: puntero cada 260 ms como
máximo, celda del rail, clase de terminal/editor, progreso musical y Cava sólo
con reproducción y panel visible. No abre consumidores nuevos de Cava. El reloj
marca noche entre 23 y 6; bostezo nocturno al 10 % cada 2 min como máximo.
Travesura rara: 8 % por oportunidad de 10 min (normal: 28 %), nunca durante
launcher, auth, grabación o notificación; un bloqueo también cancela el momento.

Config.companion y Edots → Iris controlan sueño (180 s, rango 60–1800),
reacciones a código/música/noche, seguimiento y travesuras. appearance.personality
sigue siendo el interruptor general. IdleMonitor conserva sus inhibidores.
Iris (nombre de la cara) recuerda, en `isla/iris.json` y sin timers, sólo el histograma
de horas de la primera actividad del día y un ánimo lento (`IrisMemory`, opción
`companion.remember`). Saluda una vez por día en una sola pantalla: `welcome` (parpadeo
lento 220/260 ms InOutSine/OutCubic, sonrisa 2,2 s, squash 1,05 OutBack), `welcomeBack`
(igual, 3,6 s, tras más de 36 h) o `surprised` (ojos 1,25, tilt −7 OutBack 240 ms, un
parpadeo 70/150 ms). El ánimo sólo reduce la tirada de travesura (÷ 0,6–1,6).
Iris reacciona al sistema sólo ante sucesos reales y discretos (`companion.reactToSystem`,
`CompanionBehavior.react/noteBattery`): notificación crítica → `surprised`, diferida hasta que
la cara se vea (la notificación la cubre; las demás no hacen nada); batería ≤15 % descargando →
párpados pesados persistentes (`tired`, droop 0,35), empezar a cargar → `content` (squint con
sonrisa), llegar a completa → `stretch` (squash 1,18 OutBack, tilt atrás 240 ms, vuelta 380 ms);
captura activa → brillo del ojo en `Theme.error` sin gestos al azar y, al terminar, `relief`
(parpadeo lento 220 ms + exhalación 0,94→1); contraseña fallida → `no` (dos vaivenes
decrecientes de 120 ms InOutSine con párpado `wary` 0,25), éxito → `wink`. Un solo gesto a la
vez; `stopMoment()`/`settle()` los cancelan; en `reduced` no se mueve nada.

Iris viaja con el usuario (`companion.followFocus`). Las surfaces que ocultan la cabecera
reciben la cara en la esquina superior derecha (inset 22·s + 15·s, centro vertical del reposo):
una sola propiedad `perchTravel` 0→1, 400 ms (`Motion.standardLarge`) con `SmoothedAnimation`
(`velocity: -1`: una inversión a mitad de viaje conserva la velocidad), de la posición viva de la cara de reposo a la esquina, escala 1→1 y opacidad igual al viaje; al
cerrar o cambiar de superficie se reorienta desde el valor actual. Con movimiento reducido no hay
viaje (la cara de la cabecera simplemente se desvanece). Launcher y auth conservan la cara en su
cabecera. La mirada va a lo que importa en la superficie (cursor del launcher, línea actual de la
letra, fondo bajo el puntero, espacio bajo el puntero o las teclas en overview) por los mismos
resortes de siempre; lo que importa manda sobre el puntero (`followFocus`; sin foco, el puntero
sobre la pill guía) y reducido, dormida u opción apagada la devuelven a su comportamiento anterior.
La letra sincronizada también guía en el layout dividido: `IslandOverlay` inyecta la superficie
multimedia en `Pill.attentionItem`; límite: la mirada parte de la cabecera y no se reevalúa
mientras la tarjeta se mueve, y en layout dividido la cara no viaja. El saludo del día espera a
que la cara termine el gesto de despertar (polvo, bostezo; `CompanionBehavior.noteMoment/busyFaces`),
sin temporizador fijo. Lanzar una app o aplicar un fondo hace `wink`.

Vista previa ×3: `bar/companion-preview.qml`, con rótulo de prototipo visible.
Abiertos a valoración: amplitud a tamaño real, punto interior, tiempos/probabilidades
y reconocimiento de caricia física. Informes: docs/companion-polish-2026-10-25/REPORT.md
y docs/companion-interaction-2026-10-25/REPORT.md.

Visitas de Iris (`bar/Singletons/Visitors.js`): luciérnaga, polilla (23:00 a 05:59), gota,
burbuja y copo (diciembre) comparten una escena: una forma cruza el hueco de 30x26 y los ojos la
siguen con el mismo cruce de mirada de la luciérnaga; progreso 0→1 InOutSine, 1,8 a 3,6 s según
la visita, opacidad por envolvente. La polilla tiembla ±28° (rotación) y la burbuja estalla en el
último octavo (escala hasta 1,6 y un parpadeo de 70/150 ms). Ocupan la ranura rara de la
luciérnaga (1,25 %), repartida por pesos: ninguna probabilidad total sube. Sólo cuentan como
avistamiento si la escena termina; cualquier interrupción la cancela sin rastro. Tras media hora
dormida Iris «sacude el polvo» (`dust`): mitad de amplitud y 100 ms por paso frente a `no`,
parpadeo, 560 ms de pausa y bostezo. Los ojos llevan un 12 % de acento sobre el color de texto
(`Motion.standard`); en tema claro la pupila baja de 1,9 a 1,6 veces la escala para mantener el
contraste. Informe: docs/iris-delight-2026-10-25/REPORT.md.

### Grabación y actividades (2026-10-21)

Enfoque y grabación comparten surface mediante cambio finito de pestaña. El botón
de grabación transforma disco en detener; el estado confirmado gobierna la pill.
REC es una marca estable, sin parpadeo continuo. Pausa y desconexión se distinguen
sin depender sólo del color. Cuenta atrás cancelable al abandonar el panel; una
grabación real continúa. Reduced motion completa las transformaciones sin viaje.
La implementación OBS inicial fue sustituida por captura directa por GPU. No
simular progreso ni afirmar guardado/detención antes de que el grabador finalice.
Sin proceso auxiliar con controles cerrados y sin captura; sin animación continua
decorativa. El micrófono se activa explícitamente y el encoder no cae a CPU.

Afinado de grabación tras valoración (2026-10-21): el botón protagonista pasa a
barra de acción; radio y símbolo conservan morph finito. Tiempo/estado juntos y
audio agrupado persisten durante captura, sin reordenar el panel al empezar.
No altera servicio ni pill. Propuesta visual pendiente de aprobación del usuario.

### Gota de grabación izquierda (2026-10-21)

Recording.engaged se presenta en gota izquierda con motor compartido; música
permanece derecha. Datos por propiedades, mismo reloj de servicio. Nunca duplicar
REC en gota y header: recordingDetached dura hasta absorción completa. Si falta
espacio o sesión/settings ocupan ese lado, volver al header. Sesión espera antes
de salir. En compact, centro vertical coincide con barra; compactY mantiene
bodyY por defecto para otras gotas. Texto se revela al caber y se retira al
contraerse. Input sigue visualX/yPos reales, sin foco/modalidad en reposo.

## Brote y recogida de tarjetas (2026-10-22)

Una tarjeta expandida (settings, sesión) nace como yema redonda separada de la
pill y sólo florece tras pellizcar el cuello; al cerrar se recoge a esa yema,
ya sin contenido, y vuelve redonda: nunca una tarjeta ni una cápsula del ancho
de la pill unida por el cuello (se lee como bloque o trapecio). Esquinas sobre
24 sólo en mancha vacía; con contenido >0.25, 24. docs/drop-gather-2026-10-22/.

## Microinteracciones coherentes (2026-10-23)

- Selección: un único indicador compartido que se desliza (launcher, calendario,
  overview) en vez de anillos por celda que aparecen y desaparecen. Retarget con
  SmoothedAnimation; salta sin viajar cuando cambia el contexto (mes, grupo).
- Paginación lateral (mes, grupo de escritorios): desplazamiento corto en la
  dirección del cambio (18–28 px) más un leve fundido; nada bajo reduceMotion.
  Repeaters con huecos fijos para no reconstruir delegados ni capturas.
- Texto: AnimatedLabel/CrossfadeLabel sólo para cambios discretos (contadores,
  títulos, estados); nunca para texto que cambia con cada tecla. Peso tipográfico
  constante: el énfasis se anima con color, no con un salto de grosor.
- Rechazo: ErrorShake (oscilación amortiguada, Motion.standardLarge) en bloqueo
  y autenticación. Sin sacudidas bajo reduceMotion.
- Gestos: las tarjetas del historial de notificaciones siguen al dedo sin
  suavizado, se cierran con 35 % del ancho o un lanzamiento rápido y vuelven con
  OutBack suave; el botón de cerrar aparece con hover/foco.
- Listas con teclado: MotionList.revealIndex desliza contentY hasta la fila en
  vez de saltar con positionViewAtIndex.
- Hojas: no repetir con Behavior un valor que ya suaviza su fuente
  (ContentMotion, shownValue) ni fundir en Component.onCompleted lo que ya llega
  con su surface.

## Superficies líquidas (2026-10-23)

- Un estado activo no se enciende: se derrama. `LiquidFill` nace con la forma del
  icono del control y se extiende (ancho antes que alto) hasta el contenedor; el
  texto cambia de tinta sólo cuando el líquido ya lo cubre (`covered`).
- Una selección no se desliza rígida: `LiquidSelection` adelanta el borde de
  destino (~180 ms) y deja que el trasero lo alcance (~380 ms), así se estira al
  viajar y se recoge al llegar. Interrumpir retargetea cada borde desde donde está.
- Interruptores y deslizadores comparten la regla: el botón se alarga hacia su
  destino; el relleno del deslizador es una gota en 0 % y forma menisco al arrastrar.
- El líquido tiene volumen (más claro arriba, menisco fino); las tarjetas se separan
  por tono, sin contorno.
- Todo depende de `appearance.liquidSurfaces` (clásico intacto en false) y la
  cantidad de acento de `appearance.stateIntensity`; reduceMotion lo coloca sin animar.
- La tinta activa `Theme.stateContent` considera relleno normal/iluminado sobre
  ambas caras de la tarjeta. Prefiere tinta semántica con contraste 4.5 y, si no
  llega, maximiza el peor contraste entre candidatas semánticas, negro y blanco.
  No garantiza 4.5 para toda intensidad ni fondo; mediciones y límites en
  `docs/design-accessibility-2026-10-26/REPORT.md`.
- `appearance.reduceTransparency` fuerza `Flags.glassAlpha=1` para los materiales
  compartidos, sin sobrescribir la opacidad guardada ni modificar el movimiento.
  Al desactivarse vuelve a `Config.appearance.glassAlpha`.

## Materialización de surfaces (2026-10-25)

La petición actual del usuario (abrir y cerrar no se sentía premium) prevalece sobre
la retirada de septiembre de la «curva de rebase simulada»: aquello era una curva
Bézier con rebote fijo; esto es un muelle físico retargeteable que conserva la
velocidad. Los rebotes no se extienden a otros elementos.

**Geometría** (`PillMorphMotion`, tokens en `Motion.surfaceSpring`). Ancho y alto
integran `a = -w²e - 2·z·w·v` en subpasos de 1/240 s con `FrameAnimation` (sólo
corre mientras no está asentado; `step(dt)` es determinista para pruebas).
Los cuadros tardíos recuperan el tiempo transcurrido en esos subpasos, sin
ralentizar la animación por descartar tiempo. Una suspensión se limita a 2 s
normalizados por `motionScale` (máximo 480 subpasos); se publica una vez por cuadro.
Más allá del destino el muelle se endurece (`omegaFar`, `zetaFar`, mezcla suave en
`band` x recorrido): rebasa ~3 % y se asienta en ~600 ms, algo que un zeta constante
no logra (necesita ~1 s). La velocidad es continua; sólo cambia la aceleración.
- `open` (rest u otra surface -> surface): ancho w 9.0 / z 0.60; alto w 7.8 / z 0.60
  (90 % ~40 ms después que el ancho). Rebase 2.7-3.0 %, 90 % a 258/300 ms,
  asentado (< 0.5 px) a 604/638 ms.
- `resize` (misma surface con `contentHeld`, p. ej. resultados del launcher):
  w 15 / z 1, sin oscilación.
- `close` (destino = reposo): ancho w 17 / z 1 (sin infrarrebase); alto w 17 / z 0.85
  (retroceso < 0.5 %). `closeness` es unilateral: rebasar cuenta como llegado, para
  que el contenido de reposo no se atenúe por el retroceso.
- El tipo se decide en el primer paso tras el retarget, cuando destinos y estado de
  la surface ya se evaluaron (el orden de los handlers no es fiable). Un A->B usa
  `open`; un retarget a mitad de vuelo conserva posición y velocidad.
- Notificaciones, aviso de workspace y movimiento reducido NO usan el muelle (misma
  ruta y duraciones de antes). `springOn` depende de la altura, no del ancho, para
  que el aviso de workspace (sólo ancho) no secuestre el muelle.
- El radio no rebasa. El muelle ignora `Motion.morph`; escala con `Flags.motionScale`.

**Contenido** (`PillSurfaceHost`). p = `morphCloseness` x `loadReveal` x `returnFade`.
Entrada: escala 0.94 -> 1 (origen superior), desenfoque `MultiEffect` (0.6 x
`blurMax` -> 0) y 6·s px hacia abajo -> 0. La capa sólo existe mientras p < 1 o
hay intercambio; en reposo no hay capa (escala exactamente 1). A->B: la saliente se
retira a escala 0.97 con desenfoque y fundido (`Motion.fast`); la entrante se
materializa. Cierre: el contenido sale entre el 90 % y el 60 % del crecimiento
(antes: 80 %-45 % al abrir), sin alargar el cierre; la fase 2 del launcher se retira
con `returnFade` (`Motion.fast`) en lugar de cortarse. Contenido de reposo: vuelve
con escala 0.96 -> 1 atada al mismo fundido. Superficies grandes (> 480000 px² a
escala 1: wallpaper, ajustes) limitan `blurMax` a 14. Movimiento reducido: sin
escala, capa ni desenfoque.

El launcher pide foco al cargar el buscador, sin esperar al asentamiento ni a
`Motion.morph`. Los reintentos sólo actúan mientras está abierto y no cerrando;
cerrar o descargarlo libera el foco. La entrada útil y la cola visual se validan
por separado (`launcher-focus-regression.qml`).
# Integración de entrada y escritorio · 2026-10-26

Fullscreen invalida inmediatamente la ruta, el docking pendiente y la captura de
teclado de ese monitor; pill y gotas conservan su retirada visual compartida.
El cierre animado del launcher libera teclado desde el primer tramo. Las acciones
de aplicación/workspace se programan fuera del contexto descargable del panel;
Escape respeta primero búsqueda y popups locales. No añadir una segunda espera
de morph para ejecutar o enfocar la aplicación.

### Quicksilver: controles y reproductor (2026-11-06, sustituye Swiftify/Material)

Petición del usuario: los controles y el media de Bead parecían Material You;
se quiere identidad propia (refs Squish Switch, Rubber Segment, Wake Slider).
Lenguaje: canal hundido (`kit/MercuryChannel`) donde corre el mercurio y gota
cromada (`kit/MercuryBead`) que es lo que se toca; el acento entra saturado como
hilo de cinabrio o tinte de la gota, nunca como relleno tonal.
- Switch: gota 20 que se estira hacia el destino y se aplasta al pulsar; hilo
  de acento detrás. Slider: hilo con estela (muelle sólo al arrastrar) y gota
  que se aplasta al pulsar. Segmented: pastilla de vidrio elevada con gota-punto.
- Play principal: gota de mercurio teñida con el color de portada (círculo en
  pausa; al sonar respira con dos ondas cos(2t)/cos(3t) a 40°/s, sin girar).
  `primaryInk` se calcula sobre el cuerpo plateado. Activo secundario
  (aleatorio/repetir): gota-punto bajo el glifo, sin contenedor tonal.
- Timeline: canal hundido + hilo de mercurio teñido + gota cabeza 9→14·s al
  apuntar. La fase (wavelength/1.6 s) mueve reflejos sobre el hilo; pausa,
  oculto y reducido los apagan. Sin onda, sin huecos, sin tirador de barra.
