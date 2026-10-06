# Shell: componentes y configuración

## Responsabilidades actuales

| Capa | Fuente | Responsabilidad |
| --- | --- | --- |
| Contrato de ajustes | `bar/Singletons/Settings.js` | Versión, valores por defecto, tipos, límites, validación y combinación de parches. JavaScript puro, sin servicios ni E/S. |
| Adaptador de ajustes | `bar/Singletons/Config.qml` | Archivo JSON, vigilancia, estado de edición, guardado e IPC. |
| Compatibilidad | `bar/Singletons/Flags.qml` | Propiedades de sólo lectura enlazadas a Config para consumidores existentes. No almacena otra copia ni corrige valores. |
| Diseño | `Theme.qml`, `Motion.qml` | Tokens derivados de los ajustes y de la paleta. |
| Servicios | `Players.qml`, `Cava.qml`, etc. | Datos y operaciones de los sistemas externos. |
| Presentación | `IslandMediaCover`, `IslandMediaMetadata`, `IslandMediaSummary`, `IslandMediaVisualizer` | Datos por propiedades; acciones por señales. No seleccionan reproductor ni consultan MPRIS/CAVA. |
| Composición | `Pill.qml`, `FluidMediaCompanion.qml`, surfaces | Conectan servicios con componentes; controlan apertura, layout y transiciones. |

La extracción de `IslandMediaSummary` unifica cabeceras de launcher, wallpapers
 y overview. Conserva sus medidas y fuentes mediante propiedades explícitas.
El visualizador recibe `hasMedia`, `isPlaying`, `hasFrame`, `values`; el dueño
sigue gestionando el consumidor CAVA y el clic. Los componentes conservan Theme
como dependencia del sistema visual del proyecto: todavía no son una librería
independiente de Quickshell.

## Contrato para una app de ajustes

Archivo: `$ISLA_CONFIG`, o `$XDG_CONFIG_HOME/isla/shell.json` con fallback a
`$HOME/.config/isla/shell.json`. `bar/shell.json.example` muestra el formato.

- `version: 1`; archivos anteriores sin versión siguen funcionando.
- Claves ausentes usan los valores por defecto del contrato.
- Tipos incorrectos, números no finitos, valores fuera de rango, rutas relativas
  y versiones desconocidas rechazan el documento completo. No hay coerción ni
  aplicación parcial. Las rutas aceptan `/...`, `~` y `~/...`.
- JSON inválido al iniciar usa defaults; después conserva el último estado válido.
- Claves desconocidas se preservan, pero no se aplican como ajustes de la shell.
- `get` distingue el documento original de los valores efectivos (con defaults
  y rutas resueltas). Los defaults de rutas respetan XDG.
- `Flags` es de sólo lectura. Cambiar ajustes con `Config.update`, no asignando
  `Flags.fontScale` ni modificando un objeto anidado directamente.
- `appearance.fontMediaFamily` configura la familia multimedia antes fija en Inter.
- `profile.displayName` acepta vacío para usar el nombre de sesión;
  `paths.userAvatar` apunta a la foto (default `~/.face`). Estos ajustes sólo
  cambian presentación: no alteran el usuario PAM. El lockscreen independiente
  lee ajustes persistidos; una previsualización del proceso de barra no se comparte.

### IPC disponible

Con la shell en ejecución:

```sh
quickshell -p "$PWD/bar" ipc call settings schema
quickshell -p "$PWD/bar" ipc call settings catalog
quickshell -p "$PWD/bar" ipc call settings get
quickshell -p "$PWD/bar" ipc call settings validate '{"appearance":{"fontScale":1.1}}'
quickshell -p "$PWD/bar" ipc call settings update '{"appearance":{"fontScale":1.1}}'
quickshell -p "$PWD/bar" ipc call settings discard
quickshell -p "$PWD/bar" ipc call settings save
quickshell -p "$PWD/bar" ipc call settings reload
```

`schema` entrega `{version, sections}`: cada campo tiene tipo/default y, cuando
corresponde, mínimo/máximo o indicador de ruta. Es un catálogo propio, no una
implementación de JSON Schema. Una UI puede generar controles y validar con
`validate`, que evalúa un documento completo sin alterar el estado.

`update` combina un parche con el documento de trabajo y valida el resultado.
Retorna `{ok, errors, effective}`. Es una previsualización de sesión; `discard`
restaura lo leído del disco. Un cambio válido externo o `reload` reemplaza esa
previsualización. Al eliminar el archivo se restauran los defaults.

`save` retorna si la petición fue aceptada, **no una confirmación de escritura**.
La app observa `get.saving`, `get.error` y `get.dirty` hasta terminar. Se crea el
directorio si falta y se usa FileView con escritura atómica asíncrona; fallo de
escritura conserva el archivo anterior y la edición en memoria. Un error de
lectura/validación impide guardar sobre el archivo hasta corregirlo y recargar.

Antes de guardar se relee el archivo: si cambió desde la última lectura, se
rechaza el guardado. No es un bloqueo entre procesos: una escritura externa en
el intervalo entre esa comprobación y el rename aún puede competir. La primera
app debe usar este servicio como escritor único; ediciones manuales concurrentes
requieren recargar antes de guardar. No hay gestión de perfiles, autenticación
remota ni API de red.

La vigilancia requiere conectar `onFileChanged` con `reload()`. Referencia de
[FileView de Quickshell](https://quickshell.org/docs/v0.3.1/types/Quickshell.Io/FileView/).

## Añadir un ajuste

1. Declarar tipo/default/límites en `Settings.js` y añadir casos de validación.
2. Exponer un binding de lectura si lo necesita una API existente (Flags/Theme),
   o consumir Config desde la capa de composición.
3. Pasar el valor al componente por una propiedad semántica, sin leer archivos
   ni servicios dentro del componente visual.
4. Actualizar el ejemplo, documentación y prueba del consumidor real.

## Extensiones pendientes

- Exponer dimensiones como preferencias requiere validar límites y monitores.
- Una app de ajustes puede consumir el contrato existente: consultar,
  previsualizar, cancelar y guardar. No hay una app de ajustes incluida todavía.
- Construir la interfaz de ajustes sobre Settings/Config y su catálogo;
  la separación de las catorce surfaces, la cabecera y la política de input está completada.

## Segunda fase: sesión multimedia y geometría

- `components/MediaSession.qml` es una instancia por vista, sin Players, Cava ni
  Theme. Recibe `player` compatible con MPRIS, `trackKey` y `active`. Expone
  metadatos, capacidades, progreso/tiempos y acciones verificadas. Su reloj se
  detiene cuando la vista está inactiva; cancelar/cambiar canción/reproductor
  descarta el arrastre para no buscar sobre otro contenido.
- MediaSurface conserva composición, selección de fuente y registro CAVA, y
  consume la sesión. `albumDistinct` sigue expuesto al host para su altura.
- `Singletons/IslandGeometry.qml` contiene tamaños exteriores sin escalar y
  altura de reposo, compartidos por Pill, shell y FluidMediaCompanion. Cada
  consumidor aplica su escala una vez. No se modificaron resortes ni umbrales.
- Esta centralización de geometría ya está completada para el catálogo actual;
  exponerla como preferencias requiere validar límites y monitores. La sesión
  multimedia y su presentación MediaView también están separadas. No crear
  otra sesión global duplicando Players.

## Tercera fase: navegación y ventanas por monitor

- `components/SurfaceRouter.qml` posee openMon/openSurface, peek, espera de
  absorción de media y cierre en dos fases del launcher. Recibe monitor enfocado,
  movimiento reducido y duraciones. No importa servicios: emite
  `authCloseRequested` y el adaptador cancela la autenticación real.
- `toggleSurface` inicia/cancela navegación; `finishMediaDock` acepta sólo el
  monitor pendiente; `present` sustituye navegación pendiente (autenticación);
  `close` y `peek` completan el contrato. No debe haber copias de este estado
  dentro de ventanas. Sin monitor válido, toggle no inicia una apertura.
- `windows/IslandOverlay.qml` recibe modelData y SurfaceRouter explícitamente.
  Posee máscaras, foco/teclado, fullscreen y composición Pill/companion de ese
  monitor. Sigue dependiendo de servicios de escritorio: es un adaptador Wayland,
  no un componente visual portátil. No altera la física ni las duraciones.
- `windows/IslandReserve.qml` reserva espacio y mantiene máscara vacía.
- `shell.qml` instancia router, ShellRuntime y ventanas y expone IPC.
  ShellRuntime conecta Auth/WinMap/Notifs, inicia singletons y refresca
  Hyprland mediante allowlist. La interfaz de keybinds no cambió.

La coreografía de notificaciones también está separada, como se describe abajo.

## Cuarta fase: coreografía de notificaciones

`components/NotificationChoreography.qml` recibe `popup`, `surfaceOpen` y cuatro
intervalos. Posee fases, timers, notificación retenida y suspensión/revelación de
surface. Emite `advanceRequested`; no importa Notifs ni modifica la cola.
Pill conecta el servicio, aporta tiempos Motion y conserva geometría, material y
contenido. Sus propiedades de estado son de lectura. IslandOverlay configura
`notificationsEnabled` según el monitor enfocado, sin escribir activeNotif ni
permitir que una pill inactiva avance la cola al terminar su retirada.

Una surface abierta durante la secuencia queda suspendida hasta la restauración.
PillGeometry/PillMorphMotion reciben los tokens de Motion; PillMaterial renderiza
el material. La política de cola permanece en el servicio Notifs.

## Gotas reutilizables a ambos lados

`components/FluidCompanion.qml` contiene el único motor de nacimiento, expansión
 y absorción, bridge, material y host de surface. `leftSide` refleja sólo geometría;
texto y controles conservan orientación. Acepta surfaceName/surfaceSize y un
Component opcional para contenido compacto, sin dependencias de Players/Cava.
`FluidMediaCompanion.qml` es su adaptador musical. IslandOverlay instancia otra
gota transitoria con session a la izquierda; Pill permanece en reposo, media a la
 derecha. El material admite extensión izquierda y derecha independientes.

El overlay enruta teclado/clic exterior hacia la surface de sesión cargada en la
 gota. Al cerrar, pierde interacción y termina la absorción; no persiste un botón
 compacto de sesión. Si la pill se mueve durante el retorno, el destino sigue su
geometría conservando velocidades. El atajo Win+M existente no cambia.

## Módulos opcionales de la barra

La pill principal es obligatoria: el contrato no ofrece un interruptor para ella.
`modules` en Settings.js expone booleanos con default `true`:

| Ajuste | Componente |
| --- | --- |
| `workspaceRail` | Navegación izquierda |
| `systemStatus` | Contenedor derecho completo |
| `apps` | Aplicaciones del workspace |
| `audio` | Acceso al mezclador |
| `network` | Acceso a conectividad |
| `battery` | Batería, si el equipo dispone de ella |
| `animateChanges` | Entrada y retirada de módulos |

Los defaults conservan la composición existente. La futura app usa el mismo
`settings schema/get/update/discard/save`; desactivar un acceso lateral no
inhabilita su surface en la pill ni los atajos.

```sh
quickshell -p "$PWD/bar" ipc call settings update '{"modules":{"workspaceRail":false,"apps":false}}'
quickshell -p "$PWD/bar" ipc call settings discard
```

`TopBarModules` compone los laterales por monitor. `OptionalModule` retiene su
contenido durante una retirada corta de opacidad/traslado, libera input al
comenzar y descarga el Loader al terminar. Una inversión parte de la exposición
actual. Ocultación temporal por surface/fullscreen/espacio insuficiente conserva
el módulo habilitado. `animateChanges: false` y reduceMotion resuelven la
transición inmediatamente, incluso si está en curso. Las regiones Wayland sólo
incluyen módulos interactivos. Los módulos habilitados conservan su posición y
la geometría principal no depende de ellos.

`TopSystemStatus` es el adaptador de Hyprland/DesktopEntries/Pipewire/UPower/Nmcli.
`TopAppStrip`, `TopAudioStatus`, `TopNetworkStatus` y `TopBatteryStatus` reciben
datos por propiedades; emiten acciones que la composición enruta. La lista de
apps conserva identidad, intro de app única, hover y overflow. El contenedor
recalcula el ancho según controles realmente presentes y se oculta cuando no
hay contenido o no cabe. Desactivar el contenedor descarga sus indicadores;
desactivar apps descarga su lista y desactivar audio libera su tracker local.

`ShellRuntime` posee integración de servicios y efectos externos del router.
El router sigue siendo independiente y `shell.qml` conserva ventanas e IPC.
Todavía existen adaptadores de escritorio en surfaces; modularidad conserva
los servicios detrás de entradas y acciones explícitas.

## Adaptación de estado de la pill

`DesktopStatus` es un singleton: observa Pipewire/Brightness/UPower y Caps Lock
una sola vez por proceso, con los intervalos originales (teclado1s,
rebind500ms, recordatorio crítico60s). Comparte Caps Lock y emite eventos
semánticos de volumen, micrófono, brillo y batería. Ajustar volumen sigue
validando dispositivo/ready y acotando el rango0–1.

`IslandStatusAdapter` es una instancia por pill; conserva debounce16ms,
selección de fallback y escala local. Recibe eventos mediante Connections y
emite señales para los chips/OsdOverlay. `observeServices: false` desconecta
la instancia; la fixture de distribución deshabilita observación externa sólo
en su propio proceso e inyecta eventos, sin modificar dispositivos reales.

La extracción mantiene presentación por monitor y evita duplicar sondeos y
trackers en cada pill. No es una medición de FPS; requiere QA físico multimonitor.

## Geometría de la pill

`PillGeometry` calcula dimensiones y radios objetivo sin servicios ni acceso a
archivos. Recibe catálogo de tamaños, escala, ancho de reposo, tokens de fuentes
y espaciado, fase de notificación y métricas semánticas del contenido. No recibe
el objeto de surface ni selecciona reproductores. Conserva prioridades de
notificación/auth/launcher, tamaño inicial sin contenido cargado, calculadora,
límite de resultados, retorno y altura de álbum.

Pill conserva sus propiedades públicas enlazadas a ese cálculo; PillMorphMotion
posee ancho, alto/radio animados, límites exteriores y progreso del contenido.
No se duplican resortes ni se anima dos veces un destino. IslandGeometry sigue
siendo el catálogo central y Settings/Config sigue definiendo los ajustes; la
app puede usar estas entradas para previsualizaciones aisladas. Exponer nuevas
preferencias requiere declararlas y validarlas en Settings, como el resto.

## Workspaces: datos y presentación separados

`WorkspaceModel` adapta los modelos nativos de Hyprland por `screenName`:
`activeId`, `count` y `occupied` son salidas reactivas; `activate(id)` valida
el rango y realiza la misma acción nativa existente. Las propiedades `monitors`
y `workspaces` admiten datos sintéticos para pruebas sin cambiar escritorios.

`TopWorkspaceRail` recibe `activeId`, `count`, `occupied`, escala y ancho
disponible. No importa Hyprland ni ejecuta comandos. Emite `workspaceRequested`
y `requestWorkspaces`; TopBarModules conecta el modelo y el router. Motor de
lente, hover, geometría, material y reduced motion permanecen en el rail.
El modelo vive dentro del Loader opcional: desactivar el rail descarga ambos.

`WorkspacesSurface` compone ese mismo modelo con `WorkspacesView`. La vista
mantiene diez tarjetas, recibe `activeId`/`workspaceData` y emite
`workspaceRequested(id)`. El mapa incluye `windows`, además de ocupación y
urgencia. `minimumCount` del adaptador es 5 para el rail y 10 para el panel,
por lo que permite seleccionar tarjetas vacías sin ampliar la cuadrícula.
El panel sigue disponible aunque se desactive el rail.

La futura app utiliza `modules.workspaceRail` para presencia y el contrato
Settings/Config para previsualizar y persistir; una previsualización aislada del
rail puede inyectar estos datos sin una sesión Hyprland.

## Coreografía del material

`MaterialChoreography` posee barrido, pulso y epoch; recibe movimiento reducido,
duraciones y curva desde la composición. `awaken()` conserva reinicio de ambas
secuencias y el reset al activar reduceMotion. Pill expone esos valores como
lecturas y conserva `awakenMaterial()`. Abrir o sustituir una surface dispara
ese gesto consultando la entrada `surface` directamente; hover no lo dispara.
Esto evita depender del orden de propagación de la geometría recién extraída.

La app de ajustes mantiene un escritor y contrato únicos (Settings/Config).
Los componentes reciben valores, no escriben preferencias ni consultan archivos.
Los cambios aquí son separaciones de responsabilidad; añadir un control nuevo
requiere declarar su ajuste, límites, consumidor y comprobación en ese contrato.

## Controles rápidos: vista y composición

`UtilsSurface` conserva el contrato de PillSurface y sus márgenes; delega el
contenido a `QuickControlsAdapter`. Éste enlaza Brightness/KeepAwake, lee el
perfil con `powerprofilesctl get` y ejecuta las acciones.

`QuickControlsView` recibe escala, disponibilidad/porcentaje de brillo, estado
de escritura, inhibición/tiempo transcurrido y perfil/lista de perfiles. Emite
`requestPage`, `keepAwakeToggleRequested`, `brightnessSetPercent`,
`brightnessStepRequested` y `profileSelected`. No consulta servicios ni lanza
procesos. Conserva controles, semántica accesible, entrada escalonada y bloqueo
de la rueda. La selección de perfil sólo acepta las opciones declaradas y
conserva la selección optimista anterior; todavía no confirma el éxito del
comando.

La app puede reutilizar estas vistas con datos reales o de previsualización.
Los controles del sistema no se convierten en preferencias persistidas de Isla;
para ajustes de la shell se mantiene el contrato único Config/Settings.


## Separación completa de surfaces (2026-10-05)

Las catorce entradas de `surfaces/` conservan el contrato PillSurface, sus
propiedades públicas, navegación y geometría. La composición conecta servicios;
las vistas reciben datos por propiedades y devuelven intenciones por señales.
Theme/Flags siguen aportando los tokens compartidos de presentación.

| Surface | Presentación reutilizable | Integración y acciones |
| --- | --- | --- |
| Appearance | AppearanceView | AppearanceEditor, Config inyectado |
| Auth | AuthPromptView | AuthPrompt, backend inyectado |
| Calendar | CalendarView | CalendarData, reloj y clima |
| Clipboard | ClipboardView | ClipboardController y ClipboardPreviewAdapter |
| Connectivity | ConnectivityView, WifiCredentials | ConnectivityAdapter, Nmcli/BlueZ |
| Launcher | LauncherView | LauncherController, Apps/calculadora/ejecución |
| Media | MediaView | MediaSurface, MediaSession, Players/Cava |
| Mixer | MixerView | MixerAdapter, Pipewire |
| Notifs | NotifsView, NotifCardView | NotifsSurface, retención/acciones/iconos |
| Overview | OverviewView | OverviewSurface, WinMap/Hyprland |
| Session | SessionView | SessionSurface, acciones inyectadas |
| Utils | QuickControlsView | QuickControlsAdapter |
| Wallpaper | WallpaperView | WallpaperController, biblioteca/aplicación |
| Workspaces | WorkspacesView | WorkspaceModel |

Los procesos y previews de cliphist viven en el controlador, incluyendo caché
y limpieza al descargarlo. NotifCardView emite acciones y retención; la composición
resuelve iconos y ejecuta invoke/lock/unlock. NotifCard conserva la integración
compatible para los toasts. CalendarData permite `observe: false` para probar
el parser sin red. AppearanceEditor conserva borrador local y sólo actualiza
Config al guardar; la salida espera confirmación de persistencia.

MediaSurface conserva registro/liberación de Cava y MediaSession cancela seek
al cambiar de fuente. OverviewView recibe mapas y objetos de captura; emitir
selección no despacha Hyprland desde la vista. SessionView mantiene confirmación
y teclado sin ejecutar acciones del sistema. Las vistas pueden recibir objetos
nativos como datos opacos, pero sus métodos de acción pertenecen a composición.

PillContentAdapter separa reloj, workspace, metadatos multimedia e icono de
notificación de la presentación de Pill. Pill conserva montaje, geometría,
foco y coreografía; no se ha creado un segundo motor de ajustes.

`tests/surface-boundaries.cjs`, incluido en verify-config.sh, exige cobertura
de todas las surfaces y prohíbe servicios, procesos y acciones nativas en las
vistas. Las regresiones de datos/entrada completan esa comprobación estática.
La app puede reutilizar estas presentaciones; el catálogo está descrito en la
siguiente fase. La interfaz de edición es desarrollo nuevo, no surfaces pendientes.


## Composición de overlay y pill (2026-10-05)

`OverlayInputPolicy` recibe monitor/foco, workspaces, surface/cierre del launcher
 y dimensiones actuales/destino de pill y companions. Calcula fullscreen,
modalidad, foco on-demand/exclusivo, Escape, grab de Auth, máscara y límites de
backdrop. No consulta Hyprland ni cierra el router. IslandOverlay conecta esos
resultados con WlrLayershell/Region y las acciones del router; conserva montaje
por monitor, TopBarModules y companions. Los objetos nativos y su ciclo de vida
permanecen en la ventana, no dentro de la política reutilizable.

`PillHeaderView` reúne reloj/indicadores de reposo, cabecera multimedia y divisor
del launcher. Recibe escala, fecha, Caps Lock, metadatos/progreso y estado de
exposición. Emite requestCalendar y expone métodos visuales de feedback y flash,
además de restContentWidth/workspaceAnimating. No consulta servicios ni ejecuta
acciones del escritorio. La composición mantiene PillContentAdapter y
IslandStatusAdapter y enlaza sus datos/señales con esta vista.

`PillMorphMotion` recibe destinos y tokens, posee dimensiones/radio animados,
closeness, último tamaño de surface y exposición del contenido. Conserva
SmoothedAnimation y su inversión; no anima de nuevo el ancho cuando el chip de
workspace ya lo está haciendo. La respiración de notificación conserva ciclo
1400ms por tramo y salidas de radio/glow. Movimiento reducido desactiva morph
 y respiración. Pill proyecta estos resultados con las mismas propiedades
públicas; PillGeometry sigue siendo el único cálculo de destinos.

Esta fase conserva routing de teclado y recursos nativos dentro de composición;
separación de responsabilidad no implica una clase por binding o un segundo
motor de animaciones. Las vistas/motores nuevos y la política están incluidos
en el gate de límites de servicios.


## Catálogo para la app de ajustes

`Settings.schema(context)` mantiene tipo/default/límites y añade label,
description, control y availability para los 30 campos actuales. Los booleanos
exponen opciones false/true; los números conservan los límites de validación
existentes; las rutas describen las formas absolutas y home que ya se aceptan.
No se añadieron preferencias, rangos arbitrarios ni otro validador.

`Settings.catalog(context)`, `Config.catalog` e IPC `settings catalog` entregan:

- sections y sectionOrder: los mismos campos y su agrupación de edición.
- requiredModules: pill obligatoria, sin ajuste para desactivarla.
- optionalModules: rail, contenedor de estado y sus cuatro hijos. Los hijos
  señalan parentModule; el contenedor declara dependencyMode=any y visibleWhen,
  porque basta un hijo habilitado y espacio disponible.
- surfaces: las 14 entradas, con dependencias obligatorias y opcionales.
- capabilities: servicios/recursos, condiciones, fallback y consumidor existente.

availabilityIsLive=false: este inventario describe requisitos y comportamiento;
no es un sondeo de hardware, ejecutables o red, ni debe usarse como certificado
 de disponibilidad actual. Las capacidades external-unprobed/path-configured-unprobed
no comprueban instalaciones o existencia de rutas. No se añadieron procesos de
sondeo para servir metadatos.

pillBlur y showGlyphs se marcan inactive porque no tienen consumidor actual.
clockSeconds se marca partial: actualiza el dato por segundo, pero la cabecera
actual no pinta segundos. time12h afecta calendario/bloqueo, mientras el reloj
compacto conserva 12 horas. La app debe respetar estos alcances y no presentar
un ajuste inactivo como una función implementada.

Consultar get aporta valores efectivos y estado de edición; catalog/schema
aportan metadatos. Se mantiene update para preview de sesión, discard para
cancelar y save para persistir. El próximo desarrollo es la interfaz de la app;
los tres puntos de esta fase de preparación están completos.
