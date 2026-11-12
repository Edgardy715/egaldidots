# Archivo de TASK_STATE.md: fases 2026-10-14 a 2026-11-04

Movido sin cambios desde TASK_STATE.md el 2026-11-12 (líneas originales 14–2559).
No añadir fases aquí: las nuevas van a TASK_STATE.md. recall.py indexa este archivo;
también sirve `rg`. Índice de archivos en la cabecera de TASK_STATE.md.
<!-- fin-cabecera-archivo -->

## Launcher: búsqueda al reabrir (2026-10-14)

PillSurfaceHost conserva open=true mientras displayedSurface siga cargada; la reapertura puede cambiar solo closing. LauncherView limpia texto/query/selección también al pasar closing a false con open=true. Conserva texto durante salida. Regresión launcher-input-safety cubre reapertura retenida y ciclo open false/true, sin lanzar apps. PASS offscreen y Wayland; git diff --check PASS. Sin inspección visual de la animación completa.

## Pixel media seekbar: Android 16 (2026-10-14)

- Fuente primaria/versionado → SquigglyProgress, SeekBarObserver, dimens/Interpolators/thumb Android16, fuentes y comparación en docs/pixel-media-timeline-2026-10-14/REPORT.md.
- Geometría/fase/amplitud/pausa/arrastre → MediaTimeline port seekable20u/1.5u/8u-s/2u, entrada60+800ms, salida550ms, curvas exactas. Sin gap/crossfade; thumb4×16u y extremo redondo. Fase desplazada con path estable; trazo conserva grosor al aplanar.
- Teclado, seek y retorno al inicio750ms → regresión QtTest con player/MediaSession simulado, puntero/flechas/Home/End PASS offscreen/Wayland. Revisión independiente corrigió duración capturada antes de binding y falso reset por commit MPRIS transitorio0; probe commit mantiene0.8 a300ms, cancel inmediato.
- Reduced/hidden/cierre/interrupciones → PASS; no trabajo de fase oculto. Media layout offscreen/Wayland (font1/1.2/1.75) y MediaSession offscreen PASS.
- QA visual → capturas Wayland3× playing/pausa intermedia/plana/drag inspeccionadas por coordinador/revisor; sin gaps ni grosor variable. Diez muestras temporales pausa serial: error máximo.0127 frente curva estándar; no FPS claim. Evidencia ~/.cache/isla-pixel-timeline/2026-10-14 y logs en REPORT.
- git diff --check PASS; qmllint255 sin diagnóstico (no PASS). IPC reload true. Licencia AOSP conservada, cambios ajenos preservados.
- Límites → AOSP16 con Theme/escala/entrada de Isla/MPRIS, sin overlays/binario Pixel ni comparación con dispositivo físico, sin certificar frames del panel completo.

## Matugen: migración total (2026-10-14)

Plan de cuatro fases completado; contrato/pipeline/consumidores y configuración activa migrados con backups. Paleta semántica, ANSI independiente, publicación única current y recarga IPC. Matugen4.2.0 oficial local con SHA verificada; sin sudo. Integración GTK3/4 Adwaita, Hyprland Lua activo preservado, Starship/Fish/Kitty/Rofi/Waybar/Swaync/Wlogout y Neovim local. Ajustes y bloqueo usan paletteFile; controles solid-primary usan primaryContent. Revisión encontró indicador checked del mismo color que pista y campo avanzado antiguo; corregidos, además filtro/path reactivo/lector bloqueo y config Matugen vacía inválida. 7 pipeline, 14 recuperación real-Stow, parser/contraste JS, Settings UX/Lock entrance Wayland, seis paletas nativas y CSS GTK activo PASS. Recarga live sin configerrors; wallpaper vigente respetado. Backup ~/.local/state/isla/matugen-migration/20261014-104241; detalles, logs y límites docs/matugen-migration-2026-10-14/REPORT.md. La revisión del agente quedó interrumpida por cuota después de dos hallazgos: coordinador cerró validación. GTK abierto/restricciones libadwaita, login frío y PAM real no certificados. Cambios ajenos conservados.

Cierre adicional: exportador conserva todos los roles nativos, no sólo mínimos QML, para evitar fallback constante en selección/statusline Neovim. Pipeline7/7 y refresh real PASS; surface_variant/on_background comprobados en JSON activo.

## Matugen: recarga IPC corregida tras reporte del usuario

Hyprland cambiaba pero Isla conservaba paleta: generator llamaba reloadColors con argumento vacío aunque firma=0 argumentos. Rechazo impreso en stdout quedaba oculto por optional stderr-only. Corregidos repo/live; nuevo paletteStatus confirma estado realmente cargado. Regresión real aislada con Quickshell rechaza argumento extra y aplica dos swaps sin shell reload; mock comprueba aridad. Se preservó y refrescó wallpaper vigente; primary/wallpaper del shell coinciden con JSON. Detalle en REPORT de migración; las pruebas anteriores no cubrían esa recarga end-to-end.

## Wallpapers · auditoría UI/UX, motion y pipeline · 2026-10-14

- Alcance: view/surface, navegación/cierre/reapertura, preview y miniaturas,
  Controller/Wallpapers, scanner C++, Matugen/awww/publicación/recarga.
- Resultado: composición adaptable a640px y fuente grande, confirmación inline,
  fade conserva transición visible y consume último destino; reduced también
  llega a awww. Error parcial permite reintentar; explorar tras éxito no bloquea
  Aplicar. Marcador/preview reaccionan a cambios de roles del modelo.
- Correcciones de pipeline: URLs reservadas/revisiones, callbacks caducados,
  caché invalidada por fuente modificada/corrupción, publicación parcial y recarga
  fallida de shell existente. Worker sin captura de QObject; QFutureWatcher.
- Evidencia requisito→prueba y capturas: docs/wallpaper-audit-2026-10-14/REPORT.md.
  View y surface PASS Wayland; original/pipeline PASS; 11Matugen y seis fases
  scanner PASS; IPC real aislado PASS; gate configuración y launcher PASS.
  Lint255 vacío, no PASS. Revisión UI independiente corregida; no FPS/AT-SPI,
  multimonitor físico, biblioteca masiva ni awww real sobre escritorio del usuario.
- Plugin de usuario instalado, generador activo actualizado con backup; wrapper
  de arranque conserva compatibilidad NVIDIA y antepone qml de usuario.
- Incidente de ratón: fixtures terminadas, surface cerrada, Hyprland responde;
  causa no determinada. Usuario permite continuar. No monitores añadidos.

## Wallpapers · huecos en la tira de miniaturas · 2026-10-14

- Captura del usuario muestra miniaturas intermitentes con huecos. Biblioteca
  y URLs cargan sin errores; reproducción aislada devuelve Image.Ready en todos
  los delegates. No se reprodujo el hueco en reposo; causa exacta no certificada.
- Se elimina ClippingRectangle de cada miniatura; Rectangle nativo con imagen
  inset conserva radio/borde sin recorte personalizado por celda. Preview grande
  mantiene su recorte. Evita esa ruta de render durante scroll/hover.
- View regression PASS; surface Wayland añade saltos4→5→6→14→4, captura durante
  movimiento y comprobación de al menos ocho miniaturas visibles Ready. Evidencia:
  docs/wallpaper-audit-2026-10-14/strip-fast-navigation.png. No FPS ni prueba
  concluyente de reproducción del defecto original en GPU. Surface cerrada al salir.

## Wallpapers · rediseño de galería y microinteracciones · 2026-10-14

- Miniaturas112×63, rail82, flechas junto a galería, borde móvil nativo y elevación3px
  con InteractionMotion; hit targets fijos. Fondo actual marcado independientemente.
  Galerías cortas centradas; footer libera espacio de navegación para metadatos.
- Nombre inmediato tras revisión independiente: fade reiniciado lo vaciaba en
  navegación rápida. Mantenidos Rectangle nativo y reduced motion.
- Awww conservado; fade800ms curva de Isla, target de FPS desde monitores30–240Hz,
  fallback144. Objetivo actual240, no rendimiento medido. None para reduced.
- View/surface Wayland, regresión original y12tests Matugen PASS. Tres ciclos rápidos
  en shell real, reapertura estable y captura revisada; sólo avisos textinput al cerrar.
- Generador activo actualizado con backup; barra recargada. Evidencia y límites:
  docs/wallpaper-audit-2026-10-14/redesign/REPORT.md. No awww real, FPS/AT-SPI ni
  multimonitor físico en QA; valoración estética del usuario pendiente.

## Wallpapers · aplicación escritorio con confirmación verde · 2026-10-14

- Usuario aclara objetivo: efecto al aplicar en escritorio, no selección del preview;
  pide loading→verde/check tipo confirmación de pago. Fade800ms queda sustituido.
- Preparación real con aro; stdout HANDOFF tras preflight; cerrar picker en monitor
  dueño y esperar420ms. Grow top1.45s/step35/curva0.65,0,0.35,1; FPS adaptativo.
  Commit/recarga y plazo monotónico antes de éxito. Medallón verde/check progresivo
  vive fuera del picker; no regiones nuevas de input/foco; auth/fullscreen suprimen.
- Error mantiene último intento y permite reintento tras destruir/reabrir picker;
  la sincronización inicial no borra feedback error. Reduced none y check inmediato.
-16tests Matugen, feedback Wayland, protocolo Process real simulado, pipeline,
  original y gate PASS. Revisión independiente sin defecto sustentado.
- Backend real awww+Matugen+IPC probado con otro fondo y restauración original:
  PASS; fixture de ese recorrido offscreen para no capturar entrada. Capturas del
  widget sí Wayland. No FPS/todosframes/multimonitor físico certificados.
- Generador activo y shell cargados, backup confirmation-20261014-190246.
  Evidencia/contrato/límites: docs/wallpaper-audit-2026-10-14/desktop-confirmation/REPORT.md.

## Wallpapers · confirmación dentro de la surface · 2026-10-14

- Corrección explícita del usuario: feedback integrado, sin tarjeta aparte.
  WallpaperApplyFeedback vive en WallpaperView/preview, con velo local. Retirada
  del montaje en IslandOverlay y de la espera420ms del generador. Surface abierta
  durante carga/éxito, cierre1.1s después de completarse; cierre manual retira todo.
- View Wayland PASS con assert del indicador integrado y16tests Matugen PASS.
  Generador activo y barra recargados. No nuevo cambio real de fondo por este ajuste.
  Evidencia actualizada: desktop-confirmation/REPORT.md y capturas03/06.

## Runtime y retirada legacy · 2026-10-14

Requisito → evidencia: dependencias reales → procesos/servicios/config Lua y check vivo PASS; limpieza repo+sistema → ocho paquetes retirados sin recursión, configs/hooks/templates retirados, backups de modificaciones previas; recuperación →14tests PASS; Matugen →16tests PASS; integración →gate y sintaxis PASS, revisión independiente CI corregida.

Fallo real conservado: auto-cpufreq activo y power-profiles-daemon masked hacen no disponible selector perfiles; no activar gestores competidores. Config Lua externa no equivale a .conf versionado; no certificación de instalación limpia real. Autoreload runtime desactivado mientras se limpiaron módulos; no reload/login/energía/PAM físico. Informe detallado: docs/runtime-cleanup-2026-10-14/REPORT.md. Backups ~/.local/state/isla/legacy-cleanup-20261014.

## Publicación de actualizaciones · 2026-10-14

Usuario autoriza publicar todos los cambios pendientes y limpieza legacy. Paquete incluye Matugen/apps/recuperación, wallpaper scanner/feedback, media Android16, bloqueo, Edots Hyprland y continuidad. Informes/capturas y experimento scrolloverview patch conservados locales por política previa; licencia AOSP incluida. Revisión independiente detectó launcher sin conexión al wrapper NVIDIA y upgrade sin respaldo de links retirados: corregidos launcher+prepare-stow con prueba de ruta launcher y fixture de upgrade. Docs explicitan plugin/Lua ScrollOverview externos. Suite15grupos PASS y4fixtures QML offscreen PASS (sin QA visual nueva); check vivo PASS. Publicación pendiente de commit/push al cerrar tests finales.

Publicación completada: ea47851 `feat: update Isla runtime and migrate to Matugen`, 145 archivos, push origin/main exitoso. Status vacío, ahead/behind0/0. Correcciones finales revisión sin hallazgos nuevos; recuperación15PASS, NVIDIA wrapperPASS y check vivoPASS tras cambios. Primer gh run list --commit sin entradas (CI no certificada). Notas/evidencias locales excluidas, AOSP license publicada.

## 2026-10-14 · Rediseño completo de Sonido

Petición: sustituir la surface mínima y cubrir las funciones de pavucontrol con
identidad y microinteracciones de Isla. Implementado centro760×600 con Salida,
Entrada, Aplicaciones y Hardware; dispositivos/predeterminados/puertos/perfiles,
volumen/silencio, canales independientes/vinculados/equilibrio/dB, amplificación,
rutas playback/recording incluidos monitores, búsqueda, detención de streams,
formatos digitales y latencia precisa por puerto. Renombrado libpulse implementado
para servidores que lo admiten; prueba real PipeWire devuelve Not supported y
el control se omite en este servidor. No se desinstaló pavucontrol del host.

Composición MixerSurface→MixerAdapter→AudioController/MixerView; hojas de audio
sólo reciben props y emiten señales. Helper Python+pactl sin shell, validación de
comandos, coalescing de arrastre/eventos, picos reales sólo en filas visibles y
limpieza de hijos al cerrar. ext-device-manager usa libpulse con plazo y cleanup.
Instalador retira dependencia pavucontrol y declara libpulse/parec.

Revisión independiente: cuatro P2 de slider/selección/rango/medidores corregidos
y cubiertos por fixture; fallo de medidor ya no oculta un snapshot válido. Prueba
de cierre/reapertura detectó selección retenida de medidor sin reinicio; corregido
al pasar ready=true. Eventos de cliente de pactl no provocan bucle de snapshots.

Validación:6backend tests; integración real con dos null sinks privados (volumen,
canales, mute, rutas playback/capture y picos), cleanup/predeterminados intactos;
controller real lectura/medición/cierre/reapertura; fixture de vista offscreen y
Wayland, incluido fuente1.75/reduced/retarget/teclado/Escape/15filas;14surfaces
Escape nativo; motion-regression; verify-config; qmllint;15recuperación instalador.
Capturas e informe: docs/audio-redesign-2026-10-14/REPORT.md.

Límites: perfiles/puertos/formats/latencia del hardware personal no se mutaron;
comandos probados con fixtures. No certifica Bluetooth/passthrough/multicanal
físico/AT-SPI/FPS. Renombrado nativo PulseAudio sólo simulado; error real PipeWire
verificado. Diseño implementado pendiente de valoración del usuario.

## 2026-10-14 · Sonido seguimiento: apps reales, deshabilitación y medidores

Corregidos nombres Spotify(audio-src, identidad en cliente) y Discord(WEBRTC,
identidad en proceso); lookup por índice Pulse, preservación índice0 e iconos.
Lista de apps abre playback, cuenta streams y reinicia scroll al navegar/buscar.
Hardware/Detalles deshabilitan salida/entrada con perfiles reales conservando la
otra dirección; tarjetas off permanecen reactivables. Cola de dos cambios aplica
perfil confirmado intermedio, no estado obsoleto.

PS4 deshabilitada en ambos sentidos por petición del usuario: dúplex→input-only→off.
Sin endpoints del mando; defaults Corsair intactos. WirePlumber restore-profile=true
y entrada persistente=off comprobados, sin reinicio ni replug. Otros dispositivos,
volúmenes y rutas de Spotify/Discord conservados.

Medidor:48k estéreo/20mslatencia/10msbloque/30Hzenvío, picos acumulados, ataque
inmediato/caída85ms por tiempo y escala−60..0dBFS, interpolación32ms. Snapshot
agrupa list+info para no bloquear recepción con8subprocesos. Tono privado en
contrafase: ataque61–143ms, cero falsos0, release539–574ms; no FPS medidos.

Validación:8backend+7discovery/policy; live null sinks+rutas+picos; controller
lifecycle; vista offscreen incl switches; Wayland apps Spotify/Discord reales,
fuente1.75 y hardware; gate/diff PASS. qmllint255 sin diagnóstico, carga nativa
válida. Revisión independiente resuelta con pruebas. Informe/capturas y límites:
docs/audio-followup-2026-10-14/REPORT.md. Sin replug/reboot/Bluetooth/físico/AT-SPI.

## 2026-10-14 · Neón selectivo de la shell

Petición: reforzar glow y añadir neón en superficies/interacciones donde aporte
jerarquía, preservando lectura y evitando encender cada acento.

- Material compartido PillMaterial: borde luminoso fino con halo suave, intensidad
  según expansión/awake/pulse; hereda silueta, captura izquierda/derecha y
  edgeExposure para retirar costura durante absorción. Abarca pill, companions
  y LockGlass mediante composición existente.
- IslandMediaCover: glow sobre el arco real de progreso, sin duplicar aro ni
  cambiar geometría/tiempo. TopWorkspaceRail: lente de selección luminosa.
- MotionArea/MotionButton: hover, foco y presión reutilizan InteractionMotion;
  activación breve existente. Toggle: estado activo y respuesta de interacción;
  GlassCard: glow explícito o interacción clickable; OsdOverlay: halo contenido.
- NeonOutline reutilizable: seis trazos huecos con alpha decreciente y núcleo
  fino. Sin textura, blur de contenido ni reloj nuevo. Color Theme.accent o
  materialAccent. No se modifican preferencias persistidas.

Aceptación → evidencia:
- Neón selectivo/coherente → docs/neon-2026-10-14/preview.png, render Wayland
  de bar/neon-regression.qml inspeccionado. Fondo opaco en captura evita
  artefactos de visualización del alpha del PNG.
- Input/estados intactos → keyboard-icon y interaction-surfaces (14) PASS
  por implementador; microinteraction/material-choreography/companion-continuity
  PASS por coordinador, offscreen con ISLA_CONFIG temporal.
- Reduced/idle → fixture neon verifica intensity0 oculto y brillo estático
  visible con reduced; pruebas vecinas cubren cancelación/retarget.
- Integración → verify-config PASS; qmllint archivos afectados sin diagnóstico;
  git diff --check PASS.

Límites: no medición GPU/FPS, AT-SPI ni multimonitor físico. QA render cubre
primitivas representativas, no certifica cada estado de cada superficie.
Cambios previos de audio/instalador conservados.

Cierre de integración neón: revisión independiente sin defectos sustentados.
Recarga IPC island.reload=true y log Configuration Loaded sin errores de carga;
paletteStatus loaded=true. Captura compositor /tmp/isla-neon-live.png.
Bóveda regenerada:1156 fichas/124 carpetas/430 fuentes, PASS.

## 2026-10-14 · Corrección de dirección: neón interior

La petición más reciente sustituye los contornos de neón de la fase inicial:
la luz nace de los componentes internos. Eliminados NeonOutline y sus instancias
en pill/gotas, cards, botones, MotionArea, OSD, batería y lente. Material base
conservado. MultiEffect sobre relleno de batería (acento/verde/amarillo/rojo
según estado), Pac-Man y marcadores de cinco estilos; lente conserva glow
reforzado. Sliders emiten desde fill; MediaTimeline desde thumb; Toggle desde
knob; iconos desde glifo durante interacción y Keep Awake activo; launcher
sólo marcador seleccionado interior; OSD desde icono y barra.

Pruebas v2 batería, Pac-Man interrupciones/hidden/reduced, cinco estilos y ambos
layouts, timeline Pixel, teclado PASS; implementador verificó interaction y
14 surfaces PASS. Fixture neon Wayland final inspeccionada con fondo opaco.
Revisión independiente v2 sin defectos sustentados. Eliminación posterior
de contornos no cambia input/geometría. No GPU/FPS ni QA todos los estados.

## 2026-10-15 · Confirmación circular con neón

Petición: confirmación similar al aro Apple, correcta verde/error roja, con
vueltas de carga que se alargan y recogen. Referencia recibida es PNG: no hay
evidencia temporal para afirmar réplica exacta.

ConfirmationIndicator.qml: estado inyectado idle/busy/success/error. Arco
28–300° variable con giro continuo1100ms; cola avanza al recogerse. Resultado
completa aro desde tramo actual (Motion.press) y dibuja check/X (Motion.standard).
MultiEffect sólo trazos; sin fondo luminoso ni contorno del contenedor. Oculto
detiene giro, reduced fija arco y resuelve símbolo; reintento cancela resultado.

Integración: WallpaperApplyFeedback conserva API/checkProgress, error visible
en preview con applyError y retry; AuthPromptView submit/detalle, WifiCredentials
badge, LockSurface éxito/feedback, Edots guardado real al terminar Config.saving.
No cambia autenticación, éxito/cierre ni acciones de los servicios.

Validación: confirmation-indicator y wallpaper-apply-feedback Wayland/offscreen
PASS; auth-prompt y lockscreen-motion Wayland PASS con capturas. Implementador
lockscreen/textbox offscreen PASS. settings-controls Wayland PASS; config gate y
diff-check PASS, qmllint nuevos/wallpaper/settings sin diagnóstico. Lint auth/lock
255 sin diagnóstico conocido. Protocolo wallpaper primer intento directo falló
por fixtures inexistentes; driver correcto bar/tests/wallpaper-apply-protocol.py
PASS con script simulado. Revisión independiente sin hallazgos sustentados.

Capturas apply-success/error/auth revisadas en docs/confirmation-2026-10-15.
No PAM, red Wi-Fi o cambio de fondo real; no FPS ni equivalencia temporal Apple.

## Cava: formato real y envolvente continua (2026-10-15)

Petición: quitar vibración extraña en visualizadores compactos/gota y media expandida.
Primer ajuste de suavizado insuficiente según usuario. Medición posterior del stream
real identifica causa: cava1.0.0 ignora data_bits=8 y emite48bytes/frame(16bit),
pero od -w24 -tu1 dividía cada frame en dos e intercalaba bytes altos/bajos.
Se reemplazó pipeline binario/od por ASCII explícito, rango255, delimitador32 y
frame10;60Hz. Referencia: https://raw.githubusercontent.com/karlstav/cava/master/example_files/config
Cava conserva consumers; Spectrum.js valida atómicamente, agrupa vecinos y aplica
envolvente exponencial65ms/210ms por frameTime sin overshoot. Sin señal250ms decae.
Compacto promedia cinco bandas contiguas; MediaView reutiliza agrupación. Quitadas
animaciones height/color reiniciadas por cada muestra; reduced motion fija barras.
No cambian reproducción, dispositivos ni configuración personal.

Evidencia: captura real previa48bytes/frame a30Hz; posterior57frames ASCII válidos
con24niveles0..255 en1.5s. cava-response-regression Wayland PASS (validación, bandas,
independencia30/144Hz y stale decay), capturas attack/release en docs/cava-2026-10-15.
media-motion-regression offscreen PASS birth/rebirth/cover exclusion con Playing real.
git diff --check PASS. Capturas inspeccionadas: composición compacta y expandida;
no equivalen a QA temporal con música ni medición FPS. Valoración perceptual del
usuario pendiente tras corregir formato; no declarar acabado aprobado.

## Cava: aislamiento del player, precisión y escala perceptual (2026-10-15)

Usuario rechaza movimiento y sospecha fuente distinta a Spotify. Investigación
confirma que monitor global mezclaba Discord con Spotify; MPRIS sólo encendía
captura. Cava_stream.py ahora resuelve player exacto, sink-input único y monitor
real con audio_discovery, captura parec --monitor-stream por FIFO y supervisa
reemplazos1s. No fallback a mezcla, sin match/ambiguo emite ceros; no cambia routing.
Autosens0/sens100/noise0, ASCII65535 antes de log relativo[-72,-12] y envolvente
65/210ms; PCM Spotify medido~-37..-40dBFS explica pobre precisión del rango255.
Visualizador compacto base fija y luminosidad constante; sin perfil artificial.

Evidencia:5unit helper PASS; Spotify112frames/2.5s60Hz, mediana16.7ms/gap39.3ms;
nullsink220Hz+1kHz confirma aislamiento y silencio tras retirar stream elegido
mientras otro continúa. Fixture QML Wayland live Cava→envelope→render PASS,
parse/range/quiet/silence/30vs144Hz/stale PASS; geometría media PASS; diff check
PASS. Revisión independiente cerró riesgo de escrituras PCM parciales eliminando
relay Python (parec stdout directo FIFO bloqueante). Al salir fixture se detectó
un Cava huérfano; se limpió su PID/config exclusivamente y se añadió parent-death
SIGKILL con comprobación de carrera para ambos hijos. Test automatizado y probe
real SIGKILL al helper confirman ausencia de niños vivos100ms después. Reload
shell activo y fixture live final PASS; al salir queda sólo captura del shell.
Fuentes, evidencias y límites en docs/cava-2026-10-15/followup/REPORT.md.
No afirmar réplica Apple/Spotify ni dBFS de barras; no FPS ni QA temporal sostenido.

## Cava pequeño centrado (2026-10-15)

Usuario aprueba estabilidad del pequeño y pide barras centradas verticalmente.
IslandMediaVisualizer vuelve a anchors.verticalCenter en cada barra, creciendo
simétricamente desde eje fijo. Captura, precisión, ganancia y envolvente intactas.
Media-motion PASS y fixture Wayland live PASS; captura attack revisada.

## Cava centrado: corregir deriva del eje (2026-10-15)

Usuario reporta temblor vertical tras centrar. Reproducido en fixture nueva
cava-center-regression con120alturas y escalas1/1.25: deriva centro0.724px.
Desactivar alignWhenCentered no bastó por cadena Row/anchors; fix mínimo:
Row tiene altura explícita del visualizador y cada barra y=(parent.height-height)/2.
Se evita redondeo del eje, sin tocar señal/ganancia/envolvente ni cuantizar altura.
Regresión geométrica falla antes y PASS después: deriva~7e-15px offscreen,
~6e-14Wayland; exige encontrar5barras. Fixture live Spotify Wayland y media
birth/rebirth/cover exclusion PASS, captura revisada; git diff --check PASS.
La estabilidad geométrica está medida; la percepción final queda al usuario.

## Cava expandido: proporción y amplitud visual (2026-10-15)

Usuario rechaza línea de puntos del visualizador bajo los metadatos. MediaView
usaba hasta32barras ensanchadas para llenar panel y sólo14px de recorrido.
Ahora24bandas como máximo (sin exceder24fuentes), ancho3·s/gap4·s, altura de
región38·s y recorrido34·s desde mínimo2·s, color Theme.accent alpha0.78 fijo.
Grupo natural compacto alineado al texto en lugar de estirar puntos al ancho
completo. No cambia señal, captura, envolvente ni visualizador pequeño aprobado.
Fixture Wayland Spotify real PASS y captura expanded/attack inspeccionada;
media-layout-regression PASS (seek ancho, bounds, fonts y artwork), diff check PASS.
Evidencia docs/cava-2026-10-15/expanded. No FPS ni aprobación perceptual final.


## 2026-10-15 · Portapapeles: foco estable y biblioteca persistente

Petición: corregir selección mouse/teclado y previews, ampliar utilidad con
contenido guardado y colecciones manteniendo Theme/Motion de Isla.

- Foco/selección → ClipboardView conserva geometría de lista, preview lateral
  fijo, HoverHandler único sobre lista y selección por movimiento real. Flechas
  no compiten con reflow/creación de delegados. ScriptModel reconcilia índice al
  terminar actualización; identidad y highlight conservados tras guardar.
- Biblioteca → clipboard_library.py conserva bytes exactos fuera de cliphist,
  texto completo para búsqueda, SHA256 evita duplicados, permisos700/600, flock
  entre procesos y publicación atómica/fsync. Error post-publicación conserva
  snapshot; error de metadata no sobrescribe datos previos.
- Colecciones → crear/renombrar/eliminar y mover guardados; borrar colección
  conserva entradas sin colección. Editor animado mantiene borrador ante error,
  Escape y éxito devuelven foco. Historial/Guardados/colecciones con tabs en
  scroll horizontal; preview/acciones/colecciones con scroll vertical.
- Limpieza → sólo cliphist, con exclusión de guardado/copia; cachés guardadas
  conservadas. Error se presenta en footer reservado, sin tapar filas.
- Aceptación y evidencia → 6unittest backend PASS (escrituras concurrentes,
  texto/imagen exactos, corrupción/fallos, dedup y post-replace); clipboard-library
  integration PASS offscreen y Wayland (save/create/rename/move/delete/filter,
  wipe/reload/preview/copy exacta); clipboard legacy5rutas PASS; interaction QtTest
  Wayland/offscreen PASS con mouse/teclado/scroll, editor, selección/metadata y
  reduced. qmllint5archivos y verify-config PASS; revisión independiente cerró
  P1 postreplace y P2 duplicados/error. Capturas Wayland en docs/clipboard-2026-10-15.
- Límites → QA con datos temporales, no copia/limpieza del historial personal,
  no FPS/AT-SPI/multimonitor físico. Marca Guardado del historial es sólo de esta
  sesión; tras reinicio/backend dedup reconoce contenido al guardar. No cambio
  de claves globales, configuración personal ni código ajeno.


## 2026-10-15 · Portapapeles: seguimiento mouse y composición rechazada

Usuario informa que todavía se desplaza hacia abajo con mouse y rechaza diseño
lateral. Escoge explícitamente lista limpia con vista previa bajo demanda.

- Causa adicional: hover asignaba currentIndex nativo de ListView con ApplyRange,
  activando scroll al seleccionar fila parcial; HoverHandler también generaba
  cambios de punto durante scroll. Eliminados índice/highlight nativos: current=-1,
  selección semántica propia en filas, MouseArea pasiva fija al viewport y wheel
  liberada. Sólo move(flechas) llama positionViewAtIndex; cambio de modelo no
  impone posicionamiento. No doble resaltado ni búsqueda de filas por puntero
  durante scroll inercial.
- Composición: lista ancho completo, separadores tenues, selección única y footer
  compacto; fuera columna permanente. Vista previa explícita reemplaza contenido
  con fade y Volver/Escape; la lista retiene geometría y scroll. No extracción
  full al hover ni al navegar sin abrir detalle. Colecciones y backend conservados.
- Evidencia: QtTest ampliado a40filas, hover repetido sobre fila parcial inferior
  sin desplazamiento, luego rueda real QTest y contentY170 con hover inferior y
  superior sin cascada. Navegación rápida/foco/clic/metadata/editor/reduced PASS
  Wayland; fullRequests=0 cerrado y >0 al abrir. Legacy5rutas y library integration
  PASS; lint y diff check. Capturas followup inspeccionadas; revisión UI independiente
  encontró extracción full anticipada, corregida y cubierta por assert.
- Límites: fixture Wayland, sin historial personal ni FPS/IME/AT-SPI/multimonitor
  físico; usuario aún debe valorar acabado y sensación en su uso real. No afirmar
  que la fase anterior ya había resuelto este caso: pruebas previas no cubrían
  hover sobre fila parcial con listas largas.


## 2026-10-15 · Portapapeles: vista previa y flujo de colección

Usuario aclara: mouse/scroll principal ya funciona; problemas dentro de preview,
seleccionar/guardar en colección poco claro y movimiento flojo. Se conserva el
main scroll y se corrige el flujo concreto, sin seguir parcheando hover principal.

- Filas ClipboardEntryRow muestran Ver y Guardar…/Organizar junto a cada entrada;
  cuerpo copia. Se elimina footer de acciones dependientes de hover. Guardar abre
  detalle de esa entrada con destino explícito; texto de ayuda explica clic/copiar.
- detailEntry es snapshot estable: buscar, flechas y selección oculta no cambian
  preview/objetivo; búsqueda/tabs bloqueados durante detalle. ScrollView/TextEdit
  readOnly permite texto completo, selección y rueda; requestText decode asíncrono,
  nunca sustituir texto por resumen al actualizar saved. Volver preserva lista.
- Destino se elige con lista dentro de la propia surface, sin Popup externo.
  Crear colección desde detalle deja elegido el nuevo ID y conserva scroll del
  preview. Guardar aquí realiza save+asignación en commit; mover usa savedId.
  libraryActionFinished sólo tras instalar el refresco, alimenta check real y
  mensaje «Guardado en…». Mismo destino ofrece Guardado aquí deshabilitado.
- Movimiento: entrada/salida de detalle retarget SmoothedAnimation, lista se
  retira en escala/fade y detalle viaja24s; preview revela imagen/lectura sin
  reflow; foco/iconos/botones animados y confirmación compartida. Reduced activado
  durante salida detiene/sitúa el progreso directamente.
- Revisiones: duplicados por nombre podían seleccionar otro destino; se rechazan
  nombres casefold iguales al crear/renombrar sin modificar datos. Quitar guardado
  desde detalle ahora vuelve a lista y desactiva controles de snapshot eliminado.
  TextoJobs/previewJobs toleran destrucción de roles sin TypeError. listProcess
  espera stdout y exit; no acepta salida parcial de proceso fallido.
- Evidencia:9unittest backend PASS; legacy6rutas incluye list parcial/error; QML
  biblioteca PASS con decodecompleto, savecolección y callback postrefresco.
  Nuevos clipboard-workflow-regression.qml/.sh instancian Pill real:40entradas,
  texto100líneas, previewwheel/hover, objetivo fijo, crear/seleccionar destino por
  mouse+teclado, save/check/fulltext/scroll, duplicado error/Escape, quitar desde
  Guardados, copiar bytes exactos de snapshot y reduced/reversión PASS Wayland y
  offscreen. Fixture input anterior PASS Wayland; lint5archivos y configgate PASS.
  Capturas inspeccionadas en docs/clipboard-2026-10-15/workflow.
- Límites: comandos/db temporales, no portapapeles personal; no FPS/AT-SPI/IME ni
  multimonitor físico. Native fixture emite avisos de textinput de Qt sin errores
  QML en corrida final; no certifica toda integración física de entrada. Usuario
  aún debe valorar sensación/intuición final. Cambios ajenos conservados.


## 2026-10-16 · Portapapeles: auditoría y rediseño completo

Usuario invoca UI/UX Pro Max e Impeccable, pide plan y ejecución premium con toda
interacción animada. Prioridad confirmada: copiar rápido y organizar sin salir
 del flujo. Se preservan identidad Theme/Fluid, lista completa, backend y controles.

- Auditoría independiente detecta jerarquía plana, botones que compiten con texto,
  cuatro filas visibles, lectura comprimida, estados vacíos pobres y foco de
  Escape pendiente. PLAN.md documenta fuente→decisión e inventario de movimiento.
  Query general UIUX devolvió landing ajena: descartada; guías UX/estilo native
  aplicadas selectivamente. QML no tiene stack dedicado en esa base.
- Composición680×600; cabecera con título/contexto, acción Colección y limpieza
  semántica accesible; búsqueda despejada y borrar consulta animado. Navegación
  icono/label/indicador con overflow mediante flechas animadas, sin chips perdidos.
  Filas con tiles48, dos líneas útiles y contexto tipo/colección, Ver por icono
  etiquetado y Guardar/Organizar legible. Targets y viewport no escalan con hover.
- Guardar abre organizador compacto en viewport recortado sobre la misma lista;
  material opaco sube físicamente y controls viajan unidos. Ver abre lector con
  mucho más espacio. Snapshot y scroll preservados, crear destino y guardar sin
  pasar por lector; sigue guardado+asignación atómico y resultado real.
- Movimiento por intención: colores/trazos/foco/press y retorno compartidos,
  selección interrumpible, cambio sección retirada→commit→revelado, pestañas,
  búsqueda/contador, vacíos/carga estructurada, formulario/error, disclosure de
  destino, busy/check/error y cierre. Reader usa exposiciones por fases sin
  coexistencia de texto saliente/entrante. Reduced resuelve directamente.
- Revisión visual agrupada detectó textos superpuestos, transparencia de drawer,
  estado falso de lectura en imágenes y clipping intermedio de controles. Se
  corrigen fases, material opaco+clip, filtro de tipo y fallback de feedback vacío;
  capturas asentadas esperan p1. Binding loop de height eliminado evitando y
  dependiente de altura en el cálculo normal. Revisión acotada confirma cierre.
- Pruebas: workflow Pill real Wayland PASS con lectura100líneas,40entradas,
  drawer sin full-decode, crear/elegir destino por mouse/teclado, save/callback,
  texto/scroll preservados, error nombre duplicado, retirar Guardados y copia
  exacta. Fixture diseño Wayland PASS fuente1.5/600px, claro/oscuro,12colecciones,
  scroll de navegación animado, cancelación de sección, Escape devuelve foco,
  loading/vacíos y reduced. Input Wayland, legacy6rutas y QML biblioteca PASS;
  9backend PASS; qmllint6archivos y verify-config/diffcheck PASS.
- Evidencia: docs/clipboard-2026-10-16/captures y REPORT.md. Pruebas sintéticas
  sin portapapeles/config personal; sin FPS, AT-SPI/IME ni monitores físicos.
  Acabado y preferencia perceptual final pendientes de valoración del usuario.


## 2026-10-16 · Guardado en página separada por petición del usuario

Captura del usuario muestra organizador sobre lista; pide retirar inicial y
pantalla dedicada premium/intuitiva, destinos prácticos distintos de Sin colección.
Petición actual sustituye decisión previa de drawer contextual.

- Se elimina organizerViewport y composición sobre lista. Guardar/Organizar usa
  página entera bajo cabecera; lista/búsqueda/navegación se retiran por fases,
  y al volver conserva consulta, selección y scroll. Sin decodificar imagen full.
- Resumen de la entrada con thumbnail/tipo, colecciones visibles, selección con
  marcador, Sin colección al final. Entrada nueva con destinos existentes exige
  elegir; no asume vacío. Si no hay colecciones, único destino Sin colección
  queda disponible. Nueva colección en footer conserva entrada y preselecciona ID.
  Acción final nombra destino; resultado real muestra Entrada guardada/colección.
- Revisión independiente detecta índice de foco viejo al crear destino y combo
  del lector mostrando Sin colección sin elección. Se fija índice en mouse/crear,
  foco diferido tras instalar modelo; reader muestra Elegir colección y abre en
  primera si no hay selección. Escape sale página o cierra selector del lector.
- Evidencia: workflow Pill Wayland PASS con elección existente, guardar, crear
  Referencias, Enter conserva destino, mover y Sin colección explícito; copia exacta,
  lista retirada completamente, volver/scroll y reduced. Diseño Wayland PASS
  fuente1.5, colección larga, placeholder/índice inicial y Escape/foco. Input,
  legacy y biblioteca PASS; lint y configgate/diffcheck PASS. Capturas sintéticas
  en docs/clipboard-2026-10-16/save-page, imagen usuario sólo inspeccionada /tmp.
- Límites: sin historial/config personal; sin FPS/AT-SPI/IME o monitores físicos.
  Valoración perceptual final pendiente. No cambios de backend/persistencia.

## 2026-10-16 · Investigación MacShell como referencia para Isla

Petición: lectura profunda de código visual/animaciones/materiales para identificar
mejoras transferibles. Evidencia y comparaciones en
`docs/macshell-review-2026-10-16/REPORT.md`; fuente fijada al commit
18d9ceb682960aa96347e422e9b1578f1a4707cb, clon temporal /tmp/isla-macshell-review.
Lectura principal de shaders/material/capturas/widgets y contraste local; revisión
independiente de animaciones Dock/barra/helpers mediante economy_researcher.
Aceptación: material→trazado GLSL/textura; movimiento→curvas/valores/cancelación;
transferencia→componentes Isla y prioridades; límites→solo estático, sin QA/FPS.
Se verificaron referencias concretas de Dock/notificaciones tras investigación.
No ejecución ni instalación de MacShell; acceso web falló, clon Git sí permitió
leer fuente. Sin cambios de producto ni pruebas runtime pertinentes a esta fase.
Pendiente: elegir/implementar experimento con QA Wayland; recomendación portada y
ambiente antes de refracción. No hay aprobación implícita de los diseños propuestos.

## 2026-10-17 · Aplicación de mejoras MacShell manteniendo identidad

Usuario autoriza implementación y exposición de preferencias ajustables. Cerrado:
- Reutilización → ArtworkImage para covers/ambiente y CrossfadeLabel para metadatos.
- Continuidad → dueño/barrera/progreso compartidos por panel en Pill (compact) y
  FluidMediaCompanion (split), inyección PillSurfaceHost; fuente retenida hasta
  salir el contenido; cancelación/último URL y error/ausencia controlados.
- Estabilidad → título2líneas usa métricas redondeadas hacia arriba; fallo inicial
  por66px frente67.2necesarios corregido y comprobado lineCount2+QA nativa.
- Material → luz fija superior y absorción interior, intensidad0–1, edgeExposure;
  sin puntero, neón añadido ni cambios del motor físico. Valores discretos0.25.
- Configuración → Settings/Flags/Edots/example, esquema y save/discard temporal.
  Apariencia: Profundidad del material/Alinear selección en menús. Movimiento:
  Transiciones multimedia. Menú conserva bounds y teclado con fallback.
- Validación → gate, settings integración/UX/controles, media presentación con
  HTTP local lento400ms, imágenes fallidas, reversión, ocultación/reduced/disabled,
  title1↔2, progreso compartido, layout fuente1/1.2/1.75, morph/media-motion y
  routing real con Players inyectado en copia temporal2layouts×2motion PASS.
- QA visual → capturas nativas inicial/intermedia/final/title2líneas/material0/1
  y Settings Apariencia/Movimiento, revisadas. No equivale a FPS ni todosframes.
- Revisión → agencia independiente identificó layout, reloj separado y liberación
  prematura; corregidos y probados. La sospecha final sobre playerreal no aplica:
  driver settings-media-routing.py inyecta fixture con SVG local en copia temporal.
- Límites → qmllint255 sin diagnóstico (carga real PASS), sin AT-SPI/GPU sostenido
  ni monitores físicos adicionales. Varias advertencias Wayland de foco/texture
  expuesta, sin FAIL tras ejecutar tests de foco secuencialmente. No reproducción,
  fondo ni settings personales alterados. Shell activa loaded/clean/errorvacío y
  defaults efectivos comprobados por IPC. Cambios ajenos preservados.
Informe y evidencia: docs/macshell-review-2026-10-16/implementation/REPORT.md.
Sin nuevas dependencias ni código/shader copiado. Toast.qml legacy descartado:
notificaciones actuales usan pill/NotificationChoreography; no añadir vuelos
raster o infraestructura de capturas especulativa a Overview. Valoración visual
final del usuario pendiente, no requisito de permiso para completar esta fase.

## Swiftify: análisis y adaptación musical · 2026-10-17

Petición: estudiar código Swiftify y adaptar movimiento/letras, fondos/ambiente e
iconos/formas a Isla. Fuente fijada aee47bb027c09c7ed9c6b4b4839534f85a1427b3; sin
licencia global encontrada, implementación propia de ideas sin copiar componentes.
Análisis con enlaces permanentes: docs/swiftify-2026-10-17/ANALYSIS.md.

Requisito→evidencia: letras onda+seek clic/teclado y cambios tardíos→fixture
swiftify-media; cover/play shape retarget→misma fixture; fondo lowres/fase
conservada y guards→media-ambient; continuidad loading/shared artwork→media-
presentation.py; integración split/compact→settings-media-routing.py. Gate, parser
lyrics/media-source, diffcheck PASS; regresión letras existente PASS. Wayland
musical640×360 y ambiente con capturas inspeccionadas. Revisión independiente sin
hallazgos sustentados. Ver docs/swiftify-2026-10-17/REPORT.md y ambient/REPORT.md.

Se mantienen cambios locales previos. No se alteraron servicios personales ni
reproducción. No ejecutada app referencia; sin FPS/GPU/AT-SPI ni seek/lyrics reales;
qmllint255 sin diagnóstico. Valoración perceptual del usuario pendiente.

## Swiftify segunda fase: letras reales y rediseño integral · 2026-10-17

Usuario rechaza letras que no cargan y prefiere botón/iconos de Swiftify. Causa
reproducida: LRCLIB GET con álbum503 frente a sinálbum200 en HOY AQUÍ/Rauw
Alejandro/PLAYA SATURNO/187.826s. Controlador añade exact→sinálbum→search,
ranking estricto y reintentos/timeout finitos. Consulta QML real final PASS:
ready, sincronizadas69líneas; sin tocar reproducción personal.

Composición720×440 (height escala), portada circular/CAVA radial real, metadata
natural y controles a derecha, letras junto a portada, símbolosMaterialRounded
rellenos subsetlocal3784B con licenciaApache2, forma propia5→9lóbulos/giro bajo
demanda y popicon. Ambientealfa0.32. General mantiene preview16:9. No afecta
iconos globales. Conserva cambios previos ajenos.

Aceptación→evidencia:9escenariosHTTP/parser + público→letras; swiftify-media
Wayland/offscreen→acciones/morph/seek/estados/familiafont; media-layout fonts
1/1.2/1.75→geometría; media-presentationHTTP→continuidad; settings-media-routing
split/compact normal/reduced→integración; gate/diff PASS. Revisión funcional
reprodujo timeout y testlayoutobsoleto: corregidos. Revisiónvisual detectó etiqueta
sincronizada duranteerror: corregida y snapshot/assert PASS. Evidencia/capturas
finales docs/swiftify-2026-10-17/redesign/REPORT.md. qmllintglobal255 sin diagnóstico;
controllerlimpio. SinFPS/GPU/AT-SPI ni seek/transporte personal. Valoración pendiente.

## Swiftify afinado aprobado: respuesta/neón/seguimiento/progreso · 2026-10-17

Usuario aprueba diseño anterior; pide espectro más visible, letras que no se
queden en otra parte con neón/descenso y barra Swiftify. Causa vista: following
manualfalse retenido al reabrir. Ahora abrir resetea; exploración retoma tras3.2s
sin interacción/inercia; seekline retoma. MultiEffect emite acento desde glifos
activos y se retira con énfasis. Reloj auditado sin deriva real: máximo0.061s
vsMPRIS/30muestras; no se cambió MediaSession ni offset. Espectro48spokes3.5px,
alfa0.98 y3+28·signal^.72; backend/compacto intactos. Nueva SwiftMediaTimeline en
panel con medidas de referencia4/6px, onda34px, amplitud1.6/2.4, thumb4×18 hover,
cola/gap y fase1onda/1.6s; no reloj de posición extra.

Aceptación→evidencia: swiftify-media offscreen/Wayland seguimiento-auto/reopen,
glow/retiro y48radios0/moderado/pico PASS; nueva timeline input/phase/flags PASS
offscreen/Wayland; media-clock sparse/rate/seek/pause/reopen/mock+live PASS;
CAVA selected-player real+render PASS sin modificar reproducción. lyrics-view,
media-layout3fonts, gate/diff PASS. Revisión independiente sin hallazgos nuevos.
Capturas inspeccionadas; informe docs/swiftify-2026-10-17/refinement/REPORT.md.
SinFPS/GPU/AT-SPI ni certificación fonética LRC. qmllint agrupado255 sin diagnóstico.
Base visual aprobada; afinado pendiente valoración del usuario.

## Paleta de portada en música · 2026-10-17

Usuario autoriza implementar dentro del uso restante. Consulta inicial:12%5h y
27%semanal restantes, no promesa de coste exacto. MediaPalette derivado compartido
con helper Python/ImageMagick ya instalados, miniatura48px/8colores, lectura8MiB,
timeouts y caché64colores. Resultado identifica URL para descartar obsoletos.
Acento corregido claro/oscuro y fundido500ms único; reduced directo. Fallback
Matugen ante fuentevacía/error. Inyección a CAVA/radial, progreso gota/panel y
neón; controles y hojas sin inyección siguen Theme. No modificar reproducción.
Waylandpaleta/capturas, helper local/HTTP/cache, portada Spotify real, regresión
musical offscreen, gate/diff PASS. Límites contrasteuniversal/FPS y sincronía de
fundidoimagen/color no certificadas. docs/swiftify-2026-10-17/palette/REPORT.md.

## Player: paleta/progreso/neón/botón · 2026-10-18

Usuario autoriza correcciones propuestas y pulido de barra/neón/color del botón.
MediaPalette cancela jobs obsoletos, retry2 a800/1600ms y watchdog12s; helperSIGTERM
limpia hijo/temporales. Progreso: reproducidos seek bloqueado por reset y drag
obsoleto tras cambiar duración. Eliminado reset/interpolación secundaria; valor
inmediato de MediaSession, lifecycledrag y extremos corregidos. OndaFrameAnimation
con gateenabled. Botón primaryColor portada+tinta por luminancia, giro/forma
intactos. Gradiente radial interior bajo disco, más tenue en pausa; sin contorno.

HTTPcancel/retry/watchdog y helper PASS; barra y paleta Wayland PASS, musical
completa/layout3fonts/gate/diff PASS. Capturas inspeccionadas coral/azul. Revisión
independiente motivó quitar heurística de reset; sin defectos pendientes sustentados
en alcance tras corrección. SinFPS/GPU/AT-SPI/seekpersonal; color/imagen aún no
comparten reloj exacto. Evidencia: docs/media-fixes-2026-10-18/REPORT.md.

## Publicación organizada 2026-10-18

Autorización: usuario pidió commits y subida de todos los cambios anteriores. Publicados en origin/main: 3890745 UI/confirmaciones; 533f6d2 audio; 2fa3996 portapapeles; 1327474 CAVA; 41b1e69 reproductor/paleta/letras/progreso; d09ca29 documentación. Push ea47851..d09ca29 confirmado; HEAD y origin/main coinciden, árbol limpio. Se mantuvieron locales las nuevas carpetas de capturas/informes mediante .git/info/exclude, siguiendo 6a32a55.

Verificación final: configuración/settings, instalación (15 casos), audio backend/policy y medición privada con limpieza, biblioteca portapapeles (9 casos) y dos flujos QML, extracción de paleta, CAVA, backend/letras, recuperación HTTP/cancelación de paleta y fixtures QML offscreen de timeline/player/reloj: PASS. git diff origin/main anterior..HEAD --check: limpio. Sin nueva QA visual nativa durante esta publicación; se conserva la evidencia visual de fases previas.

## 2026-10-18 · Optimización de contexto y orquestación Codex

Autorizada tras auditoría local. Trabajo directo por defecto; normalmente un
subagente, dos sólo con independencia y ventaja concreta, contexto nuevo,
aceptación/retorno definidos y sin sondeo rutinario. Roles mantienen modelos y
esfuerzos; revisión pertinente y pruebas/QA requeridas se conservan. Reglas en
~/.codex/AGENTS.md, skills ahorro-tokens/agency-agents y seis roles locales.
PROJECT_MEMORY.md pasa a mapa breve; contenido anterior íntegro preservado en
docs/PROJECT_MEMORY_ARCHIVE-2026-10-18.md, con búsqueda explícita por rangos.
Backups y manifiesto: ~/.codex/token-economy/audit/2026-10-18/optimization-backup/.
Validación: comparar archivo histórico con backup, parsear TOML y validar skills;
resultados finales en informe de optimización externo. Sin cambio de defaults,
compactación, MCP, plugins ni producto. Efecto conductual/quota aún no medido;
comparar próximas tareas de alcance equivalente sin generar benchmarks de pago.

## 2026-10-18 · Auditoría integral del modo compacto

Objetivo: uso/diseño/funcionalidad y especialmente movimiento, con correcciones
y evidencia acotada. Informe: docs/compact-audit-2026-10-18/REPORT.md.

- Contrato→evidencia: metadatos/anchos/fontScale/foco→compact-island ampliada
  offscreen y Wayland PASS; módulos/selección→optional-modules y
  top-workspace-motion offscreen PASS; routing/todos los paneles→layout-motion
  Wayland11surfaces PASS; notificación/ausencia media/reversión→
  layout-interruptions Wayland PASS; retarget/reduced→compact ampliada PASS.
- Corregidos TopBarModules, CompactMediaStatus y TopWorkspaceRail: reserva
  independiente evita rail invisible robando ancho; música legible>=112 o
  portada sola36, visualizador>=146; medidas/dibujo usan Theme; un target con
  foco visible; selección<=slot; separadores siguen exposición existente.
- Fixture falla con exit1 ante aserción propia; espera ancho/alto y opacidad
  de reloj para reposo. Primera altura falló intermitentemente antes de
  reforzar espera, sin evidencia suficiente para cambiar motor.
-72capturas de escena Wayland con tiempos reales en dos ciclos calendario;
  resumen y trazas conservados en informe. No grabación completa ni FPS.
- Revisión independiente Sol/medium detectó reserva de rail y revisó solución;
  sin nuevos hallazgos sustentados. Gate/lintQt6/diff-check PASS; lint conserva
  warning preexistente de Loader.item.playing en fixture.
- Captura de texto grande coincidió con cambio de minuto; diagnóstico aislado
  CLOCK mostrado37/entrante37/travel0/alto56/animatingfalse y captura asentada
  confirman reloj correcto. No se cambió ClockReel por una imagen transitoria.
- Pendientes de evolución (no implementados): prioridad apps/metadatos, reparto
  asimétrico de sobrante, acceso overview con rail saturado y tooltip portada
  sola. Límites: sin AT-SPI/FPS/GPU/multimonitor físico/escala fraccional.
- Config personal y reproducción intactas; la sesión estaba en split, QA
  compacta aislada. Archivo ajeno PROJECT_MEMORY_ARCHIVE preservado.

## 2026-10-18 · Aro compacto y neón CAVA pequeño

Usuario señala aro ausente y pide neón en CAVA de reposo compacto/normal.
CompactMediaStatus tenía hasProgress:false explícito; ahora propiedades
inyectadas desde TopBarModules/MediaSession y forwarding a IslandMediaSummary.
Se conserva guard canSeek/duración válida de MediaSession; sin otro reloj.
IslandMediaVisualizer compartido añade un MultiEffect en la fila completa de
cinco barras, acento musical y energía RMS de Spectrum; capa detenida en
silencio/pausa/oculto/reduced. No se altera señal, eje ni alturas.

Pruebas: compact-island offscreen y Wayland PASS (progreso>0.3, posición120/240
en pausa=0.5, longitud0 oculta aro); CAVA Wayland PASS con deriva5.68e-14
a escalas1/1.25 y apagado efecto en pausa/reduced. LintQt6 exit0 con avisos
no cualificados heredados; gate/diff-check PASS. Capturas de aro y neón
inspeccionadas; sinFPS/GPU ni cambios a reproducción personal.
Informe: docs/compact-audit-2026-10-18/media-followup/REPORT.md.

## 2026-10-18 · Transición de pista sin player abierto

Petición: cambio fluido/premium en música de reposo compacto y normal. Se usa
compresión sutil de portada dirigida por identidad título/artista (también
mismo álbum), SmoothedAnimation independiente reiniciada desde valor actual y
retorno tras Motion.press. Aro/target estables. ArtworkImage opt-in swapTravel4
sobre fundido/carga retenidos; CrossfadeLabel traslado4 de ambas capas, default0.
Solo CompactMediaStatus y FluidMediaCompanion/IslandMediaMetadata activan la
coreografía; otras surfaces y player conservan defaults existentes.

Nueva rest-media-transition-regression Wayland PASS: último destino, misma
portada, bounds estables, hidden/reopen, panel opt-out, reduced/disabled. Prueba
HTTP media-presentation PASS para imagen retenida, respuesta obsoleta y defaults.
Revisión independiente acotada a primitivas/consumidores y corrección cancelación
sin hallazgos nuevos. Primer intento de cancelación con animación hija de
Behavior no era controlable; sustituida por SmoothedAnimation independiente.
Start no retomaba nuevo destino mientras corría; restart toma valor actual y
resuelve. No se afirma continuidad física de velocidad. LintQt6/gate/diff PASS
con avisos preexistentes. Informe docs/rest-track-transition-2026-10-18/REPORT.md.

Integración posterior: compact-island completa Wayland PASS con nueva transición;
aro, CAVA, fuentes, widths, paneles e interrupciones conservan contratos.

## 2026-10-18 · Tipografía del lockscreen

Petición: mejorar aspecto y sensación premium, especialmente la hora.
LockSurface.qml y LockMedia.qml usan Theme.fontMedia (Inter configurada),
conservando configuración global. Hora pasa de Rubik Light a Medium,
tracking de −3 a −2, cifras tabulares y Text.CurveRendering; sombra del
bloque menos opaca y fecha Medium. Resto de estructura y autenticación intactos.

Validación: preview en ventana Wayland, reposo/acceso inspeccionados en
docs/lockscreen-type-2026-10-18/{rest,access}.png. Regresión lockscreen PASS
con ISLA_CONFIG temporal; diff --check PASS. Detector tipográfico devuelve []
pero no acredita QML. No se activó bloqueo real ni PAM; capturas sin wallpaper
y sin reproducción. Advertencia Wayland textinput disableSurface al cerrar fixture.

Regresión de doce transiciones Wayland PASS: todas se estabilizan; no acredita FPS del bloqueo real.

## 2026-10-18 · Fluidez de Edots / Composición

Petición: reducir tirón al entrar y salir de Composición y navegación general.
Causa: selección de sección/claves no atómica construía secciones completas
transitorias; filas ocultas y selectores tipográficos en cada ajuste.
Cambio: EdotsWindow/SettingsPage selección atómica; SettingRow Loader tipográfico;
EdotsComboBox modelos según visibilidad y popup. Borradores/validación conservados.
Requisito→evidencia: navegación sin modelos intermedios, resize, búsqueda,
borradores e interrupción/reduced→settings-navigation PASS; controles teclado y
ratón→controls aislado PASS; UX/async/motion/gate→PASS. QA Wayland de distribución
conservada. Driver máximo176/181→62/58ms; Composición11/14ms; no FPS/GPU.
Revisión del coordinador de integración y contratos sin hallazgos pendientes.
Límite: Apariencia~60ms, lint con warnings y sin AT-SPI/multimonitor físico.
Informe y logs: docs/settings-fluency-2026-10-18/REPORT.md. Sin config personal.

## 2026-10-18 · Auditoría general y fluidez de la shell

Objetivo: bugs, trabajo redundante y fluidez general conservando diseño/cambios
ajenos. Scope: runtime/IPC/routing/ventanas/loaders, servicios/adaptadores y
consumidores UI; revisión por riesgo, no lectura íntegra de cada archivo.
Correcciones: Nmcli process destruction + refresh serial/callback identity;
Brightness destinos/teclas seriales, fallback y lectura obsoleta; launcher stale
activation/hidden debounce/reopen; clipboard texto original/índice porID/jobs;
BreatheBorder hidden/reduced/agile; router close reduced; urgent; fileURLs
reservados en overview/lock. Archivos y hashes en informe sources.json.
Requisito→evidencia: procesos/refrescos→nmcli-service PASS40→2/25→0;
brillo→brightness-service PASS60→80, pasos, fallo/stale; entrada→launcher
controller/pending/input Wayland PASS; clipboard→3suites + previewjobs PASS;
UI/integración→calendar/breathe/router + layout-motion Wayland11surfaces PASS;
wallpaper→Image.Ready ambos previews con #/?/%/Unicode y capturas; gate/lintQt6
exit0 con warnings/pycompile/diffcheck PASS. Negativos3fixes fallan explícitamente.
Revisión independiente detectó coalescing Qt.callLater de cleanup: closure por
job corregida y revalidada; servicios/brillo sin más hallazgos sustentados.
Límites: sinFPS/GPU/energía/hardware red-brillo/PAM/AT-SPI/multimonitor físico;
no cambia configuración personal. Informe y logs:
docs/shell-audit-2026-10-18/REPORT.md. Sin pendientes de implementación conocidos
en los hallazgos cerrados; no garantiza ausencia de bugs en toda la shell.

## 2026-10-18 · Rediseño de Conectividad

Petición: UI/UX de Wi-Fi/Bluetooth al nivel de media/bloqueo; usuario confirma dos
vistas. Nuevo cuerpo460×520 (+altura fuente), cabecera/selector con estado,
red conectada protagonista, redes sin límite8 y dispositivos con acciones bajo
nombre. Theme/material/motor y contratos de servicios conservados.

Archivos: ConnectivityView.qml, WifiCredentials.qml, IslandGeometry.qml;
fixtures connectivity-design-regression.qml y connectivity-host-regression.qml.
Retirada antes de cambiar contenido; retarget/hidden/reduced resuelven. Foco
Tab/ShiftTab revela acción en scroll; scrollbar discreta. Credenciales legibles,
colores semánticos y limpieza/foco/feedback preservados.

Requisito→evidencia: composición/nombres→capturas Wayland1/1.5; acciones→fixture
mock PASS; teclado→Tab/ShiftTab/Space PASS; credenciales→fixture diseño y textbox
PASS; host→geometría/split/compact/reopen/unload/reduced PASS; lintQt6/gate/diff
PASS. Revisión independiente detectó foco fuera viewport; corregido y revisor
lo puntuó resuelto/ship al alcance. Sin pendientes técnicos identificados.

Dirección, capturas, logs de sesión y límites en docs/connectivity-2026-10-18/REPORT.md.
No conexiones/pairing reales, FPS, AT-SPI ni multimonitor físico. Valoración visual
del usuario pendiente. Se conservaron cambios ajenos; no publicación/commit.

## 2026-10-18 · Música absorbida ausente en wallpapers

Usuario aprueba rediseño conectividad; reporta música absorbida que no se muestra
en wallpapers y pide revisar surfaces integradas. Causa: WallpaperView requería
width>1000*s para mostrar resumen, pero cuerpo1000 menos40 de márgenes nunca
cumple. Misma condición limitaba título. Corrección local: visible por mediaHas,
ancho de texto según espacio, cover conservado estrecho y título hasta resumen.
No cambio al motor/router ni a otras surfaces aprobadas.

Wallpaper-media-header-regression PASS Wayland (ancho real con márgenes,
escalas1/0.8, fuentes1/1.5, estrecho/sinplayer). Media-dock-surfaces-regression
fuerza gota presente de fixture y prueba absorción antes de abrir wallpaper,
overview y launcher y cierre normal/reduced: PASS Wayland. Gate y diff PASS;
lint carga sin errores con warnings unqualified heredados. Capturas inspeccionadas.
Detalle/logs/límites: docs/wallpaper-media-2026-10-18/REPORT.md. Sin cambio de fondo,
reproducción personal ni mediciónFPS; secuencia probada, no todos los frames.

## 2026-10-18 · Expansión de rail al superar workspace5

Usuario pide transición suave como panel apps. Width de TopWorkspaceRail era
instantáneo; ahora usa SmoothedAnimation/Motion.morph, revelado por espacio de
nuevas posiciones y selección acotada al ancho presente. Fits por ancho destino,
retarget conserva valor presente; hidden/reduced/animateChangesfalse resuelven.
TopBarModules propaga preferencia existente. Conservados cambios ajenos de
lente integrado y urgent, sin tocar WorkspaceModel ni activar workspaces reales.

Fixture workspace-width Wayland PASS5→6/intermedios/inversión/split/integrated/
reduced/hidden/disabled; lente existente Wayland PASS; compact-island offscreen
PASS; lintQt6/gate/diff PASS. Capturas temporales inspeccionadas; reporte/logs en
docs/workspace-width-2026-10-18/REPORT.md. Sin FPS/AT-SPI ni cambio workspace real.
Host compacto mantiene gate al cambiar presupuesto: no se certifica exposición
continua de módulos durante esa ruta. Valoración perceptual del usuario pendiente.

## 2026-10-21 · Investigación Nusa/Coucou, identidad y microinteracciones

- Petición: análisis profundo de referencias y transferencia a Isla; sin implementación funcional.
- Evidencia: demo Nusa inspeccionada en navegador (music/shelf/lyrics/focus/headphones), HTML/CSS/JS; Coucou código fijado a 1e5180921c1326fc72e41d313e3e2855e9c10162 mediante investigación independiente. Contraste con fuentes actuales de interacción, OSD, router, notificaciones y contratos Fluid; captura histórica de compacta como referencia, no runtime vigente.
- Resultado: docs/nusa-coucou-2026-10-21/REPORT.md y COUCOU-EVIDENCE.md. Propuesta: respuesta semántica, bandeja temporal con prueba Wayland primero, vistazo que preserve contexto, temporizador mínimo y agentes opcionales posteriores. Sin personaje obligatorio ni sustitución del reproductor aprobado.
- Requisito → evidencia: animaciones → CSS/JS demo y fuentes Swift; funcionalidad → límites demo/README/código explícitos; diseño → comparación con Theme/Motion/contrato y captura histórica; encaje → matriz de componentes existentes y rutas propuestas.
- Límites: sin apps nativas remotas, DnD real, CPU/FPS ni QA actual de Isla. Nusa web no demuestra aplicación Windows. Coucou separa MIT y assets reservados. No se modificó código funcional ni configuración; cambios ajenos preservados. Decisiones de implementación quedan pendientes de elección del usuario.

## 2026-10-21 · Personalidad, pulso interior y enfoque

- Usuario autoriza aplicar ideas Nusa/Coucou y enfatiza pulso gradiente, carga, mirada/expresiones y morph. Aclaración posterior: no necesita Shelf; trasladar sensación a surfaces existentes. Se detuvo encargo Shelf antes de crear archivos; no se integró bandeja.
- Implementado: ReceptionPulse dentro de material; feedback confirmado clipboard/Wi-Fi/Config/Focus, carga compacta sin foco, IslandCompanion/ActivityChip junto a reloj con opt-out en Movimiento, FocusSession/FocusSurface temporal1..180min y acceso desde ojos/ajustesrápidos/IPC. Theme/Fluid y reproducción/configpersonal preservados.
- Atención: informativas diferidas mientras cualquier surface activa (incluye companions); crítico/auth conservan prioridad. Notifs.advancePopup recibe identidad de la mostrada, sin fallback sobre null; sync posterior presenta reemplazo intacto.
- Requisito→evidencia: pulso/mirada/reduced→personality-regression Wayland y capturas; timer→focus-session-regression Wayland/offscreen; integración→compact Wayland y motion offscreen; prioridad→notification attention/priority y regresión existente; configuración→verify-config y settings-integration PASS. Detalles/logs/límites docs/personality-2026-10-21/REPORT.md.
- Revisión independiente: corregidos completed00:00 tras elegir duración y consumo prematuro del crítico, incluida destrucción NotifData. Tests nuevos acreditan recorridos. QmllintQt6 exit0 con avisos de metatipos; carga nativa PASS.
- Límites: sin cargador/conexiones/D-Bus/AT-SPI reales ni FPS; timer no persiste y usa reloj civil. No módulo de agentes IA ni sonidos. GIF de muestras nativas, no vídeo/FPS. Pendiente valoración visual del usuario.

## 2026-10-21 · Afinado discreto de pulso y hover

- Usuario rechaza intensidad del pulso y tooltip de ojos; pide limpieza/cohesión.
- ReceptionPulse elimina frente anular, limita expansión al borde inferior y baja alfas0.52/0.40/0.24→0.12/0.075/0.025. Duración950ms y entrada/salida sinusoidal. Sustituye acabado previo; no cambia señales/acciones.
- IslandActivityChip elimina ToolTip. Hover/foco usan respuesta compartida (luz local tenue, presión visual y ojos levemente abiertos) dentro de target estable; nombre accesible conservado.
- Validación: personality-regression Wayland PASS con mouseMove real del test, foco, ancho estable, pulso/reduced/hidden; qmllintQt6 y diffcheck PASS. Capturas inspeccionadas en docs/personality-2026-10-21/refinement/. Sin FPS/AT-SPI/hardware; pendiente valoración del usuario.

## 2026-10-21 · Actividades y grabación OBS

- Petición: grabación en interfaz de enfoque, estado en pill y movimiento cuidado inspirado en Caelestia. Integración OBS existente, sin dependencia instalada ni servidor activado.
- Implementación: puente OBSv5 local autenticado + Recording singleton; ActivityView con pestañas, countdown3s cancelable, morph disco/detener, pausa/reanudar, guardado confirmado y estado incierto ante desconexión. Pill prioriza REC/tiempo sobre ojos sin alterar reloj. Cierre de shell no detiene grabación.
- Revisión independiente y correcciones: reconciliar rechazo de pausa/inicio perdido; cancelar countdown al salir de pestaña/ruta/cerrar/destruir. Sin toggles ni reenvío de comandos tras reconectar.
- Evidencia: backend11tests PASS; RecordingView/RecordingIntegration Wayland PASS, texto1.5 inspeccionado; FocusSession, motion, settings-integration y verify-config PASS. Personalidad Wayland PASS (hover no reproducible offscreen). Ruta producción abierta/IPC consultado: servidor OBS desactivado reconocido. Reporte docs/recording-2026-10-21/REPORT.md.
- Límites: escenas/audio/encoder y captura real no probados; no se inició OBS ni se grabó escritorio; sin FPS/AT-SPI. Capturas de estados activos son fixtures simulados. Cambios ajenos preservados.
- Cierre: compact-island Wayland PASS (límites, monitor estrecho, layouts y reduced); diffcheck final PASS. Memoria de fuentes actualizada con tools/brain.py.

## 2026-10-21 · Grabación directa tipo Caelestia y recursos

- Petición sustituye elección OBS: captura integrada de baja sobrecarga. Referencia Caelestia Recorder.qml consultada; backend nuevo gpu_recording.py stdlib, antiguo obs_recording.py/tests retirados. Interfaz y pill conservan movimiento aprobado; audio sistema/mic separados.
- Requisitos→evidencia: H264GPU30/VFR/noCPUfallback→argumentos + --info NVIDIA + ffmpegNVENC sintético1s/ffprobePASS; ahorroreposo→binding sólo controles/engaged/busy, sin auxiliares en /proc al cerrar y0ticksCPU/3s conpanelabierto; UI→RecordingView/RecordingIntegration WaylandPASS con controles/audio, cancelación, morph/reduced/texto1.5; gates/lint/diffcheckPASS.
- Seguridad/lifecycle: revisión detectó SIGTERM que abandonaba captura; corregido finallySIGINTesperafinalizar y parent-deathSIGINT Linux anteSIGKILL. Pausa absoluta porUnixIPC conack envezdeseñal toggle. Sólo PIDpropio; MKV único y guardado condicionado aexit0+no vacío.
- Disponibilidad: paqueteCachyOS6.1.4 extraído ~/.local/lib/isla/gpu-screen-recorder, sin cambiar paquetes/root; backendprefierePATH. README/TESTING/capabilitiesactualizados. Documentación docs/recording-2026-10-21/DIRECT.md.
- Límites: sin captura real portal/audio, sin benchmarksenergía/FPS ni primerframe verificado; aperturaMKVesproxy de arranque. No captura escritorio privado. HistorialOBSpreservadoenREPORT.md pero supersedido. Cambios ajenos preservados.
- Cierre: backend11tests y py_compile PASS, incluye Quickshell real offscreen con grabador falso destruido → SIGINT+MKV finalizado; revisión independiente confirma P1 resuelto sin nuevos defectos importantes. Settings-integration PASS.

## 2026-10-21 · Composición de grabación más cuidada

- Usuario confirma funcionamiento pero considera feo el panel. Propuesta visual acotada: sustituir gran botón circular por barra grabar/detener con morph, agrupar reloj/estado, audio en dos filas con iconos/interruptores persistentes, pausa secundaria compacta. Subtítulo contextual Pantalla y audio; Enfoque intacto.
- Archivos: RecordingView.qml, ActivityView.qml y recording-view-regression.qml (expectativas de geometría actualizadas). Backend/codificación/sondeos sin cambios. No nuevos procesos/shaders/loops.
- Evidencia: RecordingView e integración Wayland PASS con teclado/mouse/audio, estado/error/busy, morphintermedio/hidden/reduced, cancelación/pill/guardado y texto1.5. Lint sin diagnósticos, verify-config/diffcheckPASS. Revisión visual independiente sin hallazgos importantes en capturas vigentes. docs/recording-2026-10-21/refinement/REPORT.md.
- Límites: capturas de estados simulados; sin FPS/AT-SPI, no se repite encoder/backend porque no cambiaron. Propuesta pendiente de valoración del usuario.

## 2026-10-21 · Gota izquierda para estado de grabación

- Usuario pide sacar el estado de grabación de la pill como gota a la izquierda. Nuevo FluidRecordingCompanion de presentación con datos del overlay; reutiliza FluidCompanion, sin reloj/proceso/loop decorativo añadido. Glyph+tiempo y click a controles; música derecha.
- recordingDetached evita duplicar estado en header incluso durante retorno. InputPolicy incorpora límites visualX/yPos y fuera-de-cuerpos; no cambia foco/máscara idle. Fallback al header si falta espacio o sesión/settings; sesión espera absorción. Retirada en fullscreen/cambio layout.
- Ajustes QA: texto oculto hasta caber en nacimiento/retorno; compactY con defaultbodyY conserva otras gotas y centra38px contra56px encompact. hoverWidth/nombre accesible configurables con defaults originales.
- Evidencia: recording-drop-regression WaylandPASS incluye click, música, fases, split/compact/centro, colisiones, finalabsorption/interrupción y reduced/narrow/fullscreen. InputPolicy offscreenPASS. Media-motion/session-companion y Pill recording-integration offscreenPASS; lint sin diagnósticos, verify-config y diffcheckPASS. Revisión independiente sin defectos sustentados, incluyendo últimos ajustes.
- Visual: capturas simuladas Wayland docs/recording-2026-10-21/drop y grim compuesto; grabToImage muestra bordes corruptos también enmúsica, grim confirma borde suave. Detalle drop/REPORT.md. Sin grabación vídeo real, FPS/energía ni multimonitor físico; valoración perceptual pendiente. Backend sin cambios. Cambios ajenos preservados.


## 2026-10-21 · Optimización de rendimiento con baseline y lifecycle

- Objetivo: reducir CPU, invalidaciones, bloqueos UI y procesos sobrantes conservando diseño, configuración e integraciones. Auditoría por caminos de QML/JS, servicios/procesos, native Wpscan y arranque/Matugen. Luna/medium investigó servicios; Sol/medium implementó QML/native/lifecycle y revisó riesgo; coordinador midió e integró. Sin reescritura Rust ni dependencias nuevas: el trabajo medido se resolvió con señales y QtConcurrent existentes.
- Media: MediaSurface entrega MediaSession QObject estable con length/displayTime/remainingTime readonly. Fixture Wayland reproduce 34→0 cambios de identidad y reevaluaciones de título por ~1s, mientras avanza posición y seek. IslandMediaVisualizer evita cálculos ocultos 378→0; visible conserva 378/384 por diferencia de un frame. Overlay visible ligado a opacidad pausa brillo y libera CAVA en fullscreen, con reanudación/reduced probados. Cambios ajenos de grabación/personalidad conservados.
- CAVA: envelope duerme en cero exacto (38→0 publicaciones/600ms offscreen); ataque/release/resume/reset PASS. Descubrimiento escucha eventos y reconcilia cada30s, agrupa ráfagas y sigue clientes propietarios sin reaccionar a los propios clientes pactl. Primer intento de filtro generó feedback real y fue rechazado. Comparación final read-only15s, identidad sin resolver: CPU helper+hijos1.067%→0.067% de un núcleo; añade pactl subscribe ~1.4MiBPSS sólo mientras se pide CAVA. Mock6.5s:21→3 consultas más1suscripción. Integración fake activa cubre identidad, reroute, EOF/reconnect y cleanup sin capturar audio personal.
- Audio: DesktopStatus sustituye timer500ms de rebind por bindings/Connections nativos; default nodes notify y audio constante por nodo confirmados en qmltypes. Rebind/mute/hotplug simulados y fanout PASS. Caps Lock conserva polling1s por exactitud visible; sin fuente de eventos equivalente demostrada.
- Wpscan: scan asíncrono por poolQt existente, una tarea activa y último pedido pendiente, descarte stale, reentrada/destructor seguros. Warm1000: llamada85→1ms; warm10000:851→<1ms, gap heartbeat855→30ms; trabajo total849→871ms máximo, sin afirmar menos CPU/FPS. Biblioteca real35: llamada5→1ms. BuildRelease, lifecycle C++ (incluye worker bloqueado), thumbnails6invocaciones y benchmark8casos PASS. Callback grande aún convierte datos en UI.
- Integración: tras reinicio del equipo se perdieron /tmp; baseline recuperado exacto con402SHA originales. Archivo source-before.tar.gz conserva previos de código y caché persistente ~/.cache/isla-performance/2026-10-21/baseline. Módulo instalado en ~/.local/share/isla/qml/Wpscan, rollback ~/.local/state/isla-performance/2026-10-21/Wpscan-before. Shell1589→12806, stop/reemplazo/ConfigurationLoaded826ms; configuración conserva hash/dirtyfalse. Native map y hash verificados.
- Bug descubierto en restart: nmcli monitor1873 sobrevivió SIGTERM y quedó huérfano; eliminado sólo ese PID identificado. AboutToQuit nativo no cubre SIGTERM. Nmcli monitor usa helper10líneas, parentPID explícito, PR_SET_PDEATHSIG reutilizado y exec, sin supervisorPython. Prueba RED antes, PASS quit/SIGTERM/reload/evento/restart/mismatch; servicio existente PASS. Recarga activa reemplazó monitor12836 por20567, único hijo monitor de12806. Revisión independiente sin P1/P2 en todos los diffs, incluyendo esta corrección.
- Evidencia: docs/performance-2026-10-21/REPORT.md y subinformes/JSON/capturas/logs. Config/boundaries/calculator gate, settings IPC/editor/conflictos/guardado, clock/cava-center/swiftify/media-layout/timeline/rest-media y routing Wayland split/compact normal/reduced PASS; Qt6lint sin bloqueantes. Nuevas herramientas de medición y regresión documentadas en bar/TESTING.md; arquitectura actualizada.
- Límites: global antes45s19.62%CPU y PSS482729→486725KiB; después120s19.42% y329842→342998KiB, procesos y sesiones distintos por reinicio, no A/B atribuible. Fixtures de startup/RAM variables, sin ganancia demostrada. Sin FPS/potencia/GPU, horas de uso, hotplug físico, PAM o grabación/audio personales. Edots retenido y geometría/movimiento visible preservados. Seguimiento detallado de wallpaper Wayland y cierre final quedan en el informe de la fase.


## 2026-10-21 · Backend híbrido Rust para CAVA con comparación previa

- Usuario pide evaluar Rust implementando una parte concreta y verificar mejora antes de integrar; reafirma arquitectura híbrida. Se conserva QML/Qt para UI/animación y CAVA/parec para FFT/captura. Rust sustituye sólo orquestación Python. Sol/medium implementó crate y lifecycle; revisión independiente Sol/medium sin hallazgos; coordinador integra/mide. Sin extender migración a toda la shell.
- Baseline actual de siete fuentes congelado con SHA256 en docs/rust-cava-2026-10-21/baseline.json y baseline/. Primer ensayo Python previo pasa. Benchmark nativo con null sink privado inaudible y stream440Hz único, orden Python→Rust/Rust→Python por escenario, dos muestras12s tras1s warmup. Árbol helper+hijos; servidor compartido/productor excluidos. Sin mover audio personal/defaults; cleanup y defaultsPreserved PASS.
- Evidencia → decisión: unresolved PSS11,73→1,63MiB (-10,10MiB); activo28,60→17,32MiB (-11,28MiB mediano; núcleo estable del ahorro ~10,1MiB). CPU activa observada2,468→1,983% de un núcleo, mejora en ambas parejas pero no conclusión general con dos rondas. Ambos24bandas y60Hz; P95~16,8ms. Primera señal669/706→595/604ms. Memoria justifica promoción, sin prometer batería/FPS/arranque global. Fuentes/resultados/alcance en REPORT.md y comparison.json.
- Integración: rust/cava-stream (serde_json/nix/signal-hook/tempfile, Cargo.lock); bar/services/cava-stream.sh hace exec binario XDG_DATA_HOME/isla/bin/isla-cava-stream --parent QS_PID, o Python si ausente. Cava.qml cambia sólo comando. Python se conserva también por nmcli_monitor. No supervisor extra ni proceso en reposo sin consumidor. build-cava-helper.sh locked release y copia atómica; install.sh build opcional con cargo, fallback disponible sin toolchain. Cargo aislado local, sin cambios de perfil/paquetes. Binario449776bytes, hash fc1449e6…bda4, recompilación instalada idéntica al benchmark. Build cache fuera del repo.
- Aceptación → evidencia: Rust7unit/clippy-Dwarnings/release PASS; misma regresión Python contra Rust7tests PASS (unitPython+integraciónRust, identidad/reroute/descubrimiento/coalescing/reconnect/cleanup); lifecycleRust5tests PASS instalado (mismatch, TERM/KILL, propietario muerto, snapshot bloqueado, stdout saturado/BrokenPipe); backend argv/exec/fallback/atomicfailure + QML real fakeframes y Rust instalado unresolved PASS; envelope PASS; verify-config/sintaxis/diffcheck PASS. Revisión independiente validó privacidad/async/lifecycle con ensayos adicionales1–3ms de cancelación. No cambios Rust después de medir/revisar.
- Diferencias explícitas: silencio hasta2Hz frente~1Hz Python sin despertar envelope; hijos read-only SIGKILL+reap frente TERM/gracia; JSON8MiB y2s/consulta, líneas4KiB, salida acotada parcial+última. Rollback retirando binario y reabriendo consumidor. Fallo de un binario presente no activa fallback silencioso. Cambios ajenos de grabación/personalidad/etc conservados.
- Pendientes/límites: sin captura personal, horas de uso, batería/GPU/FPS físicos, multimonitor ni arranque global. Streams compartidos dentro de un cliente conservan límite anterior. Sólo trasladar otra función a Rust si se demuestra cuello de botella y beneficio específico.


## 2026-10-21 · Relevo: prototipo Rust audio-peak sin validar

- Usuario decide continuar optimizaciones generales Rust en otro chat. Mantener arquitectura híbrida y medición previa a promoción. CAVA ya está instalado y validado; sección anterior/documentación siguen vigentes.
- Siguiente candidato observado: audio_meter.PeakMeter.feed recorre muestras float32 en Python por fuente activa del panel de audio. Se empezó rust/audio-peak (cdylib sin dependencias, función C ABI isla_peak_f32_v1) y loader opcional ctypes en bar/services/audio_meter.py. Routing/controlador/envelope sin cambios. Conserva Python si biblioteca ausente/incompatible.
- Baseline copiado antes del cambio: docs/rust-audio-peak-2026-10-21/baseline/bar/services/{audio_meter,audio_bridge}.py. Crate nuevo y Cargo.lock existen; release construido en ~/.cache/isla/audio-peak-build/release/libisla_audio_peak.so. NO instalado en XDG_DATA_HOME/isla/lib, NO añadido al build/install; NO benchmark, unit/clippy, paridad ni integración de este prototipo comprobados. Loader actualizado aún usa fallback mientras no exista biblioteca instalada.
- Pendiente: revisar frontera unsafe/ctypes (array retenido, alineación, longitud, NaN/Inf, fragmentos), probar misma salida/envelope y fallback, medir CPU real con null sink privado usando audio-meter-timing.py como base, valorar overhead/RAM. Sólo integrar si beneficio comprobado; no asumir que será siguiente candidato definitivo. Implementación pequeña pendiente, no presentar como terminada.
- Se intentó delegar investigación; herramienta rechazó spawn y followup por límite de threads. No se simuló revisión independiente; próximo chat puede disponer de agentes nuevos. Muchos cambios ajenos existentes: conservarlos. No continuar ejecución en este chat por petición de relevo.

## 2026-10-21 · Audio peak Rust validado, integrado y cierre de procesos

- Objetivo inmediato completado: verificar y terminar o descartar el prototipo de audio-peak. Se preservaron cambios ajenos y modelo principal. Revisión independiente Sol/medium acotada a FFI, instalación, método y lifetime; sin hallazgos sustentados. No se extendió Rust a UI/controlador ni se añadió daemon/dependencias.
- Referencia → evidencia: baseline recibido de audio_meter/audio_bridge conservado y bridge idéntico verificado; prototype/ y reference.json congelados antes de editar. Comparación inicial completa en comparison-pre-lifetime.json; la definitiva se repitió tras corregir ownership, comparison.json complete/defaults_preserved=true, summary.json, sources.json y source-final.tar.gz en docs/rust-audio-peak-2026-10-21/.
- Decisión: integrar por CPU con coste PSS explícito. Cuatro rondas alternadas de12s/backend, calentamiento1s; bridge+descendientes, dos medidores del stream/monitor privado, tono1kHz float32LE48kHz en contrafase. CPU mediana3,366→1,249% de un núcleo (rangos3,079–3,496 /1,248–1,331); PSS13257→13354,5KiB (+97,5),4procesos ambos. Feed960 completo71,897→3,037µs; vacío empeora0,649→0,931µs por FFI, sin rama extra. Sin medidores CPU debajo de resolución3s,2procesos; no ahorro global demostrado.
- Latencia/cadencia: ataque mediano59,9→62,1ms, release522,1→541,7ms, máximos dentro200/900ms; publicaciones29,31→29,26/s. Sin mejora concluyente de latencia ni FPS físicos. No se extrapola ~63% CPU relativo del árbol a la shell o energía. Productor/servidor compartido excluidos y no se tocó reproducción, defaults, volumen ni audio personal.
- Implementación: rust/audio-peak conserva C ABIv1; guard de alineación usa is_aligned y añade test desalineado. ctypes retiene array propio en llamada síncrona; Python conserva fragmentos/endian/envelope. Rechaza nulo/desalineado/longitud excesiva, ignoraNaN/Inf; punteros arbitrarios siguen sujetos al contrato unsafe. Fallback por ausencia/dlopen/símbolo. scripts/build-audio-peak.sh release--locked, copia temporal0644+rename atómico XDG; install.sh intenta build opcional, conserva release previo ante fallo. README, arquitectura y TESTING actualizados.
- Instalación: ~/.local/share/isla/lib/libisla_audio_peak.so,269400bytes, SHA256c02d51815203d06ce7a1325446354afa33407178e8d7324fe053fe92f8fde5a1; recompilado coincide con lo medido. Loader por defecto PASS; no se reinició shell personal ni había bridges activos al check. Nuevos bridges usan Rust. Rollback reversible moviendo biblioteca a otro nombre y reabriendo panel, mantiene guard útil con Python.
- Hallazgo adicional real: fixture QML dejaba pactl subscribe huérfano después de morir bridge, también fallback y tras3s. Evidencia rojo QML y fake contra bridge original; sólo se limpiaron hijos de fixtures identificados por XDG temporal. Extraído die_with_parent existente a process_lifetime.py (guard LinuxSIGKILL+check padre); CAVA conserva alias público, Nmcli importa módulo ligero. Audio bridge protege sus3sitiosspawn con PID capturado antesfork. No se alteraron argv, routing, protocolo ni configuración; launchers siguen single-thread.
- Aceptación → comprobaciones: Rust2unit/clippyalltargets-Dwarnings/fmt PASS; audio-peak3paridad/fragmentos/floatbits/NaN/Inf/ausente-corrupta-símbolo PASS contra release instalado. Atomicinstall/XDGespacios/fallosbuild-copia PASS; audio-backend8 PASS. audio-lifetime5modos (stdinEOF,TERM,KILL,querybloqueadaKILL,servidorEOF) PASS, baseline rojo reproducido. QML controlador real native/fallback en monitor privado: snapshot,close/reopen,maps y cleanup PASS (offscreen, noQAvisual). CAVAPython7 y Nmcliquit/TERM/reload/race PASS tras extracción. Instalador15, sintaxis/py_compile/diffcheck PASS. Logs y review.txt preservados en validation/ e informe.
- Límites/pendientes: sin ahorro RAM, batería/GPU/FPS físicos/arranque global/multimonitor ni horas de uso. Escenario de2medidores no cuantifica uso diario. SIGKILL de bridge sí termina hijos; SIGKILL deQS durante consulta sigue dependiendo de stdin/terminaciónQS y timeout8s previo, no se certificaron todas sus fases. PunterosFFI sólo confiables dentro del contrato del array. No se eligió otro rewrite: siguiente optimización exige perfil concreto. Sin commits/merges/publicaciones, sin alterar diseño/configuración personal.

## 2026-10-21 · Inicio de evaluación Rust para lectura del portapapeles

- Objetivo: reducir latencia del panel/biblioteca mediante helper Rust sólo list, conservar escrituras Python y configuración/diseño. Evidencia inicial congelada en docs/rust-clipboard-list-2026-10-21/baseline/ y baseline.json; Python10muestras por0/100/1000entradas: medianas62,06/65,39/85,77ms. Sólo fixtures privadas, no historial personal.
- Requisitos → evidencia pendiente: validación/permisos/flock/formato → paridadCLI y revisión; beneficio → comparaciones alternadasCLI y disponibilidad de datosQML; build/rollback → atomicidad y ausencia de binario; cancelación → lockbloqueado sin hijos; integración → regresión QML de biblioteca privada. No promover por compilar.
- Orquestación: investigación Luna/medium acotada a paleta/fuzzy (sin evidencia para migrar, fueraUI/por defectoFzf); implementación Sol/medium del crate exclusivo, coordinador mide/integra y revisión independiente posterior según riesgo. Parser JSON Rust más estricto conserva compatibilidad con exec fallback Python ante error de parse, sin daemon ni escrituras nativas.

## 2026-10-21 · Biblioteca clipboard: Rust de lectura integrado y latencia medida

- Cierra la evaluación iniciada arriba. Se eligió sólo list de guardados: overheadPython observado incluso con0entradas; no reescribir persistencia ni toda la shell. InvestigaciónLuna/medium descartó migrar paleta/fuzzy sin perfil; implementacióncrateSol/medium y revisiónindependienteSol/medium, coordinadorcomparó/integró. Conservaron modelo principal y cambios ajenos, sin commits/publicación.
- Referencia: docs/rust-clipboard-list-2026-10-21/baseline/{fuentes} y baseline.json congelados antes de editar; clipboard_library.py sigue byte a byte igual. Entorno Rust/Cargo1.99.1, Python3.14.8, Linux7.2.9, fuentes y archive en sources.json/source-final.tar.gz. Toda biblioteca/historial de test sintética temporal; cliphist/wl-copy falsos para integración, sin acceder a datos personales.
- Decisión/beneficio → comparison.json válido/completo:20ejecucionesCLI/backend/tamaño en ordenalternado, QML2sesionesABBA×10lecturas. Medianas0/100/1000: CLI61,17→0,94 /41,24→1,26 /95,01→10,94ms; CPUrequest59,87→0,76 /40,23→0,95 /90,05→7,56ms. QMLdato listo39→3 /55,5→6 /65,5→14ms;1000rangoPython62–73/Rust13–15ms. Es disponibilidad del modelo con controlador real offscreen, no primerpixel/FPS/latencia general de shell.
- Memoria separada4runs/backend/tamaño, /proc despuésexec: en1000, mediana máximoPSSobservado11216→2654KiB yVmHWMobservado21652→4696KiB. Muestreo~0,5ms pierdepicos/perturbatiempo; nativo0/100apenas1–2muestras, no cuantificar ahorroPSS allí. ModeloQML retiene mismosdatos, sin demostrar ahorroresidente/global. Primerbenchmark relojint32QML overflow yru_maxrss heredadoharness: archivado INVALIDO explícito; instrumento corregido(double/proc postexec), comparación completa repetida. /usr/bin/time ausente; no se instalaron paquetes.
- Implementación: rust/clipboard-list (serde_jsonarbitrary_precision+nixfs ya cacheados), launcherexec bar/services/clipboard-list.sh; ClipboardController cambia sólo comando list. Directorio0700, metadata/lock0600, nofollow/tiposregulares, IDs/duplicados/referencias/digest/campos validados, snapshots verificados sin leerpayload. Flock exclusivo interoperablePython. Unknown/camposordenarray preservados; JSONparse/clavesescapadas/reservadas hacen execPythonconruta del launcher despuéssoltarlock; IO/validación nofallback. NaN/Inf/profundidad/enterosgrandes probados. BrokenPipe sinpanic/core; TERMlock sinhijos. Escrituras/snapshots no modificados salvopermisospreviosPython.
- Build/reversión: scripts/build-clipboard-list.sh lockedrelease cacheexterna, modo755, temporal+renameatómico, fallobuild/copia conserva releaseprevio. install.sh opcional juntoaudio/CAVA. Instalado ~/.local/share/isla/bin/isla-clipboard-list412376bytes SHA256abf7420a81e0e9c78b372f2d10897b425166142747aabe1857e81f51eb2b79fb idéntico almedido. Moverbinario aotronombre restauraPython siguientelectura. Sinreiniciar shellpersonal; controladorfuenteactualizado necesita cargarse/recargarse comoantes.
- Requisitos → validación:8unitRust/clippyalltargets-Dwarnings/releaseoffline-locked PASS según implementador (salidasentools sinlogspersistentes; comandos/resultados en validation/rust-checks.txt); fmt--checkcoordinadorPASS. CLI7testscontra instalado: paridad, inválidos, permisos/symlinks,lockPython/cancelación, JSONfallback/mismoPID,argv/BrokenPipe PASS. Backendfakes launcherexec/espacios/metacaracteres/ausencia yatomicidad/fallosPASS. Bibliotecapython9PASS. RegresiónQMLcompletacon fallback antesinstalar y nativo después: guardado/colecciones/filtros/wipe/reabrir/previews/copia exactatextoimagenPASS. Configgate/boundaries/calculadora e instalador15PASS; sintaxis/py_compile/diffcheckPASS. Revisiónindependiente sin defectossustentados; casosadicionales clavesraras ystdout cerradoPASS, sin repetirbenchmark/QML. Logs en validation/.
- Límites/pendientes: sin batería/FPS/arranqueglobal/horas/primerpixel, ni perfilde toda la shell. Fixturestextocorto hasta1000, falta cargasdocumentalesmuygrandes yhardwarepresentación; parsing/modeloJS yserializaciónwrites siguen. Formatosraros pueden pagarfallbackPython; PSSobservadonoes picoexacto. Siguiente cambioRust exige otro cuello de botella medido, no migrar porlenguaje. Informe: docs/rust-clipboard-list-2026-10-21/REPORT.md.

## 2026-10-22 · Edots: corregido lag al cambiar apartados, sin frontera Rust innecesaria

- Usuario reporta navegación lenta y autoriza Rust si beneficia. Repro actual Wayland muestra Apariencia38/76ms de intervalo driver; referencia congelada docs/settings-latency-2026-10-22/baseline/ + baseline.json. Hipótesis separadas: creacióncontroles, configuración y fuentes/animaciones. Fuente actual y evidenciaprevia de fluidez consultadas sin repetir auditoría global.
- Perfil: Luna/medium sóloSettings.js Node, updatecore0,071–0,098ms; despuésQt10series×100operaciones por ejecución~0,530/0,515ms medianas, sin cambioalgoritmo. Contadores privados en clones Config durante48transicionestotales:0snapshot y0validate ambosbackends. Navegación usa fieldSelection/entries; no se mueve configuración aRust porque no participa en coste observado. Config.qml/Settings.js/SettingsPage/EdotsWindow/EdotsPageMotion/StaggerItem iguales a hashesbaseline. No daemon/FFI/deps/procesos/configpersonal nuevos.
- Causa/cambio: SettingRow instanciaba Switch,slider,texto/choices aunque ocultos; además Restablecer/Personalizado existía sin modificación. ImplementadorSol/medium propietario sóloSettingRow usa Loaders por tipo y root.modified, conserva diseño/señales/validación/drafts/a11y y fontpickerlazy existente. focusEditor usa Loader.Ready/aliases. UIreviewSol/medium independiente comparó código ycapturas4loaderssin defectos; followupreset identificó incertidumbrefoco para probar.
- Regresión roja: harness `bar/tests/settings-navigation-performance.py --baseline-lazy-check` sobreclonantiguo con nombresdeobjeto de prueba falla por slideroculto de mediaTransitions. Ver baseline-red-before-0.txt. Inicialharnessrojo falló además por ausencia delmensajeoculto QtTest::fail; se añadió diagnósticoprevio yserrepitió. Primeraparcomparación4loaders coincidióconrojo: excluida pareja0conmotivoencomparison.json, no seusaencierre.
- Beneficio final → comparison-final.json/summary-final.json:2paresaisladosantes→después/después→antes,2ciclos6destinos/proceso,4máximos porapartado. Medianas delmáximodriver antes/después: Apariencia62,5→21ms (máximos70→23), Movimiento27,5→11,5, Tipografía32,5→16, Avanzado24→14,5. Perfil12→11 yComposición11→13,5 varían poco, no se presentanmejoras; peor pausa global70→23ms. EsFrameAnimationdriver noinput→pixel/GPU/FPSfísicos;23ms aún excede frame rápido. Benchfinal5loaders antes pequeñohelperdefoco (no se invocaalnavegar),funcionalfinalpruebaafectadarepetida.
- Validación: navegacióncold/warm/ausenciaeditores/modelosinintermedio/búsqueda/composiciónancha-estrecha/borradores/reduced/rápidoretargPASS. UXWaylandantes/después4loaders ylayout5loaders,1000×700/640×560 fuentes1/1,75,focuserror/picker/scroll/layoutPASS;16capturasporvariante,avatarfixture yISLA_CONFIGtemporal. Motionretarget/reduced/hidden yasyncPASS. ControlesWaylandpointer/keyboard/combo/customfont/texto/switch/slider/restaurarmódulosPASS. Test nuevoreset por teclado reproduceShiftTab inutilizable tras destruirbotón; root.restoreDefault desdecontextofilaemitereset+focusEditor lo corrige, testfinalreset/unload/Tab/ShiftTabPASS, controls-final.txt. MarkerPASS exigido porqueqs puedeexit0conTestCasefallido. QMLlintQt6exit0conavisos segúnimplementador; configintegrationtemporalPASSfase4loaders, backendintacto. Gate/sintaxisPython/diffcheckPASS.
- Evidencia/cierre: docs/settings-latency-2026-10-22/REPORT.md, sources.json/source-final.tar.gz, config-profile.json, logscomparison/validation yqa-before/qa-after/qa-final. Reviewscope/hash y límites enreview.txt. Bar/TESTING actualizado. SóloproducciónSettingRow; testcontroles ybenchmark nuevos, cambiosajenosconservados. No guardarconfigpersonal/reiniciarforzadamente/commit/merge/publicar.
- Límites: sin batería/CPU-PSSglobal/arranque/horas/AT-SPI/input→pixel, Hyprland yfuentesextraordinariamentegandes no perfiladosaquí. Se conserva coreografía aprobada. Otro trabajoRust exige cuelloreal, no sustituirQMLporlenguaje.

## Publicación GitHub · 2026-10-22

Commit e66a860 subido a origin/main (Edgardy715/egaldidots), 164 archivos: cambios acumulados de grabación/enfoque, UI y rendimiento, auxiliares Rust y pruebas. Capturas, informes y memoria permanecen locales según criterio anterior; se incluye baseline fuente de navegación requerido por su prueba. Validación actual: diff --check, verify-config, gpu-recording (11), cava-stream (7), brightness-service, nmcli-service e instalador (15) PASS. Cargo no disponible en PATH ni ~/.cargo/bin: no se repitieron tests Rust; sin nueva QA visual. Push confirmado d09ca29..e66a860.
## Eshell Pets — fase 3: música y wallpapers (2026-10-22)

Autorización de continuar por fases. MediaView/MediaSurface delegadas Sol medium:
ghost junto servicio conservando icono, mirada a portada, eventos play/pause/pista
sin art/seek. Coordinador integra contexto estable por monitor en IslandOverlay,
Pill/FluidCompanion/PillSurfaceHost y contrato petPresented/petEligible, exclusión
de legacy eyes. Wallpaper usa placa decorativa, mira miniatura actual/hover,
prioridad teclado, reacción selección y sólo éxito confirmado desde controller.
PetHost.notify/PetRuntime.notify acotados; resting mantiene ojos de pausa.

Requisito → evidencia: paths compact/split y≤1host, monitor, suspensión, ruta
rápida, aplicación fallida/confirmada/tardía, no consumidores CAVA añadidos →
pets-surfaces.py Wayland PASS con copia privada y servicios simulados. Rail,
sueño/wake, input/keyboard, sizes/scales yMediaView → pets.py3fixtures PASS.
Gate, media-source, compilePython/diffcheck PASS; lintQt6 exit0 con avisos dinámicos/
cualificación. Revisión independiente Sol medium sin hallazgos sustentados.
QA actual en docs/eshell-pets-2026-10-22/phase3/qa; informe REPORT.md ysources.json.
Detectado/corregido filtro de opacidad inexistente en PanelWindow antes de cerrar.

No comandos personales ni aplicación real de fondo; mocks conservan fuentes UI y
controladores reales. No nuevas medicionesCPU/PSS/GPU/FPS ni multimonitor físico:
baselinefase2 no certifica integración actual ytarget8MiB siguependiente. Próxima
fase4 blob/pulpo, superficies/comportamientos y alimentación explícita; fase5
paquetes/plantilla/validador/skill. Conservar cambios ajenos y aspecto aprobado.

## Eshell Pets — fase 2: sueño y baseline (2026-10-22)

Usuario acepta aspecto inicial y desea más superficies/comportamientos (dormir,
comer). Fase2 añade sueño local tras45s, ojos/cuerpo en reposo, dos respiraciones
nativas3,6s y quietud sin loop. Workspace/hover/foco despiertan desde breath actual.
Reduced/minimal estáticos; hidden/disabled descargan. Comer queda ligado a futura
acción explícita en host con espacio, sin alterar botón de navegación.

Requisito → evidencia: sleep/wake/cancelación/unload/input/escala → pets.py Wayland
PASS; lintQt6 y gate PASS; revisión independiente sin hallazgos sustentados.
Benchmark delegado Sol medium,2rondas invertidas/3,5s escenario, configs temporales,
fuentes estables y originales/logs: docs/eshell-pets-2026-10-22/phase2/performance/.
CPUquiet/hidden0observada; reacción8,425 y respiración9,275% núcleo; PSSincremental
+7,73/+9,55/+12,92MiB. Unproceso, driverp955ms/max8ms, noFPSfísicos. Target8MiB
noalcanzado en animación, conservado como pendiente. ExperimentoShape→SVGcache
repitió mismos2pares y empeoróPSS; revertido, datos performance-cached/ conservados.
Hash de3fuentes pets finales coincide con primer benchmark, snapshot verificado.

QA compositor directa sin bloom blanco, no modificar shader por artefacto Qt.
36muestras con timestamps, clip10,04s ampliado3×: phase2/sleep-wake.mp4; no todos
los frames físicos. Pruebas finales en phase2/qa-compositor/, informe phase2/REPORT.md.
Sin cambiar config/reproducción/workspace personales ni reiniciar shell. Próxima
fase3 música/wallpapers; pendiente presupuesto memoria sobre integración real,
multimonitor/hotplug físico, GPU/energía/FPS, comer/otros personajes/paquetes/skill.

## Eshell Pets — fase 1 implementada (2026-10-22)

Autorización de continuar el plan, alcance por fase. Primer host resuelve espacio
mediante icono del botón abrir workspaces: fantasma original, acción/hit target
existentes, sin paseo sobre números. PetHost/PetRuntime/GhostPet en bar/pets;
IslandCompanion admite color de ojos. Composición filtra monitor activo y retira
ojos anteriores sólo mientras pet visible; hidden/sin espacio/disabled descargan.
Configuración por agente Luna medium: Settings/Config/Edots/example/tests; añadido
grupo pets y sección, actualizado índice Hyprland y callers a7.
Revisión independiente Sol medium sin defectos sustentados.

Requisito → evidencia: configuración/persistencia/editor → settings.cjs y
settings-integration.py PASS con config temporal; navegación → hyprland UI PASS;
input, bursts, reduced/hidden/unload/tamaños/escala → pets.py Wayland PASS;
monitor/composición/fallback/compact-split → fixture IslandOverlay real PASS;
boundaries/config/calculadora → gate PASS; QML nuevo → lintQt6 sin diagnósticos.
Capturas inspeccionadas en docs/eshell-pets-2026-10-22/qa; informe REPORT.md.
Sin modificar config personal ni reiniciar shell. Fase2 pendiente: CPU/PSS/frame
times, grabación movimiento, contraste bloom del indicador split observado en
capturaQt con compositor y multimonitor físico. No paquetes externos/media/
wallpaper/otros personajes/skill aún. Plan actualizado y siguiente paso fase2.

## Eshell Pets — planificación acotada (2026-10-22)

Petición actual limita el adjunto de implementación a planificar con consumo
contenido. Plan: docs/ESHELL_PETS_PLAN.md. Inspección selectiva de arquitectura,
Settings/personality, IslandCompanion, TopWorkspaceRail y WallpaperSurface;
guías ahorro-tokens, segundo-cerebro, Quickshell, Ponytail y Fluid aplicadas.
Propuesta: runtime opcional, hosts locales, una mascota visible, fantasma primero;
continuar con media/wallpaper, otros personajes, paquetes de datos y skill.
QML externo arbitrario incompatible con restricción de servicios sin aislamiento.
Sin código funcional modificado ni tests/QA/mediciones ejecutados. Pendientes:
geometría libre, convivencia personality y esquema final de paquetes al implementar.



## Eshell Pets fase4 — personajes y personalización (2026-10-22)

- Tres personajes → bar/pets/BuiltinPet.qml, mismo runtime/host; fantasma conserva
  silueta original. GhostPet sustituido por BuiltinPet, sin duplicar ojos/motores.
- Superficies/behaviors → Settings.js/Config existente/Edots: ocho booleanos nuevos,
  defaults true y enabled false; context estable y rail reciben todos los campos.
- Comer → botón explícito accesible en cabecera MediaView, nombre del usuario;
  cuatro masticaciones/1,6s, no reinicio por clicks, minimal/reduced estático,
  ocultación/deshabilitar/cambio de perfil cancelan. Input previo conservado.
- Evidencia → docs/eshell-pets-2026-10-22/phase4/REPORT.md y qa. Pets3fixtures y
  superficies reales compact/split Wayland PASS; persistencia/editor14campos,
  gate/lintQt6/diff PASS (warnings dinámicos/preexistentes); revisión independiente
  sin defectos sustentados. Capturas compositor9estados inspeccionadas, no FPS.
- Pendiente → fase5 paquetes/plantilla/validador/skill, fase6 matriz/rendimiento.
  Sin nueva medición de recursos, targetPSS8MiB sigue pendiente; sin multimonitor
  físico ni cambios en sesión/config/media/wallpaper/workspace personales.

## Claude local — 2026-10-22

Configurado CLAUDE.md con import de AGENTS.md, rutas a memoria y contexto selectivo.
.claude/settings.local.json añade bóveda, skills locales y token-economy; excluido localmente de Git.
Claude Desktop: ~/.config/Claude/claude_desktop_config.json conserva preferencias y añade
MCP edotsShell con Node absoluto y server-filesystem 2.0.0 instalado en
~/.local/share/claude-edots-mcp. Alcance: proyecto, bóveda Isla, ~/.codex/skills,
~/.agents/skills y ~/.codex/token-economy. Copia previa en ~/.local/share/claude-edots-backup/.
Verificación MCP real por stdio: initialize, tools/list, lecturas de CLAUDE.md, mapa,
Inicio.md y skill segundo-cerebro; rechazo /etc/hostname. No se ejecutó inferencia
ni se reinició Desktop: integración UI pendiente de reinicio. Modelo personalizado
preexistente conservado; no se probó autenticación/proveedor. Cambios funcionales ajenos intactos.

## Memoria: índice breve y archivo de fases — 2026-10-22

PROJECT_MEMORY.md pasa de 18127 a ~3,3 KB (índice: estado activo, contratos, recuperación);
mapa previo íntegro en docs/PROJECT_MEMORY_ARCHIVE-2026-10-22.md. TASK_STATE.md (369288 B,
241 encabezados) se parte sin cambios: docs/TASK_STATE_ARCHIVE-2026-09.md (líneas 1–1235),
docs/TASK_STATE_ARCHIVE-2026-10-01_13.md (1236–3392) y aquí desde 2026-10-14. Cabeceras nuevas
terminan en `<!-- fin-cabecera-archivo -->`; sin ellas la concatenación es byte a byte igual al
original y la secuencia de encabezados coincide (script de verificación PASS). recall.py añade
ARCHIVE_GLOBS (docs/TASK_STATE_ARCHIVE-*.md) a sus fuentes por defecto; los PROJECT_MEMORY_ARCHIVE
siguen vía `--file`. test_recall 6/6 y token-economy 24/24 PASS; consultas compacta densa,
grabación directa, gotas, wallpaper y lockscreen devuelven secciones archivadas y recientes.
Fichas de la bóveda regeneradas con tools/brain.py. Límite: el bloqueo de lectura completa del
mod isla-ahorro no cubre aún docs/TASK_STATE_ARCHIVE-*.md.

## Auditoría Claude: animación, transiciones y bugs — 2026-10-22

Informe en docs/claude-audit-2026-10-22/REPORT.md (mapa, hallazgos F1–F6/A1–A5/R1–R3,
propuestas P1–P5). Corregido: contenido retenido al redimensionar la misma surface
(`contentHeld` en PillMorphMotion, liberado al cerrar/cambiar/notificar/volver a reposo;
el launcher ya no vacía el campo al escribir); cerrar con swap pendiente no devuelve
swapOpacity; `fullscreenHide` único para pill y gotas en IslandOverlay (reduceMotion directo);
hold de notificación sin escalar (1000/2000); respiración continua (`holdLevel`, sin Behaviors
de 300 ms en IslandNotification); la lista del launcher hereda la altura de la pill sin Behavior.
Fixtures nuevos con A/B: content-hold, surface-swap-close, notification-breath (offscreen) y
fullscreen-hide (Wayland). Revisor independiente: un defecto (fase 2 del launcher), corregido.
QA en vivo: launcher antes/después y swap-close (docs/claude-audit-2026-10-22/qa/). Sin QA en vivo:
fullscreen real y respiración con notificación real. recording-drop-regression no emite resultado
aquí. No decidido: P1 SmoothedAnimation internas, P2 tokens literales, P3 peek, P4 amplitud,
P5 descarga del launcher.

## Cuello GPU de gotas — 2026-10-22

Petición: tragar/expulsar gotas (media, grabación, sesión, settings) más fluido,
discreto y limpio, con menos CPU/memoria. Evidencia: docs/drop-neck-2026-10-22/.

Decisiones:
- FluidMetaballBridge (CurveRenderer, barra opaca, teselado CPU por frame) y la
  OpacityMask inversa (nunca renderizaba: vidrio doble) salen de FluidCompanion.
- `bar/fluid/FluidNeck.qml` + `shaders/fluid_neck.frag`: smin de SDF rounded box
  pintada fuera de ambos cuerpos, recortada al casco convexo exacto (ternaria
  14 pasos), material por extremo fundido por d1/(d1+d2).
- `shaders/fluid_cut.frag` como layer.effect smooth del módulo: recorta la parte
  dentro de la pill mientras solapa unida o en fase transitoria (no asentada,
  para no cortar una tarjeta centrada en reposo).
- Bordes AA contiguos compensados x=(1-c)/(1-c·a) en cuello y recorte.
- edgeClearance: halo/borde/brillo de la gota a 0 en los 7·s previos al contacto.
- PillMaterial: sombra sin layer/MultiEffect con opacidad 0; TopWorkspaceRail:
  lente integrada sin MultiEffect inerte. Rust innecesario: el coste era CPU de
  teselado, ahora GPU por fragmento en el bbox del cuello.
- Apertura de surfaces sin tocar: PillMorphMotion ya conserva velocidad y tiene
  trabajo local ajeno; P1/P2 de la auditoría quedan como seguimiento.

Revisión isla-revisor: 1 media (columna recta en centrada) y 4 bajas (halo
cortado por el layer, material copiado de la gota, layer sin smooth, gota ancha
solapando sin cut). Todas corregidas y revalidadas con fixtures Wayland
(derecha, izquierda, centrada, animación real 25 ms/cuadro).

Pruebas: absorption, centered-companion, companion-continuity, media-motion,
session-companion y settings-companion PASS (offscreen: lógica, no QA visual);
fullscreen-hide PASS en Wayland; qmllint sin avisos nuevos.

Límites: un reload no recarga .qsb cacheado (reiniciar quickshell tras
recompilar shaders); costura residual 2–4 niveles; tono de 1 px del InnerGlow;
QA en vivo con grim ~16 fps no resuelve los ~150 ms unidos; recording-drop
termina sin salida (ya registrado arriba). `bar/fluid/FluidNeck.qml` y
`bar/fluid/shaders/` están sin seguimiento en git: añadirlos al commitear.


## Gotas: brote y recogida sin «cuadrado» — 2026-10-22

Usuario: al salir y regresar la gota «se ve como un cuadrado»; pidió reproducir
settings o una gota con canción simulada. Captura real con grim ~60 fps
(docs/drop-gather-2026-10-22/tools/cap.sh) mostró tarjetas unidas a la pill hasta
~500 px y entrando más anchas que ella; luego, con retorno a cápsula de pill,
un trapecio de fondo plano por el casco del cuello.

Cambio sólo en FluidCompanion: fases `brotando` (yema moduleH separada antes de
florecer) y `recogiendo` (tarjeta → yema, returnHome bajo gatherSize 66·s);
returnW = returnH (retorno redondo; revierte «cápsula inscrita» 2026-10-12, cuyo
problema era el editor visible encogiéndose, ahora ya desvanecido); cardRadius
con size² para que una tarjeta vacía media sea mancha. Tests centered-companion
y companion-continuity adaptados conservando su intención.

Media probada con MPRIS falso mudo `islasim` (tools/fake-mpris.py), sin tocar
la reproducción real. Offscreen PASS: absorption, centered-companion,
companion-continuity, media-motion, session-companion, settings-companion;
Wayland PASS: recording-drop, layout-interruptions. Evidencia y límites en
docs/drop-gather-2026-10-22/REPORT.md; MOTION_LANGUAGE «Brote y recogida».

Revisión isla-revisor: grave (reabrir durante retorno/absorción florecía unida
hasta 601×425) y menor (bodyBusy saltaba la yema); ambos corregidos con bloom()
único y salida de brotando por stretch ≥ 1.30; regresiones y QA en vivo de
reapertura repetidas PASS.

## 2026-10-22 — CPU en reposo: InnerGlow a 240 Hz

- Causa: `InnerGlow` (pill en reposo, workspace activo, GlassCard) avanzaba la deriva con
  `FrameAnimation`, forzando render a la tasa del monitor (DP-1 240 Hz) sin interacción.
- Cambio: Timer 83 ms (12 Hz) con dt real (tope 250 ms); deriva ~5 px/s en degradado difuso,
  paso <0.5 px, invisible. Pausa/reduceMotion/reanudación sin salto se conservan.
- Medido A/B en sesión real, arranque limpio, sin media: qs 20–25% → 3.7–4% CPU; RSS igual (~450 MB).
- Pruebas: inner-glow-regression PASS. qml-performance-regression FAIL "overlay objects available"
  en la búsqueda inicial de objetos, ajeno al glow (no verificado si ya fallaba antes).
- Pendiente: RSS creció 450→588 MB en 28 min de uso (posible caché de imágenes/fuga, sin medir);
  Cava (FrameAnimation + Spectrum.advance JS + array nuevo por frame), ondas de MediaTimeline/
  SwiftMediaTimeline y giro de MediaTransportButton corren a 240 Hz con música: candidato a
  reloj ambiental 60–120 Hz o envolvente en rust/cava-stream. Bucle de binding en Players.active.

## 2026-10-22/23 — Rendimiento: relojes compartidos, Players y límite de memoria

- Encargo: `docs/performance-2026-10-22/PROMPT_SOL.md`; resultado/evidencia en REPORT.md
  de esa carpeta. P1/P3/P4 cerrados; **P2 no cerrado**: no declarar estabilidad PSS.
- P1 `f63ee86`: AmbientClock/Subscription (default60Hz, Settings/Flags/ejemplo,
  rango30–240, dt50ms), CAVA/ondas/giro; interacción conserva motores. Base local
  guardada, configuración/estado temporales, ABBA con Spotify. Ronda base limpia
  pill29,50%/media32,58% → A13,25–13,50%/16,50–16,83%. Primera base exploratoria
  tuvo solape con compilación y no sostiene la atribución. Arrays siguen notificando.
- B Rust sólo experimental: 82 parse/600 advance contra JS,10 unit tests,
  clippy/release locked y5 lifecycle PASS. CPU árbol A17,83–17,86% frente a
  B19,41–21,73%; se conserva A. Sin instalación ni cambio de fallback. Datos,
  protocolo y reproducción en rust-experiment/. Los12 PID de captura de las rondas
  desaparecieron al cerrar sus qs.
- P3 `fe6229b`: glows locales12Hz desfasados generaban ~48 renders/s. GlowClock
  comparte83ms/dt250ms; conserva aspecto y velocidad. A/B limpio sin música y sin
  logging:4,25–4,42%→2,58% CPU (40,4% media). Logging separado578→288 renders/12s
  (~48→24/s), no FPS físicos; efecto añade trabajo tras cada tick12Hz. Control sin
  glow sólo en copia:0,08–0,92%. No se desactivan efectos en producción.
- P4 `f5634a2`: onActiveChanged consulta active.isPlaying en vez de playing cacheado.
  Regresión base roja con dos loops exactos; corregido verde. Prioridad intacta.
  >5min de sesión con40 pistas/40 notificaciones y aperturas sin binding loops.
- P2: pss-watch reutiliza lector /proc existente, JSONL cada30s y self-test. Dos
  tandas de20 por media/wallpaper/launcher/pistas/notificaciones/Edots. PSS normal
  323,16→381,34MiB en8,6min; gc no lo resuelve. Tres tandas instrumentadas de20
  media+launcher vuelven a2542 nodos y un consumidor, sin acumulación visual.
  Primeros perfiles truncados por SIGTERM; harness corregido a Qt.quit. Perfil
  válido4,2M asignaciones: JS vivo tras gc6,27→6,29MiB, insuficiente para explicar
  crecimiento nativo. No atribuirlo a caché GPU sólo por descarte. Dos vías
  diagnósticas evaluadas; pendiente perfil nativo/fragmentación/recursos de render,
  sin parche especulativo ni falsa regresión de estabilización. Crudo .qtd.gz y
  resumen reproducible conservados; PSS con profiler no comparable al normal.
- QA: usuario confirma continuidad60Hz y brillo común suave/mismo aspecto;
  composición final inspeccionada en final-media.png. Final limpio con ambas
  mejoras:12,50% pill musical/17,83% media. No son muestras universales de música.
- PASS: configuración/boundaries/calculadora, ambient-settings/reloj (cadencia,
  dt, reduced, pausa, destrucción y proveedor), inner-glow, CAVA envelope/stream,
  Players, PSS; Wayland timelines/transporte/media-clock/session/motion/morph.
  Revisión independiente de relojes/providers/Players sin defectos sustentados.
  qml-performance.py falla igual antes/después: su reemplazo de prefijo id:overlay
  también modifica overlayPets y produce id duplicado; fallo previo documentado.
  qmllint255 sin diagnóstico, no contado como pase. Logs en validation/.
- Se conservan cambios ajenos (incluidos hunks previos Settings/ejemplo/comentario
  InnerGlow) fuera de commits; sin push. Config personal comprobada por hash sin
  cambios; copias temporales sólo para ensayos. Producción reiniciada con código
  final y Spotify Playing. No se certifican memoria estable, GPU/potencia ni horas
  de uso. Mapa breve actualizado; bóveda se regenera una vez al cerrar.

## 2026-10-23 — Pendiente de memoria: jemalloc y registro autónomo de uso normal

- Usuario pidió verificar pendientes y después prefirió logs locales para no
  mantener el modelo activo durante2h. Se deja recolector finito sin API de IA ni
  wakeup/automatización: bar/tests/session-soak.py, PID552155, qs545318, máximo7200s,
  intervalo30s. Datos/estado en docs/performance-2026-10-23/normal-use-01/.
- Inicio04:38:50UTC (00:38:50 Santo Domingo); self-test y ensayo integral2s/3muestras
  PASS. PID/starttime protegidos; salida al acabar qs/reutilizar PID, logs de shell
  start/end para posibles recargas. IdleHint sólo orientativo; no afirmar dos horas
  de interacción por tiempo transcurrido. Registro confirmado running con datos.
- Hallazgo: qs enlaza jemalloc5.4.0 (Use jemalloc ON), no asignador principal glibc.
  Intento GDB con malloc_stats/trim0 descartado e interrumpido; cleanup restauró
  shell normal. No usar sus ceros para descartar fuga. Siguiente sonda: jemalloc
  epoch/allocated/active/resident/retained frente a smaps, sin purga especulativa.
- GPU pmon ofrece VRAM por PID; SM '-' es null/no medible, no0. Datos crudos del
  intento, entorno y límites en REPORT.md del10-23. No atribuir potencia global a qs.
- No se cambió código de shell/diseño/config real ni se avanza reproducción. La
  estabilidad PSS y el ensayo de horas **siguen sin cerrar** hasta revisar logs.
  El usuario puede volver con «analiza los logs»; no se programa análisis con IA.

## Rendimiento: Caps Lock sin hyprctl y colector con swap (2026-10-23)

- Análisis de normal-use-01 (~1h45): CPU coincide con Sol (13,4 % reproduciendo,
  2,8 % en pausa). La caída de PSS de 230 MiB (min 52–57) fue swap a zram, no
  liberación: qs llegó a SwapPss 156 MiB. El crecimiento (~2,3 MiB/min reproduciendo,
  ~1,6 MiB por pista) sigue abierto; experimento propuesto: normal / sin CAVA /
  jemalloc `background_thread:true,dirty_decay_ms:1000`.
- DesktopStatus: `hyprctl devices -j` por segundo (~5,5 ms CPU, ~9,6 KB JSON;
  ≈0,5 % CPU de hijos constante) sustituido por lectura de
  /sys/class/leds/*::capslock/brightness con FileView a 250 ms (OR entre teclados,
  redescubrimiento a 2 s si un LED desaparece) y eventos activelayout/submap.
  hyprctl queda sólo como respaldo si no hay LEDs (`capsLockSource`).
  Regresión bar/desktop-status-capslock-regression.qml con LEDs falsos PASS offscreen.
- Colector: sample-process.py añade Pss_Anon/Pss_File/Swap/SwapPss; session-soak.py
  añade pss_with_swap_kib, descendientes vivos (nombre, CPU, PSS, SwapPss) y
  tree_cpu_percent. Self-tests PASS; smoke 4 s contra qs real PASS (vio `nmcli`).
- No verificado: la shell viva no se reinició con el nuevo DesktopStatus (el
  colector de Sol sigue con el módulo viejo); falta medir el coste real y pulsar
  Caps Lock en vivo. Sin commit.
- Medición viva: qs 545318 recargó en caliente el nuevo DesktopStatus (~06:23 UTC,
  una recarga intermedia falló por Players.qml y se recuperó). CPU de hijos 0,45–0,48 %
  → 0,0 % (60 s, pausa; qs 2,96 %, sólo `nmcli` vivo). El registro normal-use-01
  queda contaminado por esas recargas desde ~06:23. El usuario confirmó en vivo
  que el indicador Caps Lock se enciende y apaga correctamente.

## Auditoría de animaciones y microinteracciones (2026-10-23, Claude)

- Alcance: toda la shell (pill/surfaces, barra superior, OSD, bloqueo, Edots,
  notificaciones, calendario, overview, portapapeles, media, conectividad).
  Contrato nuevo en bar/fluid/MOTION_LANGUAGE.md «Microinteracciones coherentes».
- Primitivas: ErrorShake (sacudida de error compartida: bloqueo, AuthPrompt),
  SpinSettle con `settling` y Motion.spinner, MotionList.revealIndex (desliza
  contentY con standardSmall; posicionamiento directo con reduceMotion/oculto).
- Decisiones: indicador de selección compartido que se desliza (launcher,
  calendario, overview, workspaces) en vez de fundido por celda; paginado lateral
  (calendario mes, overview grupo de espacios con slots fijos); etiquetas que sólo
  cruzan en cambios discretos (contador de WifiCredentials sin crossfade por tecla);
  peso tipográfico constante en selección; sin doble suavizado (opacidad ligada a
  progreso, no Behavior extra); sin fundidos de montaje (ClipboardChip);
  Slider mantiene el valor arrastrado 300 ms al soltar (sin rebote);
  NotifCard recorta sólo durante el cambio de tamaño; swipe para descartar
  notificaciones con retorno elástico; OSD con valor suavizado y origen superior.
- Edots: búsqueda y foco de error diferido hasta que la búsqueda está visible
  (`pendingErrorFocus`); ComboBox con transiciones de popup; validación con fundido.
- Revisión independiente (isla-revisor) aplicada: snaps de overview al abrir y al
  cambiar grupo, slot persistente del calendario, Slider hold, iconos de giro hasta
  asentar. Hallazgo 8 (resultado de búsqueda Hyprland antes de searchShown) no
  aplicado: hyprland-settings-regression sólo espera 100 ms.
- Pruebas offscreen PASS: overview, calendar-data/media, weather-view,
  notifs-surface, notification, settings-motion/ux/regression, wallpaper-view,
  connectivity-design/surface, interaction, neon (OSD), quick-controls,
  mixer-surface, clipboard-interaction/preview-jobs y los 3 arneses
  bar/tests/clipboard-*.sh. Fallos que también ocurren en HEAD: clipboard-design
  «Escape returns focus», clipboard-library por qml directo (pasa con su arnés),
  hyprland-settings «revert». settings-navigation deja un quickshell offscreen
  vivo que retiene la tubería (también en HEAD); matarlo manualmente en barridos.
- Shell viva recargó sin avisos tras los cambios (la recarga fallida por
  Players.qml:128 fue transitoria y ajena).
- Comparación completa contra HEAD (git archive, revert por archivo en paralelo):
  personality fallaba sólo en el árbol: el Behavior de color de MaterialIcon
  animaba al crear cientos de iconos y alteraba el arranque (OSD showMic →
  VolumeChip en reposo → la pill encogía bajo el puntero). Corregido con
  `enabled: ready && visible`. swiftify-media fallaba por dos cambios de media:
  capa de brillo en líneas vecinas (revertida: el contrato es «la línea anterior
  deja de brillar» y ahorra GPU) y el fundido de letras, que mantiene visible la
  vista al cerrar; LyricsView expone `open` (MediaView lo enlaza a `shown`) y
  reabrir restaura el seguimiento sin esperar a que cambie la visibilidad.
  Todas las regresiones media/lyrics PASS. También fallan en HEAD: cava-envelope,
  lyrics-controller, matugen-palette, media-palette-recovery, top-system-status,
  wallpaper-apply-protocol/scanner/source; media-dock-surfaces requiere Wayland.
- No verificado: QA visual/en vivo de gestos (swipe, arrastre de Slider, paginado),
  sensación de tiempos. Sin commit.

## Pulido visual de surfaces (2026-10-23, Claude)

Petición: analizar el diseño y mejorar lo que no esté a su máximo estético, sin
rehacer lo aprobado. Auditoría con capturas vivas (grim DP-1) de todas las surfaces.

- Tipografía: `Theme.fontNumeric` ({tnum:1}); cifras de BatteryChip, AppearanceView,
  NotifCardView, NotifsView, OsdOverlay, VolumeChip, contador de WallpaperView,
  AudioEndpoint y WorkspacesView pasan de monoespaciada a Theme.font+tnum. Reloj:
  hora de un dígito ya no reserva hueco de dos (widthSample).
- SurfaceHeader: título 22 px DemiBold sin icono (se retiraron los iconName).
- QuickControlsView reescrita como Centro de control: cabecera «Ajustes rápidos» +
  cápsula «Apariencia»; dos tiles 92 px (Mantener activa, Actividades → focus);
  brillo como slider ancho 30 px con sol que cambia de color al cubrirse (rueda/
  flechas ±5; quitados −/+); Energía con segmentado de acento deslizante. Cabe en
  360×420 (antes desbordaba y escondía el acceso a enfoque).
- CalendarView: fines de semana sin bloque de fondo (sólo cifra atenuada);
  ubicación+estado del tiempo en una línea; previsión con barra de rango
  (forecastRange) entre mín./máx. tabulares; «Ahora» en cápsula; nada a 9 px.
- FocusTimerView: alineada con Grabación. Cifra grande centrada (fontMedia, tnum),
  chips cápsula 15/25/45 + campo «✎ Otro» (no repite la cifra del atajo; al
  enfocarlo selecciona todo), botón primario píldora 52 px y cancelar redondo
  «stop», nota al pie (rango válido en acento si el valor es inválido).
- ClipboardEntryRow: acciones (vista previa/Guardar) aparecen sólo con hover,
  selección o foco, con fundido+desplazamiento 6 px; la columna sigue reservando
  su ancho (sin saltos de texto).
- WallpaperView: «Fondo actual» sólo en la insignia de la imagen; el botón pasa a
  «Aplicado» con check en tinte de acento (no relleno apagado) y el subtítulo dice
  «Ya es tu fondo · ← → para explorar otros».
- Pruebas offscreen PASS: quick-controls (actualizada: flechas en vez de −, y
  alcance de openFocus), calendar-data/media, weather-view, focus-session,
  mixer-surface, notifs-surface, pill-interface, wallpaper-apply-feedback/
  media-header/surface/view/regression, clipboard-interaction. qmllint sin errores;
  git diff --check limpio. Fallos clipboard que también ocurren en HEAD:
  clipboard-regression «clipboard entries», clipboard-design offscreen (PASS en
  Wayland), clipboard-library timeout por qml directo.
- QA en vivo (capturas): ajustes rápidos, calendario, enfoque, portapapeles,
  fondos, notificaciones, sonido. No verificado: sensación de la aparición de
  acciones del portapapeles al pasar el puntero; contraste de «Aplicado» con
  paletas muy oscuras. Sin aprobación del usuario aún. Sin commit.

## Lenguaje líquido de surfaces (2026-10-23, Claude)

Petición: el pulido anterior «se ve casi igual»; quiere un cambio visual claro
que conserve la identidad (gotas, morph, vidrio, Matugen), sea fluido y
personalizable. Prototipo en Ajustes rápidos y Calendario antes de extender.

- Ajustes (Settings.js → Flags → Edots y AppearanceView): `appearance.liquidSurfaces`
  (bool, true) y `appearance.stateIntensity` (0.3–1, 1). Theme: `liquid`,
  `stateFill` (acento×intensidad), `stateFillLight` (Qt.lighter 1.14),
  `onStateFill` (primaryContent si intensidad ≥ 0.6, si no foreground),
  `onStateFillSecondary`.
- Piezas compartidas nuevas: `LiquidFill` (el activo nace del círculo del icono:
  ancho adelanta al alto, radio de gota → radio del contenedor, degradado de luz
  cenital y menisco; `covered` decide cuándo cambia la tinta del texto) y
  `LiquidSelection` (bordes animados por separado: el delantero llega en ~180 ms,
  el trasero en ~380 ms; retargetea sin saltos; `volume` opcional). Las
  propiedades se llaman edgeLeft/… porque left/right son FINAL en Qt 6.12.
- Toggle: el botón se alarga hacia el destino al viajar; pista con volumen.
  Slider: `minFill` (en 0 % el relleno es una gota) y menisco de arrastre
  (±6 px que se relaja en 60 ms); en modo líquido sin capa de brillo.
  GlassCard y cápsulas sin contorno en modo líquido.
- QuickControlsView: tiles con LiquidFill; brillo 36 px con el sol dentro de la
  gota y cifra grande DisplayLg+tnum que sigue el arrastre (el «%» va aparte,
  fixture actualizada a "47"); perfil de energía con LiquidSelection.
- CalendarView: selección = LiquidSelection (se estira entre semanas; sin pop
  en modo líquido), hoy con stateFill+volumen, flechas sin contorno.
- Modo clásico intacto con liquidSurfaces=false (comprobado con fixture visual).
- Previsualización: arneses con estado simulado en el scratchpad
  (qc-preview.qml, cal-preview.qml, import "file:…"), grabToImage offscreen
  sobre fondo opaco; la capa MultiEffect del slider clásico no se dibuja
  offscreen. La shell real no tenía estados activos (sin perfil de energía ni
  brillo legible), así que la animación no se vio en vivo.
- Sin commit. Pendiente de aprobación antes de extender a mixer, conectividad,
  notificaciones, launcher, etc.
- Pruebas offscreen PASS: config, settings, settings-controls, settings-ux,
  settings-motion, surface-data-contract, quick-controls, interaction-surfaces,
  microinteraction, connectivity-design/surface, mixer-surface, notifs-surface,
  focus-session, calendar-data/media, weather-view, wallpaper-view,
  recording-view, pill-interface, input-motion; node tests/settings.cjs PASS.
  settings-navigation se cuelga/crashea al ir a la página 4 también en un árbol
  HEAD limpio (git archive): previo, no causado por este cambio.

## App de ajustes Edots con lenguaje líquido (2026-10-23, Claude)

- Petición: que la mejora se note en la interfaz; se rediseñó la app Edots
  completa con el lenguaje líquido, sin tocar defaults ni modelo de ajustes.
- EdotsWindow: con ancho ≥860 y fontScale ≤1.35, raíl lateral (196 px) con
  LiquidSelection `settingsNavSelection` (flechas ↑/↓); si no, pestañas arriba.
  Cabecera de página con insignia stateFill + título display 26. Pie en tarjeta
  con LiquidFill `settingsSaveFill` que sale de Guardar cuando hay cambios
  pendientes; botones con `onFill` cuando el relleno los cubre. Motion studio
  visible con contentWidth ≥660.
- SettingRow: filas agrupadas por sección como tarjetas (radios sólo en los
  extremos, separador interior), punto de «modificado» que entra con resorte,
  Restablecer en línea. Opciones = control segmentado con LiquidSelection;
  `selectedChip` usa `chipRevision` (onItemAdded/Removed) porque itemAt() no
  notifica y la gota no aparecía en vivo. Slider líquido: tubo 26/28/30 px,
  relleno mínimo una gota, botón onStateFill translúcido dentro del extremo,
  valor en cápsula tnum que se llena al arrastrar. Interruptor con gradiente
  y botón que se estira.
- EdotsButton: `onFill`; botón acento con volumen y sin borde en modo líquido.
- QA en vivo (`qs -c bar ipc call island settings`, grim DP-1): raíl, filas,
  segmentado, sliders y pie comprobados tras corregir la gota del segmentado y
  suavizar el botón del slider. No se comprobó en vivo el estado con cambios
  pendientes (habría que modificar la config real).
- Offscreen PASS: settings, settings-controls, settings-ux, settings-motion,
  module-composer. settings-layer-picker y settings-async necesitan Wayland.
  settings-path-picker no imprime veredicto (igual con copia base; probable
  previo). hyprland-settings falla en «revert»: tras Config.discard() la
  fixture cambia a la página 7 y pulsa a los 50 ms, cuando el bloqueador de la
  transición de página aún intercepta; con wait(700) avanza y cae en «search
  opens page». EdotsPageMotion tiene cambios ajenos sin commit e incompatibles
  con su versión HEAD, así que no se pudo aislar. No atribuido a este cambio,
  sin verificar.
- Sin commit.

## Eshell Pets: rediseño pixel art, propuesta (2026-10-23, Claude)

- Estado: **aprobada por el usuario (Mimo; nicho tras el reloj, paleta Marea, nombre Mimo, escala ×2; «un poquito más animado»). Fase 1 implementada abajo.**
- Documento: `docs/eshell-pets-redesign-2026-10-23/PROPOSAL.md` (+ `proposal.html` autocontenido).
  Arte: `design/` (poses claro/oscuro, 12 GIFs, paletas, accesorios, maquetas). Fuentes: `design/src/`.
  Paquete borrador: `design/mimo.pet.json` (37 fotogramas, 20×20, 9 colores indexados).
- Decisión propuesta: Mimo (piedrecita con brote) pixel art; una capa de mascota por `IslandOverlay`
  con perchas declaradas por superficie y saltos parabólicos; se reemplazan BuiltinPet, PetHost local,
  botón de comer y fantasma del botón de workspaces; se conservan Settings/Config/Edots, gates
  `petPresented/petEligible`, disciplina de PetRuntime, eventos `notify(kind)` y arnés de rendimiento.
- Abierto: nicho de la barra en reposo, paleta por defecto (Marea fija vs Matugen), nombre/tamaño.
- Las maquetas son composiciones sobre capturas; la QA real (`grim -o DP-1`) empieza en la fase 1.

## Eshell Pets: fase 1 Mimo, runtime y perchas (2026-10-23, Claude)

- Estado: **fase 1 implementada y validada; sin commit, en `main` sin cambiar rama**.
- Runtime `bar/pets/`: `PetPack` (atlas+json), `PetLayer` (uno por `IslandOverlay`, Loader activo
  sólo con `Config.pets.enabled`), `PetPerch` (perchas registradas), `PetActor` (cerebro, sueño,
  clicks, caminar, keep-clear), `PetSprite`. Paquete `packs/mimo` (20×20, 37 fotogramas, cuerpo 15 filas);
  `tools/petpack.py validate|build` (atlas con sha256 del `pet.json`).
- Decisiones: el actor se reparenta a la percha disponible de mayor prioridad; perchas: barra nicho
  (p0, tras el reloj, reserva ancho sólo con mascota), media timeline (p2, `mood: music` → baile,
  `avoidFrom/To` para la cabeza de reproducción), launcher borde (p3, a la derecha sobre el campo de
  búsqueda). px = min(base, floor(headroom/bodyRows)): nunca agranda percha, máscara ni input; el hit
  area sólo cubre el cuerpo. Fuera de foco/fullscreen/otro monitor no hay percha → oculto y sin timers.
  Reduced motion: una pose fija, sin paseos, reacciones terminan a tiempo. 3 clicks en 1.5 s → feliz.
  Ajustes nuevos (Settings.js, 9 campos): enabled, pack, name, scale, barSurface, launcherSurface,
  mediaSurface, sleepEnabled, sleepAfter (1–30 min). Claves heredadas (character/size/profile) se
  ignoran y se conservan. Código heredado en `docs/eshell-pets-2026-10-22/legacy-code/`.
- Fallos corregidos: frame indefinido al cambiar animación (step se reinicia antes y se acota);
  keep-clear con rango a medio actualizar (avoidFrom/avoidTo se coalescen con `Qt.callLater`);
  `unregister is not a function` al descargar la capa (`_release` protegido).
- Pruebas PASS: `bar/tests/pets.py` (paquete fresco, `pets-regression.qml` offscreen: prioridad,
  fallback, clamp, ocultar sin timers, clicks, música, keep-clear, sueño quieto, reduced motion,
  descarga; `pets-overlay-regression.qml` Wayland con IslandOverlay real: nicho, launcher, cierre,
  foco de monitor, opt-out, desactivar); settings.cjs, settings-integration.py (9 campos),
  layout-routing y media-dock-surfaces con mascota, pill-interface, status, clock-reel,
  overlay-native-input.py (14 superficies).
- QA real DP-1 (`grim -o DP-1`, capturas en scratchpad de la sesión): barra, Mimo duerme en el nicho
  dentro del cristal; launcher, de pie sobre el borde derecho del buscador (el brote cruza la línea
  tenue del header, aceptado); media split, sobre la timeline a px 1 sin tapar título, baila al
  reproducir y vuelve a idle en pausa. El compañero de ojos del header se oculta mientras hay mascota.
  No probado en pantalla: clicks con ratón real (cubiertos offscreen).
- Rendimiento (`bar/tests/pets-performance.py`, 2 rondas, 3.5 s; `docs/eshell-pets-redesign-2026-10-23/perf/`):
  antes (legacy) reaccionando 195 fps/8.3 % CPU, durmiendo 240 fps/9.6 %; Mimo `after-isolated`:
  disabled/hidden/sleeping 0.6 fps 0 %, idle 1.3 fps 0 %, walking 6.3 fps 0.43 %, reacting 5.1 fps
  0.43 %, dancing 4.3 fps 0.14 %; PSS mediana del proceso de prueba 97.5 MiB disabled, 105.2 MiB idle,
  106.7 MiB dancing (coste de mascota ~8 MiB con atlas y QML).
- Límites/siguiente (fase 2): la percha de barra no tiene `mood` música (no baila en la barra); los
  eventos mischief/code/yawn existen en el paquete pero el cerebro aún no los usa; saltos parabólicos
  entre superficies; hit area del pet en media solapa ~9 px superiores de la timeline en su posición.
  Fase 3 personalización Edots; fase 4 plantilla, harness de preview, skill creadora y segunda mascota.
- Ajeno: quedan 5 procesos quickshell offscreen de otra sesión (pids 67213, 88067, 89171, 89247, 89989);
  pueden sesgar mediciones de rendimiento. No se tocaron.
- Ronda de revisión (isla-revisor, 7 hallazgos):
  1. brainTimer seguía vivo con reduced motion tras cambiar de percha;
  2. con sueño desactivado aún dormía.
  Causa común: `restart()` rompía el binding `running:`. Ahora `armBrain()`/`armSleep()` arman los
  timers de forma imperativa en cada cambio de percha, sueño, reduced o enabled; desactivar el sueño
  despierta a la mascota. 3/5/6: el clamp de px usa `reachRows` (bounds del paquete, 18 filas) en
  perchas de línea/borde y `bodyRows` (15) en el nicho; la percha media exige headroom ≥ reachRows.
  El nicho reserva `bodyWidth/2 + reachRight` y pasa de 34 a 42 px a px 2, para que las Z del sueño
  quepan dentro. 4 (launcher tapando el reloj con media): verificado en DP-1, Mimo queda ~18 px bajo
  el reloj; sin cambio. 7 (el nicho se anima al cambiar de monitor enfocado): aceptado por diseño.
- Parpadeo del nicho: el ancho de la pill seguía tarde al nicho y la disponibilidad oscilaba en la
  frontera 0.99 de la opacidad del reloj. La pill sigue al nicho sin Behavior mientras se anima
  (`petNicheAnimating` → `workspaceAnimating`); `petAvailable` pide opacidad y opacidad objetivo
  > 0.95. Una histéresis con estado provocó un binding loop y se descartó. Al abrir/cerrar el launcher
  la percha mejor cambiaba dos veces en el mismo evento (bar → "" → bar en 1 ms): PetLayer separa
  `candidatePerch` de `activePerch` y asienta el cambio con un Timer de 0 ms (hijo de la capa, no
  `Qt.callLater`, para no ejecutarse tras su destrucción). Las perchas ya no llaman a `unregister`
  en una capa que se destruye (`closing`), lo que eliminaba el aviso «invalid context».
- Media: la percha queda en `z: -1` bajo la zona de seek: donde se solapan, el clic busca, no
  acaricia (resuelve el límite de hit area anterior).
- Aceptado: el bostezo invade 2 columnas a la izquierda del nicho y la reacción sobresale hacia arriba
  en la barra.
- Pruebas PASS tras la ronda: pets.py (nuevos pasos: perchas de línea caben en todas las poses,
  restaurar headroom restaura px, reduced motion silencioso al cambiar de percha, sueño desactivado
  desarma y despierta; overlay: el nicho se asienta y el retorno del launcher no suelta la mascota),
  layout-routing, media-dock-surfaces, pill-interface, status, clock-reel, pill-composition,
  bar-layout-transition, island-status-adapter, settings.cjs, settings-integration.py,
  overlay-native-input.py.
- QA DP-1: nicho de 42 px con Mimo en el cristal; ráfaga de 42 capturas al abrir/cerrar el launcher
  sin parpadeo: la mascota se oculta durante el morph de vuelta y reaparece con el reloj. No verificado
  en pantalla: las Z del sueño dentro del nicho (cubierto por geometría en el fixture).

## Eshell Pets: brief de fase 2 para Codex (2026-10-23, Claude)

- Encargo cerrado en `docs/eshell-pets-redesign-2026-10-23/PHASE2.md`. Incluye:
  - A. saltos entre perchas: parábola de 380–520 ms, retarget en el aire; con más de
    400 ms sin relevo o más de 900·s de distancia, desvanecer y caer;
  - B. estilo de workspaces «Mascota» (`pet`): las celdas se dibujan como puntos, Mimo
    ocupa el punto activo con la percha `rail` (p1, `interactive: false`) y brinca al
    cambiar de workspace;
  - C. eventos: programa con terminal o editor enfocado (ToplevelManager), baile de 8 s al
    empezar música, noche entre 23:00 y 06:00 y saludo tras 10 min oculta;
  - D. travesuras por tick del cerebro;
  - E. animación `hop` y `code` con settleAfterLoops 4;
  - ajustes nuevos: jumps, mischief, codingReaction, musicReaction y nightReaction.
- El brief fija los invariantes de la fase 1:
  - timers armados de forma imperativa;
  - umbrales 0.95 y `petNicheAnimating` sin tocar;
  - el `settleTimer` y el flag `closing` se mantienen;
  - sin máscaras de input nuevas;
  - coste cero oculta o dormida.
- También fija las pruebas de aceptación (incluido el fixture nuevo
  `pets-rail-regression.qml`), los límites de rendimiento en `perf/phase2/` y la QA en
  DP-1 en `qa-phase2/`.
- El paquete se dibuja en `design/src/anims.py`. `build.py` sólo escribe hojas, GIF y
  `frames.json`; `pet.json` se actualiza a mano desde `frames.json`.
- Estado: no implementado. Tras la entrega de Codex: revisión con isla-revisor y QA propia
  en DP-1.


## Eshell Pets: fase 2 (2026-10-23, Codex)

- Encargo `docs/eshell-pets-redesign-2026-10-23/PHASE2.md`: A → E implementados,
  cada bloque con pruebas verdes antes del siguiente. Sin cambio de rama/commit;
  se conservan cambios ajenos. Informe y evidencia: `REPORT-PHASE2.md` en esa carpeta.
- A: un actor, host de vuelo separado, candidate → settleTimer 0 ms → activePerch;
  parábola y destino móvil, retarget desde posición/velocidad actuales, px en ápice,
  crouch80/land90, fade160 y entrada200. Se reparenta al tocar y para el driver;
  ocultar/reduced/jumps false cancela. El traslado despierta un origen dormido.
- B: Mascota añade rail p1 no interactivo, oculta sólo el punto activo ocupado;
  fallback al nicho si no cabe/presenta. Brincos y retarget comparten A; Timer0
  coalesce activeId/límites para no leer restX antiguo. Hover fijo, clic de celda
  conservado, lens inactiva para pet; split/compact. Percha z2 sobre el cristal.
- C: ToplevelManager nativo verificado con dos ventanas Wayland en Hyprland;
  clasificador fijo sin distinguir mayúsculas, sin WinMap/sondeo. La composición
  conecta foco/MPRIS. Base sleep > dance > code > idle; code asienta tras cuatro
  vueltas y se reanuda cada20–40s. Baile8s de casa con deadline, suspendido en
  traslado; no despierta ni deja timer al dormir. Noche23–06, sueño mitad con
  mínimo1min y yawn12% con cooldown2min; reloj/RNG inyectados. Saludo tras>10min
  oculto, una vez al aterrizar en casa.
- D: never/rare/normal/frequent, pesos del paquete, siguiente media×(0.6…1.4),
  decidido por think sin timer adicional; bloqueos sueño/reduced/vuelo/paseo/
  launcher y3s tras cambiar percha. Twirl/sneeze/wave terminan en baseAnim.
- E: hop crouch/air/land80/100/90ms, no loop; dibujo con helpers existentes,
  hojas claras/oscuras y GIF regenerados e inspeccionados. Atlas40frames, ambas
  pet.json idénticas; code settleAfterLoops4 real y fallback hop→react.
- Ajustes: jumps, mischief, codingReaction, musicReaction, nightReaction;
  defaults y validación en Settings.js, catorce campos en el editor existente.
- Desviación autorizada por el usuario: limitar ápice al espacio visible. El
  literal recortaba el brote (probe-rail-top.png). Frenado del ascenso durante
  retarget conserva velocidad; si la escala de destino aún no cabe en ápice,
  se cambia px al descender cuando cabe. No se altera la geometría de perchas.
- Desviación autorizada por el usuario: retener origen durante el cierre normal
  del launcher hasta presentar el hogar y entonces volar. Tope2500ms si desaparece
  todo hogar, cancelación al reabrir/ir a otra superficie; resto de relevos400ms.
  No se tocaron umbrales0.95 ni petNicheAnimating/workspaceAnimating. El fixture
  usaba cierre reducido y ocultaba este caso; ahora prueba cierre normal,
  reapertura y visibilidad del actor en lugar de exigir activePerch siempre.
- Rendimiento del driver: FrameAnimation continua en DP-1/240Hz rendereaba aun
  sin escrituras (3.2% CPU). Se suspende entre avances mediante Timer imperativo;
  puerta inicial17ms aún dio2.11% con contador preciso; ahora24ms, tiempo real
  integrado y sin driver en reposo. Duración/trayectoria no se ralentizan.
- Pruebas PASS: pets.py (paquete/clasificador, runtime, rail, overlay normal y
  reapertura), settings.cjs, settings-integration.py14campos; los14fixtures del
  brief (4Wayland/10offscreen), overlay-native-input.py14superficies. Tras el
  último ajuste del driver se repitieron Pets y los4Wayland: PASS. Cada fixture
  usa ISLA_CONFIG temporal. Logs por bloque y finales en validation-phase2/.
- Revisión independiente Sol: hallazgo de recorte superior corregido con la
  autorización; revisión posterior de límite/frenado/px, retención/cancelación
  y contador CPU sin hallazgos pendientes. No sustituyó pruebas ni QA.
- QA DP-1 final:29escenas/327capturas, todos los frames capturados de vuelos y
  ambas repeticiones inspeccionados. Barra↔launcher, rail1→2/1→5 y1→5→2 en ambos
  layouts, hover/punto activo, rail↔launcher, media→launcher, Kitty→code, MPRIS
  falso dance8s→idle, frequent→wave, reduced sin vuelo. Silueta completa;
  margen superior mínimo muestreado2.03px. Regreso launcher→rail split usa fade+
  entrada al superar900·s; media pasa por casa según disponibilidad real.
  Hojas de contacto/muestras/log en qa-phase2/. Las ráfagas son irregulares
  (~127ms mediana), no todos los frames del compositor ni medida de FPS.
- Medición final PASS (`perf/phase2/final-results.json`): disabled/hidden/sleeping
  0.4fps y0.0% CPU a una décima; idle/rail-idle1fps, coding asentado0fps;
  walking6.6fps/0.50%, reacting5.6fps/0.44%, dancing4.4fps/0.30%; flying32fps
  medios y1.97% CPU (cinco inicios/5s; rondas1.85/2.08%).
  Antes, after-isolated: quietos0.6fps/0%, idle1.3fps/0%, walking6.3fps/0.43%,
  reacting5.1fps/0.43%, dancing4.3fps/0.14%; escenarios nuevos sin referencia.
  PSS idle histórico105.22MiB → actual114.15MiB (+8.93MiB bruto, no cumple
  usando sólo el histórico). Referencia emparejada fase1 112.59MiB → actual,
  +1.56MiB: cumple +2MiB. Se recuperó el core pre-A del respaldo y reversión
  comprobada de sus ediciones, Settings9campos y paquete37frames; mismo harness
  salvo binding coding y la inyección equivalente de RNG en la copia temporal.
  El entorno también eleva la PSS del core antiguo; histórico preservado.
- Benchmark: idle/rail-idle fijan RNG0.99, mantienen frames/cerebro y separan
  paseo/bostezo de reposo; una muestra antes paseó y dio2.6fps. Dos rondas
  completas PASS; después sólo flying se repitió al iniciar el primer vuelo a
  t=0 y exigir cinco inicios/5s. Los otros nueve escenarios conservan evidencia
  válida; producto idéntico por hashes, sólo fixture/assert de conteo cambian.
  Referencias, muestras, fallos y método precisos quedan en perf/.
- Método: dos rondas inversas,5s por escenario, ventana200×100, sin offscreen
  concurrentes. CPU schedstat por hilo en ns con árbol estable; conserva ticks,
  ventana completa y muestras. Excluye250ms por extremo de marcadores; cero
  mostrado a una décima (<0.05%), no cero tiempo físico. Sonda hidden/disabled
  igual~0.3ms/4.5s en Qt/Wayland explica el tick espurio de10ms del método previo.
  Se conservan intentos fallidos. Limpieza de seis fixtures offscreen abandonados
  identificados, sólo esos procesos; shell personal sin reiniciar.
- Límites: qmllint devuelve255 sin diagnóstico (no PASS); fixtures cargan los
  componentes realmente. QA nativa sólo DP-1/escala1, overlay de producción
  desplazado96px para no tapar barra personal. No se midió toda la shell.
  Quedan revisión de Claude/isla-revisor y QA propia antes de cerrar la fase.

## Eshell Pets: correcciones de revisión fase 2 (2026-10-23, Claude)

- Origen: revisión Claude/isla-revisor de la fase 2 de Codex. Codex Sol no estuvo
  disponible (gpt-6.1-sol rechazado para la cuenta ChatGPT), así que Claude
  implementó; la revisión independiente la hizo isla-revisor (Opus), dos rondas.
  Sin commit ni cambio de rama; cambios ajenos y Pac-Man/occupiedLevel intactos.
- F1 salto desde reposo: el rail fija petCell sólo tras `prepareHop()` (fase
  `ready`); hopTimer 0 ms llama `hop()` o `cancelHop()` si la percha se vacía.
- F2/F3 retorno al inicio: `holdForHome()` sólo arma con origen launcher;
  reabrir llama `cancelHomeReturn(true)` y conserva la espera (vuelve volando,
  sin fade); otra surface cancela y arranca la gracia normal (lostAt=0).
- F4 opacidad: fade parte de `fadeFrom`; entry = (1-remaining)·reveal; wait
  atenúa a 0.4 (0.6 por 160 ms) y el relevo recupera +dt/120, también en crouch.
- R1 `loseTarget()` reinicia motionAt/frameGate (wait→wait no emite cambio y la
  atenuación reproducía el retraso en un fotograma). R2 techo en vuelo
  `1-min(1,t/d)·(1-reveal)`: sin bajón al aterrizar en nicho que aún se revela
  (motionScale≤2). R3 `hop()` no actúa durante fade. Ronda 2: `detach()` hereda
  la opacidad mostrada (antes saltaba 0.4→1 al dejar un nicho revelándose) y
  `cancelHomeReturn()` sin espera activa no reinicia la gracia.
- Pruebas nuevas: rail (salto de reposo síncrono + máx. salto/fotograma ≤0.6·slot,
  retarget en land medido 8.4 px con slot 24); pets-regression (entrada en nicho
  revelándose, origen perdido oculto en 513 ms, espera cancelada oculta en 465 ms,
  relevo a nicho lento con |Δ|≤0.25/fotograma, detach a 0.4, hop en fade);
  overlay (reabrir sin fade, opt-out no arma espera). Mutación: revertir R2, R3,
  cancel y detach hace fallar su prueba. pets.py, 14 fixtures, settings.cjs,
  settings-integration, overlay-native-input PASS.
- QA DP-1 real (`qa-phase2-fixes/capture.py`, `grim -g` porque DP-1 está en 0,0):
  9/9 PASS con el código final; hojas de contacto revisadas a ojo.
- Perf `perf/phase2-fixes` vs fase 2: flying 1.25 % (1.84), idle 0.065 % (0.094),
  rail-idle 0.055 % (0.085), disabled/hidden/sleeping ≤0.006 %; PSS idle
  116 528 KiB (116 889). El check idle-pss falló sólo por la base por defecto
  (after-isolated); recalculado contra phase1-matched, la de fase 2: PASS
  (anotado en results.json `checks_note`).
- pets-qa.qml (fixture QA): campos opacity/shown/landArmed, `landTarget` e IPC
  `workspaceOnLand(id)`.
- Límites: saltos planos a escala grande (7) sin tocar; pose aérea en wait es
  deliberada (cambiar a suelo en el aire se ve mal); 400 vs 2500 ms de gracia no
  se mide directo, sólo por sus efectos; cancelHomeReturn desde onSurfaceChanged
  en wait ordinaria ya no prolonga la gracia, pero no tiene prueba propia.

## Claude local — 2026-10-23: pareja Claude ↔ Codex y router 0.2.0
- Decisión: plugin oficial openai/codex-plugin-cc 1.0.6 (scope local) en vez de
  Hermes o puentes MCP; sin script propio. Review gate apagado. Guía y plantilla
  de encargo en .agents/skills/orquestacion-pareja (enlazada en .claude/skills);
  AGENTS.md y CLAUDE.md la referencian; `.pareja/` excluido en .git/info/exclude.
- Router isla-ahorro: la copia instalada era 0.1.0 antigua (sin /isla-ruta, registro
  ni escalada). 0.2.0 reinstalada: escalada sólo por 3 fallos reales seguidos (no
  rg/fd/diff/test; un éxito reinicia), modelo real por turno en /isla-ruta, toast al
  cambiar de ruta, guarda Codex (rellena gpt-6.1-sol/medium; Astra/xhigh → Sol/high
  salvo `!astra`; review nativa sin esfuerzo controlable). Fuente ~/.claude/mods.
- Pruebas: claude plugin test 16/16, tsc 0 errores, validate OK. Codex real con
  gpt-6-luna/low confirmado en su rollout. No verificado: el router 0.2.0 en vivo
  (requiere reiniciar la sesión; luego `/isla-ruta` debe mostrar «modelo real»).
- Límite: Codex interactivo sigue con su default gpt-6.1-sol/high (decisión del
  usuario); economy_architect (Astra) vetado en encargos desde Claude.

## Claude local — 2026-10-23: slug de Codex, indicador de modelo en vivo y agent-flow

- Codex con cuenta ChatGPT rechazaba `gpt-6.1-sol` (400). Slugs válidos: gpt-6-sol,
  gpt-6-luna, gpt-6-astra, gpt-5.6-sol/terra/luna. Corregido a `gpt-6-sol` en
  `~/.codex/config.toml`, la skill orquestacion-pareja y `CODEX_DEFAULT_MODEL` de
  isla-ahorro. Delegación real verificada (`task --model gpt-6-luna --effort low`).
- isla-ahorro 0.3.0: la línea de estado añade `▶ …` con quién trabaja ahora: hilo
  principal con el modelo que informa la API (`Opus 5.5`, `Sonnet 5.5`), cada
  subagente vivo (`tipo·modelo`) y cada llamada Codex en primer plano
  (`Codex gpt-6-sol`); se limpia al terminar. Codex `--background` no se muestra.
  Pruebas: `hooks/live.test.ts` (4) + 16 previas, 20/20. Instalado en scope local;
  requiere reiniciar Claude.
- Catálogo comunitario de mods (davila7/claude-code-templates): no hay un mod de
  "modelo activo"; jev-model-router es otro router (choca con isla-ahorro y pide
  claves) y FlashModel es un selector. Por eso el indicador va en isla-ahorro.
- `ui/agent-flow` (panel lateral con el árbol de agentes, tipo, modelo, contexto y
  herramientas; `/agent-flow`): código revisado (sólo observa eventos y los pasa
  intactos; sin fs/proceso/red), copiado a `~/.claude/mods/agent-flow`, validado y
  6/6 tests. Registrarlo en el marketplace local quedó a decisión del usuario (el
  modo automático bloqueó integrar código de terceros). El panel acoplado necesita
  el layout fullscreen (≥110 columnas); si no, se dibuja sobre el prompt.

## Claude local — 2026-10-23: router revisado (isla-ahorro 0.4.1) e isla-relevo

- Diagnóstico del router: la ruta sí se aplica (el modelo medido coincide), pero
  63/70 turnos fueron a experta. Causas: rúbrica de Haiku que mandaba a Opus todo lo
  visual (27/48 en una muestra de prompts reales), regex con `por qu[eé]`, `lag` y
  `race` sueltos, y el bloqueo de bajada con >60k de contexto, que retenía Opus
  toda la sesión.
- 0.4.x: rúbrica nueva («mencionar la interfaz no basta»; 17/48 experta en la misma
  muestra), regex con límites de palabra, bajada permitida con caché fría (>55 min
  sin turno principal) o tras compactar, toast cuando se retiene una bajada, y
  `/isla-ruta` muestra cómo clasificó Haiku y cuántas bajadas se retuvieron.
  El aviso de contexto pasó a isla-relevo. Pruebas 23/23 (`downgrade.test.ts` nuevo).
- isla-relevo 0.1.0 (`~/.claude/mods/isla-relevo`, scope local): toast y banda sobre
  el prompt al terminar un turno con ≥150k de contexto («relevar al cerrar la tarea»)
  y ≥300k o ≥60% («relevar ya»). `/relevo` pide al modelo un relevo con objetivo,
  hecho con evidencia, pendiente, decisiones, archivos, restricciones y verificación
  en `~/.claude/relevos/<proyecto>/AAAA-MM-DD-HHMM.md` (fuera del repo público);
  `/retomar` carga el más reciente. Al abrir sesión anuncia un relevo de <3 días una
  vez. No toca prompt.compose. Pruebas 6/6 (terminal y desktop). No verificado en
  vivo: requiere reiniciar Claude.
- Terceros revisados (sin fs/proceso/red; hooks pasan los eventos): savvy-progress
  (panel de agentes con rol/modelo/contexto/coste, `/agents-info`; registra 2 tools
  no diferidas) y cache-tax (guarda ante envío con caché fría; keepwarm con pings
  `model.fork` que gastan uso, y auto-keepwarm 3 h tras pagar una escritura fría).
  savvy-flow (skill de orquestación con Opus/Fable xhigh) no se recomienda: Isla ya
  tiene explorador/implementador/revisor. Instalación pendiente de consentimiento.
- Instalados con consentimiento del usuario (scope local, fuente ~/.claude/mods):
  savvy-progress 1.2.1 (tools `progress`/`step` ahora diferidas; 24/24 tests) y
  cache-tax 2.3.1-isla.1 (opciones `guard` por defecto `warn` y `autoWarm` false;
  160/160 tests del upstream ejecutados con guard=refuse/autoWarm=true; no hay
  test propio del valor por defecto). Sustituyen a agent-flow, que queda sin
  registrar. Requiere reiniciar Claude; `/agents-info` abre el panel, `/cache-tax`
  y `/keepwarm` gestionan la caché.

## 2026-10-23 · Codex vuelve a gpt-6.1-sol
- Codex CLI actualizado a 0.164.0 (npm); `gpt-6.1-sol` responde. El 400 previo era del cliente 0.155.1.
- Defecto restaurado a `gpt-6.1-sol` en ~/.codex/config.toml, skill orquestacion-pareja e isla-ahorro 0.4.2 (23/23 tests, reinstalado).

## Eshell Pets fase 3: paletas, «más vida» y auditoría (2026-10-23, Claude + Codex Sol)

- Reparto: Codex Sol·medium implementó «más vida» (pets-vida), su ronda de
  correcciones (pets-vida-fix) y una auditoría estática de sólo lectura
  (pets-auditoria); isla-revisor (Opus) revisó; Claude hizo QA DP-1, benchmark,
  el arreglo de media y la integración. Encargos/informes en `.pareja/pets-*`.
- Caída de media (captura del usuario) arreglada en FluidCompanion/FluidMediaCompanion/
  Pill; regresión `pets-media-gather-regression.qml`; evidencia qa-media-gather/.
- Paletas `pets.palette` (marea por defecto, coral, lavanda, arena, matugen vía
  shader pet_palette.frag); preview Edots usa el borrador. Verificadas en Edots.
- «Más vida»: doze (3 fr, sin bucle) antes de sleep, wake con reacción según
  afterWake, love al acariciar (anti-repetición 2,5 s), stretch e idle_breath; la
  música no despierta a una mascota dormida. Mirada a la pill (`pillLook`, umbral
  250 ms con aplicación diferida del último lado, retorno a idle).
- QA DP-1 (`docs/eshell-pets-redesign-2026-10-23/qa-vida/capture.py`, escena
  `pets-qa.qml`, IPC nuevos sleepAfter/pet/gaze): doze→sleep, wake, love y mirada
  izquierda/derecha 4/4 (verdicts.json + hojas). Límite del arnés: los warps de
  Hyprland (`hl.dsp.cursor.move`) dentro de una misma superficie no entregan
  movimiento (pill.pointerX quieto), así que la prueba entra a la pill por cada
  lado; el seguimiento continuo con ratón físico no está verificado en esta QA.
  Mimo en la percha bar está en el extremo derecho de la pill: la franja «derecha»
  es estrecha.
- Auditoría: (1) media aceptaba percha con timeline oculto (pista sin seek) →
  `available` exige `timeline.visible`; regresión `pets-media-perch-regression.qml`
  con mutación (falla sin el arreglo). (2) Hover de la mascota detrás del área de
  búsqueda en media: compromiso ya documentado (dentro de la línea manda la
  búsqueda); se mantiene, baja severidad. Relevos, nicho, timers y PetPreview sin
  hallazgos.
- Pruebas: `python bar/tests/pets.py` (Wayland) PASS completo; media-presentation,
  media-palette-recovery y regresiones media-timeline/layout/ambient/lyrics-view PASS.
  Perf (perf/vida/results.json): dormida/oculta/desactivada ≤0,0064 % CPU, reposo
  0,058 %; idle-pss recalculado contra phase1-matched por deriva del entorno.
- Pendiente menor: doze tiene fotogramas 2 y 3 idénticos (se lee como pausa antes
  de dormir; un tercer gesto «cabeza abajo» sería pulido opcional). Memoria con
  pets desactivadas sin medir. Sin commit.

## Pets y cierre del launcher con música (2026-10-24, Claude)
- Colisión pill/gota al cerrar el launcher con música: la gota nacía con la pill aún
  en movimiento y, con mascota, el nicho de casa se abría después del brote (la pill
  crecía ~63 px hacia la gota). Solución coordinada en tres piezas:
  1. `PetLayer.reservedPerch` + `PetPerch.reservable/reserved`: mientras la mascota
     visita el launcher (o espera volver a casa) el nicho de la barra queda abierto;
     el ancho de reposo no cambia bajo el launcher, la pill vuelve en un único morph,
     la gota brota desde su borde final y la mascota aterriza en su asiento. Sin
     saltos (y en reduceMotion) `holdForHome()` también reserva y `loseTarget()`
     conserva la reserva tras el `attach()`.
  2. `PillGeometry.launcherLeaving`: SurfaceRouter vacía la surface antes de poner
     la fase a 0, pero el `launcherClosing` derivado del overlay podía caer antes que
     `pill.surface` → targetW transitorio 680 que reiniciaba el SmoothedAnimation
     (salto de ~60 px en un fotograma). La geometría lee también la fase.
  3. `FluidCompanion`: `carryClearance()` mantiene ≥7 px de holgura si el borde de la
     pill avanza durante separando/companion/media; rama `separando` en followBody;
     el cuello no se suelta mientras la gota aún solapa el cuerpo.
- Regresión nueva `bar/tests/launcher-media-clearance.py` (Wayland, overlay real,
  MPRIS fixture): sin mascota / con saltos / sin saltos × visita 1400/500 ms +
  reduceMotion. minGap ≥0 en todos, crecimiento tras el brote 0,0 px, nicho
  reservado y percha «bar» en visitas largas. Antes del arreglo: −18 px de solape y
  +63 px de crecimiento. Ojo: QtTest bajo `qs -p` no imprime FAIL; el runner exige PASS.
- doze_2 de Mimo ya no duplica doze_1: cuerpo aplastado una fila con la cabeza a la
  altura de sleep_0 (ojos pesados → cabezada → asentarse → Z). petpack validate/build
  PASS, copia de diseño sincronizada.
- Pruebas PASS: pets.py, settings-media-routing, settings-surface-switch,
  media-presentation; regresiones pill-geometry, surface-choreography (offscreen),
  surface-router, surface-swap-close, launcher-controller/pending, pill-composition,
  pets-media-gather/perch, media-dock-surfaces.
- No verificado: QA visual en pantalla real (grim/DP-1) del cierre con música; la
  medida es geométrica por fotograma. Fase 4 del rediseño (contrato de paquete,
  plantilla, preview, skill creadora, segunda mascota) sin empezar; petpack.py
  validate/build ya existe. Sin commit.

## Eshell Pets rediseño fase 4: herramienta, arnés, skill y Pip (2026-10-24, Claude)
- `petpack.py` gana `new` (plantilla `bar/pets/template/pet.json`) y `preview` (build/sheet.png +
  GIFs); validación nueva (archivos no permitidos/>256 KB, claves desconocidas, ids, silueta,
  contraste sobre vidrio) y ~15 caídas por excepción convertidas en errores limpios. Tests:
  `python -I bar/tests/petpack.py`. `pets-palette.py` ahora exige 0 errores (Mimo da 3 warnings).
- Arnés `bar/pets-preview.qml` + `pets/PetPreviewBoard.qml`; `PetActor.previewPlay/oneShot`
  (sin efecto en producción). Regresión `pets-preview-harness-regression.qml` (en pets.py).
- Skill `.agents/skills/eshell-pet-creator/`. Segunda mascota Pip (`packs/pip`, registrada en
  Settings.js y settings.cjs) creada desde un prompt.
- Pruebas PASS: petpack.py, settings.cjs, pets.py completo (Wayland), pets-palette.py,
  settings-integration.py. Sin QA visual en pantalla ni commit.
- Límites: paleta matugen no recolorea Pip (shader pet_palette.frag fijo a colores de Mimo);
  paquetes de usuario en XDG no se cargan; botones de paleta del arnés sin cobertura;
  Mimo conserva 3 warnings (contraste b sobre vidrio claro, saltos en react).

## Compañero rediseñado: la cara de la isla (2026-10-24, Claude)
- Diagnóstico: dos personajes compitiendo (pet pixel ocultaba los ojos de la isla, que sí
  seguían eventos), cerebro idle aleatorio del pet, pixel art con contorno negro a 4–7 fps
  frente a vidrio antialiasado con resortes, nicho +35 px y viajes sobre launcher/rail/media.
- `components/IslandCompanion.qml` reescrito (API previa intacta + `asleep`, `sleepy`,
  `listening`, `cheerful`, `droop`): ojos cápsula vectoriales, sonrisa como arco Shape con
  extremos redondos, párpado plano nocturno por máscara. Momentos finitos: nod, celebrate
  (2 saltos), sway (2 vaivenes), pat, wake. Reduced/hidden → settle().
- Cableado: Pill.qml `IdleMonitor { timeout: 180; respectInhibitors }` → companionAsleep;
  noche 23–6 → companionSleepy; Players.playing → companionListening; pasan por
  PillHeaderView → IslandRestStatus → IslandActivityChip. Caricia = HoverHandler con 3
  inversiones en 1,4 s. Settings.js: descripciones de personality y pets.enabled.
- Config del usuario: `pets.enabled` → false en ~/.config/isla/shell.json (sólo esa clave;
  copia en scratchpad de la sesión).
- Pruebas PASS: personality-regression ampliada (momentos finitos, sueño/despertar, noche,
  caricia real sobre el chip, reduced/hidden cortan) offscreen; absorption, bar-layout,
  clock-reel, companion-continuity, media-motion, overlay-input, pets-* (7), pill-composition,
  pill-interface, rest-media, status offscreen; launcher-media-clearance, layout-routing,
  layout-interruptions (falló 1 vez en paralelo, PASS 2/2 en solitario), media-dock,
  pets-overlay, recording-drop en Wayland; tests/qml-performance.py PASS.
- QA visual: `bar/companion-preview.qml` (8 expresiones ×3 + recorrido de momentos)
  capturado con grim; barra viva DP-1 recargada sin errores, cara dentro de la pill sin
  solape y vuelve a reposo tras el momento de música.
- No verificado: sueño real tras 180 s en vivo (IdleMonitor sólo cargado sin error),
  caricia con ratón real, aspecto con tema claro, revisión independiente del diff.
  Abiertas: borrar pets pixel y `pets-blob-prototype.qml`; timeout de sueño y horas de
  noche configurables. Sin commit.

## Eliminación del sistema pixel (2026-10-24, Claude)
- Decisión del usuario: se elimina Eshell Pets (Mimo y Pip). El único pet es
  `components/IslandCompanion.qml` (lógica sin tocar). Copia previa en
  `~/.local/state/isla/pets-archive-2026-10-24.tar.gz`.
- Borrado (698 archivos en disco): `bar/pets/` entero, `bar/pets-*.qml`, `bar/settings/PetPreview.qml`,
  `bar/tests/{pets,pets-palette,pets-performance,petpack}.py` y `pet-events.cjs`, skill
  `.agents/skills/eshell-pet-creator`, `docs/ESHELL_PETS_PLAN.md`, `docs/eshell-pets-2026-10-22/`,
  `docs/eshell-pets-redesign-2026-10-23/`. Historial (TASK_STATE, ARCHIVE) intacto.
- Integración retirada: IslandOverlay (petLoader, notify, holdForHome, pillLook, props a hijos), Pill,
  PillSurface/Host, LauncherSurface/View, MediaView, IslandRestStatus (nicho), PillHeaderView,
  FluidCompanion (`barNicheOccupied` y su física de nicho), FluidMediaCompanion, TopBarModules,
  TopWorkspaceRail (hop, lookAt, estilo "pet"). `companionEnabled` = `appearance.personality`.
- Ajustes: sección `pets` y opción `workspaceStyle: "pet"` fuera de Settings.js; Config.qml sin
  `pets`; EdotsWindow sin página Eshell Pets (Hyprland pasa de índice 7 a 6; hyprland-settings-
  regression ajustado); shell.json.example sin `pets`. Un `workspaceStyle: "pet"` guardado cae al
  default sin error (excepción explícita en validate; antes habría rechazado el documento). Una sección
  `pets` antigua en shell.json se conserva como clave desconocida.
- Pruebas ajustadas: settings.cjs, settings-integration.py, launcher-media-clearance (sólo sin pet:
  solape y crecimiento de la pill; mantiene retención, reduced motion), config-draft-conflict,
  workspace-styles, TESTING.md. Ideas a reinterpretar: docs/companion-legacy-ideas-2026-10-24.md.
- PASS: settings.cjs, verify-config.sh, settings-integration.py, hyprland-settings-ui.py,
  personality, companion-continuity, absorption, bar-layout-transition, clock-reel, media-motion,
  overlay-input-policy, pill-composition, pill-interface, rest-media-transition, status,
  launcher-input-safety, config, workspace-styles/-width, top-workspace-motion, island-status-adapter
  (offscreen); layout-routing, layout-interruptions, layout-motion, media-dock-surfaces,
  recording-drop, fullscreen-hide, overlay-native-input, settings-ux/-surface-switch/-media-routing,
  qml-performance (Wayland). La shell viva recargó sin errores tras las ediciones.
- Límites: launcher-media-clearance.py falló 1 de 6 ejecuciones (reduced motion: crecimiento de la
  pill 44 px, no se reprodujo en 4 repeticiones; no se probó contra el HEAD previo, por lo que no se
  sabe si preexistía). Sin QA visual en pantalla, sin commit. Config real del usuario conserva su
  bloque `pets` inerte.


## 2026-10-25 · Pet independiente del panel de actividades

- Decisión del usuario: Enfoque/Grabación accesibles mediante el acceso existente
  Ajustes rápidos → Actividades. Sin botón adicional en la barra.
- IslandActivityChip: clic y Space/Return acarician (reutiliza pat finito); hit acotado
  a la cara, con nombre accesible «Acariciar al compañero de Isla». Retirada la cadena
  requestFocus de IslandRestStatus/PillHeaderView/Pill. Texto de actividad conservado
  como información; RecordingGlyph ocupa su propio espacio y no sustituye la cara.
  Opt-out oculta/deshabilita la interacción y conserva el indicador de grabación.
- docs/PROMPT-companion-polish.md y MOTION_LANGUAGE.md registran el contrato. El
  prototipo de personalidad descrito en el prompt queda pendiente, sin adelantar
  rediseño ni añadir opciones. Cambios anteriores de Claude conservados; sin commit.
- PASS: personality-regression (offscreen y Wayland; clic/teclado no emiten navegación,
  recording mock mantiene cara/hit independiente, opt-out), quick-controls-regression
  (ratón/Return abren focus), status, compact-island, pill-interface (offscreen),
  git diff --check sobre archivos tocados. Configs ISLA_CONFIG temporales.
- Evidencia: logs output-qf00l5yj.log, output-6l8m2xss.log y output-02iuem6x.log en
  ~/.cache/codex-economy/. Inspección visual real: grim /tmp/isla-companion-click-live.png
  y /tmp/isla-companion-activities-access.png; captura nativa del fixture en
  /tmp/isla-companion-native.k5e58q/recording-with-companion.png. Shell recargada y panel
  de Ajustes rápidos abierto/cerrado por IPC. Sin iniciar captura real ni cambiar config.
- Límites: no grabación real, sueño tras 180 s ni tema claro. Un RangeError aislado en
  IslandOverlay apareció durante una recarga intermedia; la siguiente recarga y las
  pruebas posteriores cargaron sin ese error, no se investigó su origen en esta fase.


## 2026-10-25 · Prototipo del compañero: caricia física, juego y contexto

Encargo ejecutado: docs/PROMPT-companion-polish.md con corrección del usuario:
caricia por roce del cursor, clic/teclado para gestos distintos aleatorios. Acceso
a enfoque/grabación separado en Super+U → Ajustes rápidos → Actividades.

Cara vectorial: párpados independientes, asimetría, punto interior, guiño, curiosidad,
giro de pupilas, estornudo, bostezo y sonrisa por clics repetidos. Momentos finitos;
CompanionBehavior recibe contexto de Pill/IslandOverlay y detiene movimiento oculto
o reducido. Travesuras máx1/10min con bloqueos y opciones; noche máx1/2min al10%.
Config.companion + Edots → Compañero: seis controles, sueño180s entero60–1800.
Conservados cambios previos ajenos; sin commit ni nuevas dependencias.

Evidencia: docs/companion-polish-2026-10-25/REPORT.md, source-hashes.txt y capturas
reales grim de expresiones×3/liberación/reposo, Edots y barra viva, inspeccionadas.
Settings unitarios/integración/verify-config PASS con ISLA_CONFIG temporal; personalidad
offscreen y Wayland PASS; ocho regresiones de cabecera requeridas y rendimiento PASS.
Revisión Claude no disponible (sin login), revisión independiente Codex encontró y
verificó correcciones de blink solapado y alegría diferida bajo reduced. La prueba
nativa exigió espera eventual del muestreo, manteniendo la guarda de retardo mínimo.
Diffcheck PASS; búsqueda de referencias retiradas sin coincidencias en fuentes activas.

Pendiente de valoración: ratón físico/caricia, ausencia real hasta timeout, tema claro,
amplitud y personalidad durante uso prolongado. Código/música/bloqueos probados en
fixtures, sin alterar reproducción/workspace/grabación del usuario. Sigue PROTOTIPO.


## 2026-10-25 · Compañero: roce expresivo y continuidad de interacción

Implementadas las seis ideas aceptadas: roce suave gradual en dos dimensiones,
cosquillas por velocidad, curiosidad al permanecer y mirada al retirarse, secuencia
de clics, afecto local 30 s, despertar según ausencia y raro intento de resistir
el sueño antes de bostezar. Sin puntos, necesidades, persistencia ni nuevos relojes
continuos. Seguimiento desactivado elimina inclinación/mirada persistente. Actividades
sigue separada en Super+U → Ajustes rápidos → Actividades; teclado equivale a clic.

Revisión independiente en dos rondas detectó solapamiento de roce con otros gestos
y Behavior encolado tras caricia. Cancelación central y restauración inmediata del
binding corregidas; reproducer repetido por coordinador: touch cero al instante y
a 40/260 ms, un nuevo roce sigue alcanzando objetivo y liberándose.

Personalidad PASS offscreen/Wayland con entrada horizontal y vertical sintetizada,
gestos finitos/exclusivos, hover, afecto, despertar, oculto/reduced y opciones.
Absorption, companion-continuity, bar-layout-transition y pill-composition PASS en
Wayland; rendimiento PASS sin lecturas/cambios de reproducción, muestras ocultas
ni Cava/glow activos en fullscreen. Diffcheck PASS. Capturas grim reales revisadas
en dos pasadas acotadas; cierre de ojos legible, liberación y composición estables.

Evidencia y hashes: docs/companion-interaction-2026-10-25/REPORT.md. El fixture
omite una opción nocturna en una asignación parcial y avisa undefined→bool; no
error de carga. Sin commit ni configuración del usuario editada. Conservado árbol
previo de Claude. Pendiente: ratón físico, ausencia real prolongada, tema claro y
percepción durante sesión larga. Sigue PROTOTIPO.


## Compañero · superficie táctil e historia · 2026-10-25

Primera fase implementada del plan: material comparte presión del roce (escala0.92/1.08, traslación acotada y luz) sin cambiar target/layout; cuarto clic y oportunidad existente de travesura lanzan holdSneeze finito1.74s, interrumpible. Sin nuevos servicios/ajustes/loops. Revisión independiente Sol medium detectó sonrisa heredada del tercer clic: corregida y prueba de secuencia real añadida; segunda revisión sin nuevos hallazgos. Claude sólo lectura no pudo iniciar por falta de login, documentado.

PASS: targeted offscreen/Wayland escalas1/1.5/3, fases/cancelación/opt-out/reduced/hidden, personalidad Wayland con clic/teclado, continuidad offscreen, verify-config y diff --check. Capturas nativas inspeccionadas por coordinador. qmllint255 sin diagnóstico, no PASS. IPC reload true y Configuration Loaded. QA físico/tema claro/sesión larga pendientes; demás ideas fuera de esta fase. Cambios previos preservados, sin commit/push. Evidencia/diff incremental/hash: docs/companion-delight-2026-10-25/REPORT.md.


## Compañero · luciérnaga finita · 2026-10-25

Segunda fase: quinto clic/travesura existente inicia firefly2.6s dentro del slot, ojos siguen luz de Theme y retornan sin cambiar layout. Sin servicios/config/dependencias/loops nuevos. Cancelación reutiliza stopMoment. Revisión independiente Sol medium encontró salto con mirada previa no nula: captura inicial e interpolación, cesión explícita al Behavior antes de limpiar escena; segunda revisión sin hallazgos.

PASS targeted actual offscreen/Wayland s1/1.5/3, recorrido/mirada/finitud, tres interrupciones, reduced/hidden/suspended/blocked/asleep, cadencia y continuidad inmediata. Personalidad Wayland PASS antes de última corrección de mirada, cubierta luego por targeted actual. Preview carga offscreen, diffcheck PASS, reload true/Configuration Loaded. Capturas nativas actuales inspeccionadas, sin afirmar análisis por frame ni FPS. Evidencia/diff incremental/hashes: docs/companion-firefly-2026-10-25/REPORT.md.

Pendientes: memoria persistente/saludo aprendido, continuidad entre surfaces; ratón físico/tema claro/sesión larga. Sin commit/push. Árbol ajeno preservado. Sigue PROTOTIPO.


## Iris · deleite (lote 4) · 2026-10-25

Visitas por reloj en Singletons/Visitors.js (luciérnaga, polilla 23:00-05:59, gota, burbuja,
copo en diciembre) como escena única de IslandCompanion; ocupan la ranura rara 1,25 % de
tryMischief repartida por pesos, el resto de probabilidades y los 10 min no cambian. Avistamiento
sólo al terminar la escena (señal visited, IrisMemory.noteSighting, tope 99, validado al cargar,
inerte con remember=false); fila informativa en Edots Iris. Polvo (`dust`) tras >=30 min dormida:
sacudida a mitad de amplitud, parpadeo y bostezo. Ojos con 12 % de acento y pupila 1,9/1,6 según
Theme.dark. Quinto clic sigue siendo luciérnaga. Copo desplazado a x 26,3 tras captura: a 24 se
perdía sobre el ojo derecho.

No hecho por falta de gancho fiable: reacción a copia del portapapeles (sin watcher; cliphist
sólo bajo demanda), obturador de captura y esconderse en pantalla completa (la pill sube fuera de
pantalla; no hay señal de capturas).

PASS offscreen: iris-delight, iris-continuity, iris-system, iris-memory, companion-delight,
companion-continuity, personality, notification-routing, compact-island, verify-config.sh,
settings.cjs, settings-integration.py. PASS Wayland: iris-delight con capturas inspeccionadas.
Pendiente: ratón físico, tema claro percibido, sesiones largas, contador de avistamientos en vivo
tras sesión real, productor de overview. Sin commit. Evidencia: docs/iris-delight-2026-10-25/REPORT.md.

## Iris · perch y atención (lote 3) y correcciones de revisión · 2026-10-25
Lote 3 (perch + atención) no tenía entrada. Perch: `perchTravel` 0→1 de la cara viva de la cabecera
(`header.faceSlot`) a la esquina superior derecha de superficies que ocultan la cabecera; ahora con
`SmoothedAnimation { velocity: -1 }` (sin morphCurve) para conservar velocidad al invertir. Atención:
`CompanionBehavior.focusActive/focusX/focusY`; el foco manda sobre el puntero (`followingFocus`).
Letra sincronizada también en layout dividido vía `Pill.attentionItem` (IslandOverlay). Saludo: ya no
espera 1200 ms fijos; espera `busyFaces === 0` (`noteMoment` desde IslandCompanion) + 300 ms.
Fallo real corregido: `wakeAfter` leía `interactive` obsoleto dentro del handler y el polvo nunca
sonaba. `IrisMemory._accept` tolera `null` y `warmth: null`.
Pruebas offscreen PASS: iris-continuity (escalas 1/1.33/2, foco+puntero), iris-memory (archivos hostiles,
polvo→saludo), iris-delight, iris-system, companion-delight, companion-continuity, personality,
notification-routing, compact-island, verify-config.sh, settings.cjs, settings-integration.py.
Wayland escala 1: iris-continuity PASS y perch-mixer inspeccionada (cara en la esquina superior derecha).
Límites: sin ratón físico; foco no se reevalúa durante el movimiento de la tarjeta; en layout dividido la
cara no viaja; despertar con monitor inactivo real sin verificar. Sin commit.

## Materializacion de surfaces: muelle fisico y contenido (2026-10-25)

- Geometria -> PillMorphMotion integra un muelle retargeteable que conserva velocidad para abrir/cambiar/cerrar surfaces (Motion.surfaceSpring, asimetrico: rebasa ~3 % al abrir, <=0.5 % resize, ~0.3 % cierre). Notificaciones, aviso de workspace y reduceMotion mantienen Behavior+SmoothedAnimation. Reintroduce un overshoot fisico pese a la retirada de la curva simulada de septiembre, por peticion actual.
- Contenido -> PillSurfaceHost materializa escala 0.94->1 (origen arriba), blur y 6 px de traslacion mientras p<1; capa solo durante el tramo; A->B se retira a 0.97; cierre retira contenido antes (0.9->0.6); reposo vuelve con escala 0.96->1 (PillHeaderView, faceSlot ajustado). Blur max 32, 14 en superficies grandes (>480000 px2).
- Pruebas -> surface-materialize PASS; pill-composition (esperas 900 ms, aviso de workspace con pill asentada), iris-continuity (faceSlot sigue la escala) y las regresiones de pill/iris/companion/surface/notificacion PASS offscreen; layout-motion, layout-interruptions, settings-surface-switch, media-dock-surfaces, recording-drop, launcher-media-clearance y qml-performance PASS en Wayland; verify-config, settings.cjs, settings-integration PASS.
- QA visual -> capturas Wayland grim antes/despues en docs/surface-materialize-2026-10-25/ (hojas y compare-*.png). Medido en despues: overshoot 2.5-3.2 %, t90 ~250-360 ms, asentado 1 % ~480-630 ms; antes sin overshoot y ~400 ms.
- Limites -> t90 del launcher (~360 ms) y asentado 0.5 px de mixer (~700-740 ms) superan el objetivo; sin FPS medidos ni raton fisico; offscreen no es QA visual. Sin commit.

## Auditoría de diseño y movimiento frente a escritorios maduros (2026-10-26)

- Petición: análisis profundo con herramientas del diseño/animaciones de Isla frente a macOS y otros escritorios; no implementación. Informe: docs/design-competition-2026-10-26/REPORT.md.
- Evidencia actual: lectura de fuentes y revisión independiente acotada de controles/temas/accesibilidad; barra viva y fixture Wayland con calendario/Sonido, configuración e Iris temporales. Sin prueba física completa. Fuentes principales identificadas por source.sha256; capturas privadas en /tmp/isla-design-audit-20261026/.
- PASS actuales: surface-materialize-regression, surface-swap-close-regression, content-hold-regression offscreen, marcador explícito y exit 0. Logs en el directorio del informe. No equivalen a FPS ni QA visual.
- Hallazgo reproducido: PillMorphMotion.step limita dt a 1/30; con frecuencias sintéticas el t90 de ancho pasa de 267 ms (60 Hz) a 400 ms (20 Hz), y fin de integración de 700 a 1050 ms. Harness frame-step.qml y log; no mide FPS actuales del escritorio. Pendiente decidir e implementar política de cuadros tardíos.
- Acabado: mezcla de idioma inglés/español observada en calendario; objetivos de navegación 28×28*s; falta acreditar contraste y recorridos completos con asistencia. No se afirma incumplimiento general de accesibilidad ni lentitud nativa medida.
- Prioridades propuestas: disponibilidad útil, continuidad temporal bajo carga, composición/idioma/objetivos de entrada, legibilidad e integración con compositor/aplicaciones. Conservar identidad y efectos aprobados. Soak 10-23 confirmado completado (241 muestras/2h, possible_reload), sin nuevo diagnóstico de memoria.
- Límites: sin comparación en hardware equivalente, lector de pantalla, contraste medido ni auditoría de toda superficie/multimonitor. No cambios de código/configuración personal; sin commit.

## 2026-10-26 · Correcciones tras análisis de diseño y movimiento

Petición: arreglar los detalles sugeridos. Primera fase con defectos reproducibles,
sin reescribir identidad/material ni revertir árbol local ajeno. Informe y pruebas:
`docs/design-fixes-2026-10-26/REPORT.md`.

- PillMorphMotion.step recupera tiempo de cuadros tardíos, subpasos<=1/240,
  suspensión<=2s normalizados/480 pasos y publicación por cuadro. Mismos perfiles,
  continuidad de velocidad/posición. Prueba roja previa y verde actual.
- LauncherView solicita foco al cargar (antes Morph+60); guardas active en
  adquisición y reintento para no reclamar durante cierre. Prueba nativa de
  escritura temprana/cancelación/liberación/reduceMotion PASS: muestra221ms desde
  apertura y19ms desde carga. Window no acredita toda política layer-shell.
- CalendarView: días/meses/pronóstico qsTr coherentes con idioma fuente español;
  nav36*s mínimo32, teclado conservado. Implementación delegada acotada Solmedium.
- Once fixtures distintos PASS, incluido calendario en dos locales; captura
  Wayland del Pill real inspeccionada. Frame-step mismoharness: 10Hz settle2100→700ms,
  20Hz1050→700ms; 60Hz700→700ms. No sonFPS medidos.
- Revisión independiente agency_reviewer sin hallazgos. Claude CLI falló
  Not logged in antes de revisión; fallback documentado. Modelo efectivo no expuesto.
- MOTION_LANGUAGE/TESTING/mapa actualizados. Sin commit/push, cambios personales
  de configuración, compositor, wallpaper ni reproducción.
- Pendientes de auditoría amplia: composición de todas las superficies, contraste
  medido/perfil semántico menor transparencia, lector de pantalla, temas/fondos,
  secuencias GTK/Qt/Electron y frame pacing físico bajo carga. No se declaran resueltos.


## 2026-10-26 · Continuación de diseño: legibilidad y materiales

Petición: seguir las siguientes recomendaciones. Alcance/evidencia en
`docs/design-accessibility-2026-10-26/REPORT.md`, revisión en REVIEW.md.

- ReduceTransparency: booleano defaultfalse en Settings, Edots → Apariencia;
  Flags fuerza glassAlpha1 sin sobrescribir valor persistido. Consumidores
  compartidos PillMaterial/GlassCard/NotifCardView/FluidCompanion conservados.
- Tinta activa: stateContent/Secondary reemplazan nombres onStateFill/Secondary
  que QML interpretaba como handlers; fallo negro reproducido por revisor.
  Selección por contraste de cuatro caras preserva semántica con objetivo4.5,
  luego maximiza mínimo entre semánticas/negro/blanco. Callers actualizados.
- PASS: verify-config, settings-integration repetida con archivos estables,
  controles rápidos/calendario, 426 intensidades×paletas (71×6), settings-ux y
  settings-controls Wayland; fixture material Wayland split/compact/restauración.
  Matriz medida: mínimos rose dark/light4.00/4.19, blue3.99/4.21, green3.98/4.19.
  No se garantiza4.5 universal ni tinta secundaria alpha/hover/fondos externos.
- QA nativo: capturas grim recortadas de fixture claro/oscuro, texto175%,
  intensidad0.6 y franjas adversas: material opaco y controles sin recortes.
  Foco por QtTest/API, sin ratón físico/lector de pantalla; Window no layer-shell.
- Revisión independiente agency_reviewer: hallazgo nombres QML corregido; sin
  otros defectos sustentados. Integration inicial del revisor tuvo IPC vacío
  durante recarga; nueva ejecución estable PASS. No se inventa revisión Claude.
- qmllint8archivos exit0; QuickControlsView/CalendarView exit255 sin diagnóstico,
  fixtures runtime PASS. No se declara lint completo. Fuente/evidencia source.sha256.
- Pendientes: composición de todas las superficies, accesibilidad integral,
  GTK/Qt/Electron/multimonitor y frame pacing físico. Sin commit/push ni cambios
  de configuración personal; se preserva árbol ajeno. TESTING/mapa/lenguaje actualizados.
# Integración completa del escritorio · 2026-10-26

Usuario autorizó cinco áreas: launcher→app/foco, workspaces, fullscreen,
Escape/paneles y tema/escala/cursor. SurfaceRouter.dismissMonitor invalida rutas
y docking por monitor; OverlayInputPolicy evita captura fullscreen, incluido auth.
Settings expone búsqueda activa para resolver Escape local primero. Workspaces
cierra al confirmar. Apps singleton y dispatches nativos difieren ejecución fuera
del contexto descargable. Launcher Enter lee datos actuales antes de crear delegate.

Matugen/GTK/Qt/instalador actualizados con pruebas aisladas (20+15). Usuario señaló
pill clara: gsettings `default` había pasado de paleta dark a light por nuestra
interpretación; corregido para conservar modo publicado y restaurado dark con
wallpaper original, sin cambiar gsettings. Backup y evidencia en
docs/desktop-integration-2026-10-26/REPORT.md; captura restored-dark.png.

Revisión independiente encontró hueco de Flags.reduceMotion en fixture y pérdida
de scroll al cambiar implicitHeight; corregidos. Nativo prueba escritura real en
14 paneles y DesktopEntry, no sólo bindings. Offscreen no certifica QA visual;
sin pruebas multi-monitor, credenciales reales ni todas las apps. Electron/portal
default puede elegir apariencia propia; sin observador permanente. Sin commit.


# Iris · refinamiento visual inicial · 2026-10-26

Ojos en reposo ligeramente más anchos, pupila más legible, sonrisa más amplia y apertura del gesto curioso con el resorte existente. Comparativa nativa de fixture a escala ampliada y real en docs/iris-visual-2026-10-26/; no es QA completo del escritorio. personality e iris-delight offscreen PASS. personality Wayland falló por espera de firefly con fuentes anterior y nueva; una prueba con margen ampliado falló después en pat y se restauró el margen original. Quedan interacción real, temas adicionales y continuidad de cuadros sin verificar. Sin cambios de configuración personal ni commit.

## 2026-10-29 · Portal general de actualizaciones

Implementado Edots → Actualizaciones para oficiales CachyOS, paru/AUR, Flatpak
opcional e Isla/upstream Git. Settings/Config incluyen controles de búsqueda
periódica y avisos; SystemUpdates consulta al inicio (45 s)/6 h, publica aviso
DND y huella persistida24h. Notifs conserva acción local tras restauración.
Bridge Python stdlib con argv fijos, timeout por comando y flock; instalaciones
interactivas por Kitty, Git limpio/sin ahead/ff-only. No instalación real.

PASS: verify-config, backend10, settings-integration (save/discard updates),
servicio mocks+replay, Notifs real+bus privado/reinicio/DND, UI Wayland fuentes
1/1.75 y tamaños1000/640, settings-ux, diff-check acotado. Revisión independiente
halló P2 acción restaurada: corregido y segunda revisión cerrada sin hallazgos.
Claude CLI no tenía login; se usó revisor independiente Sol medium disponible.
Consulta real: oficiales0, AUR4, Flatpak ausente, Isla bloqueada por11ahead+dirty.
IPC abre portal en escritorio real; no se guardó captura del escritorio personal.
Rutas/artefactos/límites en docs/system-updates-2026-10-29/REPORT.md y arquitectura.
No commit/push; cambios ajenos conservados. Apps fuera de pacman/AUR/Flatpak no
cubiertas; terminal sin progreso persistente, reconsulta manual al terminar.


## 2026-10-29 · Pulido del portal de actualizaciones

Petición: pulir animaciones y comprobar funcionamiento. UpdatesPage anima
disclosure con SmoothedAnimation retargeteable; ocultar página/Window y reduceMotion
asientan el destino. Indicador de consulta sólo activo visible, cabecera AnimatedLabel
distingue terminal/consulta/error parcial/éxito. SystemUpdates.install refuerza
guardias por fuente. Archivos: UpdatesPage.qml, SystemUpdates.qml, ambas fixtures
updates-regression/updates-service-regression y runner tests/updates-service.py.

Requisito → evidencia: movimiento/interrupción/reduced/hidden → updates-ui.py
Wayland PASS output-p3nmc1de.log (también 1000×700/640×560 fuentes1/1.75 y acciones);
funcionamiento/fallos → updates-service.py dos procesos PASS output-4eisfps0.log
(guardias, JSON inválido, error proceso, resultado preservado y recuperación);
shell real → IPC consulta/apertura y grim inspeccionado, AUR4 sin instalar.
Revisión independiente Sol medium de código/interacción/capturas sin hallazgos.
qmllint255 sin diagnóstico: límite, carga nativa sí comprobada. Diff-check/pycompile
PASS. Informe/capturas fixture en docs/system-updates-2026-10-29/REPORT.md.
No instalación real ni medición FPS; no commit/push. Trabajo ajeno conservado.

Segundo cerebro sincronizado: tools/brain.py PASS 2294 fichas/255 carpetas/934
fuentes, output-ew4xbpds.log.

## 2026-10-29 · Rediseño del portal de actualizaciones

Petición: portal limpio, moderno, fluido y premium. Cabecera héroe (icono de estado,
titular 26 px, fecha relativa, Comprobar), tarjetas por fuente (UpdateSourceCard.qml:
píldora de estado, acción, lista de paquetes acotada a 232 px con nombre y
versión anterior→nueva), entrada escalonada (Motion.stagger, emphasizedDecel),
banner de feedback en hueco reservado. Contratos objectName conservados.
Prueba: tests/updates-ui.py Wayland PASS (1000×700 y 640×560, fuentes 1/1.75).
Indicador: ConfirmationIndicator (arco de login/contraseña) sustituye spinner e iconos Material; anillo con contador cuando hay pendientes, punto por fuente en reposo. Nueva propiedad `animating`.
Límites: sin "Actualizar todo" (requiere cambio de servicio y decisión de producto);
altura del disclosure sigue animando implicitHeight en layout; no medido con profiler.

## 2026-10-29 · Actualizaciones: errores, instalación en segundo plano y lenguaje de carga

Petición en tres fases: errores del panel → actualización limpia sin terminal →
animaciones/iconos de toda la shell con el estilo del arco de confirmación.

Fase 1 (errores, causas raíz): `paru -Qua` sale 1 sin salida cuando no hay nada
(ahora `quiet=(1,)`); Flatpak ausente se mostraba como error (ahora supported=false);
Git con 11 commits sin publicar y árbol sucio era error rojo en inglés (ahora estado
neutro `blocked: ahead|dirty|no-upstream|detached`); el titular "necesita atención"
derivaba de esos falsos errores. Textos amables en Singletons/UpdateText.js.

Fase 2 (instalación): scripts/system-updates.py check/install/follow/cancel/status.
Unidad systemd transitoria `isla-update-<fuente>.service` (sistema vía polkit de
Isla; usuario para AUR/Flatpak/shell), eventos JSON phase/result, LC_ALL=C. Cancelar
sólo antes del punto de no retorno (snapshot/install/finish); fallo tras él → código
`partial` con número de snapshot snap-pac (reversión desde menú grub-btrfs, no
automática). `--noconfirm` hace fallar conflictos antes de cambiar nada. Reengancha
tras reiniciar la shell. AUR usa `--skipreview` con askpass de Isla (compromiso de
seguridad aceptado). UI: anillo determinado de ConfirmationIndicator (estados nuevos
progress/cancelled), titular por fase, aviso "no apagues" tras el compromiso.
Archivos: SystemUpdates.qml, UpdateText.js, UpdatesPage.qml, UpdateSourceCard.qml,
ConfirmationIndicator.qml, tests/system-updates.py (14 PASS), updates-service-regression
+ tests/updates-service.py, updates-regression, confirmation-indicator-regression.

Fase 3 (lenguaje de carga): spinners Material/SpinSettle/pulsos sustituidos por
ConfirmationIndicator en ConnectivityView (StatusIcon), WallpaperView (refrescar,
aplicar con `busyColor`, insignia de escaneo), MixerView (error y carga), CalendarView
(tiempo); LockSurface sin hourglass. ConfirmationIndicator: `busyColor`, `update()`
renombrado `resync()` (chocaba con QQuickItem::update) con guarda en callLater, resync
al hacerse visible. Motion.easeBreathe (InOutSine) nuevo; OutCubic→Motion.easeStandard
e InOutSine→Motion.easeBreathe en ~25 archivos que ya importaban Motion (valores
idénticos). Literales conservados a propósito: IslandCompanion (rig de mascotas),
MaterialChoreography (recibe duraciones por props), respiración 1400 ms de
PillMorphMotion, OutBack de NotifCardView, bezier de MediaTimeline, bucles Linear.
Marcas de selección (check de portapapeles/ajustes) y confirmación de energía no son
estados de carga: sin cambio. SpinSettle.qml queda sin consumidores (no borrado).
updates-regression: el clic en el resultado de búsqueda caía mientras la página
deslizaba; ahora espera `settingsPageMotion.transitioning === false`.

Pruebas offscreen PASS: confirmation-indicator, connectivity-design/surface/host,
mixer-surface, calendar-design/data, wallpaper-apply-feedback/pipeline/media-header,
lockscreen/motion/power, breathe-border, motion, notification-breath, notifs-surface,
settings-controls/motion/path-picker, input-motion, textbox-motion,
top-workspace-motion, updates. settings-path-picker sale 0 pero a veces pierde la
línea PASS en stdout al salir (el código de salida es la señal fiable).
clipboard-design falla en "Escape returns focus to destination" también con
ConfirmationIndicator y ClipboardDetails de HEAD y sin tokens: preexistente, ajeno.
No verificado: actualización real del sistema y cancelación real (requiere que el
usuario escriba su contraseña en el prompt de Isla); fluidez sin medir con profiler.
Sin commit/push; trabajo ajeno conservado.

## Tidemark: plan aprobado y Fase 0 (2026-10-30)

- Decisión → lenguaje de trazo **Tidemark** aprobado con las animaciones de referencia (incluido el mute nuevo). Plan: docs/plan-trazo-pill-2026-10-30.md; prompt: docs/prompts/implementar-tidemark.md; movimiento aprobado: docs/previews/tidemark-lenguaje.html.
- Piloto usa **muelles + morph**, no `trim` (el plan hablaba de trim): donde difieran, manda la vista previa. `trim.end` queda para trazo = medida (LevelStroke, anillo).
- Fase 0 hecha → tokens `Motion.stroke*` (strokeSpring con omega/zeta de la vista previa, strokeTideHold, strokeHeadScale, strokeGlow) y `Theme.signalSuccess/signalError/strokeIcon/strokeRing/strokeSymbol`; ConfirmationIndicator ya no tiene literales de color ni grosor. `SpringValue.qml` (muelle escalar, subpasos 240 Hz, conserva velocidad al cambiar de destino, oculto/reduceMotion = snap, FrameAnimation sólo mientras integra) y `LevelStroke.qml` (line|arc, trim.end sobre pista, cabeza sólo al crecer, marca de marea con Timer sólo mientras el pico supera el nivel).
- Pruebas → bar/stroke-language-regression.qml PASS offscreen (tokens, asentamiento, interrupción con velocidad, reduceMotion, oculto, nivel y marea); confirmation-indicator-regression PASS; qmllint sin diagnóstico; git diff --check limpio. Nota: en este arnés un compare/verify fallido aborta la función sin avisar; la prueba cuenta funciones completadas y sólo imprime PASS si llegan todas (comprobado con una aserción rota).
- No verificado → nada visible aún (Fase 0 no cambia pantalla); `motion`, `interaction-regression`, `lockscreen`, `osd` no se han re-ejecutado (aún no se tocan sus archivos).
- Siguiente → Fase 1 piloto (glifo de volumen OSD con mute, FocusTimer play↔pause + anillo, lock↔unlock). Preguntas abiertas al empezarla: nivel del OSD (arco o línea) y cabeza gruesa vs trazo uniforme. Sin commit. MOTION_LANGUAGE.md y skill sin tocar hasta el OK del usuario.


## Tidemark: Fase 2 (2026-10-30)

- Hecho → PlusCheckGlyph (portapapeles Guardar/Organizar, `ClipboardChip.morphIcon`), RadioGlyph (wifi/BT: ondas se trazan en orden desde el punto, barra de apagado; en pestañas y estado vacío de ConnectivityView), rayo de BatteryIndicator dibujado con `trim.end` + relleno tardío, play/pausa del botón primario de media con PlayPauseGlyph (cookie intacto; sin symbolPop para ese glifo). Tokens nuevos `Motion.strokeSpring.morph/radio`.
- Decisión → medidor del mezclador (AudioEndpoint ~218) NO migrado: ya es una barra viva con suavizado lineal de 32 ms por muestra, y LevelStroke añadiría un integrador por endpoint (hasta 12) contra "sin animar muestras". Nivel de batería tampoco: el relleno de 14 px conserva su Anim.
- Pruebas → stroke-language (13 funciones, +más/check y radio), battery-indicator (+rayo visible solo cargando), connectivity-design/host/surface, clipboard-interaction, motion, interaction, microinteraction, confirmation-indicator PASS offscreen; qmllint limpio.
- No verificado → clipboard-design FALLA "Escape returns focus" también sin `morphIcon` (probable preexistente, sin baseline limpio); clipboard-workflow no dio resultado en 100 s; media-*/regresión de MediaView no re-ejecutadas; QA visual en vivo NO hecha (offscreen no es QA visual).
- Siguiente → el usuario ve Fase 1+2 en vivo; luego Fase 3 (pill-detail-audit, qt-qml-profiler, isla-revisor). Sin commit.

## Tidemark: Fase 3 parcial, revisión de Fase 2 (2026-10-30)

- Revisión isla-revisor (independiente) → corregidos: play/pausa ignoraba `moving` (PlayPauseGlyph.animate), RadioGlyph animaba falso on/off al cambiar wifi↔bluetooth (snap en onKindChanged), ondas saturadas (waveExtent normalizado, token `Motion.strokeRadioStep`), rayo: trim recortaba el relleno (ShapePath de relleno separado) y trazo/relleno con distinto color (`boltInk`), badge de conectividad perdía el indicador "busy" con reduceMotion.
- Pendiente → `add: Transition` de las listas de ConnectivityView puede parpadear en cada refresco (no es de Fase 2, sin verificar en vivo); rayo 1·s más grueso (QA visual); literales 0.6/0.4/1.6/1.4 sin token; `clipboard-design` falla también con ClipboardChip/EntryRow de HEAD (no es de esta fase).
- Pruebas → stroke-language, battery-indicator, connectivity-design/surface, media-motion/layout PASS offscreen tras las correcciones. Perfilado con qt-qml-profiler y pill-detail-audit NO hechos (requieren la shell en vivo). Texto propuesto: docs/propuesta-tidemark-motion-language.md (sin escribir en MOTION_LANGUAGE ni skill).

## Tidemark: Fase 3, auditoría visual, de animación y latencia (2026-10-30)

- Método → arnés fuera del repo (scratchpad, copiado temporalmente a bar/ y borrado): 8 glifos a 3× y 1× en Wayland a 240 Hz, guion ida / vuelta / interrupción a 120 ms / interrupción a 280 ms; cada cuadro guardado con grabToImage y contactos por pieza. Ojo: en modo captura el contenido llega ~80 ms tarde respecto a la marca de tiempo; vale para la forma y el orden, no para medir tiempos (se midieron sin captura).
- Hallazgos corregidos → (1) PlayPauseGlyph: al rebotar más allá del play las y de la punta se cruzaban y dejaban un grumo en el vértice ~100 ms; ahora la punta sólo rebota en x. (2) BatteryIndicator: el contorno de 1·s seguía visible en reposo y engordaba el rayo (a 1× quedaba ilegible sobre el relleno); ahora el trazo se retira mientras entra el relleno (`boltFill`) y el reposo es la silueta de HEAD.
- Aceptado sin cambio → candado abierto con el arco estrechado (sx 0,25, como la vista previa); muescas sub-píxel en el "clac" del candado y bultos del cuello del play al cerrarse (forman parte del diseño, limpios en reposo); trozos de onda atenuados durante el apagado del wifi.
- Medidas (sin captura, 2 corridas) → 1085 cuadros, hueco p50 4 ms / p95 5 / p99 5-6 / máx 7-8 ms con piezas en movimiento (0 cuadros perdidos a 240 Hz); primer cuadro tras el cambio 1-4 ms; reposo 0 cuadros en 2 s; asentamiento: más/check y rayo 465 ms, play/pausa 583, ondas/volumen 653, candado 823-866. CPU con 16 glifos animando a la vez ≈26-35 % de un núcleo (≈2 % por glifo), reposo ≈1 % (el Timer del propio arnés).
- Bloqueado → qmlprofiler: el binario de Quickshell rechaza `-qmljsdebugger` e ignora QML_DEBUG_ARGS (sin QQmlDebuggingEnabler); el coste por binding no se pudo desglosar.
- Pruebas → stroke-language, battery-indicator, media-motion, media-layout PASS offscreen; tests/qml-performance.py PASS en Wayland (0 cambios de reproducción, 0 bandas ocultas).
- No verificado → glifos dentro de la shell completa (ConnectivityView, portapapeles, media) en vivo; `add: Transition` de ConnectivityView. Pendiente → isla-revisor de cierre de Fase 3 y OK del usuario al texto docs/propuesta-tidemark-motion-language.md. Sin commit.

### Tidemark Fase 3: cierre tras revisión independiente (2026-10-30)
- isla-revisor: sin bugs graves/medios. Corregido: arnés `tidemark-qa-tmp.qml` borrado, comentario de TimeRing; `kick(9)`/`kick(-14)` ahora son `Motion.strokeKick.cone/seat`.
- Tests nuevos en stroke-language-regression (16 funciones): geometría final y no-cruce de la punta en play/pausa, `boltFill` y alfas de trazo/relleno del rayo (reposo, interrupción, reduceMotion), reposo sin muelles integrando en candado y volumen.
- Abiertos (bajos): ritmo de espera de TimeRing (`breathe` vs `heat`), ColorAnimation de batería con reduceMotion, tokens sin consumir (strokeIcon/Draw/Erase/Stagger), integraciones de media/radio/más-check sin test. No verificado: glifos en vivo en la shell completa.

### Tidemark: pendientes cerrados (2026-10-30)
- ConnectivityView: confirmado con sonda que cualquier cambio de contenido del array recrea todas las filas del Repeater; el `add:` con fundido las haría parpadear en cada refresco → eliminado (queda `move`).
- TimeRing espera con `Motion.heat/2` (ritmo único de espera del plan). ColorAnimation de batería se queda con `Motion.standard` (convención MOTION_LANGUAGE: el color sigue siendo señal suave).
- Tokens: borrados `Motion.strokeStagger` y `Theme.strokeIcon` (sin uso); `strokeDraw/Erase` se mantienen (vocabulario del plan, con test). Literales 0.6/0.4/1.6/1.4 → `Motion.strokeBoltFillStart/BarGain/CrossFade/SeatShift`.
- Regresiones OK offscreen: battery, media-motion, connectivity-design/surface/host, focus-session, confirmation-indicator, lockscreen. Propuesta de docs revisada, sin cambios, sigue pendiente de OK.
- No verificado: glifos en vivo en la shell completa.
- Tests añadidos (stroke-language-regression, 18 funciones): reposo y `kind` en caliente de RadioGlyph, reposo de PlusCheckGlyph, MediaTransportButton real (sigue a `playing`, `mediaTransitions:false` y reduceMotion saltan). Verificado por el hilo principal: PASS.

## QA visual y de movimiento de la shell completa (2026-10-30)
- Método → ráfagas grim (~12,6 ms/cuadro, muestreo irregular, no prueba FPS) abriendo/cerrando cada superficie por IPC en el espacio 8 vacío: calendario, conectividad, mixer, media, notifs, portapapeles, utils, sesión, foco, grabación, espacios, launcher, overview, wallpaper, Edots; más hover, popup de notificación, OSD, swap calendario→mixer, cancelar a 160-200 ms y escritura en launcher. Auditoría estática de tokens con subagente. Sin cambios de código.
- Hallazgos clave → iconos del launcher con damero (AppItem usa `iconPath(name,"app-no-icon")`; causa sin confirmar, fallan apps con PNG en hicolor); OSD en blanco ~450 ms al repetirse; destello de contenido al cancelar (plausible); fase de cristal vacío de 100-250 ms en cada apertura, legible a 300-450 ms; cierre del launcher ~600 ms frente a ~130 ms del resto; desenfoque del overview sin rampa; popup legible a 600-700 ms; hover quita el «8» de la pill; cristal deja pasar fondos saturados.
- Propuestas → REPORT.md: P0 defectos, P1 gramática «el contenido llega con la forma» + cristal adaptativo, P2 IA y tokens, P3 identidad (todo brota de la isla, marea de contexto, peso según importancia; Iris fuera de las superficies). Evidencia en docs/shell-visual-qa-2026-10-30/evidence/.
- Estado tocado → volumen ±2 % restaurado a 1,00; fondo intacto; queda una notificación de prueba «Isla QA / Copia completada» en el centro.
- No verificado → bloqueo, reduce-motion, tema claro, multi-monitor, frame time real, repetición del destello al cancelar. find-skills (Vercel) no instalada; bastaron las skills locales. Pendiente de OK del usuario para implementar.

## QA visual — correcciones P0 (2026-10-30)
- Instalada find-skills; sin skills de terceros útiles para quickshell/qml.
- Corregidos: iconos launcher (pragma), OSD en blanco (restResizing), avisos efímeros fuera del historial (ephemeral; `transient` es palabra reservada QML), clima con caché en disco.
- Probado: island-status-adapter, neon, personality (offscreen); layout-interruptions y motion (wayland); capturas en vivo.
- Corregidos también: Utils oculta brillo (bl_power) y Energía sin daemon; icono Ethernet en estado. Probado quick-controls y calendar-data. Pendiente: alto dinámico de Utils (fijo 420), icono batería periférico, parpadeo al cancelar, P1 movimiento.
- Nada commiteado; shell reiniciada con start-isla.sh. Quedan el aviso de prueba "Isla QA" y 15 entradas antiguas de Teclado en el centro.

## 2026-10-30 · P1 de movimiento (QA visual, segunda pasada)

- Hecho: P1.1 revelado del contenido 12–40 % del crecimiento (`Motion.openContentStart/Span`, escala 0,96, blur 0,4); P1.2 cierre de launcher 120 + 250 ms (`Motion.launcherCloseResults/Return`, `ShellRuntime.qml`); P1.3 salida del contenido en swap 90 ms (`Motion.crossfadeOut`, `PillSurfaceHost.qml`).
- Probado: motion, layout-interruptions (wayland), compact-island, surface-materialize, surface-router, launcher-controller, launcher-pending, content-hold, pill-composition: PASS. Ráfaga grim de calendario y calendario→mixer (tiempos relativos, no FPS).
- No verificado: ráfaga en vivo del cierre del launcher; FPS; tema claro; reduce-motion en vivo. Persisten ~3 fotogramas de cristal vacío en apertura/swap (carga asíncrona del Loader + `loadReveal`).
- Bloqueado: P1.4 (el blur del overview es de Hyprland `layer_rule`, no QML).
- Pendiente: P1.5 (notificación como gota, requiere diseño) y P1.6 (hover/cristal adaptativo; diagnosticar si el «8» era el aviso de workspace). Sin commit.

## 2026-10-30 · P1 de movimiento, cierre (P1.4–P1.6)

- Hecho: P1.6 cristal adaptativo (`Theme.glassChromaLift` → `PillMaterial.bodyAlpha`); P1.5 parcial (`Motion.notifCollapse` 160, `notifExpand` 260).
- Descartado: hover (el «8» era `workspaceFlash`, verificado en vivo); P1.4 (Hyprland no ramp-ea blur por capa; `hyprctl keyword` sería global).
- Probado: pill-interface, surface-materialize (muestreo ahora `Motion.notifCollapse/2`), notification-attention/breath/priority/notification/routing, pill-composition, compact-island, motion, layout-interruptions PASS. Ráfaga en vivo de notificación.
- No verificado: contraste 4,5:1, tema claro, FPS. Sin commit. Pendiente propio: notificación como gota real.

## Notificación como gota (P1.5, 2026-10-30)

- Cambio → `notificationCompanion` en IslandOverlay (FluidCompanion centered+below, springRate 1.5, z5, sin región de entrada); `FluidCompanion` gana `below` (card bajo el cuerpo, brote desde su borde inferior, idéntico si false) y `springRate`; Pill separa `notifDrop`/`notifMorphing`/`notifDropOpen` (informativas, no críticas) y la coreografía recibe `suspendSurface` (false en gota) sin tocar su máquina de estados.
- Flag → `appearance.notificationDrop` (Settings.js + Flags), defecto true; false restaura el ciclo colapso→expansión de antes.
- Pruebas → notification-attention/breath/priority/regression/routing, notifs-surface, companion-continuity, centered/settings/session-companion, config, settings/-controls/-ux/-motion offscreen PASS; layout-interruptions y motion Wayland PASS; nueva notification-drop-regression PASS (legible 201 ms).
- Ráfaga grim ws8 → gota a 25 ms, título legible ~150–175 ms (springRate 1 daba ~280 ms), hold sin colapsar la pill, retorno recoger→absorber limpio; vuelta a ws 1.
- No verificado → crítica/DND en vivo, segundo monitor, abrir una surface durante la gota, A/B visual con flag false. Cambios ajenos sin commitear conservados; nada commiteado.


## Cuerpo · Fase 3 en producción (2026-10-30)

- Petición: «Intenta aplicar la 3». Fases 1/2 previas en bar/body y demo; opción A del plan para integración real.
- Resultado: PillBody en reposo; material previo en surfaces internas/externas, Fluid, notificación, cambio layout/retorno. Fundido 100 ms interrumpible, offsets limitados, sin alterar morph/input. Header/perch sin ojos, reloj/estados conservados. Toggle personalidad renombrado Cuerpo.
- Riesgo corregido: revisión Sol/medium detectó refresh de motor inactivo por geometría/puntero; guard conserva excepción manualStep. Reproducción independiente posterior PASS, sin nuevos hallazgos. Fallback software/error, reduceMotion y reduceTransparency comprobados.
- QA Wayland: sombra externa generaba placa de blur; outsideOpacity default1 en shader, producción0, qsb recompilado y shell reiniciada. Rest/calendario/retorno inspeccionados en producción.
- Evidencia: docs/cuerpo-fase3-2026-10-30/REPORT.md y logs/hashes/capturas. Node brain/drop, QML body/drop RHI, composición,input, integración RHI y Wayland (compact/escala/oculto/interrupción/accesibilidad), fallback,linter,config PASS. Offscreen no acredita QA visual.
- Pendiente: Fase4 eventos y archivos reales, hora real (motor usa12), opciones respiración/limpieza Iris; Fase5 vídeo/QA temporal amplia/tema claro/segundo monitor. Sin revisión Claude. Sin commit/push, cambios ajenos preservados.


## Cuerpo · Fase 4 eventos y archivos (2026-10-30)

- Usuario autoriza fase4 y elige capturas/grabaciones de Isla. BodyEvents compone reacciones finitas, foco/idle/noche; Pill conecta reloj local/Cava con consumidor visible. Settings/Edots Cuerpo, respiración opt-in <=1.1px, opciones antiguas inactivas.
- BodyMessenger/BodyFile: oferta local estricta, un archivo por monitor, suspensión conserva ruta, shader full sólo viaje, chip/input separado, entrega argv explícita. Recording.saved y script externo screenshot-annotate.sh (Satty guardado al cerrar) alimentan router. IPC bodyOpen permite atajo de teclado sin robar foco.
- PASS Node brain/drop/file; eventos, pill RHI+Wayland; mensajero fake opener (clic/Enter/oculto/reduce); configuración, settings, composición/input, lint con advertencias conocidas; hook screenshot simulado clipboard vs saved.
- QA producción Wayland: recogida de PNG real, guardado y calendario inspeccionados; shell limpia tras reload, no abrir archivo real. Revisión independiente Sol sin hallazgos; Claude CLI no autenticado.
- Reporte, capturas/logs/hashes: docs/cuerpo-fase4-2026-10-30/REPORT.md. Fase5 pendiente: vídeo/QA temporal amplia, tema claro/multimonitor/bloqueo; entrega nativa y herramientas reales Satty/grabación no verificadas end-to-end. Cambios ajenos preservados, sin commit/push.


## Cuerpo · revisión Claude de Fases 1–4 y pulido (2026-10-30)

- Petición: revisar trabajo/encargos de Codex y aplicar mejoras visuales, de movimiento y coherencia antes de Fase 5.
- Hallazgos: (1) archivo guardado = cuadrado con borde y glifo Unicode «▧», ajeno al lenguaje de gotas/MaterialIcon y a la vista previa; (2) fundido body↔material bajaba ambas opacidades (alfa ~0,75 a mitad: la pill se transparentaba 50 ms en cada apertura); (3) al volver de un surface con archivo guardado se repetía la recogida completa.
- Cambios: PillBody dibuja el archivo guardado como gota de vidrio acoplada bajo la pill (drop0 en el mismo SDF, cuello por fusionRadius) que brota del borde inferior con SpringValue `strokeSpring.lift`, crece 8 % al hover, se comprime al pulsar y se absorbe con exposure. BodyMessenger publica `dock`/`docked`/`dockHovered`/`dockPressed`, MaterialIcon image/movie que espera a la gota, `wasStored` evita la segunda recogida y la entrega sale desde la gota acoplada. Body opaco bajo el material durante el relevo. Bindings en IslandOverlay.
- Pruebas: Node brain/drop; body, body-pill (nuevo: opacidad 1 en relevo, brote/absorción de drop0), body-messenger (nuevo: sin segunda recogida, hit = dock) RHI offscreen; pill-composition e overlay-input-policy PASS; qmllint sin errores nuevos.
- QA Wayland (shell real `qs -d`): reposo limpio, gota acoplada con cuello, secuencia 4 s a 200 ms: salida → recogida → fusión → brote en <200 ms sin saltos. Archivo de prueba retirado con IPC reload; no se abrió nada.
- Aviso operativo: la shell del usuario corre como `qs -d -p bar/shell.qml`; `pgrep quickshell` no la ve y lanzar `quickshell -p` crea una segunda isla superpuesta (falso «doble borde»). Usar `pgrep -ax qs` e IPC `island reload`.
- No verificado: hover/pulsación en vivo (sin mover el cursor real), entrega nativa end-to-end, tema claro, multimonitor. Sin revisión independiente. Sin commit/push.


## Cuerpo · Fase 5 QA temporal y cierre (2026-10-30)

- Petición «Sí, Fase 5». Vídeos de shell real 23 s (grim ~27 fps), recogida/entrega/hover continuos; calendario a mitad de entrega retira la gota ~80 ms antes de cubrirla (límite menor aceptado); reload a mitad de recogida limpio.
- Corregido: (1) `stored` ensanchaba el núcleo 132·k y el bulto salía ~60 px de la pill → `BodyEngine.storedWidens` (PillBody false) y `BodyDropBrain` `widen:false`; (2) atención viajaba desde x=0 → nace en el puntero; (3) volteo del bulto con puntero dentro → dirección escalada por max(dist, hh); (4) tema claro ilegible (vidrio negro fijo + tinta Theme) → uniform `colBase`, PillBody usa Theme.cardBot sólo en claro, refracción mezclada en bases claras; oscuro idéntico.
- PASS Node brain (nueva prueba falla con código previo)/drop; RHI body, drop, messenger (sin ensanche en host pill, reduceMotion a mitad de recogida/entrega), pill oscuro y claro (colBase). qmllint sin nuevas.
- GPU (nvidia-smi pmon): reposo sin respiración ≈0 por proceso; respiración on ≈1,7 % estimado, CPU 6,6 %. gpu-recording.py no mide GPU. Multimonitor no verificable (sólo DP-1); bloqueo no probado en vivo, la shell no conoce el bloqueo (sólo afecta con bodyBreath=true).
- Informe y evidencias: docs/cuerpo-fase5-2026-10-30/REPORT.md. qsb nuevo requiere reiniciar `qs` para tema claro en vivo. La entrega real dejó el PNG de prueba abierto en Brave. Sin revisión independiente; sin commit/push.


## Cuerpo · auditoría visual completa en la shell (2026-10-31)

- Petición: auditar el Cuerpo con todas las surfaces; arreglar el regreso feo del hover y cualquier detalle de color/movimiento. Trabajo autónomo en bucle (capturas grim en la shell real + fixture Wayland).
- Corregido: (1) hover: el brote interior seguía al cursor y desaparecía en un frame (radio 11,8→0) → BodyBrain lo absorbe continuo (paso ≤0,5, vuelve en ~0,5 s); (2) relevo al abrir: cápsula negra del cuerpo 2 frames sobre el material; al cerrar, 1 frame azul transparente → PillBody sigue alto/radio vivos con tinte/alfa del material: un solo vidrio; (3) tinte de reposo igual que los chips de workspace/estado; gota de notificación y tarjeta comparten vidrio; (4) barrido de material con gradiente horizontal (sin bordes duros de losa); (5) dock media→launcher terminaba en `idle` (~1 s) → libera con `concealed` (~0,4 s); wallpaper/overview liberan ya con `retornando && contentExposure<=0` (crecen a 0,24 s en vez de 0,45 s); el launcher lo excluye (dejaba una gota suelta al bajar); (6) header launcher: reloj de reposo dentro del cristal y a la derecha del anillo; anillo/título/divisor esperan a `contentReveal` (surfaceContentProgress); al abrir surface el reloj se desvanece en la fila superior, en reposo sigue centrado; (7) DesktopStatus: `onPropertiesChanged` del nodo sólo muestra OSD si cambia volumen/mute (cerrar mixer mostraba «Volumen 100%»); rutas explícitas intactas.
- Segunda ronda: (8) utils medía 360×420 fijo y con brillo ausente y perfil sin daemon dejaba ~260 px de vidrio vacío → QuickControlsView expone `contentHeight`, UtilsSurface `contentHeightHint`, PillGeometry lo usa como tope (`min(sizeFor, hint)`) sólo con el contenido cargado; ProfileProbe.js recuerda si powerprofilesctl respondió para que la tarjeta de perfil no aparezca y se pliegue en cada apertura. (9) Revisor (isla-revisor): reloj del launcher saltaba ~20 px al cerrar (fase 1) → x/y del reloj usan `surface==="launcher" && !launcherReturning`; en compacto con módulos laterales el destino derecho se interpola con `contentReveal`; clave de nivel del OSD incluye `node.id` (nuevo sink por defecto con mismo volumen sí muestra OSD). Sin defecto: dock media, contentReveal, barrido, cuerpo/qsb.
- PASS 2.ª ronda: surface-boundaries.cjs, quick-controls, surface-data-contract, surface-choreography, overlay-input-policy, pill-geometry, pill-composition, launcher-controller/pending, media-clock, wallpaper-media-header, desktop-status-audio-rebind, rest-media-transition, pill-interface; Wayland settings-surface-switch, launcher-media-clearance, layout-motion, body-pill. QA vivo: utils ajustada a dos tiles, cierre del launcher sin salto, calendario, portapapeles, actividades, wallpaper, overview.
- PASS Node body-brain/body-drop; offscreen body, body-messenger, material-choreography, motion, launcher-controller/pending, pill-composition/geometry/interface, media-clock, wallpaper-media-header, rest-media-transition, surface-materialize, desktop-status-audio-rebind, island-status-adapter; Wayland body-pill, launcher-media-clearance, layout-motion/interruptions, media-dock-surfaces (registra el estado en la liberación). qmllint y diff --check limpios.
- QA en vivo (grim, MPRIS falso silencioso): notifs, reloj/calendario, media, launcher, wallpaper, overview (compact y split), mixer, sesión; tema claro/noche en fixture. OSD real de volumen comprobado (98 % y restaurado).
- Límites: surface-materialize falla con la config del usuario (183 ms < 220) y pasa con `{}`: preexistente. Línea 55 de body depende de la hora (noche): usar reactAtNight=false. Tema claro sólo en fixture (no se cambió el tema real). Multimonitor no verificado. bar/body-hover-probe.qml queda como sonda manual. Cambios ajenos preservados; sin commit/push.

## 2026-10-31 · QA de hover/morph y corrección del hueco al cerrar (Agua W1)
- Capturas grim reales (40–80 fps) de hover, abrir/cerrar, reversión, swap y launcher. Hover correcto y tenue; abrir/revertir/swap sin saltos.
- Bug: tras cerrar una surface (calendario) la pill quedaba vacía ~170 ms: `closeness` se mide contra el destino (42 px) y la compuerta de ancho era binaria. Fix: `PillMorphMotion.restReturn` (error contra el recorrido, rampa en el último 28 %), `Pill.morphRestReturn`, `PillHeaderView.restReturn` + rampa de ancho + fundido 0.7·fast, y `IslandOverlay` side modules. Medido: el reloj entra durante el final de la contracción; el reposo coincide con el baseline ~250 ms tras llegar (antes ~700 ms).
- No es bug: el cuerpo "dormida" (9 s sin puntero real) estrecha ~12 px; el cursor sintético no cuenta como actividad.
- Pruebas offscreen: motion, content-hold, surface-swap-close, notification-breath, compact-island PASS. Visual: capturas Wayland reales. Sin commit.

## 2026-10-31 · Hover calmo bajo Agua (W1)
- Causa probable del crecimiento a un lado: en `curiosa`, `BodyBrain.update` aplicaba lean (lóbulo hacia el puntero), `tox/toy` y `th+` al acercar el cursor; con waterBody el cuerpo es plenamente visible y se notaba. No reproducido con cursor sintético (silueta simétrica en grim); no verificado visualmente con ratón real.
- Cambio: `opts.calmHover` (= `sleepWhenStill`/waterBody) deja sólo `glow` en hover y suaviza `wake` (x0.4). Fuera de waterBody no cambia nada.
- Pruebas offscreen PASS: body-regression, body-pill-regression, water-body-regression.

## 2026-10-31 · Revisión W3 (Claude)
- Diff revisado (9 ficheros): drop+cuello en body.frag vía smin/caja redondeada; Loaders legacy inactivos bajo agua; sin bucles nuevos. Sin hallazgos bloqueantes.
- RHI/OpenGL: water-drop PASS (salto de luminancia del cuello 4/255, caché). water-body RHI FALLA en línea 258 (advanceCount) también en HEAD limpio → preexistente, no de W3.
- Software PASS: water-drop, water-body, body-pill, media-motion, companion-continuity, notification-drop, session-companion.
- QA Wayland (grim, qs reiniciado): abrir/cerrar media coherente, portada visible, sin costura apreciable a 16 fps. Límite: ráfaga de grim no resuelve 1 px/frame.
- Pendiente W4: ambiente de la portada y recepción (se perdieron del PillMaterial retirado; la tarjeta abierta se ve plana).

## 2026-10-31 · Revisión W4 (Claude)
- Codex (Sol·medium, task-mvwnoup8-3s0ign) entregó parcial: decoraciones de media (arte ambiental, recepción, barrido, acento) en body.frag bajo waterBody; PillMaterial descarga sus decoraciones bajo agua.
- RHI/OpenGL: water-drop PASS, water-decor PASS (software), water-body FAIL en línea 258 igual que HEAD (preexistente).
- Software PASS: water-drop, water-decor, water-body (parte sin RHI).
- QA Wayland (qs reiniciado): portada visible y ambiental al abrir; cierre coherente con cuello. Sin costura apreciable a esta resolución de captura.
- Pendiente: el indentado de PillMaterial.qml dentro del Loader de decoraciones no está reindentado (cosmético); recepción y barrido sólo verificados por logica, no en píxeles.

## 2026-10-31 · Música en Agua: aro de neón y acento Tidemark (Claude)

Intento de Codex (M1) revertido por feo; parche en .pareja/musica-agua/codex-m1.patch
y sus restos (test, informe) en .pareja/musica-agua/. Rediseño en hilo principal:
- NeonRing.qml nuevo: halo difuminado (MultiEffect blur, saturado) bajo núcleo
  casi blanco; pista tenue + arco de progreso. Lo usan chip y tarjeta.
- Chip: portada 26→29 px (diámetro 36, aro 2, hueco 1.5), lift leve de brillo/
  contraste; portada fuera del clip para que el neón salga de la gota (metadata y
  Cava siguen recortados). Pista del aro alpha 0.42 para separarse del borde de vidrio.
- Tarjeta: el aro de progreso con neón rodea la portada (margen 8, trazo 3); el
  espectro radial nace del aro; campo de neón visible en pausa (0.6). Play cookie
  animado intacto.
- MediaPalette.tone: con appearance.waterBody usa Theme.accent («acento del
  wallpaper», Tidemark); sin agua conserva el acento de portada.
Pruebas: 13 regresiones media/neon/water/absorption PASS (offscreen RHI); neon
amplía con halo/arco de NeonRing. QA Wayland: capturas chip pausa/tocando,
tarjeta y ráfaga abrir/cerrar sin halo huérfano. No medido GPU/FPS.

## 2026-10-31 · Música en Agua: portada sumergida y ondas (Claude)

Sustituye la entrada anterior: el neón sobraba (aro redundante con la barra de
progreso de la tarjeta, chip desalineado junto al reloj). Dirección aprobada por el
usuario: «Agua con luz del día», una sola luz, nada emite neón. Color de música =
portada (MediaPalette.accent); el resto de la shell sigue con Matugen.
- Revertidos a HEAD: MediaPalette (sin `tone`), MediaSurface, neon-regression,
  rest-media-transition-regression. NeonRing.qml eliminado.
- IslandMediaCover: portada «piedra bajo el agua»: degradado de profundidad abajo,
  menisco hairline y reflejo especular (arco -150°, 48°). El aro de HEAD queda
  opcional porque IslandMediaSummary/CompactMediaStatus lo usan; la gota no lo pide.
- Chip (FluidMediaCompanion): portada 30 px centrada en el remate de la gota con el
  mismo margen lateral que vertical; mismo vidrio que el reloj.
- IslandMediaVisualizer: sin halo MultiEffect (objectName smallCavaBars).
- MediaView: fuera campo de neón y espectro radial de 48 bandas; tres ondas
  (mediaRipples) alrededor de la portada que se abren con Cava (5/8/11 px máx.),
  reposo tenue; degradado, menisco y reflejo sobre la portada. Cookie de play intacto.
Pruebas PASS (offscreen RHI): media-palette, media-layout, media-presentation,
media-motion, media-ambient, neon, cava-center, rest-media-transition,
compact-island, companion-continuity, water-drop, water-decor, media-timeline,
swift-media-timeline, absorption; swiftify-media pasa la parte de ondas pero cae
después en `toggle.contentItem.fontInfo` (falla igual en HEAD). QA Wayland:
capturas chip junto al reloj y tarjeta abierta con música sonando. Errores de
IslandMediaSummary en el log son de una recarga intermedia; la última carga es
limpia. No medido GPU/FPS.

## 2026-10-31 · Música en Agua: cambio de canción y aro del chip (Claude)

Petición: mejor transición de canción con la tarjeta abierta y en el chip; volver a
ver el progreso sin abrir la surface.
- Coreografía «la canción cae al agua»: la portada se hunde un poco, una onda sale
  de su borde y la portada y los textos nuevos suben desde abajo.
- Tarjeta (MediaView): trackKey = título+artista. trackLanding hace un hundimiento
  de 4 % (Scale sobre artwork) y una onda mediaTrackWave de +34 px que se apaga.
  ArtworkImage swapTravel 12 px. Textos en relevo (CrossfadeLabel.sequential:
  el viejo sale acelerando antes de que entre el nuevo), escalonados 0/60/110 ms y
  con recorrido 10/8/6 px. Sólo con mediaMotionAllowed; reduceMotion lo deja quieto.
- CrossfadeLabel: nuevas `delay` y `sequential`; por defecto se comporta igual
  que antes.
- Chip: el aro vuelve, concéntrico con el remate de la gota. Diámetro 34, trazo 2,
  hueco 1.5 y portada 27. Sin glow (ringGlow:false), pista Qt.alpha(foreground,0.10)
  y color de la portada. shownProgress se anima, así que al cambiar de canción el
  arco se vacía en lugar de saltar. La onda mediaCoverWave (trackWave) muere en el
  borde del vidrio. IslandMediaSummary conserva su aro con glow.
Pruebas PASS: media-palette/layout/presentation/motion/ambient, neon, cava-center,
rest-media-transition, compact-island, companion-continuity, water-drop/decor,
media-timeline, swift-media-timeline, absorption, calendar-design/media,
auth-prompt. swiftify-media sigue fallando igual que en HEAD (fontInfo).
Fotogramas de fixture (no en vivo) cada 50 ms: relevo de texto sin superposición
y onda visible; reducido sin onda ni hundimiento. En vivo sólo la captura estática
del chip con el aro al 16 %; no salté canción en Spotify. No medido GPU/FPS.

## Barra: centro común y aro del chip legible (2026-10-31, Claude)

- Medición en vivo (grim DP-1): rail/launcher centrados en y≈31.5, estado/avatar
  e isla en ≈26.5, cuerpo dormido ≈29.5. Causas: el rail mide 48 con píldora de 38
  y compartía topMargin con módulos de 38; BodyBrain dormido hundía el cuerpo 3·k.
- TopBarModules: rail no compacto sube 5·s (compacto ya bajaba los de la derecha).
  TopWorkspaceRail: botón de cuadrícula 44→38 y navWidth 68→60 (22·s de aire, se
  conserva la separación del 2026-10-01); test top-workspace-motion usa 38.
- BodyBrain sleep: sin toy, th 14.5→16.5·k; se encoge en su sitio.
- Aro del chip: ringWidth 2.5·s, pista foreground 0.16, nueva `ringColor` en
  IslandMediaCover; el chip usa el tono de la portada con luminosidad ≥0.72.
- Pruebas: workspace-width, compact-island, module-composer, optional-modules,
  workspace-styles, media-palette, companion-continuity, water-drop, absorption y
  neon pasan. top-workspace-motion falla igual en HEAD («retarget must settle at
  workspace 2»), preexistente. Captura en vivo: fila alineada, arco visible.

## Brillo del cuerpo de agua y anillo del avatar (2026-10-31, Claude)

- Petición: igualar materiales y bajar el brillo que restaba calidad.
- body.frag (qsb recompilado): lens 0.55→0.38; especular 0.42× y edge^6; contraluz 0.22→0.14;
  glow de borde 0.55→0.40; barrido de luz 0.12→0.07. TopUserStatus: anillo 0.65→0.38 y sombra 0.28→0.14.
- Pruebas: compact-island, water-drop, absorption y companion-continuity sin FAIL. Captura en vivo
  comparada: el borde central ya no destaca sobre los módulos laterales.

## Excelencia shell: regresiones, morph y límites de captura (2026-11-05, Claude)

- Petición del usuario (ausente): QA integral y mejora visual/motion sin preguntar. Sin commit ni push.
- Línea base Wayland cerrada: water-body-regression fallaba por tres causas de prueba (tiempo de
  descarga del Loader; expectativa de exposición con reduceMotion tras c00560a; reduceMotion sin
  restaurar). Corregidas sólo en la prueba. PASS Wayland y offscreen. Fallos restantes preexistentes
  (lista en docs/shell-excelencia-2026-11-05/REPORT.md).
- Grabación 240 fps (franja 60 px, sin chat): morph calendario sin saltos ni huecos >12 ms; contenido
  por fundido de ~170 ms. Cambio calendario→launcher a 250 ms sin salto. Reposo sin movimiento.
- Cadencia: 31 de 140 fotogramas repetidos durante el morph (~120 fps sobre 240 Hz). No verificado si
  es compositor, shell o grabador.
- Capturas de superficie completa descartadas como evidencia: el chat de Claude queda detrás del cristal
  y la sesión muestra el nombre de usuario. evidence/bar-top-band.png (recortada, sin avatar) sí se usa.
- Pendiente: lateralDepth en vivo, nitidez dormida, reposo y rendimiento, recorridos de cierre,
  interrupción y reduceMotion, propuesta de cabecera del launcher (docs/previews/ si se aprueba).
- Revisión isla-revisor: 7 menores. Arreglados batería (brillo animado, relleno con inset), avatar
  (acento en capa propia), icono del rail, presented del rail y comentario de BodyBrain. No arreglado:
  cristal del rail bajo el selector con módulos a 0.82 (coste de capa offscreen).
- Regresiones tras arreglos: battery-indicator, top-workspace-motion, body, neon, compact-island PASS
  en Wayland. top-system-status FAIL en Wayland 2/2 («empty width 106 base 101»), PASS offscreen.
  Pendiente de investigar; no confirmado que sea mío.

## Shell excelente, segunda tanda (2026-11-05)
- Sondas PROBE/GLOWPROBE retiradas (InnerGlow, PillSurfaceHost, BodyEngine). Detalle y medidas: docs/shell-excelencia-2026-11-05/REPORT.md.
- Cambios: ClockReel por dígitos, AudioSnapshot (caché del mixer), lámparas .004/.02, followGlassW/H, idle glow a 0 frames/s.
- top-system-status flaky en Wayland: causa = espera fija; test pasa a tryVerify. 17 regresiones Wayland + body-brain PASS.
- Sin commit. Pendiente: revisión isla-revisor y microinteracciones en vivo.

