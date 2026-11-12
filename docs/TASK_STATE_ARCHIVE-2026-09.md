# Archivo de TASK_STATE.md: cabecera original y fases 2026-09-20 a 2026-09-30

Movido sin cambios desde TASK_STATE.md el 2026-10-22 (líneas originales 1–1235).
No añadir fases aquí: las nuevas van a TASK_STATE.md. recall.py indexa este archivo;
también sirve `rg`. Índice de archivos en la cabecera de TASK_STATE.md.
<!-- fin-cabecera-archivo -->

# Estado del proyecto: Isla / Quickshell

Actualizado: 2026-09-20

## Objetivo de esta etapa

Acercar la isla a un shell modular y configurable, dejando una base para una
futura interfaz de ajustes sin editar QML directamente.

## Completado

- Configuración externa con `bar/Singletons/Config.qml`, ejemplo en
  `bar/shell.json.example` y documentación en `README.md`.
- Escalas globales de tipografía, espaciado, radios y movimiento mediante
  `Flags.qml`, `Theme.qml` y `Motion.qml`.
- Rutas de wallpaper y paleta desacopladas de una ruta de usuario fija.
- Componentes extraídos de `Pill.qml`:
  - `IslandNotification.qml`
  - `IslandRestStatus.qml`
  - `IslandMediaCover.qml`
  - `IslandMediaMetadata.qml`
  - `IslandMediaVisualizer.qml`
- Prueba ligera de configuración: `sh bar/tests/verify-config.sh`.
- Guía de validación manual: `bar/TESTING.md`.

## Ajustes visuales recientes

- El contenido de reposo usa una altura explícita igual a `pill.coreH`; evita
  depender de alturas implícitas tras la extracción de componentes.
- El reloj usa alineación vertical de texto y un desplazamiento visual de
  `1.5 * s`, calibrado contra el bloque de metadatos de música.
- El flash del workspace reserva un margen animado de `8 * s` entre su cápsula
  y el reloj. El fondo de la cápsula no ocupa ese margen.
- El visualizador CAVA reserva un margen animado de `8 * s` después de los
  metadatos de música.

## Decisiones

- Mantener valores visuales como propiedades semánticas y centralizables;
  evitar nuevas constantes dispersas en `Pill.qml`.
- No crear todavía una aplicación de ajustes. La arquitectura actual permite
  que una futura UI escriba configuración externa para forma, espaciado,
  animaciones, visibilidad y perfiles de la pill.
- Conservar la máquina de estados de la pill en `bar/Pill.qml`; los
  componentes extraídos son de presentación y exponen acciones pequeñas.

## Validación realizada

Tras los últimos cambios:

```sh
sh bar/tests/verify-config.sh
git diff --check
quickshell -p "$PWD/bar" ipc call island reload
```

Las comprobaciones pasaron y Quickshell informó `Configuration Loaded`.

## Siguiente paso sugerido

Continuar la modularización solo cuando haya una mejora concreta. Para una
futura UI de ajustes, empezar por exponer en `Config.qml` los valores ya
calibrados: altura, padding horizontal, margen de workspace, offset del reloj,
radio y multiplicador de movimiento; después construir controles QML que los
escriban.

## Fluid Island — primera iteración (2026-09-23)

- Añadido experimento independiente: `bar/fluid-demo.qml` y
  `bar/fluid/FluidIslandDemo.qml`; no lo importa `bar/shell.qml`.
- La gota retiene posición, tamaño y velocidad; el retargeting cambia sólo el
  destino. El cuello usa dos Bézier cúbicas y su ruptura depende de distancia.
- Reutiliza `Theme`/`Flags` por inyección, incluyendo Pywal y movimiento
  reducido; no modifica `Pill.qml`, `MediaSurface.qml` ni el contrato de
  surfaces actual.
- Validación: `git diff --check` y carga limpia con Quickshell 0.3.1.
- Pendiente: inspección manual de contorno e input mask en Hyprland, después
  extraer controlador multi-gota y adaptar el host de contenido real.
- Ajuste posterior de composición: eliminado el panel de fondo de la demo; en
  reposo sólo queda la isla centrada, la gota se oculta hasta el nacimiento y
  el dock de pruebas no invade la expansión.
- Corrección de continuidad: destinos adaptados al ancho real del monitor;
  `Fusionar` ahora contrae la interfaz a una gota antes de formar el cuello y
  absorberla. Se verificaron localmente los estados expandido y de fusión.
- Sustituida la primera silueta unificada, que producía lóbulos falsos, por
  `bar/fluid/FluidMetaballBridge.qml`: construcción metaball de tangencias y
  dos Bézier entre el casquete final de la isla y la gota.
- Reestudiada la referencia FluidKit: la conexión usa histéresis por distancia
  normalizada, no un rango fijo. Demo ajustada a conectar al tocar (1.02) y
  romper al estirar (1.30), por lo que la gota queda independiente tras la
  expulsión y sólo se reconecta al regresar.
- Coreografía revisada tras inspeccionar `FluidKit/Droplets`, QuickLiquid y la
  referencia SDF: expulsión con resorte más lento + residuo de pinzamiento;
  fusión en tres fases (`contrayendo`, `retornando`, `absorbiendo`) con
  amortiguación casi crítica. Así se conserva el contenido hasta entrar en el
  cuerpo, en vez de teletransportarlo al estado de reposo.
- Validación posterior: `git diff --check` limpio y
  `quickshell -p "$PWD/bar/fluid-demo.qml"` cargó sin errores QML.
- Refinamiento Apple-like: la salida ahora incluye una fase de presión desde el
  extremo y una cesión breve de ancho de la isla; al volver, la isla recibe
  masa antes de absorberla. La geometría de puente sigue usando las posiciones
  físicas actualizadas, por lo que no se desconecta del borde visual.
- Corrección de la captura: se eliminó la contracción circular visible. La gota
  conserva su tamaño mientras el capuchón de la isla avanza sobre ella y se
  retira sólo después de quedar completamente bajo esa superficie.
- Revisión posterior: la captura ya no encoge la gota en absoluto. Al quedar
  completamente oculta, se retira y el cuerpo vuelve a reposo. Se eliminan los
  bordes y el brillo internos durante una unión para evitar que se lean dos
  figuras superpuestas. Criterios contrastados con HIG Motion y la sesión
  oficial “Meet Liquid Glass”.
- Regreso simplificado a un solo trayecto físico: la gota parte compacta hacia
  su destino final y la isla comienza a envolver sólo al cruzar el umbral de
  cercanía. Se retiró el segundo acercamiento. Añadido
  `bar/fluid/MOTION_LANGUAGE.md` como contrato reutilizable del estilo de
  movimiento para las futuras superficies y conversaciones.
- Integración ajustada al módulo compacto real: mientras `Players.live`,
  `FluidMediaCompanion.qml` separa la carátula, metadatos y visualizador de la
  pill; al pausar se absorbe y queda sólo la pill normal. `MediaSurface` grande
  se restauró como vista de clic. Se verificaron manualmente la surface grande,
  el compañero en reproducción y el retorno al pausar; la reproducción usada
  para comprobarlo fue restaurada. `git diff --check` limpio.
- Refinamiento minimalista: el estado desprendido muestra sólo la carátula
  circular. El mismo cuerpo se expande lateralmente en hover para revelar
  título/artista y CAVA; clic mantiene la ruta de la `MediaSurface` grande. Se
  inspeccionó visualmente el estado compacto tras recargar la shell.

## Fluid Island — continuidad del contenido (2026-09-25)

- Auditoría: `Pill.qml` ya anima el vidrio con ancho, alto y radio en el mismo
  `PanelWindow`, pero `PillSurfaceHost.qml` descargaba el `Loader` al comenzar
  el cierre. `PillSurface.qml` además añadía una entrada temporizada con escala
  y desplazamiento, que hacía leer el contenido como panel nuevo.
- Primera corrección: el host retiene la surface durante la contracción y sólo
  la descarga al llegar al tamaño compacto. La revelación depende del crecimiento
  geométrico actual del vidrio (45–80 %), así que también se invierte al cerrar
  y tolera cierre/reapertura interrumpidos. Se retiró la entrada por escala y
  desplazamiento de la base de surfaces.
- `shell.qml` ahora incluye el rectángulo del compañero multimedia en la máscara
  de entrada del overlay en reposo. Antes sólo incluía la pill central, por lo
  que el hover y clic de la carátula separada podían quedar fuera de la ventana.
- Validación: `qmllint` de los QML modificados sin diagnósticos,
  `sh bar/tests/verify-config.sh` y `git diff --check` correctos; recarga de la
  shell con `Configuration Loaded`. Se inspeccionó una captura real del calendario
  abierto y se ejecutó una secuencia rápida calendario → conectividad → cerrar →
  calendario → cerrar sin errores QML nuevos.
- Tras ajustar la máscara se repitieron `qmllint`, las pruebas de configuración,
  `git diff --check` y la recarga; el log mostró `Configuration Loaded` sin
  errores nuevos. El hover/clic de la gota aún requiere una reproducción MPRIS
  activa para comprobarse visualmente.
- Segunda corrección: `FluidMediaCompanion.qml` posee ahora también el recipiente
  de `MediaSurface`. El clic retargetea su geometría y velocidad actuales hacia
  el tamaño de la tarjeta; el mismo `PillSurfaceHost` revela el reproductor
  cuando el cuerpo tiene espacio. Al cerrar con música, vuelve a la carátula;
  sin música, regresa a la pill. El reloj central se oculta conforme la tarjeta
  lo cubre. El integrador pasó de `Timer` fijo de 16 ms a `FrameAnimation` con
  `frameTime`, sincronizado con el refresco real de Qt Quick.
- Se inspeccionaron capturas reales de la tarjeta de medios asentada y a 110 ms
  de abrir: la carátula inicia el mismo recipiente en ambos fotogramas, sin
  reloj fantasma detrás de la tarjeta. `qmllint` y pruebas de configuración
  pasaron después del cambio; queda probar hover/clic con MPRIS reproduciendo.
- En medios → calendario, el residuo de captura del compañero dejaba un borde
  de 28 px junto al calendario; `shell.qml` ahora limita cuello/captura a reposo,
  y el compañero queda detrás del panel mientras éste crece. Captura de la
  transición asentada sin ese borde. El `FrameAnimation` se detiene al asentarse
  y el modo de movimiento reducido resuelve el cierre sin dejar una fase activa.
- Validación final: `qmllint`, prueba de configuración y `git diff --check`
  correctos; recarga y secuencia rápida medios → cerrar → reabrir → calendario
  → cerrar sin errores QML nuevos en el log.
- Próximo paso: transición directa medios → otro módulo y conservación visual de
  la carátula durante el cambio de contenido interno. Medir fotogramas reales
  en monitor de alta frecuencia y ajustar la dinámica según esa observación.

## Fluid Island — gota persistente a la derecha (2026-09-25)

- Ajuste solicitado tras comparar cuatro capturas con la referencia: la pill
  central muestra el reloj; la gota multimedia permanece a su derecha aun sin
  reproducción. Se eliminó el chip de título/CAVA de reposo de `Pill.qml`.
- `FluidMediaCompanion.qml` conserva la carátula circular en pausa o sin MPRIS;
  cuando `Players.live`, se ensancha sólo para CAVA. El título/artista se revela
  en hover, y clic retargetea el mismo cuerpo hacia la `MediaSurface` a la
  derecha. El reloj sigue visible durante esa expansión.
- CAVA sólo mantiene consumidor activo mientras hay reproducción. La apertura
  por IPC de medios funciona también sin reproductor; se conserva el fallback
  visual de la tarjeta.
- Verificado en la sesión real: recarga con `Configuration Loaded` sin errores
  nuevos, capturas de reposo, reproducción y tarjeta abierta/cerrada; la tarjeta
  queda a la derecha y la gota se ensancha para CAVA. Firefox se devolvió a su
  estado `Paused` tras la comprobación. La prueba de configuración y
  `git diff --check` pasan; `qmllint` pasa en `Pill.qml` y `shell.qml`. El
  `qmllint` del sistema sale con 255 sin diagnóstico para el compañero y la
  demo Fluid (ambos usan funciones QML tipadas), aunque Quickshell los carga.
- Pendiente de inspección manual: hover/clic con puntero real y secuencia rápida
  con `reduceMotion`, pues las capturas/IPC sólo comprueban geometría y carga.

## Fluid Island — interacción y convivencia de surfaces (2026-09-25)

- Se reprodujo el fallo de hover con el puntero de Hyprland: la región de
  entrada previa cubría la pill pero no admitía de forma fiable la gota. La
  máscara de reposo ahora abarca ambos cuerpos y notifica sus cambios de
  geometría; `MouseArea.hoverEnabled` mantiene el hover al cambiar de ancho.
- La altura compacta de la gota es fija (`38 * s`), independiente de la altura
  de calendario, fondos, launcher o notificaciones. Su posición sigue el borde
  derecho y la coordenada vertical de la surface principal; el cuello queda
  desactivado durante esas expansiones. Ya no se desvanece al abrir otra
  surface.
- `Players` excluye MPRIS `Stopped`, prioriza `Playing` y conserva el último
  reproductor que sonó al pasar a `Paused`. Esto evita que Chromium/Codex
  sustituya la carátula pausada de Firefox.
- Capturas reales verificadas: hover revela el título; reproducción ensancha
  sólo para CAVA; pausa recupera la carátula correcta; calendario, fondos y
  launcher dejan la gota circular a la derecha; la tarjeta de medios se abre y
  cierra por IPC. `qmllint` de `Players.qml`, `Pill.qml` y `shell.qml`, prueba de
  configuración y `git diff --check` pasaron. El clic físico queda para una
  comprobación manual, aunque la máscara y el `MouseArea` ya reciben hover.
- Corrección del visualizador en pausa: `IslandMediaVisualizer.qml` ocultaba su
  contenedor reduciéndolo a ancho cero, pero sus barras sin recorte seguían
  dibujándose sobre la carátula. Ahora se oculta y recorta cuando no debe
  aparecer. Capturas reales de pausa y reproducción verificadas; Firefox quedó
  otra vez en `Paused`. Recarga sin errores QML, `qmllint`, prueba de
  configuración y `git diff --check` correctos.
- Preferencia posterior: el aro de progreso vuelve a permanecer visible con
  una pista pausada que tenga duración; CAVA continúa oculto en pausa. Captura
  real de la gota pausada y recarga de Quickshell verificadas.
- Corrección de recorte del aro: en el estado compacto (42 px), el contenido
  tenía 8 px de margen derecho y sólo dejaba 31 px para una carátula de 34 px.
  El margen ahora es de 3 px, conservando el recorte del contenedor para el
  morph. Captura de la gota pausada y recarga sin errores nuevos; prueba de
  configuración y `git diff --check` correctos.

## Fluid Island — absorción sin reproductor (2026-09-25)

- La gota multimedia se abre cuando `Players.has` (pista activa o pausada), o
  mientras la tarjeta de medios está abierta manualmente. Cuando no queda
  reproductor válido, el cambio de `open` usa el retorno y la captura del motor
  fluido existente hasta `idle`, por lo que desaparece el ♪ satélite en reposo.
- Si vuelve un reproductor durante `retornando`, la gota revierte el destino
  conservando velocidad; si reaparece en `absorbiendo`, nace de nuevo desde la
  pill. Se conservó la gota pausada y su aro según la preferencia previa.
- Verificado sin reproductor válido (`playerctl` sólo mostraba Chromium
  `Stopped`): recarga deja únicamente el reloj; abrir/cerrar Medios por IPC
  devuelve el cuerpo a la pill. Secuencia de 14 fotogramas comprobó la
  contracción, retorno y absorción. Sin errores nuevos en el log; `qmllint` de
  `shell.qml`, prueba de configuración y `git diff --check` correctos.

## Fluid Island — pulido de expulsión y absorción (2026-09-26)

- Se contrastó la coreografía con Apple Meet Liquid Glass, Animate with springs
  y Motion HIG; criterios y parámetros documentados en `bar/fluid/MOTION_LANGUAGE.md`.
- El nacimiento flexiona primero la pill (6 px a escala 1, 32 ms de presentación).
  Carátula y aro aparecen según separación geométrica, y desaparecen antes de
  superponerse al reloj en el regreso. Se conserva la posición a la derecha.
- Captura de 20 px; sombra y halo siguen el casquete, y se suprimen los bordes
  interiores del satélite unido. La pill responde también a la captura.
- Las interrupciones revelaron un defecto real: el destino del casquete quedaba
  extendido al reabrir durante el retorno. `retarget()` ahora lo devuelve a cero
  al salir, conservando velocidades. Movimiento reducido termina en `companion`
  al abrir y `idle` al cerrar, sin tensión residual.
- Verificación: secuencias reales de capturas de nacimiento y absorción, y
  reversiones a 60, 160 y 330 ms. Contactos finales en
  `/tmp/fluid-final-birth-contact.png` y `/tmp/fluid-final-stop-contact.png`.
  Son muestras visuales, no una medición de FPS ni todos los refrescos de pantalla.
- Fixture offscreen del componente real: `REDUCED_OPEN true companion 0` y
  `REDUCED_CLOSE true idle 0`. El reproductor MPRIS simulado ya no está activo;
  `playerctl -l` devuelve `No players found`.
- Pasan `qmllint` de Pill, PillMaterial y shell, `bar/tests/verify-config.sh`
  y `git diff --check`. Shell cargada sin errores QML; aparecen únicamente
  advertencias del portal y de seguimiento de workspace. Continúa la limitación
  del qmllint del sistema con funciones tipadas del compañero; se validó en runtime.
- Esta fase queda terminada. El clic físico sigue sin una prueba automatizada;
  no afecta a las comprobaciones realizadas de nacimiento, retorno e interrupción.

## Launcher — integración multimedia y corrección de composición (2026-09-26)

- Al solicitar launcher, `launcherPendingMon` permite absorber la gota antes
  de abrir la surface. Una segunda solicitud cancela la apertura pendiente.
  El cierre conserva sus dos fases y libera la gota al terminar el retorno.
- Se sustituyó la primera propuesta de canción dentro del campo, rechazada
  visualmente por el usuario: ahora carátula con aro, título y artista ocupan
  la cabecera izquierda; reloj a la derecha, buscador debajo a ancho completo.
  Cabecera reducida de 94 a 78 px. Sin reproductor se conserva reloj centrado.
- Validado en sesión real con Spotify: apertura, búsqueda de Firefox con
  resultados y Escape; gota vuelve a la derecha al cerrar. Capturas:
  `/tmp/launcher-header-v2.png`, `/tmp/launcher-results-v2.png`,
  `/tmp/launcher-return-v2.png`. No se alteró el reproductor del usuario.
- Pasan qmllint de Pill, LauncherSurface y shell, verify-config y diff --check.
  Recarga sin errores QML. Lanzamiento real de apps y cancelaciones rápidas de
  apertura no se ejercitaron; Escape usa el mismo requestClose del lanzamiento.

## Pill — continuidad general de transiciones (2026-09-26)

- Ancho/alto/radio y topMargin usan SmoothedAnimation nativa: conserva velocidad
  e invierte con desaceleración al cambiar de destino. Mantiene tokens de duración.
  Se retiraron la curva de overshoot simulado y constantes de fase duplicadas.
- Revelado geométrico exige espacio en ambos ejes. PillSurfaceHost desvanece el
  contenido anterior, cambia al último destino solicitado y revela el nuevo.
  Cerrar cancela el intercambio pendiente. Se validó contra cambios rápidos.
- Movimiento reducido salta al tamaño final y cierra launcher directamente;
  suprime nuevos barridos materiales y respiración. Launcher recupera foco y
  debounce de búsqueda cuando se interrumpe el cierre sin desmontar la surface.
- Se detectaron errores HTTP de carátula durante morph: PillMaterial variaba
  sourceSize con cada frame incluso oculto. Ahora decodifica a 256 px constantes
  y sólo pide la imagen para media. No reaparecieron en la secuencia posterior.
- `bar/motion-regression.qml` prueba la Pill real offscreen: pasa interrupción,
  reapertura, cambio de contenido, movimiento reducido y descarga al cerrar.
  Inicialmente la fixture falló por imports fuera del config root; quedó junto
  a shell.qml. Se documenta cómo ejecutarla en TESTING.md.
- QA real: secuencia calendario → fondos → volumen → reposo en 18 capturas
  (`/tmp/pill-polish-contact.png`); Escape/reabrir launcher a 50 ms conserva
  consulta y foco (`/tmp/pill-launcher-reopen.png`); notificación de prueba sobre
  calendario vuelve correctamente (`/tmp/pill-notification-return.png`).
  Son muestras visuales, no medición de FPS. No se alteró la reproducción.
- Validaciones: qmllint de archivos modificados, verify-config y diff --check.
  Se preservan composición, colores y motor aprobado de la gota. Las surfaces
  de autenticación y acciones de sesión no se activaron en QA visual.

## Gota — CAVA superpuesto tras reaparecer (2026-09-26)

- Causa: birthTimer elegía siempre collapsedW (42 px), incluso con Players.live.
  Al cerrar launcher con música en curso no cambiaba live y no se retargeteaba
  a playingW (76 px); CAVA quedaba visible a x=4 encima de la carátula.
- El nacimiento ahora elige ancho según reproducción actual. La coordenada de
  CAVA tiene mínimo 38 px dentro del contenido: nunca invade los 34 px de la
  carátula y el recorte existente oculta barras sin espacio durante el morph.
- Nueva fixture `bar/media-motion-regression.qml`: pasa nacimiento, renacimiento
  y exclusión de carátula para anchos 34–218 px, con Players.live=true real.
- QA real: abrir/cerrar launcher con Spotify sonando devuelve gota ensanchada y
  barras separadas (`/tmp/media-cava-rebirth-fixed.png`). Recarga sin errores QML,
  verify-config y diff --check correctos. No se alteró reproducción.

## Wallpaper picker — galería y media integrada (2026-09-26)

- Reemplazado cover-flow superpuesto por preview completa y tira horizontal de
  miniaturas; panel 1000×640, imagen ajustada al alto disponible. Eliminadas las
  dos capas de fondo internas que producían el rectángulo y el recorte superior.
  Se conservan servicio, selección, aplicar, feedback, teclado y rueda.
- Preview usa PreserveAspectFit y resoluciones estables. El primer fundido dejó
  imagen anterior/miniatura recortada en los márgenes de archivos con otra razón
  de aspecto (captura del usuario). Ambas capas ahora desaparecen por completo
  al revelarse la imagen nueva. Se evita reiniciar dos veces el mismo fundido.
- Media integrada en cabecera (carátula, progreso, título y artista). Apertura
  comparte absorción con launcher mediante mediaDockPendingMon/Surface. Cierre
  espera el morph antes de expulsar de nuevo la gota hacia la derecha.
- Picker toma foco Exclusive mientras está abierto, como launcher, para que
  números, flechas y Escape funcionen sin un clic previo.
- `bar/wallpaper-regression.qml` pasa límites de preview, cambios rápidos,
  imagen lista y aislamiento de márgenes. Requiere biblioteca local con >1 fondo;
  sólo lee/navega, no aplica fondos. Capturas reales finales:
  `/tmp/wallpaper-fixed-final.png`, `/tmp/wallpaper-media-return.png`.
- QA real: salto al fondo 6 (relación de aspecto distinta), varias flechas,
  Escape y retorno de gota con CAVA. Sin errores QML nuevos. No se aplicó ningún
  fondo ni se cambió reproducción. La ruta de aplicación existente se conservó;
  no se ejercitó el cambio real del fondo en esta fase.

## Progreso multimedia y aviso de workspace (2026-09-26)

- El aro dependía de MprisPlayer.position sin reloj de actualización. La API
  calcula la posición al leerla pero no emite cambios por el paso del tiempo.
  Players ahora emite positionChanged cada segundo sólo durante reproducción
  con posición soportada, siguiendo documentación oficial de Quickshell.
  Esto actualiza los aros de gota y cabeceras; en pausa conservan su posición.
- El aviso de workspace animaba su ancho mientras Pill volvía a animar ese
  destino móvil. Se sustituyó por icono/número dentro del espacio del reloj,
  con fundido corto y retención de 1100 ms. Repetir cambios renueva el aviso;
  no desplaza la gota ni expande/contrae la pill. ReduceMotion evita el fundido.
- `bar/status-regression.qml` pasa ancho constante al mostrar/cambiar/retirar
  workspace y notificaciones de posición con reproducción activa (7 updates).
  qmllint, verify-config y diff --check pasan; recarga sin errores QML.
  No se cambiaron workspaces del usuario ni el wallpaper picker.

## Workspace — indicador de páginas (2026-09-26)

- El usuario rechazó sustituir el reloj por icono/número. Ahora la hora sigue
  visible, sube ligeramente y se reduce al 90% mientras aparece una línea de
  diez puntos debajo, coherente con los diez espacios de WorkspacesSurface.
  Una cápsula acentuada sigue el espacio activo con SmoothedAnimation.
- El indicador permanece 1600 ms y se renueva al navegar; no cambia el ancho
  de la pill ni desplaza media. Movimiento reducido omite los desplazamientos.
- qmllint y regresión de ancho/posición pasan. No se cambiaron workspaces del
  usuario para la prueba. Para IDs superiores a 10, la posición usa grupos de
  diez; el nombre accesible conserva el ID completo.

## Workspace — retirar puntos y desplazamiento (2026-09-26)

- Usuario rechazó indicador de páginas: se retiraron puntos, cápsula y escala/
  desplazamiento vertical de la hora. Ahora número de workspace con dos dígitos
  aparece por fundido en el espacio de AM/PM durante 1600 ms. Hora y ancho quedan
  fijos. Después vuelve AM/PM; no hay expansión ni desplazamiento de la gota.
- qmllint y status-regression pasan. Render offscreen del componente real
  inspeccionado en `/tmp/workspace-inline.png` (1:38 y workspace 03, sin solape).
  Preview temporal eliminada. Recarga aplicada; no se alteraron workspaces.

## Workspace — rueda integrada (2026-09-26)

- A petición del usuario, indicador más notorio: pequeño recipiente acentuado
  a la izquierda del reloj, rueda vertical de números y expansión de 44 px.
  Hora y AM/PM permanecen visibles. Retención 1600 ms, recogida suave.
- El ancho del indicador es el único animador durante el aviso en reposo;
  Pill desactiva su segundo Behavior de ancho mientras el indicador se mueve.
  Para surfaces/notificaciones conserva el morph general.
- ListView nativa con highlight explícito controla el desplazamiento numérico;
  navegación repetida actualiza el destino y renueva la retención. ReducedMotion
  resuelve rueda y expansión sin desplazamiento animado.
- Regresión actualizada para expansión acotada/retorno, ejecutada en Window
  offscreen (sin Window Qt no avanza igual la animación). Pasa; render inspeccionado
  `/tmp/workspace-reel.png`, número 10 legible, hora y AM/PM sin solaparse.
  qmllint y diff --check pasan. No se cambiaron workspaces del usuario en QA.

## Win + Tab — franja compacta de escritorios (2026-09-26)

- Confirmado binding en hypr/modules/binds.lua: Super+Tab llama island overview.
  OverviewSurface sustituye panel 1120×760 de seis tiles por franja 1000×320 de
  cuatro escritorios con previews vivos, wallpaper y rótulos debajo.
- Eliminadas pestañas duplicadas, reloj adicional, pulsos y halos repetidos.
  Punto acentuado marca escritorio actual; borde marca selección por teclado o
  puntero. Pie con instrucciones, anterior/siguiente grupo y cerrar.
- Conservados cambio de workspace por clic/Enter, números, flechas, rueda/grupos.
  La unidad de selección es el escritorio completo; previews de ventanas son
  contexto visual. Se retiraron handlers antiguos de foco/cierre de ventanas,
  que además usaban sintaxis de dispatcher anterior y estaban tapados por el
  MouseArea del tile. No se cambia el atajo de Hyprland.
- activeId proviene del monitor de la surface, no del workspace global. La carga
  asíncrona corrige selección inicial sólo hasta que el usuario empieza a navegar.
  Overview pide foco Exclusive al abrir, como launcher/picker.
- QA real: apertura, captura `/tmp/overview-strip.png`, flecha a escritorio 2
  (`/tmp/overview-selected.png`) y Escape. No se cambió workspace del usuario.
  Fixture `bar/overview-regression.qml` pasa selección, grupos y límites de layout.
  qmllint, verify-config y diff --check correctos. Un nombre de propiedad que
  colisionaba con Item.top se corrigió antes de la validación final.

## Overview — composición afinada y media integrada (2026-09-26)

- Cabecera con título/rango a la izquierda y carátula, progreso, canción/artista
  a la derecha. Más separación entre previews; etiquetas alineadas y conteo de
  ventanas/estado vacío. Panel 1000×340.
- Overview comparte absorción de media al abrir con launcher y wallpaper.
  mediaPanelOpen/Returning unifican la espera de cierre para overview/picker;
  la gota reaparece después de que la pill regresa a reposo.
- Render real inspeccionado en `/tmp/overview-media-refined.png`, sin satélite
  externo. qmllint pasó. La comprobación final de cierre por herramientas fue
  interrumpida por el usuario, quien confirmó que funciona correctamente y muy
  bien. Esta versión queda aceptada; no continuar ajustes visuales opcionales.

## Skill persistente Fluid Island Motion (2026-09-26)

- Creada `.agents/skills/fluid-island-motion/` como fuente versionable del proyecto:
  SKILL.md, metadatos de UI y referencias de diseño, implementación y validación.
- Instalada en `~/.codex/skills/fluid-island-motion` mediante enlace a esa fuente;
  AGENTS.md del proyecto indica consultarla en tareas relevantes incluso si el
  catálogo del chat no la muestra. Invocación explícita: $fluid-island-motion.
- Incluye patrones aceptados/rechazados, motor y rutas, contratos de media/foco,
  errores históricos, fuentes Apple/Qt/MPRIS y fixtures existentes. Sin dependencia
  de capturas temporales ni transcripciones de esta conversación.
- quick_validate pasó usando `uv run --with pyyaml` (Python base no tenía PyYAML);
  referencias locales, fixtures y enlace de instalación comprobados. diff --check
  correcto. No se modificó la UI para crear la skill.

## MediaSurface — propuesta visual Apple-inspired y skill (2026-09-26)

- El usuario pidió mejorar tarjeta y conseguir/crear skill Apple-like. Se creó
  `.agents/skills/apple-inspired-ui/` (SKILL.md, fuentes y metadatos), enlazada en
  `~/.codex/skills/apple-inspired-ui`; AGENTS.md la asocia a diseño Apple-like.
  Complementa fluid-island-motion. Validada con quick_validate.
- Consulta de HIG/Materials oficial; Typography y Playing audio sólo devolvieron
  requisito JavaScript. La referencia distingue esa limitación de lectura y las
  adaptaciones propias del proyecto.
- Media: márgenes 24, estado en texto contextual en vez de badge rojo, título
  21 px, artista/álbum juntos, espectro más bajo y neutral. Seek claro, tirador
  sólo en hover/drag, tiempo restante a derecha. CtrlBtn.primary da a play/pause
  fondo claro y símbolo oscuro sin modificar estilo de toggles secundarios.
- Render real `/tmp/media-apple-refined.png` inspeccionado con tema rojo. No se
  alteraron playback, seek, shuffle/repeat ni selección de reproductor durante QA.
  qmllint, verify-config y diff --check pasan; recarga sin errores QML.
- Es propuesta implementada, pendiente de valoración del usuario; no sustituir
  aún el catálogo de diseños aceptados por una afirmación de aprobación.

## Media — distinguir música de contenido general (2026-09-26)

- MediaSource.js clasifica identidad/desktopEntry/dbus y host exacto de xesam:url;
  no usa título/artista para inferir tipo. Spotify, Apple Music/Cider, YouTube
  Music y reproductores nativos conocidos tienen presentación musical. YouTube
  normal, VLC y navegador sin dominio musical usan presentación general.
- Musical: cover cuadrado, álbum, CAVA. General: imagen panorámica PreserveAspectFit,
  sin CAVA/álbum musical; shuffle/repeat visibles sólo si soportados. Controles,
  seek y selección de player mantienen sus rutas existentes.
- Cabecera muestra icono original del tema junto al servicio (Spotify verde
  comprobado en `/tmp/media-source-spotify.png`). Si no hay icono instalado,
  fallback semántico con color de servicio; no se presenta como logo oficial.
- Browser sin URL/identidad específica conserva nombre/icono de app; MPRIS no
  siempre entrega origen. No se promete detección de sitios que no expongan datos.
- node bar/tests/media-source.cjs pasa servicios, reproductores nativos, fallback
  y rechazo de hosts parecidos. qmllint, verify-config, diff --check pasan.
  QA visual real Spotify; Apple Music/YouTube Music cubiertos por clasificación,
  no por sesiones reales. No se cambió reproducción del usuario.

## Media — tipografía y transporte legible (2026-09-26)

- Propuesta solicitada: Inter instalada, título semibold 20 con hasta dos líneas,
  artista con contraste secundario y tiempos en la misma familia. Columna centrada
  por su altura natural; conserva presentación musical/general y fuentes de marca.
- CtrlBtn: transportes vectoriales sólidos (pausa/play/anterior/siguiente), tamaño
  óptico mayor, play/pause 52 y feedback de presión. Material Symbols ignoró el
  relleno visual de pausa en captura real; PathSvg evita depender de ese eje.
- qmllint y verify-config pasan; diff --check limpio. Recarga realizada, sin errores
  de componentes; log registra aviso de item pendiente al destruir motor anterior.
- Captura real Spotify /tmp/media-type-final.png inspeccionada. No se modificó
  reproducción. Esta sesión real no permitió validar visualmente YouTube: el
  reproductor activo era Spotify. Propuesta pendiente de valoración del usuario.

## Base reutilizable y contrato de configuración (2026-09-26)

- Settings.js centraliza versión 1, defaults, tipos y límites. Config.qml adapta
  ese contrato a archivo/IPC; Flags es fachada reactiva readonly. Las pruebas
  antiguas que escribían Flags ahora usan Config.update. Formato sin versión
  compatible; valores inválidos rechazan el lote completo, conservando último
  estado válido. Archivo ausente restaura defaults; archivo vacío es inválido.
- IPC settings: schema/get/validate/update/discard/save/reload. update previsualiza
  sin disco; save asíncrono crea directorio y escribe atómicamente con FileView.
  Estado dirty/saving/error observable. Relee antes de guardar, conserva claves
  desconocidas y prohíbe guardar encima de JSON inválido. No se ha creado app.
- Hallazgo probado: FileView requiere reload en onFileChanged y después del
  rename atómico para renovar vigilancia. No esperar otro loaded tras recarga
  idéntica (puede no emitirse). Tests cubren esa secuencia.
- fontMediaFamily entra al contrato/Theme, eliminando Inter fijo en MediaSurface.
- IslandMediaSummary reúne cabeceras de launcher, wallpaper y overview;
  IslandMediaVisualizer recibe hasMedia/isPlaying/hasFrame/values. Composición
  mantiene conexión a servicios y acciones. Theme sigue siendo dependencia visual.
- Validación: tests/settings.cjs, settings-integration.py (host aislado/config
  temporal), config-regression.qml (bindings reales, rechazo y discard/save),
  motion/media-motion/overview/wallpaper regression PASS. qmllint componentes
  visuales PASS; Config y FluidMediaCompanion devuelven 255 sin diagnóstico en
  este qmllint, validados cargando runtime real. verify-config y diff --check PASS.
- Shell real recargada; settings get reporta defaults, error vacío y dirty=false.
  Captura launcher /tmp/isla-refactor-launcher-full.png inspeccionada con media
  activa. No se cambiaron ajustes personales, reproducción ni wallpaper.
- docs/SHELL_ARCHITECTURE.md documenta contrato, capas y siguiente fase. Guardado
  usa escritor único; comprobación previa no bloquea editores externos concurrentes.
  Sigue pendiente separar sesión multimedia de MediaSurface y unificar dimensiones
  compartidas antes de exponer geometría editable o crear app. Sin afirmar que toda
  la shell esté desacoplada; se conservó el motor de movimiento aprobado.

## Modularización siguiente: sesión media y geometría (2026-09-26)

- MediaSession.qml separa metadata/capacidades/seek/acciones/interpolación de
  MediaSurface. Inyección player/trackKey/active; sin Players/Cava/Theme. La
  surface conserva selección de fuentes y consumidor CAVA (libera id anterior
  al cambiar monitor). Conservado albumDistinct público que usa Pill.mediaH.
- Arrastre se cancela al cambiar track/player/capacidad o cerrar vista; acciones
  comprueban capacidades. Test fake detectó acceso length tras player=null,
  corregido con guard directo. No se controló reproducción real durante pruebas.
- IslandGeometry singleton contiene catálogo de tamaños exteriores y restHeight;
  Pill/shell/FluidMediaCompanion consumen valores base y aplican s como antes.
  Se mantienen constantes físicas y medidas particulares locales.
- PASS: media-session-regression (fake, seek, capacidades, interrupciones, reloj),
  motion-regression, media-motion-regression; qmllint sesión/surface/geometría/
  Pill/shell, verify-config y diff --check. Límite previo de qmllint en Companion
  sin diagnóstico; runtime y regresión de gota cargan correctamente.
- Shell recargada; inspección visual media registrada en /tmp/isla-modular-media-open.png.
  Documentados contratos en docs/SHELL_ARCHITECTURE.md y test en bar/TESTING.md.
  Siguiente: separar controles visuales si existe otro consumidor, o iniciar
  preferencias sobre el API existente; todavía no es toda la shell independiente.

## Modularización: navegación y ventanas (2026-09-26)

- Extraído SurfaceRouter.qml sin servicios externos: monitor enfocado, reduceMotion
  y duraciones inyectados; estado de navegación/dock/peek/cierre launcher y timers.
  Señal authCloseRequested se conecta a Auth en shell. present limpia trabajo
  pendiente para que una finalización tardía de dock no sustituya autenticación.
- IslandOverlay.qml recibe modelData/router: composición por monitor, máscaras,
  foco/input, fullscreen y timers de retorno locales. IslandReserve.qml separa
  reserva y click-through. shell.qml pasó de 653 a 175 líneas, conserva IPC y
  adaptadores de servicios. No cambia geometría ni motor físico.
- PASS surface-router-regression: monitor, cancelaciones, auth, cierre dos fases,
  reapertura, retarget y reduceMotion. PASS motion/media-motion; qmllint de shell,
  router y ventanas, verify-config, diff --check. Shell recargada sin errores QML;
  launcher real con media inspeccionado /tmp/isla-router-launcher.png, Escape.
- No se provocó autenticación real ni se cambiaron reproducción/workspaces. Auth
  cubierta con señal falsa; multi-monitor en controlador con DP-1/DP-2, no prueba
  de hotplug real. Sigue pendiente notificaciones/coreografía en Pill.qml; overlay
  es adaptador Wayland con servicios, no una librería visual independiente.

## Modularización: coreografía de notificaciones (2026-09-26)

- NotificationChoreography.qml posee fases, timers, activeNotif y suspensión /
  revelación; recibe popup/surfaceOpen/duraciones y emite advanceRequested.
  Pill conserva geometría/material/contenido y adaptación a Notifs/Motion.
  Pill pasó de 875 a 745 líneas aproximadamente.
- Ajuste funcional: abrir una surface durante la notificación suspende contenido
  hasta restauración. Se conservaron duraciones, respiración y morph existentes.
- Integración runtime detectó un antiguo caller en IslandOverlay que asignaba
  activeNotif. Se sustituyó por notificationsEnabled (monitor enfocado), dejando
  estado en el controlador e impidiendo avances de cola desde monitor inactivo.
- PASS notification-regression (cola falsa, fases, expiración temprana, cerrar /
  abrir surface y restaurar), motion/media-motion, qmllint y verify-config;
  diff --check limpio. Shell recargada después de corregir caller readonly.
- Sin notificaciones reales de QA ni cambios al historial. No afirmar validación
  visual de toda secuencia ni hotplug/foco multimonitor físico: tests son aislados.
  Siguen en Pill geometría/render/OSD; Notifs conserva política de cola.

## Absorción continua de la gota (2026-09-26)

- Usuario percibía cierre por fases. Causa localizada: retorno esperaba settled
  (incluido cap) antes de ocultar gota y retraer cap; además cambiaba resorte a
  omega19/damping1.04 al comenzar absorción.
- Captura ahora depende de cobertura geométrica de la gota compacta por cap,
  con tolerancia3*s y contenido ya oculto. Retracción conserva velocidades y
  omega15.5/damping0.98 de retorno. No cambia nacimiento ni amplitud del cap.
- advanceMotion(dt) separa integración por frame para prueba determinista.
  PASS absorption-regression: 30/60/144Hz simulados, anchuras42/76/218/640,
  captura con velocidad residual, cobertura y regreso idle. PASS media-motion
  (nacimiento/renacimiento/reduceMotion). diff --check y recarga correctos.
- Pendiente valoración perceptual del usuario; prueba numérica no certifica
  sensación visual ni rendimiento real en esos refresh rates.

## Rediseño Sesión y energía (2026-09-26)

- SessionSurface nueva composición 540x304: header con cierre, cuatro acciones
  horizontales, iconos claros sobre círculos neutrales, etiquetas españolas,
  hover/presión y estados de foco. Conserva material/morph de Pill y tema.
- Bloquear directo; logout/reboot/shutdown preparan confirmación inline explícita,
  sin timeout ni doble clic. Cancelar/Escape y cerrar limpian estado. Tecla
  mantenida no confirma. Acciones inyectables permiten pruebas sin comandos reales.
- QA detectó foco OnDemand insuficiente. Session usa Exclusive como launcher;
  overlay delega teclas al handleKey del panel antes de Escape general, para que
  Escape primero cancele la confirmación. Navegación por flechas/hjkl/números.
- PASS session-regression fake (confirmar/cancelar/repetir/reset/teclas), qmllint,
  verify-config, diff --check. QA real reposo /tmp/isla-session-final.png y
  confirmación /tmp/isla-session-confirm-verified.png; tecla4 abre confirmación,
  Escape cancela. No se ejecutó bloqueo/logout/reboot/apagado real.
- Propuesta pendiente de valoración del usuario; no registrar como diseño aprobado.

## Sesión como gota izquierda compartida (2026-09-26)

- Extraído FluidCompanion.qml del motor media: misma física/bridge/host y slots
  para contenido compacto, surfaceName/size y leftSide. Refleja geometría sin
  invertir texto. FluidMediaCompanion es adaptador Players/Cava; no segundo motor.
- Sesión invocada por IPC/Win+M abre gota izquierda expandida y temporal. Pill
  conserva reloj, media derecha. Al cerrar absorbe y se retira por completo.
  PillMaterial admite cap izquierdo independiente del derecho; overlay actualiza
  máscara, clic exterior y destino de teclado para host de sesión.
- Return sigue destino de pill si cambia posición/tamaño mientras cierra; reduce
  motion limpia extensión residual. Escape de session se delega antes de cierre
  general para conservar cancelar-confirmación.
- PASS session-companion (izquierda, reveal, interrupción, pill móvil, reduce),
  media-motion, absorption 30/60/144 simulados, session fake, verify-config,
  diff --check. Runtime shell carga; captura /tmp/isla-session-left.png y
  /tmp/isla-winm-command.png muestra sesión izquierda, reloj y media derecha.
- Verificado binds.lua Win+M invoca `qs -c bar ipc call island session ""` y ese
  comando probado. Simulación de combinación con wtype no abrió la ventana;
  no se afirma prueba del atajo físico. No se modificaron binds ni se ejecutaron
  comandos reales de energía. Pendiente valoración del gesto por usuario.

## Investigación de consumo de Codex (2026-09-26)

- Informe: docs/TOKEN_OPTIMIZATION_RESEARCH.md. Investigación inicial solicitada;
  no se cambiaron modelos, config, skills, herramientas ni código de la shell.
- Fuentes primarias: documentación OpenAI, Anthropic, RouteLLM, Microsoft
  LLMLingua-2 y repositorios Headroom/RTK. Cifras externas no extrapolables a cuota.
- Config guardada: gpt-6-sol/medium/default; AGENTS global pide Terra. Pendiente
  comparar por tarea correcta, incluyendo reintentos, antes de cambiar política.
- Headroom portátil estima tokens con caracteres/4; trace_context=15 limita
  contexto de trazas; instrucciones de historial contradictorias entre archivos.
  Hallazgos por inspección, sin prueba adversarial ni benchmark local todavía.
- Prioridad propuesta: recuperación selectiva, salida recuperable y carga de
  instrucciones según tarea; luego modelo/esfuerzo y compresores si aportan valor.
- Próximo paso: aplicar mejoras conservadoras y evaluar casos representativos
  con las mismas pruebas/QA. No hay garantía universal de calidad ni % de ahorro.

## Optimización de consumo aplicada (2026-09-26)

- Política global y roles persistentes: Sol/medium principal e implementer;
  Luna/high researcher/worker; Astra/low consulta puntual. Máximo dos agentes,
  sin delegación recursiva. Config, permisos y plugins restantes preservados.
- PROJECT_MEMORY.md es índice/estado breve; recall.py devuelve secciones exactas
  con referencias desde fuentes actuales, sin embeddings ni modelos de fondo.
  AGENTS dirige su uso y actualización. Historial completo conservado.
- Headroom simplificado; helper output.py captura original y exit, agrupa solo
  repeticiones exactas en éxitos, preserva fallos y limpia hijos al interrumpirse.
  Helpers/config/backups/reporte en ~/.codex/token-economy. No proxy/hook global.
- Auditoría 7x24h al 26/09 17:24:28 UTC: 189.211.303 tokens locales, 96,26% de
  entrada cacheada. Son contadores, no gasto facturado ni cuota equivalente.
- A/B Sol/medium: 103.337 -> 85.598 tokens (-17,2%); 6/6 hechos correctos en ambos.
  Fuentes 43.887 -> 3.616 bytes. Selección exacta verificada, casos de errores y
  señales probados. Límite: una pareja de recuperación, no benchmark de coding;
  caché difiere. No afirmar garantía de calidad o ahorro semanal universal.
- Config carga en Codex Doctor; fallo independiente TERM=dumb en terminal de
  herramienta. No se actualizó Codex ni modificó shell. Sesiones abiertas pueden
  conservar roles anteriores. Próximo: evaluar uso normal con misma validación;
  auditar bajo demanda, sin tareas periódicas creadas.

## Memoria local con recuperación multilingüe (2026-09-26)

- Investigados Obsidian, QMD, GraphRAG y memoria nativa. Markdown sigue siendo
  fuente; Obsidian no añade por sí solo recuperación semántica. No se instaló
  Obsidian/QMD/grafo ni se activó generación de memoria que consume cuota.
- recall.py combina BM25 SQLite y E5-small ONNX local CPU. Modelo oficial fijado
  por revisión/hash, ~487 MB; venv aislado, caché de vectores privada por contenido.
  Prefijos query/passage, chunks con solapamiento, fuentes completas preservadas.
  No descarga durante consultas ni envía notas; auto fallback léxico anunciado.
- En búsqueda natural, conteo de palabras anterior fallaba. Primeros conjuntos:
  2/14 -> 10/14 secciones esperadas top5. Tras congelar método, comprobación nueva:
  3/6 -> 6/6; BM25 solo también 6/6 en esta última. Datos en memory-eval y análisis
  en ~/.codex/token-economy/MEMORY_RESEARCH.md. No se afinó tras prueba final.
- PASS 17 tests funcionales, fallback sin modelo y benchmark previo conservado.
  Límite: ranking no certifica respuesta/ausencia; consultar fuente y contexto.
  Hasta cinco candidatos pueden aumentar contexto por consulta. No afirmar nuevo
  porcentaje de ahorro de tokens ni superioridad medida frente a QMD no ejecutado.
- Próximo: usar modo automático; --mode lexical para consulta por términos sin
  modelo, --list para candidatos. Historial y contratos prevalecen sobre similitud.

## Memoria: ahorro observable por consultas agrupadas (2026-09-26)

- recall.py acepta --query repetible, conserva cinco candidatos por consulta y
  emite una vez cada sección (cuerpos íntegros y asociación query/fuente). --list
  muestra rangos. AGENTS global aplica agrupación cuando ya se conocen preguntas;
  no hay interceptor automático ni garantía universal de ahorro.
- A/B nuevos Sol/medium, 6 preguntas sobre corpus congelado: 108.741 tokens antes
  y 64.728 después, -40,475%; 6/6 respuestas correctas ambos. El antes hizo una
  relectura extra (3 respuestas modelo vs2), factor importante del ahorro medido.
  Unión de evidencia exacta: 30 apariciones ->21 secciones; no se elimina contenido.
- Una pareja con preguntas de regresión, caché diferente; no predice cuota semanal,
  generalización ni ahorro neto al incluir investigación/ensayos. Ensayo inicial
  interrumpido excluido explícitamente. Reproducción/rollouts/rúbrica en
  ~/.codex/token-economy/progressive-benchmark/REPORT.md. 18 pruebas pasan.
- QMD 2.8.3 instalado aislado y evaluado: search literal 0/6 (AND), vector-only
  5/6, mediana4,89s; query completo agotó180s primera pregunta, expansión153,3s,
  timeout durante reranking. Calidad completa desconocida; no se promueve.
  Sin procesos pendientes, MCP ni demonios. Obsidian no instalado.

## Skill personal de ahorro (2026-09-26)

Creada ~/.codex/skills/ahorro-tokens/SKILL.md: memoria agrupada, salidas originales,
orquestación por roles existentes y protocolo de medición opcional. Reutiliza
herramientas sin copias ni nuevas llamadas de modelo. AGENTS global enlaza la
skill para optimización/auditoría; conserva reglas breves de aplicación cotidiana.
Referencias locales verificadas; validación estructural con quick_validate.


## 2026-09-26 — Publicación Fluid Island

Petición: guardar versión actual en GitHub, documentada, sin IA ni secretos.
Preparados CHANGELOG.md, README, arquitectura y guía Fluid; corregidas rutas
locales en demo y docs. Exclusiones IA en .git/info/exclude (no publicadas);
.gitignore protege credenciales comunes, config local y logs. Correo de gitconfig
y commit nuevo usa noreply GitHub verificado. Auditoría de patrones no halló
secretos en snapshot; no equivale a garantía absoluta. Historial remoto antiguo
incluye AGENTS/TASK_STATE y correo anterior; no se reescribe sin autorización.
Pruebas: 12 fixtures *-regression.qml PASS offscreen con ISLA_CONFIG temporal,
verify-config.sh, media-source.cjs y settings-integration.py PASS. Sin QA visual
nueva; no se modificó comportamiento QML (sólo comentario portable en demo).
Capturas previas sin datos sensibles visibles según auditoría. Wallpapers y
plugin binario preexistentes se conservan; no se añadió material multimedia.

Publicación completada: commit 865673c en origin/main, push sin force.
Comprobación final: árbol de trabajo versionado limpio y hash remoto igual al local.


## 2026-09-26 — Limpieza autorizada del historial

Usuario autorizó retirar IA preservando rollback y correo personal. Se creó
bundle privado fuera del repo en ~/.local/state/quickshell-backups/history-cleanup-5o4689zt/.
El historial main conserva sus seis commits (incluido uno sólo documental que
ahora queda vacío): se retiraron AGENTS.md, TASK_STATE.md, docs/ORCHESTRATION.md
y tools/check_orchestration.py. Sin cambios a correos, mensajes, fechas o código.
Comparación por árbol de cada versión aprobada; árbol actual idéntico, sin
necesidad de repetir pruebas funcionales. Mapa old/new y recuperación junto
al bundle. Force-with-lease exitoso 865673c -> e8aec93; main local/remoto
verificados iguales, árbol limpio. Copias externas/cachés no se purgan con push.

Límite comprobado: GitHub API todavía resuelve el antiguo b0ba196 por SHA
tras el push. No está en main; retirada de objetos/cachés del proveedor no
se controla con Git. Documentación GitHub indica que soporte no elimina
datos no sensibles. No se envió solicitud de soporte ni se eliminó el repo.

## Lockscreen — definición de diseño (2026-09-26)

Usuario eligió definir diseño primero y pidió reutilizar código, movimiento y
tipografía de Isla manteniendo wallpaper visible. Propuesta documentada en
`docs/LOCKSCREEN_DESIGN.md`; no implementada ni visualmente aprobada. Revisados
Settings/Theme/Motion, GlassCard, inicio de PillMaterial y runtime externo
LockSurface/lock_shell/lock.sh. Google Sans Flex e Inter siguen los tokens.
El runtime usa proceso independiente con WlSessionLock y PAM; compartir código
no permite trasladar objetos vivos de la barra. FluidCompanion es lateral: no
prometer reutilización vertical sin adaptación. Pendientes: preview visual,
integración de perfil/config, instalación reproducible y pruebas funcionales.
Sólo documentación modificada; sin bloqueo, autenticación o energía ejecutados.

## Lockscreen — primera implementación instalada (2026-09-26)

Usuario autorizó implementarlo. Entrada versionable bar/lockscreen.qml conserva
PAM/WlSessionLock del runtime externo; diff limitado a imports, ruta wal de
Config y bandera preview. UI nueva en bar/lockscreen: GlassCard con blur local,
Theme/Motion, reloj central, UserAvatar compartido, MediaSession/Players/cover,
TextField y botones con teclado. Initial ~/.face ausente: fallback Z comprobado.
Settings admite profile.displayName vacío mediante minLength=0 explícito, rutas
con validación existente. Config expone perfil/avatar; ejemplo actualizado.

Validación: verify-config.sh, settings-integration.py, lockscreen-regression.qml
y tests/lockscreen-launcher.py PASS. Regresión comprueba secure/busy, borrado de
secreto, vacío y confirmación de energía mediante señales falsas. Launcher
verifica limpiar preview y fallback usando binarios falsos. bash -n y diff check
pasan. Capturas Wayland: /tmp/isla-lock-final.png y /tmp/isla-lock-light-final.png.
Fixture clara con nombre largo, avatar de prueba y fontScale1.3/reduceMotion;
config temporal, sin guardar ajustes personales. Offscreen no dibujaba avatar
con clipping; Wayland sí. No se midieron FPS ni continuidad frame a frame.

Instalado wrapper en ~/.local/share/quickshell-lockscreen/lock.sh hacia checkout,
sin modificar binds ni hypridle. Backup del launcher anterior:
~/.local/state/isla/lockscreen-backup.sHnoBH/lock.sh. Los antiguos QML siguen ahí.
No se ejecutó bloqueo/PAM ni energía real; autenticación real y multimonitor
pendientes. Aceptación estética pendiente. Primera entrada morph, sin neck
vertical ni traspaso de objetos del proceso de la barra.

## Lockscreen — blur y pill→tarjeta (2026-09-26)

Petición: blur de fondo, animación de contraseña correcta/incorrecta y morph
desde pill. LockSurface aplica MultiEffect al wallpaper (48 px máx, intensidad
0.15→0.65 ligada a presentation). Un solo LockGlass cambia posición, tamaño
y radio desde pill hasta acceso; sin traslado de objetos entre procesos.
Contenido se revela con espacio disponible, entrada espera secured.

Error: recoil -7/+6/-3/0 y color, secreto borrado. Success: campo contrae a176,
check/Listo, espera Motion.standard+fast, contenido se retira; departing depende
de contentOpacity<=.001. Una prueba Wayland detectó desfase cuando dependía de
timer y se corrigió usando opacidad real. Backend PAM Success ahora conserva
lock hasta successTimer (standard+2fast+morph+80, 220ms reduced); después suelta
y sale con quitTimer. UI no concede autenticación. Bloqueados envío/energía
tras éxito.

PASS: lockscreen-motion-regression offscreen y Wayland (interrupción/reapertura,
recoil asentado, éxito antes de recogida, retorno, reduced); pruebas previas
de acceso continúan. Capturas /tmp/isla-lock-motion/{02-expanding,04-rejected,
05-success,07-pill-return}.png inspeccionadas. Captura07 corregida para no
mutar estado en el mismo tick del grab asíncrono. Sin medición FPS ni PAM real.
No se ha bloqueado la sesión del usuario. Launcher instalado ya apunta a los
archivos actualizados; respaldo anterior sigue disponible.

## Lockscreen — pulido de tipografía y composición (2026-09-26)

Usuario confirma funcionamiento del desbloqueo real; pide aspecto más nativo
y mejor tipografía con apple-inspired-ui. fc-match confirma Google Sans Flex
e Inter instaladas. Propuesta: usar Theme.fontMedia (Inter existente) para toda
la UI de bloqueo, sin cambiar tipografía global de barra. Reloj Medium104 sin
Text.Raised, sombra más contenida, fecha Medium encima. Avatar84, tarjeta324×286
radio34 y textbox46 radio15; controles secundarios flat conservan hit areas.
UserAvatar recibe fontFamily configurable con default Theme.font. Glass local
con luz superior leve y borde fino uniforme. Overscan64 del wallpaper evita
bordes oscuros del blur. No cambios PAM ni coreografía.

Preview Wayland inspeccionada: /tmp/isla-lock-polished.png. Fixture clara con
nombre largo, imagen y fontScale1.3: /tmp/isla-lock-type-light.png (anterior al
ajuste de overscan). Regresión entrada/secretos y motion Wayland PASS. Diff
check limpio. Propuesta estética pendiente de aceptación; no atribuir la
confirmación funcional a aprobación visual.

## Lockscreen — afinar entrada (2026-09-26)

Usuario percibe rara la animación inicial. Causa de composición: traslado y
crecimiento lineales simultáneos, material grande vacío sobre zona de reloj y
revelado conjunto al final; Behavior extra sobre opacidad seguía un destino
que cambiaba cada frame. Conservado SmoothedAnimation único de presentation y
Motion.morph; travel cúbico adelanta expansión smoothstep desde fase0.18. Pill
compacta primero, expansión cerca del destino, sin pausa entre ambos. Espera
inicial80→32ms. Radio/tamaño siguen expansión, posición sigue travel.

RetirementOpacity sólo anima retirada de éxito; revelado de apertura directo
por geometría. Avatar/nombre desde expansión0.56 con ancho acotado al material,
campo desde0.84, media0.94, reloj cuando travel>.92. Acceso acompaña el cuerpo
en posición, sin deformación de texto. Autenticación/tiempos backend intactos.

PASS: motion en Wayland con interrupción/reapertura/reduced y nuevas aserciones
por frame: travel>=expansion e input sólo con espacio suficiente. Regresión
de acceso offscreen PASS. Capturas muestreadas en /tmp/isla-lock-refined,
inspeccionadas inicial/intermedia/final; sin medición FPS ni prueba física.
Pendiente valoración del usuario.

## Sesión y energía — referencia de perfil (2026-09-28)

Usuario aclaró que la nueva imagen aplica a Win+M, no al bloqueo. SessionSurface
reutiliza UserAvatar/Config.profile, añade saludo y tarjetas principales en orden
Suspend/Reboot/Shutdown/Logout con tintes contenidos. Bloquear secundario; no
se añaden controles inactivos de cambiar usuario o avión. Conservado material
único externo de FluidCompanion/PillMaterial y motor izquierdo. Avatar dentro
del cuerpo para no recortarlo en el host existente. Geometría base640×470
limitada por espacio del monitor.

Acciones existentes mantienen índices0..3 y numéricas1..4, suspend índice4
con tecla5. Flechas siguen orden visual4/2/3/1/0. Destructivas requieren Confirmar,
lock/suspend directas; pruebas actualizadas y sólo fake. PASS session-regression
y session-companion-regression; snapshot preview en520px para ancho limitado
/tmp/isla-session-reference.png. Runtime real abierto vía IPC y captura
/tmp/isla-session-live.png inspeccionada; cerrado por toggle mismo IPC. No se
ejecutó energía/bloqueo/logout real. session-preview.qml sirve para revisión
con acciones vacías. Pendiente aceptación estética y selección de imagen de
perfil; default ~/.face ausente muestra inicial.

## 2026-09-28 · Sistema global de interacción

- Auditoría previa de primitivas y handlers; cobertura y criterio en
  docs/INTERACTION_SYSTEM.md. Theme/pywal, layout y motor FluidCompanion intactos.
- Motion tokens compartidos; InteractionMotion (compresión corta + retorno
  SpringAnimation), MotionArea compatible MouseArea y MotionButton sobre Button
  Basic. Escalas sólo en hijos visuales; Pill hover pasa a su material existente.
- MaterialIcon conserva API visual, fuente/axes y paths vectoriales de transporte;
  swap solapado interrumpible, direcciones y giros semánticos. ReduceMotion y
  ocultamiento paran feedback físico/swap. No timers ni efectos nuevos en controles.
- CtrlBtn, Toggle, LockButton, SessionSurface, launcher, surfaces de conectividad,
  utilities, mixer, calendario, clipboard, notifs, overview/workspaces/wallpapers y
  media compacto migrados. Drag/scroll conservan sus grabs. Slider centra knob y
  reutiliza valFromX; grips tienen token. Disabled/foco/teclado en primitivas.
- Correcciones previas encontradas al cargar: Clipboard if como objeto QML + s
  inexistente; NotifCard duplicate Behavior implicitHeight; layout anclado Notifs.
- Pruebas PASS: interaction (eventos QtTest/cancel/keyboard/toggle/slider/swap/reduce),
  carga 12 surfaces sin Auth, motion, media-motion (playing false), status,
  wallpaper, overview, sesión con acciones falsas y lockscreen. QMllint compartido
  pasa. Logs originales en ~/.cache/codex-economy/output-* (véase doc para comandos).
- QA Wayland: preview falsa normal/hover/press/release/swap/final capturada en
  /tmp/isla-interaction-*.png e inspeccionada. Stress 96 controles:128 frames,
  promedio16.98ms/máximo22.61ms; escala máxima1.0000/cero sin asentar. Intervalos de
  fixture, no medición GPU/full-shell/input hardware. No se ejecutó energía ni
  se cambió playback/wallpaper/workspaces. Valoración de sensación a largo plazo
  y cobertura física de todos los dispositivos quedan a criterio del usuario.
- Un smoke inicial importó Auth y registró un socket de prueba; se excluyó Auth
  de la fixture permanente. Shell real recargada por IPC island.reload;
  log confirma Configuration Loaded y Polkit registrado; endpoint restaurado. No guardar ajustes de test en la configuración personal.
- Lint final de primitivas PASS; Auth/Calendar devuelve255 sin diagnóstico
  (limitación previa del qmllint local). Carga runtime y fixtures aportan evidencia
  distinta; no interpretar ese lint de surfaces como pase.

## 2026-09-28 · Completar cobertura real de iconos y Win+M

- El usuario señala que Win+M apenas responde; la primera pasada había dejado
  gestos semánticos sin conectar en varios controles. Corregido, no sólo tokens.
- MaterialIcon recibe interaction explícita, con progreso común y gesto de
  energía/suspensión/reinicio/logout/lock/conectividad/add/remove. Se conectan
  iconos y etiquetas en surfaces; compresión sólo visual, sin mover hitbox.
- SessionSurface tarjetas de cuatro acciones: fondo/presión progresivos, iconos
  con gesto y labels coordinados. QtTest Wayland verifica los cuatro, presión de
  composición, anchura y scale de hitbox fijos, retorno y cancelación con fake.calls0.
- Lock power popup pasa a MotionButton; batería crossfade sin cambiar glifo;
  cover de gota conecta hover/press reales. Demo handlers usan MotionArea.
- Intento de envolver backgrounds mediante aliases de pintura provocó crash en
  fixture offscreen; retirado por completo. Se usan transforms en visuales ya
  separados y MotionArea/MaterialIcon, sin esa abstracción. Shell PID3001 intacta.
- PASS: interaction-regression, session-regression, lockscreen-regression,
  media-motion, interaction-surfaces12; previewWayland cuatro acciones; qmllint
  CtrlBtn/MaterialIcon/MotionArea/SessionSurface. Performance aislado127frames,
  media16.95/max22.09ms, maxScale1, unsettled0. Concurrencia conpreview da19.50ms,
  no se trata como A/B. Intervalos fixture, no GPU/input hardware.
- Shell recargada por IPC, ConfigurationLoaded/Polkittrue. Panel real de sesión
  abierto y capturado en /tmp/isla-session-live-complete.png, inspeccionado y
  cerrado con island.hide. No se ejecutaron acciones reales de energía.
- Detalle y cobertura vigente en docs/INTERACTION_SYSTEM.md. QA física de todos
  los dispositivos/uso prolongado no demostrada por estos tests.
- Demo final: `QT_QPA_PLATFORM=wayland timeout3s quickshell -p bar/fluid-demo.qml`
  muestra ConfigurationLoaded sin errores; exit124 es cierre por timeout. Sólo
  se valida carga, no clicks físicos de cada control de demo. No quedan fixtures
  ejecutándose; instancia principal es la única listada al finalizar.


## 2026-09-28 · Iconos vectoriales según referencia Animate UI

Petición: iconos como animate-ui.com/docs/icons en todo el sistema; sustituye
la interpretación previa de mover un glifo completo. MaterialIcon mantiene API
pero usa AnimatedIconData (80 nombres, 267 nodos SVG, geometría oficial Lucide
con licencia en docs/licenses/lucide.txt). AnimatedSymbol es QML nativo, sin
React/Motion web: trim de strokes, ondas, vástago/arco de power, arco del candado,
campana/badajo, gear y flecha interior. Una secuencia650ms×motionScale en
hover/foco/tap; salida retargetea desde progreso actual. ReduceMotion y ocultar
ventana/surface paran el trabajo. Qt6.10+ (local6.11.2). BatteryChip sustituye
emoji por estados vectoriales; LockButton permite foco como trigger compartido.

Validación: galería16 familias Wayland con assert de partes/progreso, fin de
hover sin loop, reduced motion y parada al ocultar pasa. Se corrigió un fallo
real: ocultar Window no cambia Item.visible; exposed observa también Window.
Capturas rest/motion inspeccionadas; el progreso sí cambia trazos/piezas. Preview
Win+M pasa las cuatro tarjetas con cancelación segura; interacción offscreen,
lockscreen guards y carga12 surfaces no Auth pasan. qmllint MaterialIcon y
AnimatedSymbol exit0, git diff --check pasa. Shell principal recargado mediante
IPC, Configuration Loaded y Polkit true; panel de sesión real abierto,
inspeccionado y cerrado. No se ejecutaron acciones de energía.

Rendimiento: stress96 cambios simultáneos mostró media20.36/max109.52ms.
Async path no mejoró (21.12/91.74) y GeometryRenderer19.32/93.43; ambos descartados.
Se conserva CurveRenderer y Repeater por número de piezas, reteniendo delegados
cuando el nuevo icono tiene igual cantidad:18.31/max62.48ms,116frames, escala1,
unsettled0. No es A/B estadístico ni coste de shell/GPU; hay mayor coste de
cambios masivos que los glifos. Uso prolongado/valoración visual pendientes.
Logs en ~/.cache/codex-economy/output-{kcw0cjz9,tevhae59,4g864i54,nuz0fk9h,cfshl4b_}.log.


## 2026-09-28 · Afinar solicitud de contraseña (sudo/Polkit)

Petición: máxima mejora funcional y de animación con fluid-island-motion,
apple-inspired-ui, ahorro-tokens y qt-qml. Se preservan cambios anteriores.

Hallazgos corregidos: campo oculto900ms tras error; texto de contraseña separado
del contenedor que temblaba; éxito Polkit nunca visible (cerrado al acabar flow);
tres temporizadores competían por foco; notificación podía suspender formulario;
doble-submit/stale results/socket desconectado no acotados; helper ignoraba prompt
argv1 y wrapper rompía -S con -A.

AuthSurface es wrapper de AuthPrompt con backend inyectado: TextField nativo,
Password sin último carácter visible, respuesta eco explícita de Polkit, IME,
selección, nombres accesibles, Enter/Tab/ShiftTab/Escape, popup de cuentas, texto de
solicitud/supplementary, Bloq Mayús. Errores no esconden campo; editar retira banner
sin timer. Acción/cancel mantienen caja fija, spinner sólo visible durante busy;
recoil -4/+3/0 mueve campo completo. Éxito muestra candado abierto/check y retiene
confirmación750/1100ms mínimos (Motion/reduceMotion desde composición). Nuevo flujo,
cuenta, envío, cancelación, cierre/destrucción limpian campo. Un envío rechazado
retiene respuesta sólo si sigue vigente. Polkit prioriza sudo simultáneo.

Pill: auth400×s + reloj, altura mínima82 adaptada a fuente. Host inyecta ancho de
contexto/caps y closing incluye !open para limpiar antes de unload. Contenido se
revela sólo en últimos24×s disponibles, sin cruzar reloj. Motor Smoothed existente
conservado. Overlay Exclusive para auth, fuera de timer genérico y Shortcut Escape
(para permitir cerrar popup antes de cancelar). NotificationChoreography.blocked
para auth cancela animación sin descartar popup; lo pendiente/ vigente se reanuda
al salir. RootBackend presenting conserva éxito aunque desaparezca flow.

Auth valida requests JSON/ID/prompt/tracked, envío único, alive socket, una sola
línea, resultados0..255 sólo tras envío para ID vigente; desconexión conserva
feedback final; timeout tracked120s. sudoCanRespond distingue retry de final.
PolkitSubmitting/Error/Success/Message se sincronizan con señales de flow/cuenta.
Prueba copia Auth a temporal con Polkit fake + SocketServer inactive, asserts de
seguridad del aislamiento antes de cargar.

Helpers externos: ~/.local/bin/isla-sudo-askpass prioriza argv1 y normaliza CR/LF.
Fish sudo en ~/.config/fish/config.fish sólo inyecta-A donde corresponde; detector
acotado de opciones antes de comando, valores/cluster/--, stdin y askpass explícito.
preflightsudo-v sólo normal intacto; argumentos de comando-S no confunden opciones.
Backup ambos ~/.local/state/quickshell-backups/auth-bridge-u0asow7q; permisos y resto
config preservados. Terminales vivos no se manipulan; requieren sesión nueva.

PASS: auth-backend.py (ug2l3gzy), auth-bridge.py (3po5syx0), auth-prompt-regression
Wayland (eubep4qb), offscreen (o4gt6443), claro/font1.75/motion2 (56n7zf3q),
motion-regression (6b4o_3i9), router (n8ewe1_2), notification (c67ppjjb), qmllint
primitivas AuthPrompt/AuthSurface/Host/Notification (n_iw08ck), diffcheck. Lint
conjunto con IslandOverlay/Auth retorna255 sin diagnóstico (4rfhr9pp); no contado
como pase. Capturas de mock con PillMaterial normal/error/busy/success y
close/reopen inspeccionadas. Assert por frame exige ancho suficiente para contenido;
recoil asienta, reduceMotion resuelve, Popup Escape no cancela petición, backend
rechazado y prioridadsudo cubiertos. Sin medición FPS ni credenciales reales.

Shell recargado, Configuration Loaded; authDebug registered=true, active=false,
flow=false/sudo=false y sin residuo. Documentado en docs/AUTHENTICATION.md y TESTING.
Pendiente: validar próxima solicitud real del usuario y valoración estética/uso
prolongado. No se ejecutaron operaciones privilegiadas, ni cambios al lockscreen.


## 2026-09-28 — sudo sin contraseña: socket borrado durante recarga

El usuario observó `sudo su` → `sudo: no password was provided`. El shell real
seguía registrado y ss mostraba listener, pero /run/user/1000/isla-sudo-askpass.sock
no existía: askpass no podía conectar. La implementación nativa de SocketServer
borra el pathname al destruirse. `island.reload` utilizaba reload(true), abriendo
el listener nuevo antes de destruir la generación anterior. Se reprodujo ausencia
tras hard reload; Qt.callLater no resolvía el orden y se descartó.

Corrección final: reload(false) conserva el traspaso nativo; SocketServer tiene
reloadableId islaSudoAskpass. No timers ni polling de recuperación. Askpass instalado
informa indisponibilidad de conexión con texto fijo en stderr, nunca respuestas.
Cancelación continúa silenciosa. Se conserva el backup auth-bridge-u0asow7q.

Validación: cuatro recargas efectivas del shell real con conexión AF_UNIX tras
cada una; Polkit registrado y auth inactivo. Auth transport nuevo copia backend,
reemplaza agente por falso y usa runtime temporal/Wayland; toma el método reload
real de shell.qml. Inicio + cuatro recargas entregan fixture-response. PASS log
output-10n39kfs.log. Backend PASS output-aqaheitz.log; bridge PASS output-2ryxbflj.log.
Fixture offscreen no sirve para esta prueba: popup de recarga sin PanelWindow
impedía IPC listo. Se cambió a Wayland aislando runtime y ruta del socket.

Límite: no se ejecutó sudo real ni se usaron credenciales. Solicitud real del
usuario pendiente; QA visual anterior permanece vigente, sin cambios de UI aquí.


## 2026-09-28 · Fish con Starship

Petición: mejorar la shell mediante Starship. Antes: Fish con prompt Isla
personalizado y código de coloreado Tide aún en config.fish. Instalado Starship
1.26.0 mediante instalador oficial en ~/.local/bin (sin sudo). Configuración
en ~/.config/starship.toml: dos líneas, firma 🎩, ruta truncada, Git con conteos
independientes staged/modified/untracked, contexto Python/Node/Bun/Rust/Go/Nix/
Docker cuando aplica, estado/duración >=2s/hora a la derecha. Transience nativo
en Fish. Colores de ruta/rama/carácter/hora con contraste estable tras inspección
de Kitty; pywal conserva colores de sintaxis y terminal.

config.fish conserva el bloque sudo Isla, aliases, zoxide y ajustes CachyOS;
se reemplaza el coloreado/caches Tide por actualización pywal de sintaxis. Los
archivos del prompt anterior y el plugin Tide quedan disponibles como fallback;
Starship redefine fish_prompt/fish_right_prompt al final del inicio interactivo.
Respaldo original: /home/zdito/.local/state/shell-backups/starship-20260928-172844.

Validación: fish -n; prompts Starship sin stderr; fixtures temporales Git
normal/staged/untracked/modified, error42/duración3456 y virtualenv Python pasan.
Inicio Fish confirma ambos prompts Starship y fish_transient_prompt=1, sudo y
zoxide presentes. Sesión PTY confirma reducción del prompt al ejecutar comando;
el PTY de herramienta no responde consultas DA de Fish (aviso de terminal),
Kitty real abre y renderiza prompt correctamente. starship timings en este repo:
git_status3ms, directory1ms, time1ms, restantes visibles <1ms; una muestra, no
benchmark global. Terminales previas requieren exec fish o reapertura.


## 2026-09-28 · Starship sigue el wallpaper (corrección solicitada)

Usuario pide que los colores cambien con pywal. ~/.config/starship.toml usa
alias wal7–wal14/wal_fg y fallback; ~/.config/starship/pywal.py deriva paleta
de ~/.cache/wal/colors.json, mezclando solo cuando hace falta hacia foreground
hasta contraste4.5 sobre background. No garantiza contraste sobre cada zona
de wallpaper transparente. Config generado atómicamente en
~/.cache/starship/pywal.toml y exportado como STARSHIP_CONFIG desde
__wal_apply_colors al inicio interactivo y al recibir wal_sync_signal.
Selector actual ~/.config/hypr/scripts/wallpaper-picker.sh emite esa señal.
Historial transitorio también usa starship module character con args nativos.

Checks persistentes: python3 ~/.config/starship/test_pywal.py cubre paletas
oscuras/claras/poco contraste, diferencias rojo/azul, idempotencia y rechazo
de hex inválido. fish -n pasa; inicio Starship sin warnings; señal simulada
confirma regeneración/export en Fish. Render actual usa valores pywal rojos
aclarados y texto de foreground comprobados en la salida ANSI. Se abrió preview
Kitty temporal, pero la captura mostró otra ventana: QA visual de esta corrección
no certificada. No se cambió el wallpaper real para probar. Terminales ya abiertas requieren exec fish una vez para cargar
el handler nuevo; futuros cambios por el selector se aplican en vivo. Backup
previo: ~/.local/state/shell-backups/starship-pywal-20260928-173454.


## 2026-09-28 · Publicación Starship en el repo

Integrado el cambio de prompt en paquete Stow starship/.config (TOML,
pywal.py y test_pywal.py). fish/config.fish incorpora solo el adaptador pywal
y arranque/transience de Starship, conserva guards de CachyOS y aliases del
repo; no se copió el bloque local sudo Isla, ligado a otros cambios pendientes.
Retirados Tide de fish_plugins y conf.d/tide-structure.fish. install.sh añade
paquete Stow starship y dependencias oficiales starship/python. README describe
flujo, uso, pruebas y límite de contraste sobre transparencia.

Checks: fish -n, bash -n, install.sh --help, prueba persistente de paletas,
diff --check pasan. Instalación reconstruida en HOME/XDG_CONFIG_HOME temporal:
sin pywal usa fallback; con pywal genera config/export y maneja señal y
transient prompt sin stderr. No se ejecutó instalador completo ni pacman/Stow
contra sistema. Commit20966d4 contiene solo8 archivos de esta integración;
otros cambios locales de Isla conservados.


## 2026-09-28 · Publicación de todos los cambios pendientes de Isla

Usuario autorizó incluir también el resto. Commit74b3a2c (81 archivos) incorpora
controles/iconos Lucide, AuthPrompt/backend/recarga, lockscreen/PAM/lanzador,
sesión/perfil, fixtures, docs y licencias. README y CHANGELOG actualizados.
Revisión independiente detectó helper askpass local ausente e integración de
lanzador insuficiente: fish/.local/bin/isla-sudo-askpass y wrapper Fish añadidos,
auth-bridge.py ahora prueba fuentes del repo; bootstrap añade Quickshell y
ejecuta lockscreen/install.sh después de Stow. README documenta ejecutar shell
con quickshell -p bar y conservar ruta checkout. El paquete Hypr anterior
conserva Super+L/hypridle→hyprlock, con opt-in documentado al lanzador nuevo.
No se migró el compositor ni se ejecutó bootstrap sobre el sistema real.

Validación publicación: 24/24 checks del runner temporal pasan (16 QML
offscreen + settings/media-source/static/settings-IPC/Auth backend/bridge/
transport/lock launcher). Logs individuales en /tmp/isla-publication-i363rqko,
log resumen ~/.cache/codex-economy/output-7rryg839.log. Wayland iconos/AuthPrompt/
lockscreen motion pasan (logs output-brmfgl_x/output-qazyls7k/output-h15r4jal);
inspeccionadas capturas /tmp/isla-icons-motion.png,
/tmp/isla-publication-auth-ready.png y /tmp/03-ready.png. Bridge revalidado desde
repo y launcher ampliado con instalación/XDG/backup temporal pasan (logs
output-w89_wk54/output-smgupl__). fish -n, bash -n y git diff --check pasan.
Pruebas usan credenciales y acciones falsas; autenticación real, GPU y
multimonitor no certificados por esta publicación.

Publicado origin/main; HEAD y origin/main coinciden. Checkout limpio de cambios
versionables. Memoria y estado locales siguen excluidos de Git.
## 2026-09-29 · Auditoría de serpantinum

Revisado `ilyamiro/serpantinum` en d7aa27eb99c000389a3ceacaea7ab36eb54a27c8, sus cuatro previews, módulos Quickshell y ejemplo Hyprland Lua. Comparado con este checkout de egaldidots y Hyprland 0.56.2 local. Informe versionado: `docs/SERPANTINUM_AUDIT.md`; prioridades y referencias por archivo allí. Serpantinum actual es shell, no paquete completo de dotfiles. Destacan indicador workspace de bordes independientes/direccionales, overlay captura/edición/grabación, halo media, letras, editor de temas; dock/widgets son grandes y se posponen. Isla ya tiene Cava, selector wallpaper, media/overview, pywal, Motion y motor de gota: conservarlos como dueños de estado/forma. Hyprland externo propone popin80% y capas fade; ensayo reversible, sin cambiar config actual. Licencia externa AGPL-3.0-or-later; Isla MIT. Copia directa requiere resolver licencia/avisos, créditos solos insuficientes. `hyprctl configerrors` vacío; `satty` ausente. No se ejecutó shell/instalador externo, no se cambió UI ni config activa. Validación: inspección de fuentes/capturas, enlaces a SHA fijo y `git diff --check`; fluidez y rendimiento quedan por probar en Wayland durante cada implementación.

## 2026-09-29 · Implementación inspirada en serpantinum

Petición posterior: empezar por animaciones de Hyprland y completar las cuatro mejoras anunciadas. Activo: `~/.config/hypr/modules/animations.lua` cambiado a Bézier `(0.05,0.9,0.1,1.05)`, ventanas `popin 80%`, capas fade y workspaces slide; conservado reflow/borde de Isla. Respaldo en `~/.local/state/hypr-animation-backups/animations-20260929-pre-serpantinum.lua`. `luac -p`, `hyprctl reload` y `hyprctl configerrors` vacío. Equivalente en `hypr/.config/hypr/modules/animations.conf` del repo, que hoy es legado: el Hyprland activo usa Lua fuera del repo.

Quickshell: marcador direccional en WorkspacesSurface; halo Cava condicionado a música visible, reproducción, arte y movimiento normal en MediaSurface; panel AppearanceSurface desde ajustes rápidos con borrador/previsualización local y guardado Config; rutas/geometry/host integrados. QML sincronizado con `~/.config/quickshell/bar` tras respaldar originales en `~/.local/state/quickshell-backups/serpantinum-20260929`; `qs -c bar ipc call island reload` exitoso. QA Wayland: paneles apariencia y workspaces abiertos, capturados e inspeccionados, luego ocultados; media abierta con vídeo Firefox y halo correctamente ausente. No se alteró reproducción ni workspace. `qmllint`, regresiones QML de apariencia/13 surfaces/halo/motion/config, `git diff --check` pasan; fixture temporal verificó ruta Utils→Appearance. Halo con música y carátula reales aún sin QA visual.

Captura: script propio `screenshot-annotate.sh` y bind Super+Alt+S añadidos a repo y entorno Lua activo; atajo anterior conservado. Flujo simulado y cancelación pasan. `satty` 0.22.0 instalado a `~/.local/bin/satty` desde paquete firmado de CachyOS verificado con `pacman-key`; CLI y bibliotecas comprobadas. Falta probar selección/edición gráfica real. README atribuye inspiración; no se copió QML AGPL. Queda pendiente alinear toda la configuración Hypr Lua activa con el paquete legacy del repo si se desea portabilidad completa.

## 2026-09-29 · Calendario/clima y conectividad

El usuario pidió que clima y calendario sigan juntos como en serpantinum y calificó la superficie de conectividad anterior de fea. CalendarSurface pasó de 340×420 a 660×470: calendario a la izquierda; a la derecha temperatura/icono protagonistas, sensación, humedad, viento y tres días seleccionables. Sigue el mismo `wttr.in/?format=j1`, sin servicio nuevo; parser ahora usa códigos WWO correctos (113 despejado, 116 parcial, etc.) y conserva datos anteriores si falla la consulta. Selección del pronóstico hace fade corto interrumpible y `reduceMotion` resuelve directo. ConnectivitySurface conserva Nmcli, BlueZ, contraseña y acciones; reemplaza tarjetas anidadas y hueco grande por cabecera de estado y vistas Wi-Fi/Bluetooth con selector, panel 360×400. No se copiaron fuentes AGPL.

`qmllint`, `git diff --check`, carga de las 13 superficies y regresión `bar/calendar-connectivity-regression.qml` pasan. `curl` real devolvió condiciones y pronóstico; Wayland mostró ambas superficies finales sin recorte, con datos meteorológicos y tres redes Wi-Fi tras el breve refresco inicial. Capturas internas `/tmp/isla-calendar-weather-final.png` y `/tmp/isla-connectivity-final.png` inspeccionadas. QML sincronizado con shell activo y recargado; respaldos en `~/.local/state/quickshell-backups/wifi-weather-20260929`. No se cambió red ni radio, ni se introdujo contraseña real. Pendientes: valoración visual del usuario, interacción manual con pronóstico y flujo de conexión en UI real.

## 2026-09-29 · Credenciales Wi-Fi y feedback

El usuario aprobó calendario/clima y rechazó dinamismo y diálogo de credenciales de conectividad. Inspeccionado `NetworkPopup.qml` de serpantinum: la contraseña allí usa TextInput.Password dentro del núcleo central y el estado conectado cambia icono/composición; no se copió QML AGPL. Isla ahora reemplaza lista por un `WifiCredentials` dentro del mismo vidrio de la pill, con entrada/retirada por opacidad+desplazamiento y retargeting. Campo nativo Qt Controls permite pegar, seleccionar, corregir, mostrar/ocultar; `passwordMaskDelay=0`. La escritura hace un destello breve en el cursor y un aro reactivo alrededor del icono; sin loop decorativo. La longitud mínima WPA es 8. Al conectar, input se limpia y aparece estado ocupado; error da borde rojo, texto y recoil finito; éxito llena el icono de verde, muestra check, retira controles y vuelve a redes tras 850 ms. `reduceMotion` elimina recorridos grandes. Callback se guarda por intento para ignorar respuestas obsoletas. Se eliminó `ShapePasswordInput.qml` al quedar sin uso.

Pruebas: `qmllint`, `git diff --check`, carga de 13 surfaces y `bar/wifi-credentials-regression.qml` pasan. QA Wayland con SSID y resultados simulados sin invocar Nmcli: capturas `/tmp/isla-wifi-credentials-final-{entry,error,success}.png`, inspeccionadas; el éxito final muestra check legible. El código de prueba se retiró del shell activo al terminar. QML final copiado al shell y recargado; respaldo anterior en `~/.local/state/quickshell-backups/wifi-credentials-20260929`. No se introdujo clave real ni se modificó red/radio; flujo de conexión real y valoración visual por usuario pendientes.

Corrección tras rechazo de la animación de escritura: nueva lectura de `NetworkPopup.qml` confirmó que la referencia anima la aparición de `pwdLayer` y el borde de foco; el `TextInput.Password` no tiene efectos por carácter. Retirados el aro del icono, subrayado móvil y círculo del cursor que añadía Isla. Se conserva la entrada nativa enmascarada y la transición de la vista. `qmllint`, regresión de credenciales y `git diff --check` pasan; vista con contraseña enmascarada inspeccionada en `/tmp/isla-wifi-typing-corrected.png`. Archivo sincronizado con shell activo y `qs -c bar ipc call island reload` devolvió `true`. Animación real al teclear y conexión real aún requieren valoración en sesión.

## 2026-09-30 · Auditoría UI/UX y movimiento de la pill

Revisión de código de Pill, material, host, gota, media, notificaciones, OSD, tokens y todas las surfaces. Referencias: contrato Fluid Island, Animate, Impeccable, UI UX Pro Max y documentación Qt consultada mediante Context7. Wayland inspeccionado en reposo, calendario/clima, launcher, media sin reproductor, overview y wallpaper; capturas `/tmp/isla-{pill-before,calendar-before,launcher-settled,media-full,overview-before,overview-after,wallpaper-audit,rest-after}.png`. El launcher centrado verticalmente es intencional. La composición aprobada de overview y wallpaper se conservó.

Hallazgos corregidos: el hover frecuente reiniciaba barrido y pulso material largos; ahora el barrido sólo acompaña aperturas de surface. Activar movimiento reducido en mitad del pulso lo detiene; la respiración de reposo, el marquee de metadatos y el spinner Wi-Fi quedan inactivos con ese ajuste; OSD no cambia escala. La barra seek de media recibe foco, rol/nombre/descripción accesible y control por flechas, Home/End y acciones accesibles; se conserva arrastre. Overview mejora contraste de rótulos y permite enfocar vistas previas nombradas; artista en cabeceras y gota usa el token secundario legible. El resto del diseño, geometría y física de gotas no cambió.

Validación: `bar/motion-regression.qml` (incluye hover y activación de reduceMotion durante pulso), `bar/media-session-regression.qml`, `bar/media-motion-regression.qml`, `bar/overview-regression.qml`, carga de las 12 surfaces no Auth, `qmllint` de archivos editados y `git diff --check` pasan. Shell Wayland recargado; overview antes/después y reposo final inspeccionados. La primera carga de surfaces detectó propiedades Accessible de documentación Qt ausentes en esta instalación; se retiraron y la carga final pasó.

Límites y siguientes comprobaciones: sin reproductor musical activo no se pudo verificar visualmente seek con música, halo Cava ni el marquee largo; `media-motion-regression` indicó `playing: false`. No se midieron FPS ni se inspeccionaron todos los frames de transición o todos los estados de las 13 surfaces. `Theme.dim` sigue en otros rótulos pequeños y su contraste con cada paleta pywal/fondo real merece medición antes de cambiarlo globalmente. Las modificaciones de calendario, conectividad, apariencia, workspaces y halo que ya estaban en el checkout al empezar se conservaron.

## 2026-09-30 · Revisión y rediseño selectivo de surfaces

Revisión de todas las surfaces con foco en Mixer, Notifs, Utils, Workspaces y Clipboard, usando Fluid Island Motion Language, Animate, Impeccable y UI UX Pro Max. Capturas Wayland previas `/tmp/isla-{mixer,utils,workspaces,notifs}-redesign-before.png` inspeccionadas. Mixer tenía volumen/micrófono agrupados arriba y gran hueco sin propósito; Notifs comprimía contador, DND y Limpiar en la cabecera; Utils mostraba el acceso a Apariencia sólo como engranaje y seleccionaba perfiles con acento variable y texto negro. Workspaces conserva composición recién aprobada. Clipboard tiene una ruta de preview de imagen potencialmente rota (`Image.source` recibe una cadena de comando shell), que requiere tratar junto con la decodificación y búsqueda del historial; no se cambió en esta fase.

Mixer usa el componente Slider compartido para salida, entrada y streams, con porcentajes visibles, foco/teclado/semántica accesible, estados de silencio, icono de aplicación o fallback y lista desplazable; sin streams, el espacio muestra un estado vacío. Notifs separa título/contador de una fila rotulada para DND y Limpiar; NotifCard eleva contraste de metadatos y detiene loops críticos cuando la tarjeta está oculta o se reduce movimiento. Utils rotula Apariencia, usa selección de perfil con foreground/background de la paleta y semántica de radio; StaggerItem elimina retardo y recorrido cuando se pide movimiento reducido. Se preservaron los cambios preexistentes de calendario, conectividad, apariencia, workspaces y halo.

Validación: `qmllint` de archivos editados, `git diff --check`, `bar/motion-regression.qml`, `bar/interaction-regression.qml`, `bar/interaction-surfaces-regression.qml` (12 surfaces no Auth) y `bar/notification-regression.qml` pasan. La prueba de motion descubrió que desactivar un Behavior no detenía una escala ya iniciada; duración dinámica cero resolvió el caso de entrada bajo movimiento reducido. Captura posterior `/tmp/isla-surfaces-after-check.png` confirma que Wayland seguía en lockscreen. No se introdujo contraseña ni se desbloqueó. Falta inspección visual posterior de las tres surfaces y validación con streams Pipewire reales en sesión desbloqueada; la carga offscreen no certifica esos aspectos. No se recargó el shell activo durante la pantalla bloqueada.

## 2026-09-30 · Auditoría profunda del bloqueo de sesión de serpantinum

Referencia actual fijada a commit `9861a84d8a798dfd520102912db507773dc18971`. Alcance aclarado por usuario: `src/quickshell/lock/Lock.qml` y componentes de su bloqueo de sesión; SDDM excluido. Informe versionado: `docs/LOCKSCREEN_SERPANTINUM_AUDIT.md`. Se trazaron estados reposo/entrada/verificación/error/salida, fondo congelado y barrido, reloj, centro, alas clima/sistema/notificaciones/media, power hold y animación de puntos en `PasswordInput.qml`. Diferencia clave: el input de bloqueo sí anima cada símbolo; el de Wi-Fi revisado antes no. Riesgos de referencia: captura antes de asegurar Wayland, `hidePassword=false` que deja `isRevealed=true` por defecto, notificaciones visibles, falta de reduceMotion y tablero recortado en ancho pequeño. Preview segura de Isla ejecutada en Wayland sin PAM/lock (`/tmp/isla-lock-audit-wayland-20260930.png`); `git diff --check` pasa. No se ejecutó el bloqueo externo ni se modificó la UI/configuración activa. Próximo paso propuesto: rediseño en dos escenas con motor/material Isla y prototipo seguro de puntos animados; requiere validación de movimiento real, multimonitor y PAM.

## 2026-09-30 · Bloqueo de sesión y escritura serpantinum

Implementadas dos escenas en `LockSurface`: reposo reloj/wallpaper, acceso al clic/tecla con primera tecla preservada, centro antes que alas; clima/media laterales si caben y retorno con Escape o 15 s vacío. Se mantuvo WlSessionLock/PAM, máscara inmediata, fallo/éxito y privacidad sin notificaciones. `PasswordInput.qml` de referencia se midió en SHA 9861a84d: slots redondeados con entrada escala 0,60→1 240 ms, ascenso 3,5→0 220 ms, rotación −9°→0 220 ms, opacidad 150 ms; punto interior 0,82→1,11→1 en 110+170 ms; salida 100–130 ms, desplazamiento 160 ms, centrado 180 ms y pulso de foco 120+320 ms. Isla implementa la misma coreografía visual en QML propio. El modelo contiene sólo identificadores numéricos; el secreto permanece en TextField/PAM y no se revela por defecto.

`bar/lockscreen-regression.qml`, `bar/lockscreen-motion-regression.qml`, `bar/lockscreen-typing-regression.qml`, preview Wayland de la ruta activa y `git diff --check` pasan. Capturas intermedias `/tmp/typing-{01-rise,02-middle,03-remove}.png` inspeccionadas. `bar/lockscreen/LockSurface.qml` sincronizado con `~/.config/quickshell`, usada por el lanzador. Pendiente prueba con PAM real de esta revisión, varios monitores, IME y valoración subjetiva del gesto al teclear físicamente.
## 2026-09-30 · Barra superior lateral

Nueva composición en `IslandOverlay`: `TopWorkspaceRail` anclado a la izquierda y `TopSystemStatus` a la derecha, cada uno con región de input independiente. La Pill sigue centrada geométricamente y conserva reloj/avatar, OSD, superficies y gota. Ambos laterales se ocultan al abrir una superficie o entrar en fullscreen; el ancho disponible depende del ancho real de la Pill y del monitor. Una sola cápsula sutil por lado, derivada de Theme/pywal.

El rail lee monitores/workspaces de `Quickshell.Hyprland`, distingue activo, ocupado, vacío y urgente, amplía el número de posiciones cuando aparece otro workspace y usa un único `SmoothedAnimation` sobre la lente. `MotionArea` da hover, press, teclado y click; el click emite el dispatch de foco de Hyprland usado por WorkspacesSurface. La derecha usa `Hyprland.activeToplevel`/workspace, DesktopEntries para icono/nombre, `Pipewire` para volumen, `Nmcli` para red y `UPower` para batería de portátil. Volumen y red abren superficies existentes. Sin polling añadido al nuevo código. El nombre de app se elide dentro de un ancho acotado; sin ventana, el lado derecho reduce su ancho a los iconos.

Validación: `qmllint` en tres archivos, `git diff --check` y `status-regression` pasan. Shell activa recargó y capturas Wayland inspeccionadas (`/tmp/isla-final-crop.png`, `/tmp/isla-workspace-motion.png`, `/tmp/isla-empty-crop.png`, `/tmp/isla-app-changes.png`); foco real 1→2→3→4→5 y 1→5→2→4→1 confirmado con `hyprctl`, vacío 6 y vuelta a 4. Cambios de aplicación observados sin salto de ancho ni desborde. Movimiento del cursor al rail produjo cambio visible de hover; se restauró. Dispatch real del click probado por CLI, pero no se pudo inyectar un botón en la superficie Wayland: prueba manual del click queda pendiente. Logs nuevos sin errores QML de la barra; persistían warnings previos de Notifs, avatar ~/.face y portal. Se cerró la instancia duplicada creada para QA y quedó la shell original activa.

Corrección visual tras captura del usuario: la derecha tenía demasiado ancho vacío y los laterales usaban un rectángulo plano distinto al vidrio central. Rail ampliado moderadamente a slots de 38·s; estado derecho acotado a 225·s con batería y 205·s sin ella. Ambos reutilizan `PillMaterial` con `mode: "lateral"`, que conserva gradiente, sheen, borde y sombra pero no ejecuta la respiración continua de `mode: "rest"`. Captura Wayland `/tmp/isla-same-material-crop.png` inspeccionada; `qmllint`, `git diff --check` y logs de los componentes pasan, una sola shell activa.

Petición posterior de navegación estilo Apple, aclarada como control segmentado con selección deslizante. `TopWorkspaceRail` conserva el material exterior pero cambia el círculo interno por segmento de vidrio neutro (gradiente/borde), con acento pywal limitado a una línea inferior. Se eliminan los puntos de ocupado: vacío/ocupado se distinguen por contraste y urgente por acento. El énfasis tipográfico se calcula desde la posición real de la lente, no desde el destino del workspace; evita que dos números parezcan seleccionados durante un viaje o inversión rápida. `SmoothedAnimation` sigue siendo dueña exclusiva de x; reduced motion resuelve sin viaje. Capturas Wayland final `/tmp/isla-navigation-final-crop.png` y rápida `/tmp/isla-nav-motion.png` inspeccionadas, `qmllint` y `git diff --check` pasan, logs sin errores nuevos del rail. Workspace 4 restaurado. Sigue pendiente clic físico por falta de inyección de botón Wayland; esta revisión no alteró esa ruta.

