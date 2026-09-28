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
