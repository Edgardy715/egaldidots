# Isla · propuesta de pantalla de bloqueo

Estado: primera implementación instalada, 2026-09-26. El usuario eligió definir
primero el diseño. La referencia aportada orienta la composición; el lenguaje
visual y de movimiento procede de Isla. La primera versión está renderizada en Wayland; aceptación estética pendiente.

## Composición

El wallpaper actual ocupa toda la pantalla y conserva su presencia y color.
Evitar el oscurecimiento lateral fuerte de la pantalla existente. Ajustar una
veladura suave sólo hasta asegurar legibilidad; el vidrio se concentra en las
superficies. Validar fondos claros, oscuros y con detalle antes de fijar opacidad.

Una columna central reúne isla de estado, reloj y fecha, tarjeta de acceso y
media opcional. El reloj queda fuera de las tarjetas. Avatar y acceso son el
centro de atención; música y estado tienen menor peso. Conservar espacio amplio
alrededor para que el paisaje siga siendo protagonista. En pantallas bajas se
reducen espacios y media antes de comprometer el campo de contraseña.

La tarjeta de acceso presenta avatar circular, nombre y campo de contraseña con
acción de envío integrada. Los mensajes de verificación/error tienen espacio
reservado para evitar saltos. Energía queda en la esquina inferior derecha;
conservar confirmación para reinicio/apagado y acceso por teclado.

## Tipografía e identidad

- Consumir Theme.font (default Google Sans Flex) para reloj, fecha, nombre y
  acceso; reloj grande de peso ligero, nombre Medium y contexto Regular.
- Consumir Theme.fontMedia (default Inter) para música, manteniendo la jerarquía
  ya trabajada. Respetar fontScale y familias configuradas.
- Evitar mayúsculas espaciadas en el nombre y etiquetas decorativas redundantes.
  No instalar otra familia para reproducir la imagen de referencia.
- Avatar elegido por el usuario, con recorte circular e inicial legible cuando
  falte o falle la imagen. El nombre visible no cambia el usuario utilizado por
  PAM. El perfil podrá alimentar sesión y bloqueo desde una misma configuración.

## Movimiento

El proceso de bloqueo asegura la sesión antes de presentar la coreografía.
Wallpaper estable, sin zoom decorativo. La isla de estado se asienta y la tarjeta
de acceso expande su geometría con los tokens Motion; avatar, nombre y campo se
revelan cuando hay espacio. El teclado debe estar disponible sin esperar al final
de la entrada. Media acompaña después, sin competir con el acceso.

Reutilizar SmoothedAnimation y el contrato de continuidad existente para cambios
de tamaño/destino. Los cuellos líquidos sólo corresponden a cuerpos que realmente
se acercan/separan, no a conexiones decorativas permanentes alrededor del reloj.
FluidCompanion tiene una trayectoria lateral: no copiar su física para fabricar
una versión vertical. Cualquier adaptación de eje necesita revisión específica;
la primera composición puede usar morph sin esa extensión.

Error: feedback local, contraseña vaciada y foco restaurado, sin reconstruir la
tarjeta. Éxito: retirada breve de contenido y superficie, subordinada al resultado
de autenticación. Movimiento reducido resuelve geometría directamente. Ningún
loop decorativo permanente.

## Reutilización y límites de integración

| Base existente | Uso propuesto |
| --- | --- |
| Theme, Motion, Settings/Config | Familias, escala, colores, duraciones y preferencias compartidas. |
| GlassCard / PillMaterial | Material común; revisar dependencias antes de seleccionar el componente para cada superficie. |
| MediaSession, IslandMediaCover, IslandMediaMetadata | Datos y presentación multimedia reutilizados, servicios conectados desde composición. |
| LockSurface / lock_shell actuales | Preservar PAM, bloqueo Wayland, limpieza de contraseña, foco y preview seguro. |
| lock.sh actual | Preservar exclusión de lanzamientos simultáneos y fallback existente. |

El bloqueo actual reside en ~/.local/share/quickshell-lockscreen; Session.qml lo
lanza como proceso independiente. Compartir código no equivale a compartir objetos
vivos con la barra: no prometer un traspaso físico de la pill del escritorio al
bloqueo. El nuevo diseño debe vivir en el repositorio para que sea reproducible;
resolver instalación/enlace del lanzador durante la implementación.

La transparencia de una superficie no garantiza blur del wallpaper. GlassCard
aporta gradiente, borde y sombra; comprobar el material renderizado dentro de la
superficie de bloqueo y, si hace falta, muestrear su propio wallpaper. No depender
de ver ventanas de la sesión a través del bloqueo.

## Plan de validación inicial (histórico)

Preparar preview con el mismo componente visual sin adquirir el bloqueo ni
ejecutar PAM/energía. Revisar wallpaper real, imagen de perfil ausente, nombre y
título largos, música pausada/ausente, tamaños bajos, foco, error y movimiento
reducido. Comprobar transiciones e interrupciones en entorno real; offscreen no
certifica fluidez. Validación de autenticación y varios monitores separada de QA
visual. Este plan antecede a la implementación; la evidencia y los pendientes actuales
se describen en las secciones de verificación siguientes.

## Primera implementación

Entrada: `bar/lockscreen.qml`; UI en `bar/lockscreen/`. Conserva la lógica PAM
y WlSessionLock del runtime anterior. `bar/lockscreen/install.sh` guarda el
lanzador anterior y coloca un wrapper hacia este checkout, usado por Session.
La instalación principal también lo ejecuta. Para Super+L e hypridle, sustituir
sus comandos hyprlock por `~/.local/share/quickshell-lockscreen/lock.sh`; la
configuración versionada conserva el rice anterior hasta ese cambio explícito. No mover el checkout sin
volver a instalar. Restaurar el lanzador guardado devuelve el runtime anterior.

Avatar compartido en `bar/components/UserAvatar.qml`. Ajustes mediante Config:
`profile.displayName` (vacío usa USER) y `paths.userAvatar` (default ~/.face).
Sin foto se muestra la inicial. El nombre visible nunca modifica PAM. El
bloqueo lee los ajustes persistidos; guardar cambios de perfil para que el
proceso independiente los reciba.

Preview segura: `QS_LOCK_PREVIEW=1 quickshell -p bar/lockscreen.qml`.
No inicia PAM, adquiere bloqueo ni ejecuta energía. Los controles multimedia
sí conectan con el reproductor real. Material: GlassCard reutilizado con blur
local del wallpaper. MediaSession/Players/IslandMediaCover compartidos.
La entrada usa morph de geometría y revelado; no incluye cuellos verticales.

Verificación: configuración/IPC y regresión de acceso con acciones simuladas
pasan; lanzador probado con ejecutables falsos. Render Wayland con wallpaper
actual y fixture clara, avatar presente/ausente, nombre largo, fontScale 1.3
y movimiento reducido. Capturas no certifican continuidad de todos los frames.
Pendientes: autenticación real, varios monitores, revisión del usuario y pruebas
de interacción física. No se bloqueó la sesión ni se ejecutó energía.

## Blur y coreografía de autenticación

Actualizado 2026-09-26: blur general del wallpaper ligado al morph. Un único
LockGlass nace como pill (altura IslandGeometry.restHeight), baja y expande
hasta la tarjeta; reloj y contenido se revelan al final. No hay un traspaso
de objetos desde la barra ni modificación de su motor lateral. Texturas de
muestreo del vidrio a 512×512 estables durante la animación.

Error: borde/fondo rojizo y recoil horizontal breve, vaciado y foco de entrada.
Éxito: campo se contrae y presenta check/Listo; espera breve, retira contenido
y sólo entonces recoge el material hacia pill. PAM Success activa la vista de
éxito; el backend mantiene WlSessionLock hasta terminar su espera acotada
(aprox. 1,03 s con tokens por defecto, 220 ms con movimiento reducido). Ninguna
animación ni señal de UI decide si la contraseña es válida. La entrada empieza
cuando secured es true.

Pruebas: lockscreen-motion-regression.qml pasa en offscreen y Wayland con
interrupción/reapertura, error, éxito, retirada antes de recoger y movimiento
reducido. Capturas intermedias inspeccionadas; no sustituyen medición de FPS.
Autenticación PAM real y multimonitor siguen pendientes.

## Revisión de tipografía y proporciones

El usuario confirmó que el desbloqueo real funciona. La siguiente revisión usa
Theme.fontMedia (Inter por defecto, ya instalada) en la UI del bloqueo. Fecha
sobre reloj Medium, sin relieve; avatar y tarjeta más compactos, campo de radio
moderado, transporte secundario sin discos. La barra conserva sus fuentes.
Glass mantiene blur y tokens compartidos con luz superior discreta. Esta
revisión visual está propuesta, aún pendiente de valoración del usuario.

### Ajuste de entrada

El traslado adelanta al crecimiento: pill compacta durante el primer tramo y
expansión cerca del destino. Un único progreso continuo alimenta ambas curvas,
sin encadenar pausas. Avatar, campo y media se revelan según geometría disponible;
la retirada de éxito mantiene su opacidad independiente. Se elimina el Behavior
que retrasaba el revelado detrás de la forma. Probado con inversión y reapertura
en Wayland; la percepción final del usuario sigue pendiente.
