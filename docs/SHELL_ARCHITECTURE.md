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
- Extraer controles multimedia adicionales sólo si una segunda presentación
  necesita reutilizarlos; la sesión y la geometría ya están separadas.

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
  multimedia también está separada; falta extraer controles/presentación si se
  necesita una segunda tarjeta. No crear otra sesión global duplicando Players.

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
- `shell.qml` instancia router y ventanas, conecta Auth/WinMap/Notifs, refresca
  Hyprland y expone el IPC existente. La interfaz de keybinds no cambió.

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
Las fórmulas de geometría y movimiento reducido siguen en Pill/Motion. No se ha
extraído la política de cola de Notifs ni el render del material.

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
