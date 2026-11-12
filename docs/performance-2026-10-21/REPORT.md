# Optimización de rendimiento de Isla / Eshell

2026-10-21. Se conserva la shell Quickshell, sus preferencias y su diseño. La
optimización usa señales nativas, menos invalidaciones y el pool QtConcurrent
existente. No se añadió Rust, un daemon general ni dependencias.

## Resultados comprobados

| Trabajo medido | Antes | Después | Alcance |
| --- | ---: | ---: | --- |
| Llamada de escaneo, 10.000 imágenes con caché válida, máximo | 851 ms | <1 ms | Retorno al hilo UI; el trabajo completo sigue tardando unos 850 ms |
| Mayor intervalo del heartbeat en ese escaneo | 855 ms | 30 ms | Temporizador QML, no presentación/FPS |
| Llamada de escaneo, 1.000 imágenes con caché válida, máximo | 85 ms | 1 ms | Mismo formato y comprobación de miniaturas |
| Reevaluaciones de título estático durante reproducción simulada, ~1 s | 34 | 0 | La posición y los tiempos siguen avanzando |
| Reducciones de bandas del visualizador oculto, ~1 s | 378 | 0 | El visualizador visible conserva sus cálculos |
| Actualizaciones del envelope CAVA en silencio, 600 ms | 38 | 0 | Fixture offscreen; ataque, descarga, reanudación y reset comprobados |
| Consultas de descubrimiento CAVA, ventana simulada de 6,5 s sin cambios | 21 | 3 | Después existe además una suscripción persistente, sólo con CAVA solicitado |
| CPU de descubrimiento CAVA sobre servidor real, 15 s | 1,067% | 0,067% | Suma helper + hijos; identidad sin resolver, sin capturar audio; 100% = un núcleo |
| Sondeo de rebind de audio | 2 callbacks/s | 0 | Recuento derivado del timer retirado; ahora sigue señales PipeWire |

En fullscreen simulado, la pill deja de avanzar el brillo invisible y la gota
libera su consumidor CAVA; ambos se reanudan al volver. La tolerancia de
visibilidad es la misma usada por sus efectos: opacidad >0,005. Se conservan el
fade y los resortes finitos.

Las cifras CPU son una pareja corta de muestras y tienen resolución de 10 ms
de tiempo CPU. No miden energía ni el coste completo del reproductor. El helper
de descubrimiento añade aproximadamente 1,4 MiB PSS por su `pactl subscribe`
mientras se usa, además de unos 0,15 MiB PSS observados en Python. No consume ese
proceso cuando ninguna vista pide CAVA. El primer intento reaccionaba a eventos
de los propios clientes pactl y aumentaba CPU: fue rechazado y corregido. El
filtro final sólo atiende cambios de clientes propietarios de streams, eventos
de sinks/streams/servidor y una reconciliación cada 30 s.

## Implementación

- `MediaSurface` entrega el QObject `MediaSession` estable. Duración y tiempos
  pasan a propiedades readonly; cada binding observa únicamente sus campos.
- `IslandOverlay` propaga ocultación efectiva y `IslandMediaVisualizer` evita
  reducir bandas bajo un padre invisible. El contenido visible mantiene su
  geometría, color, tipografía, curvas y respuesta musical.
- `DesktopStatus` sigue los dispositivos predeterminados y sus interfaces de
  audio mediante bindings y Connections. Mantiene el tracker y las señales OSD.
- `Cava` detiene su reloj al llegar al cero exacto que ya usaba el envelope.
  `cava_stream.py` multiplexa audio y eventos, agrupa ráfagas, reconcilia,
  reintenta tras fallo y cierra sus procesos al desconectar o terminar.
- `WallpaperScanner` enumera, ordena y valida metadatos en QtConcurrent. Hay un
  scan activo por instancia y una petición pendiente reemplazable; se descartan
  resultados obsoletos. No cambia señales, registros ni generación de miniaturas.
  La prueba cubre reentrada y destrucción incluso durante un worker activo.
- El monitor de Nmcli ya no sobrevive a SIGTERM de la shell. Un helper de diez
  líneas reutiliza la protección Linux por muerte del padre y hace exec del
  propio nmcli: no queda un supervisor Python. La prueba reprodujo el fallo y
  demostró que `aboutToQuit` no cubría esta ruta; preserva eventos y reinicio.

El módulo nativo se compiló con Qt 6.12 y se activó en la shell. La configuración
personal conservó su hash, `dirty=false`, sin grabación ni autenticación activa.
La sustitución y arranque tardaron 826 ms hasta `Configuration Loaded`; ese
tiempo incluye parar la instancia anterior y no representa primer frame usable.
Hay rollback del módulo anterior en
`~/.local/state/isla-performance/2026-10-21/Wpscan-before`.

## CPU, RAM y arranque globales

La shell original se muestreó 45 s: CPU 19,62% de un núcleo; RSS
584.056→588.052 KiB, PSS 482.729→486.725 KiB. Después hubo un reinicio del equipo;
una muestra posterior no es un A/B global controlado. No se atribuirá a estos
cambios una reducción de RAM causada por arrancar un proceso limpio.

La muestra posterior de 120 s dio CPU 19,42%, RSS 400.356→417.344 KiB y PSS
329.842→342.998 KiB. Se tomó después de activar Wpscan y antes del cambio final
de lifecycle de Nmcli. No prueba una mejora global de CPU ni una fuga: se conserva
la variación observada y falta una prueba de horas. Datos `live-before.json` y
`live-after.json`; son procesos y sesiones distintos.

El par de fixtures Wayland previo al reinicio dio carga 705→705 ms, estado usable
2.114→2.139 ms y PSS 312.254→314.995 KiB. La repetición tras el reinicio dio
705→478 ms, usable 2.164→1.861 ms y PSS 314.889→313.279 KiB. Son muestras únicas
con orden baseline→cambio y cachés calentándose: **no demuestran mejora de
arranque ni memoria**. Los cambios de contadores y estados sí se reprodujeron.

La carga de reposo visible conserva el brillo aprobado y la composición de la
shell. No se quitó movimiento visible para fabricar una cifra CPU menor. Falta
un perfil de presentación/GPU y una prueba prolongada de horas para concluir
sobre frame pacing físico o crecimiento de memoria.

## Auditoría de arquitectura y decisión sobre Rust

Se trazaron los flujos de arranque → ShellRuntime/SurfaceRouter → overlay por
monitor → módulos/gotas/hosts → surfaces → vistas. Se inventariaron procesos,
timers, FrameAnimation, loops y accesos a servicios en producción. Es una revisión
por caminos y puntos calientes, no una certificación de cada línea del repositorio.

| Área | Estado y decisión |
| --- | --- |
| Hyprland/workspaces/overview | Modelos nativos y eventos; WinMap sólo activo en overview, con agrupación. No se cambió compositor, plugins, binds ni workspace real. |
| MPRIS/media | Servicio nativo, sesiones visibles con reloj acotado. Se corrigió la propagación de identidad JS y trabajo oculto. |
| CAVA/PipeWire | Captura exacta por stream, envelope compartido y consumidores. Se redujeron procesos de descubrimiento y sondeo de rebind. |
| Wi-Fi/Bluetooth | Nmcli agrupa lecturas y destruye comandos finalizados; Bluetooth nativo por eventos. Perfiles Wi-Fi siguen consultándose serialmente al cargar o mutar conexiones. |
| Wallpapers/Matugen | Miniaturas nativas escaladas y cacheadas; escaneo ahora async. Matugen publica de forma transaccional sólo al aplicar un fondo; no se ejecutó contra el fondo personal. |
| Monitorización de sistema | PipeWire y UPower nativos; no hay otro daemon general de métricas que sustituir. Caps Lock conserva consulta cada segundo. |
| Notificaciones/clipboard/launcher | Cola y cachés existentes; controladores por surface, búsquedas agrupadas y jobs liberados. Se mantuvieron sus formatos y persistencia. |
| Grabación/auth/bloqueo | Captura GPU bajo demanda y reloj activo sólo cuando corresponde; auth/PAM sin cambios. No se grabó, bloqueó ni autenticó realmente. |
| Renderizado/movimiento | Resortes y rail paran al asentarse; ambiente y timeline ya tienen gates. Loaders liberan superficies al acabar la salida. Edots sigue precargado y retenido por monitor. |
| Dependencias/arranque/temas | Installer reconstruye el mismo módulo Qt; wrapper de GPU intacto. Matugen es el generador vigente, sin añadir otra ruta pywal. El resto de dotfiles no es un bucle de ejecución de la shell. |

Para wallpapers, Rust mantendría el coste de filesystem y decodificación y
añadiría FFI o IPC y otro sistema de build: QtConcurrent ya elimina el bloqueo
sin serialización entre procesos ni un daemon. La CPU total del scan no baja
necesariamente, y el resultado grande aún debe convertirse a QML en UI.

Para CAVA, el coste medido dominante era crear procesos `pactl`; las señales
resuelven ese coste manteniendo Python. Un rewrite tendría que conservar
selección exacta, errores, reconexión y cleanup, más su binario/dependencias. No
hay una medición que justifique sustituir el helper ni añadir threads/IPC. El
protocolo de bandas permanece ASCII y no cambia en frecuencia ni formato.

Esta decisión no demuestra que Rust no pueda aportar mejoras: no se construyó
ni comparó una implementación Rust. La medición CPU anterior usa descubrimiento
con identidad sin resolver; no mide captura activa, parsing de frames y todo el
pipeline de audio durante reproducción. El helper Python final ocupa unos
11,2 MiB PSS en esa prueba, más la suscripción. Reducir ese suelo de memoria y
medir el camino activo son candidatos razonables para un prototipo Rust acotado
con el mismo protocolo y pruebas. El ahorro posible permanece sin cuantificar.

QML bindings y servicios Qt nativos tampoco ganan una frontera Rust: seguirían
necesitando notificar al mismo árbol. Se descartó migración por lenguaje y se
mantuvieron cachés y servicios ya adecuados.

## Límites restantes

- Caps Lock: se conserva la exactitud/latencia del estado visible. No se
  identificó una fuente de eventos equivalente que justificase quitar su sondeo.
- Edots: cambiar precarga por primera apertura fría altera un compromiso visual
  previamente elegido; no hay prueba suficiente para aceptar esa regresión.
- Con 10.000 wallpapers queda un gap de hasta 30 ms al entregar el resultado.
  Si esa biblioteca se vuelve habitual, medir conversión incremental/paginación;
  la biblioteca personal actual tiene 35 imágenes.
- Perfiles Wi-Fi: el coste aumenta con perfiles guardados; no se añadió caché
  que pueda ocultar cambios externos ni se modificaron conexiones personales.
- No se midió presentación real, potencia, GPU, hotplug físico ni varias horas
  de uso. Los mocks y capturas no prueban esas condiciones.

## Evidencia y reproducción

Detalles: `qml.md`, `services.md`, `wallpaper.md`, `wallpaper-async.md` y sus JSON.
El cierre y despliegue del monitor están en `nmcli-lifetime.md` y
`monitor-activation.json`; se eliminó el huérfano histórico identificado y sólo
queda el monitor hijo de la shell actual.
`environment.json` fija versiones y base de CPU. `runtime-inventory.txt` conserva
el inventario; no sustituye la lectura de los consumidores.

La copia original de `/tmp` se perdió al reiniciar. Se reconstruyó y verificó
contra los **402 hashes originales** en
`~/.cache/isla-performance/2026-10-21/baseline`. `source-before.tar.gz` conserva las
versiones previas de los archivos modificados, incluidos sus cambios ajenos
preexistentes. Para recrear una copia aislada, copiar bar/wpscan/scripts actuales,
superponer ese archivo y comprobar `baseline-hashes.json`; no extraer sobre el
checkout de trabajo.

```sh
python bar/tests/sample-process.py --self-test
python bar/tests/cava-stream.py
python bar/tests/cava-envelope.py
python bar/tests/nmcli-lifetime.py
python bar/tests/cava-discovery-performance.py --before ~/.cache/isla-performance/2026-10-21/baseline/bar/services/cava_stream.py --seconds 15 --output /tmp/cava-comparison.json
QT_QPA_PLATFORM=wayland python bar/tests/qml-performance.py --output /tmp/qml-performance
python bar/tests/wallpaper-scanner-async.py --build /tmp/isla-wpscan-test
ISLA_WPSCAN_BUILD=/tmp/isla-wpscan-test python bar/tests/wallpaper-scanner.py
python bar/tests/wallpaper-scan-benchmark.py --build /tmp/isla-wpscan-test --output /tmp/wallpaper-performance.json
sh bar/tests/verify-config.sh
```

La revisión independiente no encontró defectos P1/P2 en los cambios QML, audio,
CAVA, lifecycle async del scanner ni cleanup de Nmcli. PASS en regresiones de
reloj/media/espectro, routing Wayland split/compact y normal/reduced, reproducción
sintética activa con reroute/reconexión, silencio CAVA, rebind de audio, lifecycle
Nmcli, invalidación de miniaturas, lifecycle nativo y los benchmarks. El gate de
configuración/boundaries y la integración real IPC/guardado/conflictos también
pasan, con configuración y estado temporales. Lint Qt6 sin errores bloqueantes;
persisten avisos conocidos del analizador, avatar de prueba ausente y fixtures
que no pueden registrar otro servidor de notificaciones. No se interpretan esos
avisos como pruebas de hardware o PAM.

La integración Wayland del módulo **instalado** también pasó: Wpscan →
Wallpapers → WallpaperController → surface, selección rápida, cierre/reapertura
y split/compact normal/reduced. Usó la biblioteca personal sólo para lectura,
caché/configuración/estado temporales y no aplicó ningún wallpaper. Evidencia
`wallpaper-surface.log` y `wallpaper-wayland/`.

La investigación delimitada se delegó a Luna/medium; QML, async nativo, lifecycle
y revisión de riesgo a Sol/medium. Se mantuvo el modelo principal y se evitó una
reescritura o consulta arquitectónica costosa sin bloqueo demostrado. No se ha
medido un porcentaje de ahorro de cuota de modelos.


Seguimiento: la evaluación posterior implementa y compara un helper Rust acotado;
ver [CAVA híbrido medido](../rust-cava-2026-10-21/REPORT.md). Esta fase histórica
no incluía Rust; la siguiente promueve sólo el helper tras demostrar ahorro PSS.
