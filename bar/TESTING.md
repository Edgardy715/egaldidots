# Isla manual smoke checklist

Run `quickshell -p bar`, then confirm:

- The pill appears on every active monitor and does not block desktop clicks while idle.
- `qs -c bar ipc call island launcher ""`, `calendar`, `connectivity`, `overview`,
  `notifs`, `mixer`, `media`, `wallpaper`, `clipboard`, `utils`, and `session` open
  and close correctly.
- Fullscreen windows keep input; the overview accepts keyboard navigation; a new
  notification does not lose the current surface.
- A wallpaper change refreshes the palette; audio and brightness changes show their OSD.
- The media droplet stays to the right of the clock while a track is playing or
  paused. Playing widens it just enough for CAVA; hover reveals metadata;
  clicking the droplet opens the media card from that same position. When no
  valid player remains, the droplet returns into the time pill. Opening calendar,
  wallpaper, launcher and a notification moves the circular droplet to the right
  edge without resizing its height. Check the same sequence with reduced motion.
- With no `~/.config/isla/shell.json`, startup uses defaults. With malformed JSON,
  startup still succeeds and logs a configuration warning.

Copy `shell.json.example` to `~/.config/isla/shell.json` to customize appearance
and paths. Paths can start with `~/`; Isla expands that prefix to your home.
`ISLA_CONFIG=/path/to/shell.json` selects a temporary configuration file for
development.

`fontScale`, `spacingScale`, `radiusScale` and `motionScale` accept values in
the ranges 0.75–1.75, 0.75–1.50, 0.75–1.50 and 0.25–2.00 respectively.

Run `sh bar/tests/verify-config.sh` from the repository root for the static
configuration checks.

## Regresión del movimiento de la pill

```sh
QT_QPA_PLATFORM=offscreen quickshell -p bar/motion-regression.qml
```

Debe imprimir `PASS: interrupted morph, content swap, reduced motion, unload`.
Comprueba apertura interrumpida, reapertura, intercambio real de surfaces,
resolución directa con movimiento reducido y descarga del contenido al cerrar.
La fixture importa la Pill real y puede avisar que el servidor de notificaciones
ya está registrado por la shell. No se importa desde la configuración normal.

Verificación visual complementaria: alternar calendario/fondos/volumen antes de
terminar el morph; cerrar; abrir launcher, escribir, Escape y reabrir a los 50 ms;
continuar escribiendo sin clic. Comprobar retorno de la gota y notificación sobre
una surface abierta seguida de restauración.

### CAVA al reaparecer la gota

`QT_QPA_PLATFORM=offscreen quickshell -p bar/media-motion-regression.qml`
comprueba ancho de nacimiento/renacimiento según reproducción y que las barras
nunca invadan la carátula durante el cambio de ancho. Ejecutar con reproducción
activa para cubrir el defecto original; la salida indica `playing: true`.
Abrir/cerrar launcher con música sonando debe devolver una gota de 76 px a escala
1, con CAVA a la derecha, nunca sobre la carátula.

### Galería de wallpapers

`QT_QPA_PLATFORM=offscreen quickshell -p bar/wallpaper-regression.qml`
usa la biblioteca local (mínimo dos imágenes) sin aplicar fondos. Comprueba
navegación rápida, preview dentro de su área, PreserveAspectFit y desaparición
de imagen anterior/miniatura para que no queden restos en los márgenes.

QA visual: abrir con música, comprobar media en cabecera y ausencia de satélite;
seleccionar archivos con distintas proporciones, navegar con flechas/números,
cerrar con Escape y comprobar expulsión de la gota después del morph.

### Reloj/workspace y posición multimedia

`QT_QPA_PLATFORM=offscreen quickshell -p bar/status-regression.qml`
comprueba que mostrar los workspaces 2 y 10 y volver al reloj conserva el ancho.
Con reproducción activa verifica que MPRIS notifica la posición periódicamente.

`ISLA_CONFIG=/tmp/isla-motion-test.json QT_QPA_PLATFORM=offscreen quickshell -p bar/top-workspace-motion-regression.qml`
comprueba viaje, cambio de destino, reposo, movimiento reducido y ocultación de la
lente del rail. Usa una ruta de configuración temporal, no los ajustes personales.

### Overview compacto (Win + Tab)

`QT_QPA_PLATFORM=offscreen quickshell -p bar/overview-regression.qml`
comprueba selección por número/flechas, grupos de cuatro y tamaño de previews.
No cambia el workspace real. QA visual: Win+Tab, flechas, controles de grupo,
Escape; confirmar por separado clic/Enter si se quiere cambiar de escritorio.

### Clasificación de fuente multimedia

`node bar/tests/media-source.cjs` verifica servicios musicales, navegador general,
reproductores nativos y coincidencia exacta de hosts. Para QA visual comprobar
icono original/fallback, portada cuadrada musical y preview panorámica general.
Un navegador que no entregue identidad/URL específica debe conservar fallback.

### Configuración y componentes reutilizables

```sh
node bar/tests/settings.cjs
python bar/tests/settings-integration.py
```

La integración ejecuta un host QML separado con `ISLA_CONFIG` temporal; cubre
IPC, guardado atómico, creación del directorio, cambios externos, JSON inválido,
cancelación, conservación de claves desconocidas y borrado del archivo. No
modifica ajustes personales. No ejecutar dos copias del mismo host a la vez.

Para bindings de los consumidores reales:

```sh
settings_test_dir=$(mktemp -d)
ISLA_CONFIG="$settings_test_dir/shell.json" QT_QPA_PLATFORM=offscreen quickshell -p bar/config-regression.qml
```

Debe imprimir `PASS: config reactive update, rejection, discard and atomic async save`.
Los tests de movimiento cambian preferencias mediante `Config.update`; Flags
es de sólo lectura. Véase `docs/SHELL_ARCHITECTURE.md` para el contrato IPC y
límites de concurrencia. La extracción visual debe revisarse en launcher,
wallpaper y overview con una canción activa, además de pasar los tests offscreen.

### Sesión multimedia independiente

`QT_QPA_PLATFORM=offscreen quickshell -p bar/media-session-regression.qml`
usa un reproductor falso: no controla el audio real. Comprueba capacidades,
seek acotado, cambios de canción/reproductor durante arrastre, repetición y
activación/parada del reloj. Debe imprimir `PASS: media session capabilities,
seek, track/player interruption, repeat and clock lifecycle` sin TypeError.

### Navegación independiente de ventanas

`QT_QPA_PLATFORM=offscreen quickshell -p bar/surface-router-regression.qml`
comprueba selección de monitor, cancelación de dock, prioridad de autenticación,
cierre de launcher en dos fases, reapertura/retarget y movimiento reducido.
No inicia autenticación ni modifica escritorios. QA real complementaria: abrir
launcher mediante el IPC habitual, comprobar media integrado y cerrar con Escape;
las ventanas Wayland y sus máscaras se comprueban en la shell real.

### Coreografía de notificaciones

`QT_QPA_PLATFORM=offscreen quickshell -p bar/notification-regression.qml`
usa objetos falsos y una cola simulada. Comprueba todas las fases, dos popups,
expiración durante entrada, cierre de surface y apertura de surface durante la
notificación. No publica notificaciones reales ni modifica el historial.

### Continuidad de absorción

`QT_QPA_PLATFORM=offscreen quickshell -p bar/absorption-regression.qml`
integra frames a 30/60/144/240Hz simulados y cuatro tamaños de partida. Comprueba
captura con velocidad residual, cobertura antes de ocultar y retirada completa
del cap. Complementar con observación real de apertura/cierre del launcher:
la prueba no mide FPS ni certifica la sensación perceptual.

### Sesión y energía

`QT_QPA_PLATFORM=offscreen quickshell -p bar/session-regression.qml` inyecta
acciones falsas y comprueba confirmación, cancelación, repetición, reapertura y
teclado. No ejecuta comandos de energía. QA visual real: abrir sesión, tecla4
muestra confirmación de apagado, Escape cancela y otro Escape cierra; no pulsar
confirmar con el servicio real durante pruebas.

### Gota transitoria de sesión

`QT_QPA_PLATFORM=offscreen quickshell -p bar/session-companion-regression.qml`
comprueba geometría izquierda, tamaño/revelación, interrupción, absorción con
pill móvil y movimiento reducido. Ejecutar también media-motion y absorption
para verificar el mismo motor a la derecha. QA real: comando de Win+M
`qs -c bar ipc call island session ""`, Escape, repetición; no ejecutar acciones
reales de energía. Comprobar que media sigue a la derecha y la sesión desaparece.

### Interacciones de controles

`bar/interaction-regression.qml` verifica entrada real QtTest, cancelación fuera
 del hit target, teclado, disabled, toggle, límites del slider, cambio rápido de
 iconos y reduceMotion. `bar/interaction-surfaces-regression.qml` carga las 12
 surfaces sin Auth; no invoca acciones. Ejecutar offscreen y exigir PASS.
`bar/interaction-preview.qml` y `bar/interaction-performance.qml` usan Wayland:
 secuencia visual con acciones falsas y stress finito de 96 controles. Detalles,
 métricas y límites en `docs/INTERACTION_SYSTEM.md`. No están en la shell normal.


### Iconos vectoriales (referencia Animate UI)

`QT_QPA_PLATFORM=wayland timeout 8s quickshell -p bar/animated-icons-preview.qml`
verifica 16 familias nativas, movimiento de piezas, fin de secuencia, reduceMotion
y parada al ocultar. Guarda rest/motion en `/tmp/isla-icons-*.png` para inspección.
No invoca servicios ni acciones de energía. Qt >= 6.10 para ShapePath.trim.

### Solicitud de contraseña (sudo/Polkit)

`python bar/tests/auth-backend.py` prueba el backend en copia temporal con agente
fake y servidor inactivo. `QT_QPA_PLATFORM=wayland timeout 12s quickshell -p
bar/auth-prompt-regression.qml` usa AuthPrompt inyectado y credenciales simuladas:
foco, teclado, máscaras, reintento, éxito, prioridad, geometría e interrupciones.
Documentación y límites en `docs/AUTHENTICATION.md`. No abre Auth real ni pide
contraseñas. Config/paleta clara vía ISLA_CONFIG temporal; ISLA_AUTH_SHOTS cambia
el prefijo de capturas. Comprobar PASS, no sólo exit.

`python bar/tests/auth-bridge.py` prueba askpass y el wrapper del repositorio mediante socket temporal
y forwarding de opciones fish con sudo/qs falsos. No usa operaciones privilegiadas.

`python bar/tests/auth-transport.py` comprueba el socket real de una copia aislada
de Auth al iniciar y tras cuatro recargas del método de shell.qml. Requiere
Wayland; usa runtime temporal, Polkit falso y respuestas simuladas.


### Lockscreen

`python bar/tests/lockscreen-launcher.py` prueba instalación con backup y rutas
XDG temporales, limpieza de preview, entrada del repo y fallback con procesos
falsos. No bloquea la sesión. `QT_QPA_PLATFORM=offscreen quickshell -p
bar/lockscreen-regression.qml` comprueba guardas del campo, limpieza de secretos,
confirmación de energía y reduced motion. `QT_QPA_PLATFORM=wayland quickshell
-p bar/lockscreen-motion-regression.qml` verifica interrupción, rechazo, éxito
y retorno usando LockSurface sin adquirir WlSessionLock ni iniciar PAM.
ISLA_LOCK_CAPTURE_DIR permite guardar capturas de esa última fixture.

### Portapapeles y rendimiento de surfaces

`bash bar/tests/clipboard-regression.sh` usa cliphist y wl-copy simulados:
carga asíncrona, selección tras filtrar, miniaturas y vista previa seleccionada,
y copia exacta de texto multilínea e imagen PNG. No modifica el portapapeles real.
Incluye limpieza asíncrona con retraso simulado, error y doble llamada: la UI
continúa produciendo frames y conserva la lista si falla el borrado.
Requiere ImageMagick (`magick`), igual que la generación de vistas previas.
QA Wayland: Super+V, buscar, seleccionar una imagen con ↑/↓ y cerrar con Escape.
Las imágenes se generan en un directorio privado temporal que se elimina al
descargar la surface; el original se copia sin transformar.

Mediciones y alcance: `docs/SURFACE_PERFORMANCE_AUDIT.md`. Para análisis estático
usar `/usr/lib/qt6/bin/qmllint`: `/usr/bin/qmllint` en este equipo pertenece a Qt5.
Los avisos de tipos/imports y referencias sin calificar no equivalen a errores
de sintaxis; contrastarlos con las pruebas de carga y ejecución.

### Microinteracciones

`QT_QPA_PLATFORM=wayland ISLA_CONFIG=/ruta/temporal.json quickshell -p
bar/microinteraction-regression.qml` comprueba salida intermedia de contenido,
retarget sin salto, último texto tras cambios rápidos, respuesta al clic y
detención al ocultar, retirada/recolocación nativa de filas y movimiento reducido.
Usar configuración temporal con `{}`; también admite offscreen para lógica.
`ContentMotion`, `AnimatedLabel` y `MotionList` comparten los tokens Motion.
No usar AnimatedLabel en contadores/porcentajes que se actualizan continuamente.
Clipboard añade salida breve antes del estado vacío; `clear-reduced` valida
el vaciado inmediato sin desplazamiento. Capturas opcionales de su fixture con
ISLA_CLIPBOARD_CAPTURE_DIR y QT_QPA_PLATFORM=wayland, usando los comandos falsos.

## Coreografía y escritura compartidas

Con ISLA_CONFIG temporal, ejecutar `quickshell -p bar/surface-choreography-regression.qml`
y `quickshell -p bar/input-motion-regression.qml` en offscreen o Wayland. La primera
cubre carga asíncrona, destinos sucesivos, cancelación, stagger interrumpido y
activación de movimiento reducido durante el viaje. La segunda cubre escritura
y cierre del launcher. `ISLA_MOTION_CAPTURE_DIR` permite capturas de la primera
fixture en un directorio existente. Las nuevas fixtures desactivan hot reload
para evitar destruir QtTest durante una edición de imports.

La fixture interaction-surfaces-regression incluye ahora Apariencia: 13 superficies
no-auth. Qt6 qmllint está en `/usr/lib/qt6/bin/qmllint`; el ejecutable genérico
puede finalizar255 sin diagnóstico.

## Textboxes: edición y animación

`ISLA_CONFIG=/tmp/isla-typing.json QT_QPA_PLATFORM=offscreen quickshell -p bar/textbox-motion-regression.qml`
comprueba posición nativa del cursor, escritura, selección/borrado, inserción
larga Unicode, Inicio/Fin, hints, máscara, ocultación y reduceMotion. Repetir
en Wayland; ISLA_TEXTBOX_SHOTS apunta a un directorio existente para capturas
sintéticas. No usa ni modifica el portapapeles real.

`bar/lockscreen-typing-regression.qml` cubre inserciones/borrados por rango,
cambios rápidos, overflow, selección y modelo visual sin secretos. Usa
ISLA_LOCK_CAPTURE_DIR para capturas opcionales. Son previews: no bloquean
la sesión ni envían PAM. IME real necesita validación adicional.

### Apps del lateral derecho

`ISLA_CONFIG=/tmp/isla-status-test.json QT_QPA_PLATFORM=wayland quickshell -p bar/top-system-status-regression.qml`
comprueba iconos visibles, identidad/deduplicación, entrada/salida, retarget de
ancho, vacío, overflow acotado, reduceMotion y ocultación con ventanas falsas.
Crear config temporal con `{}`; también admite offscreen. ISLA_STATUS_SHOTS
apunta a un directorio existente para capturas intermedias/finales.
La misma fixture comprueba ahora nombre inicial1800ms, contracción automática,
hover real QtTest y retirada, y exclusión del nombre cuando hay varias apps.

### Módulos opcionales

`ISLA_CONFIG=/tmp/isla-modules-test.json QT_QPA_PLATFORM=wayland quickshell -p bar/optional-modules-regression.qml`
verifica configuración, entrada/salida e inversión, descarga de Loaders, liberación
inmediata de interacción, controles individuales y acción del mezclador, ancho
adaptable, ocultación temporal, ausencia de animación y reduceMotion durante
una salida. `ISLA_MODULE_SHOTS=/directorio/existente` exporta capturas comparables.
También funciona en offscreen para invariantes; QA visual requiere Wayland.
`node bar/tests/settings.cjs` cubre defaults y tipos del contrato `modules`.

### Adaptador de estado de la pill

`ISLA_CONFIG=/tmp/isla-status-adapter-check.json QT_QPA_PLATFORM=offscreen quickshell -p bar/island-status-adapter-regression.qml`
comprueba debounce hacia el último valor, señales volumen/mic/brillo, escala del
fallback y API Caps Lock. Deshabilita observación de servicios en la fixture;
no modifica volumen, brillo ni batería reales. Complementar con
`status-regression.qml` y `motion-regression.qml` al cambiar composición de Pill.

### Modelo de workspaces separado

`ISLA_CONFIG=/tmp/isla-workspace-model-check.json QT_QPA_PLATFORM=wayland quickshell -p bar/workspace-model-regression.qml`
inyecta dos monitores, valida activo/cantidad/ocupación/urgencia y fallback vacío,
y pulsa el rail con QtTest para comprobar su señal sin despachar Hyprland real.
`top-workspace-motion-regression.qml` conserva cobertura de seguimiento,
inversión, reposo, ocultación y reduceMotion del motor visual independiente.

### Geometría y estado compartido

`ISLA_CONFIG=/tmp/isla-geometry-check.json QT_QPA_PLATFORM=offscreen quickshell -p bar/pill-geometry-regression.qml`
comprueba dimensiones conocidas de reposo/auth/launcher/media/notificación,
carga pendiente, calculadora, límite de resultados, retorno y escala/fallback.
El componente no necesita servicios ni monitores.

`ISLA_CONFIG=/tmp/isla-fanout-check.json QT_QPA_PLATFORM=offscreen quickshell -p bar/desktop-status-fanout-regression.qml`
inyecta eventos en DesktopStatus con observación externa deshabilitada sólo
para la fixture. Comprueba dos adapters, debounce, fallback/escala local,
Caps Lock compartido y un tercer adapter desconectado. No escribe a dispositivos.
Las fixtures QtTest de opcionales/apps/modelo desactivan hot reload para evitar
la destrucción de QtTest mientras otro proceso modifica fuentes.

`ISLA_CONFIG=/tmp/isla-material-check.json QT_QPA_PLATFORM=offscreen quickshell -p bar/material-choreography-regression.qml`
verifica progreso/reinicio/fin del barrido y pulso, y reset/supresión con reduceMotion.
La regresión de morph prueba también que abrir una surface incrementa epoch,
que hover no lo hace y que el pulso real se detiene al reducir movimiento.

### Panel de workspaces separado

```sh
QT_QPA_PLATFORM=offscreen quickshell -p bar/workspaces-surface-regression.qml
```

Comprueba diez tarjetas, contador de ventanas y aislamiento por monitor,
workspace activo fuera de la cuadrícula y clic en el espacio vacío 10.
La vista emite navegación sin ejecutar un cambio de escritorio real.

### Controles rápidos sin servicios

```sh
ISLA_CONFIG=/tmp/isla-quick-controls-test.json QT_QPA_PLATFORM=offscreen quickshell -p bar/quick-controls-regression.qml
```

Datos simulados de brillo, permisos, Keep Awake y perfiles; clics/slider emiten
acciones capturadas por la prueba, sin modificar brillo, inhibición ni energía.
Confirma también navegación hacia Apariencia. Usar una ruta temporal exclusiva.


### Separación integral de las catorce surfaces

`bash bar/tests/verify-config.sh` incluye el gate `surface-boundaries.cjs`:
catálogo completo, vistas sin servicios/procesos/acciones nativas.

Con ISLA_CONFIG apuntando a una ruta temporal exclusiva y QT_QPA_PLATFORM=offscreen,
ejecutar `quickshell -p bar/<fixture>.qml` para:

- surface-data-contract-regression: MediaView, OverviewView y borrador/guardado
  asíncrono de AppearanceEditor con Config simulado.
- calendar-data-regression: calendario bisiesto, escala, parser WWO y errores,
  sin consultas de red (`observe: false`).
- mixer-surface-regression, connectivity-surface-regression y
  notifs-surface-regression: datos simulados y señales, sin acciones nativas.
- launcher-controller-regression: búsqueda diferida y calculadora.
- interaction-surfaces-regression: carga de las 14 surfaces; Auth recibe fakeAuth
  mediante propiedades iniciales del Loader, evitando registrar Polkit o sustituir
  el socket sudo de la shell real.

Complementar con auth-prompt-regression, session-regression, media-session-regression,
overview-regression, input-motion-regression, wallpaper-regression y
`bash bar/tests/clipboard-regression.sh` (cliphist/wl-copy simulados).
Exigir marcador PASS y ausencia de FAIL; el exit 0 de QtTest no basta.
La carga offscreen no sustituye QA visual Wayland ni valida hardware/PAM reales.


### Composición de pill y política de input

Con ISLA_CONFIG temporal exclusivo, ejecutar:

```sh
QT_QPA_PLATFORM=offscreen quickshell -p bar/pill-composition-regression.qml
QT_QPA_PLATFORM=offscreen quickshell -p bar/overlay-input-policy-regression.qml
```

La primera inyecta datos de cabecera, hace clic en el reloj, comprueba ancho de
workspace, reversión de morph, exposición y respiración/reduced motion.
La segunda usa monitores/dimensiones simulados para comprobar foco, fullscreen,
regiones de ambos companions, backdrop, Auth y liberación durante cierre.
Complementar con motion-regression, surface-choreography-regression,
notification-regression y optional-modules-regression. Exigir PASS y ausencia
 de FAIL. El gate verify-config también cubre PillHeaderView, PillMorphMotion
 y OverlayInputPolicy sin servicios o IO.


### Catálogo de configuración

verify-config.sh ejecuta settings.cjs: cobertura de todos los campos y surfaces
físicas, reglas/defaults sin cambios, referencias de dependencias y módulos.
`python bar/tests/settings-integration.py` comprueba schema/catalog por IPC con
configuración temporal, además de edición, rechazo, cancelación y persistencia.
`config-regression.qml` comprueba consumidores reactivos y guardado atómico.
El catálogo declara disponibilidad, no efectúa detección actual de capacidades.

## Edots

`ISLA_CONFIG=/tmp/edots-check.json QT_QPA_PLATFORM=offscreen quickshell -p bar/settings-regression.qml`
comprueba búsqueda global, validación, borradores ocultos, descarte y carga de
escenas interrumpidas. Ver `docs/EDOTS.md` para preview y QA Wayland.

`ISLA_CONFIG=/tmp/edots-motion.json QT_QPA_PLATFORM=offscreen quickshell -p bar/settings-motion-regression.qml`
comprueba continuidad de retarget, último destino y resolución reduced/hidden.


Edots integrada como gota (2026-10-07): `settings-companion-regression.qml`
verifica centrado, retorno/revelado, retención y reapertura; router y política
incluyen settings. Ejecutar con ISLA_CONFIG temporal como las demás fixtures.
`module-composer-regression.qml` cubre alternancia de padre/hijos y estados
nativos; `settings-controls-regression.qml` requiere Wayland y envía eventos de
Qt a combo, campos, botones, interruptor y slider. Comprueba selección con ratón,
flechas/Enter, Escape, Tab, fuente manual, límites del popup, ocultación y reduced
motion. Exigir PASS y ausencia de FAIL incluso con exit 0 de QtTest embebido.
La prueba de edición también comprueba geometría animada de todos los iconos y
resolución al ocultar o reducir movimiento. QA de captura 1000×700/760×560;
no equivale a medición de FPS o interacción física.

### Selector con layer-shell real

`ISLA_CONFIG=/tmp/isla-layer-picker.json quickshell -p bar/settings-layer-picker-regression.qml`
abre la surface real en el monitor actual. Target IPC `pickerLayerTest`: `open
userAvatar` o `open wallpaperDir`, `state` y `quit`. Mientras selector esté abierto
`picker=true, focus=true` (Popup.Item integrado); al cancelar/aceptar `picker=false, settings=true,
focus=true`. Selector permanece dentro del overlay con foco modal. `preview /ruta/imagen.png`
simula clic Qt en la galería y devuelve true cuando Image.Ready. Usar configuración temporal, no guardar preferencias personales.

### Material y estados de lectura de la pill

`ISLA_CONFIG=/tmp/isla-interface-test.json QT_QPA_PLATFORM=offscreen qs -p bar/pill-interface-regression.qml`
comprueba material compacto/expandido a dos escalas, preferencia opaca,
cabecera controlada por entered y límites, y estados del launcher sin resultados,
debounce, calculadora y cierre. Se puede ejecutar también con Wayland.
No sustituye la inspección nativa: ver docs/PILL_INTERFACE_AUDIT.md.

### Deriva del glow interior

`ISLA_CONFIG=/tmp/isla-glow-test.json qs -p bar/inner-glow-regression.qml`
comprueba movimiento acotado, pausa oculto, movimiento reducido y reanudación
sin reiniciar fase. Revisar en barra real: solo la luz interior se desplaza,
sin mover bordes o texto. No equivale a medición de FPS/GPU.

### Clima en calendario

`ISLA_CONFIG=/tmp/isla-calendar-test.json qs -p bar/calendar-data-regression.qml`
valida datos parciales/error/retención señalada, códigos y cierre interrumpido.
`ISLA_CONFIG=/tmp/isla-weather-view-test.json qs -p bar/weather-view-regression.qml`
valida layout, actualizar/carga, selección/métricas/Ahora, aviso visible sin
scroll, vacío y fuente grande/movimiento reducido, sin llamadas de red.
QA shell: calendario con ubicación/temperatura wttr.in; comprobar actualización,
pronóstico y aviso arriba si falla. Ubicación aproximada por IP.

### Unidad compacta centrada

`ISLA_CONFIG=/tmp/isla-compact-check.json QT_QPA_PLATFORM=offscreen quickshell -p bar/compact-island-regression.qml`
comprueba límites de los módulos dentro del cuerpo, separación del reloj,
overflow de 14 apps, ancho de 620 px, apertura de paneles más estrechos
y movimiento reducido. Exigir la línea `PASS: compact unit bounds`:
QtTest puede terminar con código 0 después de un fallo. Complementar con
`optional-modules-regression.qml` y `pill-composition-regression.qml`.
QA Wayland: abrir volumen/calendario y regresar; revisar que el cuerpo único
conserve los grupos juntos, sin reserva vacía ni controles sobre los paneles.
La fixture exige ancho natural exacto, retorno sin solapamiento y reloj solo
sin reservar espacio para módulos desactivados.


La fixture compacta también inyecta un reproductor mock, comprueba pausa,
reanudación, capacidad de control, CAVA, música en620px y cambio de composición.
No cambia la reproducción real. Verifica también que títulos cortos liberen ancho;
en anchos mínimos, portada sin fragmentos de título poco legibles.

`ISLA_CONFIG=/tmp/isla-layout-routing-check.json QT_QPA_PLATFORM=wayland quickshell -p bar/layout-routing-regression.qml`
comprueba el IslandOverlay real: media abierta al cambiar split↔compact,
dock de launcher/ajustes y cierre. Es una ventana temporal en la sesión Wayland.
Exigir PASS sin avisos Binding loop.

`module-composer-regression.qml` prueba selector, búsqueda, ventana pequeña y
discard; settings.cjs/settings-integration.py cubren enum/persistencia temporal.


### Transiciones animadas de ambas composiciones

Usar ISLA_CONFIG temporal y exigir PASS explícito (QtTest puede salir0 sin PASS).
`layout-motion-regression.qml` en Wayland incluye IslandReserve y prueba ambos
sentidos,11 surfaces sin acciones destructivas, media abierta, inversiones y
reduceMotion. `layout-interruptions-regression.qml` añade gota split simulada,
notificación concurrente con calendar/cambio de modo, pause, desaparición de
media y OSD; no cambia reproducción ni notificaciones reales.
`bar-layout-transition-regression.qml` comprueba gates exit/settle y retirada
de cabeceras launcher/auth. `centered-companion-regression.qml` verifica origen,
puente, destino, absorción centrados a ambos anchos y conserva velocidad al
reabrir. `notification-routing-regression.qml` exige que constructor/destructor
de NotifsSurface no sobrescriban el estado de ruta vigente.

La carga `quickshell -p bar` más IPC/log es obligatoria para validar también
Scope/reserva/ShellRuntime. qmllint puede pasar aun cuando un Behavior sobre
una propiedad readonly impide cargar la shell: probar arranque real.
QA nativa con grim registra tiempos start/end; es muestreo irregular, no todos
los frames ni FPS medido. Comparar reposo, media y Configuración, interrumpir
Notifs↔media y close/reopen, y restaurar Config tras la prueba.

Entrada y media del bloqueo (2026-10-09): `lockscreen-entrance-regression.qml`
comprueba espera de `secured`, exposición intermedia, tarjeta al reproducir,
pausa/reanudación durante salida, retirada antes del formulario, desaparición
con Loader retenido, retorno, ancho estrecho y movimiento reducido. Ejecutar
con `ISLA_CONFIG` temporal y `QT_QPA_PLATFORM=wayland` para QA nativa; opcional
`ISLA_LOCK_CAPTURE_DIR` y `ISLA_LOCK_WALLPAPER` para capturas. La fixture y
`QS_LOCK_PREVIEW=1 quickshell -p bar/lockscreen.qml` nunca adquieren el bloqueo
ni autentican. Complementar con motion/typing y tests/lockscreen-launcher.py.

Reloj en reposo: `clock-reel-regression.qml` con ISLA_CONFIG temporal comprueba
11:59→12:00, cambio rápido al minuto siguiente, anchura estable, horas/minutos
independientes, reducedMotion y actualizaciones ocultas sin replay. Wayland y
`ISLA_CLOCK_CAPTURE_DIR` permiten capturar muestras del desplazamiento vertical.
Complementar con status-regression y pill-interface-regression (calendario/foco).

Representaciones de workspaces: `workspace-styles-regression.qml` renderiza
numbers/dots/bars/capsules/pacman en rail separado e integrado; prueba opciones
SettingsPage, validación, discard y save/reload con ISLA_CONFIG temporal.
`ISLA_WORKSPACE_CAPTURE_DIR` permite capturar las cinco filas en Wayland.
Complementar con top-workspace-motion-regression, workspace-model-regression,
module-composer-regression y tests/settings.cjs. Nunca usar configuración personal
para save/reload de esta fixture.

Correcciones de auditoría (2026-10-10): desde la raíz del proyecto,
`sh bar/tests/verify-config.sh` incluye el parser matemático sin evaluación de
código. `launcher-input-safety-regression.qml` escribe en el campo real con
QtTest y exige que `Qt.quit()` sea texto sin efectos. `interaction-regression.qml`
comprueba acciones Accessible y controles deshabilitados; `overlay-input-policy-regression.qml`
comprueba la política modal. `python bar/tests/overlay-native-input.py` usa una
copia temporal y wtype en Wayland para abrir/cerrar las 14 superficies sin Auth,
y verifica la liberación del teclado. No activa acciones de sistema.

`python bar/tests/settings-integration.py` comprueba IPC, escritura atómica,
watcher y conflicto de borrador mediante QtTest y reemplazo externo real.
Usa offscreen por defecto; `QT_QPA_PLATFORM=wayland` permite entrada/render nativos.
`ISLA_DRAFT_CAPTURE_DIR` guarda el aviso sobre fondo opaco. Ejecutar sobre una
copia temporal de `bar/` mientras se edita el repositorio evita autorrecargas
que interrumpan la fixture. Comandos y resultados de servicios con HOME/XDG/PATH
temporales están en `docs/audit-2026-10-10/fixes/`; nunca sustituir sus comandos
falsos por acciones reales de red, energía o bloqueo para una prueba de regresión.

`python bar/tests/settings-surface-switch.py` ejecuta una copia temporal en
Wayland: Configuración↔13 destinos, selector de archivos/fuentes abierto,
borrador retenido, peticiones de perfil mientras el editor está oculto,
escritura y Ctrl+S en launcher, callback de foco tardío y retarget rápido.
Cubre split/compact y movimiento normal/reducido. `ISLA_SWITCH_CAPTURE_DIR`
permite capturas del contenido QML; el Popup separado del selector no forma
parte del subárbol capturado. No activa acciones de sistema ni guarda ajustes
personales. Complementar con overlay-native-input para Escape entregado por wtype.

`python bar/tests/settings-media-routing.py` usa una copia temporal con un
reproductor MPRIS simulado: Configuración conserva música, retorno antes de
calendar/media/session, interrupción de retorno, prioridad visual Auth sin PAM,
acceso musical desde calendario, pausa/remoción en split/compact y normal/reduced.
`ISLA_MEDIA_CAPTURE_DIR` guarda capturas Wayland de la composición.
`calendar-media-regression.qml` prueba además el pie fijo al desplazar clima,
metadatos largos y fontScale 1.75. Usar ISLA_CONFIG temporal.

`python bar/tests/settings-ux.py` usa copia temporal de bar en Wayland y verifica
las seis páginas a 1000×700 y 640×560, fontScale1/1.75, targets de navegación,
texto de Guardar dentro del botón, estado de guardado, foco/error inline visible,
búsqueda vacía, selector compacto y contraste con dos paletas de prueba. No toca
la configuración ni la paleta personal. `ISLA_SETTINGS_UX_CAPTURE_DIR` guarda
capturas QML asentadas; el selector se captura como contenido sobre transparencia.

`keyboard-icon-regression.qml` comprueba Session con flechas y controles con
Tab/Shift+Tab: gesto activo aun con binding explícito de hover, movimiento
reducido y cero acciones de energía. Ejecutar en Wayland con ISLA_CONFIG temporal
que contenga `{}`. Complementa `interaction-regression.qml` (puntero, presión,
foco, Accessible, interrupción y disabled).
