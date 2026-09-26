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
integra frames a 30/60/144Hz simulados y cuatro tamaños de partida. Comprueba
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
