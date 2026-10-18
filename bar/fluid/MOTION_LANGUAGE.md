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

- Ancho, alto, radio y desplazamiento vertical usan `SmoothedAnimation` con
  inversión suave y duración `Motion.morph`. Al retargetear conservan velocidad;
  no reinician una curva Bézier desde reposo. Notificaciones usan su duración
  semántica existente. Referencia: [Qt SmoothedAnimation](https://doc.qt.io/qt-6/qml-qtquick-smoothedanimation.html).
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
ese mismo progreso. El puente procesa su geometría síncronamente para acompañar
los cuerpos en el mismo frame y evita acos fuera de dominio. La ocultación exige
contención en la cápsula completa con tolerancia0.08·s, no margen visible de3·s.

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

El editor vuelve como cápsula inscrita en la pill receptora, limitada al ancho
de la tarjeta: no forzar38×38 antes de ocultarlo. Seguir ancho y alto derivados
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
