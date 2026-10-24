# Eshell Pets — fase 3: música y wallpapers

Fecha: 2026-10-22. Integración funcional verificada en compact y split.

## Resultado

Mimo acompaña ahora tres contextos existentes. En reposo usa el botón de
workspaces; al abrir música pasa a la cabecera, junto al nombre del servicio y
conservando su icono; en wallpapers ocupa la placa decorativa del encabezado.
No se añadieron ventanas, máscaras de input, servicios ni consumidores de audio.

- Música: mira al centro real de la portada, reacciona brevemente al comenzar/
  reanudar y al cambiar pista, y descansa con ojos cerrados durante pausa.
  Seek, posición y actualizaciones de portada no disparan reacciones de pista.
- Wallpapers: sigue con la mirada las miniaturas seleccionadas o bajo el puntero.
  La selección por teclado prima sobre un hover estacionario. Una selección
  provoca reacción finita; aplicar sólo celebra tras éxito confirmado del
  controlador para su operación pendiente. Un click o error no equivale a éxito.
- Se conservan sueño, reduced motion, perfiles y configuración existentes.
  Al reaparecer no reproduce eventos que ocurrieron mientras estaba oculto.
- Si el tamaño no cabe, la mascota se oculta: música conserva icono/etiqueta,
  y wallpapers vuelve al icono original. No hay objetivos nuevos de teclado.

El anclaje musical utiliza espacio libre después de la etiqueta completa y
admite hasta32px lógicos. Su fila reserva la altura necesaria sólo al habilitar
la función y caber el personaje, independientemente del final del morph para
evitar un salto tardío. Wallpapers tiene28px lógicos útiles en su placa actual.
Estas regiones siguen escala `s`; tamaño24 funciona en ambos contextos.

## Contrato integrado

IslandOverlay posee un QObject estable `petContext` por monitor: enabled,
monitorActive, size y profile. Config sigue siendo dueño de los ajustes.
Pill y FluidCompanion lo entregan a PillSurfaceHost. Éste inyecta el contexto
y `petPresented`, que sólo permite revelar con surface vigente, presentación
completa, visibilidad y ausencia de cierre/suspensión. PillSurface combina eso
con su estado abierto y morph en `petEligible`.

Las hojas reciben propiedades y exponen `petVisible`. La composición retira los
ojos anteriores cuando cualquier host válido muestra la mascota. El rail se
retira antes de abrir media/wallpaper; el host saliente se descarga antes del
entrante. Cambio de monitor, fullscreen, cambio de layout, cierre, sustitución
de superficie y suspensión liberan el runtime correspondiente.

PetHost.notify acepta `media.started`, `media.paused`, `media.track`,
`wallpaper.selection` y `wallpaper.applied`. PetRuntime filtra eventos conocidos,
despierta y reutiliza la reacción finita existente; pausa es una expresión
estática mediante `resting`. No se añadió un bus ni procesamiento de audio.
La identidad musical usa Players.trackKeyNoArt, sin confundir portada con pista.

## Evidencia actual

| Comprobación | Resultado |
| --- | --- |
| `python bar/tests/pets-surfaces.py --output docs/eshell-pets-2026-10-22/phase3/qa` | PASS, Wayland, composición real con servicios privados simulados |
| `QT_QPA_PLATFORM=wayland python bar/tests/pets.py --output docs/eshell-pets-2026-10-22/phase3/qa` | PASS, rail/sueño/overlay y nueva fixture MediaView |
| `sh bar/tests/verify-config.sh` | PASS, settings/boundaries/calculadora |
| `node bar/tests/media-source.cjs` | PASS |
| Qt6 qmllint sobre fuentes/fixtures afectadas | exit0; avisos de cualificación y tipos dinámicos del Loader, no un lint completamente silencioso |
| Compilación de runners Python y `git diff --check` | PASS |
| Revisión independiente Sol medium | Sin defectos sustentados en lifecycle, routing, contexto, eventos y coordenadas |

La prueba de composición usa IslandOverlay, PillSurfaceHost, MediaSurface y
WallpaperSurface/WallpaperController reales. Una copia privada de bar recibe
player falso, Cava sin captura y Wallpapers sin scripts ni aplicación real.
ISLA_CONFIG y estado son temporales; los datos/capturas son sintéticos.

Cobertura: ruta workspaces→música→wallpapers→workspaces en ambos layouts;
cuenta de hosts visibles≤1 durante transiciones muestreadas; play/pause/pista
contra seek; cambios de monitor; suspensión de host; hover y prioridad del
teclado; aplicación fallida, confirmada y completada tras cerrar; interrupciones
rápidas; reduced motion, tamaño insuficiente y opt-out. Las claves de consumidores
CAVA no cambian por eventos de la mascota. La fixture MediaView conserva Space
en transporte, además de tamaños, escala1,5 y etiquetas largas.

Las capturas `qa/media-split.png`, `media-compact-paused.png`,
`wallpaper-compact-settled.png`, `wallpaper-split-applied.png` y las de la fixture
MediaView se inspeccionaron para posición, ojos y separación de controles.
`wallpaper-*-selection.png` muestra el inicio de una transición: el preview puede
conservar todavía la imagen saliente; `*-settled.png` muestra el destino asentado.
Logs: qa/surfaces.log y qa/pets-*-regression.qml.log. Hashes: sources.json.

Durante integración se detectó y corrigió una condición inválida: PanelWindow
no expone opacity. El filtro de monitor usa visible, foco, fullscreen y layout;
las opacidades de contenido se comprueban donde sí son Item/ClippingRectangle.
No se cambiaron compositor, reproducción, fondo o configuración personales.

## Límites y relevo

No se midieron nuevos CPU/PSS/GPU/FPS; las cifras de fase2 pertenecen a sus
fuentes y fixture, no certifican el coste actual de toda esta integración.
El objetivo inicial de memoria de8MiB sigue pendiente. No se atribuye coste cero
al nuevo contexto/host, aunque la instancia visual se descarga al ocultarse.

Se verificó el flujo real con servicios simulados, sin comandos MPRIS ni cambios
de wallpaper personales. No certifica todos los reproductores, un cambio real de
fondo, hotplug/multimonitor físico ni continuidad de cada frame de presentación.
Los avisos de avatar ausente, servidor de notificaciones ya registrado y foco
Wayland de las fixtures se conservaron en los logs.

Siguiente fase4: personajes blob/pulpo y personalización de superficies y
comportamientos; incluir la alimentación como acción explícita sin secuestrar
controles existentes. Paquetes comunitarios, plantilla, validador y skill siguen
en fase5. Conservar aspecto aprobado y avanzar con las fuentes de esta fase,
sin repetir auditoría de toda la shell.
