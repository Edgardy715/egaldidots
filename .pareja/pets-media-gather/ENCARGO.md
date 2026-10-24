# pets-media-gather: gota de media solapada con el nicho de Mimo
Lee AGENTS.md y PROJECT_MEMORY.md. Recupera sólo lo pertinente con
`python ~/.codex/token-economy/recall.py 'pets nicho media gota gather'`.
Lee `.agents/skills/fluid-island-motion/SKILL.md` (sección de gotas/media) antes de tocar movimiento.

## Síntoma (captura del usuario, DP-1, barra en reposo)
Pill compacta: «6:30 PM» + Mimo en el nicho de la barra (`barPetPerch`, IslandRestStatus.qml:186).
Justo a la derecha del nicho, pegado al extremo de la pill, se ve un círculo semitransparente con la
carátula atenuada y el anillo de progreso: es `FluidMediaCompanion` (IslandOverlay.qml:539) a medio
reabsorberse en la pill. El contenido de la gota queda tenue y encima del borde de la pill, sin
hueco respecto a Mimo. El usuario lo reporta como bug (no sabemos si quedó congelado o fue un
fotograma de transición).

Reproducción observada por Claude: con `docs/drop-gather-2026-10-22/tools/fake-mpris.py` en marcha
la gota está separada a la derecha (bien). Al matar el proceso, la gota se absorbe en ~0.3 s y en un
fotograma aparece el mismo aspecto (nota tenue sobre el extremo de la pill tras Mimo). La pill además
se ensancha más allá del nicho y luego se encoge.

## Hipótesis a confirmar o descartar (con evidencia)
1. Atasco: `petNicheAnimating` (IslandRestStatus.qml:28) entra en `workspaceAnimating` de Pill.qml:174
   y desactiva el Behavior de ancho de PillMorphMotion.qml:26. Si el ancho del nicho no converge
   exactamente (target depende de `petLayer.bodyWidth`/`reachRight`/px, que pueden cambiar con la
   pose o el sueño), el flag se queda en true o parpadea y el morph/gather de la gota no llega a idle
   (fase de FluidMediaCompanion bloqueada, contenido a exposición parcial).
2. Geometría: el destino de absorción de la gota no tiene en cuenta el ancho del nicho mientras se
   abre/cierra, o la pausa del media (no sólo la desaparición del reproductor) dispara el gather
   con el nicho ocupado, y la gota se dibuja sobre el extremo de la pill.
3. `petContext: petLoader.item` en FluidMediaCompanion: la percha de media o el relevo de la mascota
   retienen la gota.

## Objetivo
Que la absorción/separación de la gota de media sea limpia con Mimo en el nicho: nunca se queda
congelada a medio camino, su contenido no se dibuja encima del cristal de la pill ni del nicho, y
la pill no da un tirón de ancho. Sin cambiar el diseño aprobado de la gota cuando no hay mascota.

## Archivos permitidos
bar/components/IslandRestStatus.qml, bar/components/PillHeaderView.qml, bar/Pill.qml,
bar/components/PillMorphMotion.qml, bar/components/FluidMediaCompanion.qml,
bar/components/FluidCompanion.qml (sólo si la causa está ahí), bar/windows/IslandOverlay.qml,
bar/pets/PetLayer.qml, bar/pets/PetPerch.qml, bar/pets/PetActor.qml,
bar/pets-overlay-regression.qml, bar/pets-regression.qml, bar/tests/pets.py y un fixture nuevo si hace falta.
No toques nada más ni reviertas cambios ajenos (el árbol tiene mucho trabajo sin commitear).

## Fuera de alcance
Rediseñar la gota, nuevas animaciones de mascota, ajustes nuevos, Pac-Man/occupiedLevel.

## Criterios de aceptación
1. Causa raíz identificada con evidencia (traza, prueba o medición), no sólo hipótesis.
2. Regresión automatizada que falla sin el arreglo y pasa con él: reproduce aparición y desaparición
   del reproductor (y pausa si aplica) con la mascota en el nicho (despierta y dormida) y comprueba
   que la gota llega a su fase de reposo en un tiempo acotado y que `petNicheAnimating` vuelve a false.
3. Ninguna regresión en las pruebas existentes listadas abajo.
4. Invariantes de pets intactos: timers armados de forma imperativa, umbrales 0.95, coste cero
   oculta/dormida, sin máscaras de input nuevas.
5. Si puedes acceder a Wayland: secuencia `grim -g "560,0 800x60"` de 12 capturas cada 60 ms al
   matar fake-mpris, antes y después, guardada en docs/eshell-pets-redesign-2026-10-23/qa-media-gather/.
   Si no puedes, dilo como no verificado (Claude hará la QA visual).

## Validación
python bar/tests/pets.py; node bar/tests/settings.cjs; y las regresiones de media/pill que usa
TESTING.md para gotas (media-dock-surfaces, layout-routing, pill-interface, pill-composition,
bar-layout-transition). Indica el comando exacto de cada una y su resultado.

## Informe final (obligatorio, en este orden)
ESTADO: completo | parcial | bloqueado
CAUSA: <una o dos frases con evidencia>
ARCHIVOS: <lista>
CRITERIOS: <n> — probado/no verificado/bloqueado — <evidencia>
PRUEBAS: <comando → resultado>
DUDAS: <preguntas para Claude o "ninguna">
No hagas commit ni push. Subagentes sólo si ahorran: economy_worker o economy_researcher; nunca
economy_architect (Astra).
