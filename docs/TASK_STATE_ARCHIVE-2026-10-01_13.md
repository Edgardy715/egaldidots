# Archivo de TASK_STATE.md: fases 2026-10-01 a 2026-10-13

Movido sin cambios desde TASK_STATE.md el 2026-10-22 (líneas originales 1236–3392).
No añadir fases aquí: las nuevas van a TASK_STATE.md. recall.py indexa este archivo;
también sirve `rg`. Índice de archivos en la cabecera de TASK_STATE.md.
<!-- fin-cabecera-archivo -->

## 2026-10-01 · Navegación de workspaces refinada

El usuario consideró demasiado genérico el segmento anterior. `TopWorkspaceRail` ahora incorpora icono de cuadrícula con hitbox de 29·s que abre la surface existente `workspaces` mediante SurfaceRouter, seguido de separador y números. La lente es vidrio neutro más definido, con borde/catchlight propios y ancho que se deforma como máximo 7·s durante el desplazamiento; conserva una única `SmoothedAnimation` sobre `x`, sin loop ni color fijo. Se retiró el subrayado rojo. El número enfatizado sigue la lente, no el destino. El exterior sigue usando PillMaterial, y el ancho resultante equilibra el estado derecho. No se modificaron reloj/avatar ni workspaces surface.

QA: captura Wayland final `/tmp/isla-nav-premium-final-crop.png` e intermedias `/tmp/isla-better-motion.png` inspeccionadas. Instrumentación temporal confirmó pasos de `x` entre origen/destino durante cambio real; trazas retiradas. Ruta del botón al panel verificada con IPC `island workspaces DP-1` y captura `/tmp/isla-nav-panel-crop.png`, luego cerrado. `qmllint`, `git diff --check` y logs sin errores nuevos; workspace 4 restaurado. Sigue sin verificarse el clic físico por falta de inyector Wayland disponible; la ruta usa MotionArea y el mismo SurfaceRouter probado por IPC.

## 2026-10-01 · Respuesta física y hover del rail

El usuario indicó que la animación del rail aún no evocaba la navegación Apple actual. Contrastados Apple HIG Motion/Materials y WWDC25 Liquid Glass/iPad: movimiento útil, hover con resaltado que alcanza al puntero, distinta intensidad según entrada y uso contenido de vidrio. La implementación es una adaptación QML a Isla, sin refraction shader ni réplica del material propietario.

`TopWorkspaceRail` ahora dirige la misma lente hacia el segmento bajo el puntero y la devuelve al workspace activo al salir; mientras el puntero está en otro segmento, el número activo conserva un acento tenue para distinguir selección de preselección. El SpringAnimation nativo resultó demasiado lento en este recorrido. Se sustituyó por un único `FrameAnimation` que integra la ecuación amortiguada usada por FluidCompanion, con ω=26 al hover/19 al retorno y límite de 32 ms por paso; conserva velocidad al retargetear y se detiene por distancia/velocidad subpíxel. Movimiento reducido y ocultación resuelven directamente al destino; no hay frames continuos en reposo. Lente interior más discreta para evitar doble vidrio pesado.

Pruebas: `bar/top-workspace-motion-regression.qml` con `ISLA_CONFIG` temporal pasa viaje intermedio, retarget, reposo, reduceMotion y ocultación. Captura Wayland `/tmp/isla-liquid-motion.png` muestra hover 4→5 y retorno; `/tmp/isla-liquid-final-crop.png` muestra reposo. `qmllint`, `git diff --check` y logs de componentes sin errores nuevos. No se cambió workspace real para esta QA; al retomar la sesión estaba en 1 y quedó en 1. Sigue sin verificarse clic físico por la limitación previa del inyector Wayland. Diseño pendiente de valoración del usuario.
## 2026-10-01 · Boceto fluido para el rail de workspaces

El usuario aportó un boceto nuevo con tres islas: izquierda, botón de cuadrícula circular conectado por un cuello a un rail y una esfera activa luminosa; centro, avatar integrado con reloj; derecha, estado. La prioridad actual es reproducir el efecto de la izquierda; el avatar se incorporará gradualmente. `TopWorkspaceRail.qml` reutiliza `PillMaterial` para el rail y el botón, y `FluidMetaballBridge` para unirlos. La lente existente conserva su único motor `FrameAnimation` y se convierte en esfera sobresaliente, con gradiente oscuro→acento dinámico, brillo y borde; se restauran puntos de ocupación del boceto. No se cambió el reloj ni el estado derecho.

QA: captura Wayland completa `/tmp/isla-fluid-rail-final.png` y detalle `/tmp/isla-fluid-rail-final-detail.png` inspeccionados; recarga activa sin errores nuevos del rail; `qmllint`, `git diff --check` y `top-workspace-motion-regression.qml` con `ISLA_CONFIG` temporal pasan. La fixture comprueba puente válido, esfera dentro del rail, desplazamiento intermedio, retarget, reposo, movimiento reducido y ocultación. El efecto se aproxima al boceto con formas y transparencias QML; no reproduce literalmente su refracción/render. Clic físico y valoración visual del usuario pendientes.
## 2026-10-01 · Pulido de transición entre workspaces

El usuario aprobó el glow interior y pidió concentrar la fase en la transición del círculo activo, con revisión ampliada y fotograma a fotograma. La revisión Wayland de 1→5→2→1 encontró cambios bruscos: el ancho de la esfera dependía de la distancia restante y saltaba al elegir destino; el borde usaba `accentSoft` verde de la paleta actual; dos cifras podían quedar simultáneamente dentro de la esfera; un reflejo rectangular escapaba visualmente del arco superior. También había un hueco lógico: ocultar el rail a mitad de movimiento congelaba la esfera hasta reaparecer.

`TopWorkspaceRail.qml` conserva un solo motor, pero integra exactamente el resorte amortiguado usando el intervalo real entre frames, con posición y velocidad continuas al retargetear. La deformación se aplica como transformación alrededor del centro y depende de velocidad, sin recalcular ancho ni desplazar el centro. Los números se apartan según cobertura geométrica y velocidad, reapareciendo al asentarse; los puntos pierden opacidad según la cobertura. El cambio de workspace limpia hover previo y ocultar resuelve destino/velocidad. Se usa el acento cálido del tema en el borde, se retiró la línea recta de brillo y se amplió 6·s el cuello para leer mejor su forma. No se añadieron shaders, dependencias ni efectos globales; el glow de otras interfaces queda pendiente.

QA: `top-workspace-motion-regression.qml` pasa recorrido intermedio, deformación, retarget, reposo, ocultación en vuelo y movimiento reducido con `ISLA_CONFIG` temporal. `qmllint`, `git diff --check` y logs de la shell activa sin errores nuevos del componente. Se capturaron secuencias Wayland reales en DP-1 con `grim`, se inspeccionaron contactos ampliados (`/tmp/isla-workspace-transition-frames.png`, `/tmp/isla-workspace-last-contact.png`) y se guardó preview final `/tmp/isla-workspace-polished.gif`; workspace 1 restaurado. La captura interna offscreen omitió capas de `PillMaterial` y se descartó para juicio visual. Las capturas no certifican todos los frames ni FPS constante; la fidelidad óptica exacta del boceto y el clic físico siguen sin certificar.
## 2026-10-01 · Botón de cuadrícula separado del rail

El usuario señaló que la unión entre el botón izquierdo y los cinco workspaces no se veía bien. Se retiraron los dos `FluidMetaballBridge` de `TopWorkspaceRail.qml`, incluido su import, y `navWidth` pasó de 60·s a 68·s: el círculo de cuadrícula de 44·s queda con 24·s de aire antes del rail. No se alteraron esfera activa, material interior ni resorte. La regresión ahora verifica el espacio en lugar de la validez del puente.

QA: captura Wayland `/tmp/isla-workspace-separated.png` y ampliación `/tmp/isla-workspace-separated-zoom.png` inspeccionadas; `qmllint`, `git diff --check` y `top-workspace-motion-regression.qml` con `ISLA_CONFIG` temporal pasan. Logs activos sin errores del componente. Cambio visual aún pendiente de valoración del usuario.

## 2026-10-01 · Lenguaje de glow de Isla

El usuario pidió pulir el glow como rasgo distintivo de toda la shell. Auditoría de `PillMaterial`, tarjetas, workspace, Overview, OSD, portada musical y avisos: los halos uniformes no explicaban selección; el interior crítico anterior era invisible por opacidad heredada, y la portada perdía toda luz al pausar. Se creó `bar/components/InnerGlow.qml`, una luz radial interior pequeña, dependiente del acento del tema y sin animación continua. `PillMaterial` la usa sólo en islas compactas activas, con menor intensidad en reposo; los paneles grandes y el lateral permanecen tranquilos. La tarjeta del workspace activo y Keep Awake encendido reciben luz local. Overview pone un halo detrás de la vista elegida. El OSD centra la luz según el valor. La alerta crítica usa luz interior y un único borde pulsante; al reducir movimiento, cesa el pulso. La portada musical conserva halo tenue en pausa y modula intensidad con CAVA al reproducir.

Iteración visual: el primer pase produjo una mancha amplia en Calendario y Overview. Se redujo el radio y se limitó `PillMaterial` por tamaño para anclar el glow al estado. Capturas Wayland DP-1 finales `/tmp/isla-glow-final-overview.png`, `/tmp/isla-glow-final-workspaces.png`, ampliación `/tmp/isla-glow-workspaces-zoom.png` y OSD `/tmp/isla-glow-final-osd.png` inspeccionadas. Keep Awake se activó temporalmente para `/tmp/isla-glow-refined-utils-active.png` y se restauró apagado. Volumen restaurado a 1.00, workspace 1 y superficies cerradas. `qmllint` de nueve archivos, `git diff --check`, y regresiones `overview`, `notification`, `interaction-surfaces`, `motion` pasan. Logs de shell activa sin errores nuevos de QML; persisten avisos previos de icono `input-keyboard` y ruta temporal de una imagen de notificación. El halo de portada con reproductor real y el aviso crítico real no tuvieron QA visual; las regresiones offscreen sólo confirman carga y comportamiento, no acabado óptico.

Seguimiento del usuario: la pill principal y la de batería/estado recibieron una luz interior tenue. Se elevó la intensidad de reposo de `PillMaterial` de 0.16 a 0.34; `TopSystemStatus` usa modo `status`, con intensidad 0.38 y foco cerca de sus iconos. El modo `lateral` de los workspaces conserva su aspecto. Captura Wayland `/tmp/isla-pill-glow-final-strip.png` y ampliaciones del reloj/estado inspeccionadas; `qmllint`, `git diff --check`, `motion-regression.qml` y logs activos pasan sin errores nuevos.

## 2026-10-01 · Indicador funcional de batería

El usuario rechazó el glifo de batería previo y pidió silueta Apple, nivel y colores reales. `BatteryIndicator.qml` dibuja contorno, terminal, relleno proporcional y símbolo interior de carga/pausa; su luz se mantiene en la pill lateral ya aceptada. `TopSystemStatus` toma `UPower.displayDevice` sólo cuando está listo y es batería presente, muestra verde al cargar o estar lleno y conectado, gris en `PendingCharge`, rojo hasta 20 %, amarillo entre 21–40 %, neutro por encima. Hover/foco muestran porcentaje y estado; clic usa la ruta existente a Ajustes rápidos. El chip efímero reutiliza el mismo indicador. Se corrigió además el acceso anterior a `percent/status` inexistentes en Quickshell UPower: `Pill.qml` usa `percentage/state`, señales correctas y recordatorio bajo sólo al descargar.

La batería real estaba al 52 % y en `pending-charge`; captura Wayland `/tmp/isla-battery-final-shell-zoom.png` inspeccionada. Preview de cinco estados `/tmp/isla-battery-preview.png` inspeccionada; se ajustó la posición del rayo y pausa para que no crucen la zona vacía del relleno. `battery-indicator-regression.qml` y `status-regression.qml` pasan; `qmllint` y `git diff --check` pasan, recarga final de shell activa correcta. No se cambió físicamente el nivel/cargador para QA. `power-profiles-daemon` está enmascarado en este equipo, por lo que el amarillo indica carga preventiva y no el modo ahorro de iOS. El clic físico/tooltip con puntero no pudo automatizarse; señal y ruta al panel se comprobaron por código/IPC. Referencias: Soporte Apple sobre icono amarillo de bajo consumo y carga en pausa; documentación Quickshell de `percentage/state`.

Seguimiento del usuario: retiradas las dos barras de pausa del indicador; el estado `PendingCharge` conserva el relleno y tono gris, mientras porcentaje/estado siguen disponibles en el tooltip. Captura Wayland ampliada `/tmp/isla-battery-no-pause-zoom.png` inspeccionada; `battery-indicator-regression.qml`, `qmllint` y `git diff --check` pasan.

## 2026-10-01 · Skills para análisis y auditoría de la pill

Se crearon dos skills locales y se enrutan desde `AGENTS.md` sólo para peticiones especializadas. `pill-frame-inspection` reconstruye estado y dueño de la animación, pide captura Wayland con tiempos reales, extracción sin interpolación, lectura de contactos y frames ampliados, localización del primer frame defectuoso, contraste con trazas/fixture, corrección mínima y dos repeticiones comparables antes de cerrar. Su referencia `frame-workflow.md` incluye comandos `ffprobe`/`ffmpeg`/`magick` y distingue frames grabados, muestras `grim`, offscreen y FPS medido. `pill-detail-audit` define un bucle de mapa → inspección a varias escalas → interacción/datos/performance → corrección → doble revisión, con registro de hallazgos y parada cuando no queden defectos reproducibles dentro del alcance disponible. Ambas complementan `fluid-island-motion` y respetan decisiones visuales aprobadas.

Los dos `SKILL.md` pasaron el validador de `skill-creator` con un Python local que ya incluía PyYAML; la receta `ffprobe`/`ffmpeg`/`magick` produjo seis frames y un contacto a partir de un clip sintético de seis frames. Se enlazaron ambas skills en `~/.codex/skills` siguiendo el patrón de las skills previas; `.agents/` y los documentos de memoria siguen excluidos sólo por el Git local. No se añadieron dependencias, automatizaciones recurrentes ni procesos persistentes. La validación estructural no prueba todavía su eficacia durante una auditoría real; eso requiere la siguiente petición de uso.

## 2026-10-04 · Auditoría de surfaces y clipboard

Continuada auditoría integral; usuario confirmó clipboard y pidió previews y botón rápido de limpieza. Evidencia/métricas/cobertura en docs/SURFACE_PERFORMANCE_AUDIT.md. Loader asíncrono: máximos anteriores hasta106.69ms, posteriores todos<14ms en una pasada. Notifs ListView: p95 4.85/4.71ms frente8.04ms previo. Interrupciones máximo20.22/10.95ms. Intervalos QML, no FPS presentado. Instrumentación retirada y shell.qml sin diff.

Clipboard carga/copia/previews asíncronos, copia exacta texto/PNG, foco exclusivo y filtro correctos. Miniaturas144/vista768×320 con magick en mktemp privado. Super+V Lua activo ~/.config/hypr/modules/binds.lua y paquete legacy; respaldo en ~/.local/state/hypr-animation-backups/. Watchers existentes conservados. Limpiar todo usa cliphist wipe sin bloquear, guardas contra doble clic/copia y fallo conserva lista. Fixture simula borrado200ms y comprueba frames/success/error/doble llamada; comando wipe probado con DB temporal aislada. No vaciado del historial real en QA. Captura /tmp/isla-clipboard-clear-button.png inspeccionada y shell recargada.

Regresiones aprobadas detalladas en informe. Fixture lockscreen-motion actualizada a activateInput desde reposo sin tocar diseño. Qt6 lint mantiene avisos de metadatos/unqualified, sin sintaxis; /usr/bin/qmllint es Qt5. Cambios previos conservados; no energía/PAM real. QA música real, WiFi, brillo/perfiles y multimonitor limitado por disponibilidad.

## 2026-10-04 · Microinteracciones fluidas

Usuario pidió animar limpieza y todas las microinteracciones abruptas de la pill. Auditoría de componentes/surfaces localizó confirmaciones de sesión, metadatos multimedia, rótulos de mute, listas de redes/dispositivos y estados vacíos. ContentMotion200ms retira contenido con opacity/scale0.975→1/traslado6px; se conserva modelo hasta terminar. Clipboard sólo retira tras éxito de wipe; fallos conservan entradas. Notifs usa misma coreografía. AnimatedLabel70+120ms lleva texto al último destino y resuelve inmediato al ocultar/reduceMotion; aplicado a metadata compacta/grande, mixer, connectivity, appearance y sesión. Porcentajes/tiempos de actualización continua siguen inmediatos. MotionList usa add/remove/displaced Qt nativo y modelos con identidad; WiFi/BT reemplazan Repeater/stagger simultáneo. MotionArea agrega confirmación breve de color al clic, sin hitbox transformado ni trabajo en reposo.

QA: microinteraction-regression pasa offscreen y Wayland (posición intermedia, retarget, último texto, clic/ocultación, filas retenidas al salir/recolocación, reduceMotion). Clipboard fixture pasa texto/image/clear/error/clear-reduced en Wayland y offscreen; prueba salida con modelo conservado y frames durante wipe simulado200ms. Capturas nativas de fixture /tmp/isla-micro-20261004/ y contacto clear-only inspeccionados; no se borró historial real. Session confirm/cancel vía teclado en shell real, captura /tmp/isla-session-confirm-micro.png; no ejecución de energía. Connectivity real desactivado en /tmp/isla-connectivity-micro.png; filas nuevas/reordenadas probadas con modelo fixture, no redes reales. Regresiones session, interaction, interaction-surfaces, media-motion y motion pasan con ISLA_CONFIG temporal. Qt6 lint sin sintaxis, conserva avisos previos de scopes/metadatos; corregido warning opacity+value-source en vacío WiFi. Sin certificación de FPS nuevo ni QA media MPRIS/WiFi activos; cambios preexistentes preservados.

## 2026-10-05 · Rediseño de coreografía pill/surfaces y escritura

Conservados los numerosos cambios preexistentes. PillSurfaceHost revela Loader
asíncrono con Motion.standardSmall y desplazamiento4·s; no reinicia retirada al
cambiar destino varias veces, cancela al volver al actual y completa al activar
reduceMotion. PillSurface usa smoothstep; StaggerItem unifica progreso con
SmoothedAnimation, traslado6·s y escala0.985, retraso máximo200ms base. Calendario,
workspaces y Utils esperan contentReady y suavizan escala específica.

IslaTextField mantiene TextInput nativo sin cursor delegado rezagado; placeholder
respeta floating y reduceMotion. Launcher/Clipboard reutilizan componente.
Launcher retiene visibilidad de resultados durante salida; WiFi cancela recoil
al ocultar/reduceMotion, Auth respeta reduceMotion en foco. Wallpaper sólo promueve
readyPreview cuando termina su revelado. LockSurface vincula alas a expansión
central, desvanece media inferior, corrige foco al cerrar energía y detiene pulso
de puntos al ocultar. PAM y acciones reales no alterados.

Validación: motion-regression, surface-choreography (offscreen y Wayland),
absorption, notification, carga13 surfaces, input-motion, Auth, Wallpaper,
Clipboard y ambas regresiones lockscreen pasan según pruebas de coordinador y
agentes. Qt6 qmllint sale0 con avisos previos; binario genérico sale255 sin texto.
git diff --check pasa. QA representativa de calendario/Utils apertura/intercambio
y lockscreen en previews Wayland inspeccionadas. Capturas iniciales en
/tmp/isla-motion-redesign-20261004 y /tmp/isla-lock-agent-capture son temporales.
Una ejecución QtTest sufrió crash al recargar imports durante ediciones
concurrentes; fixtures nuevas usan settings.watchFiles:false y la repetición
Wayland de coreografía pasa (log output-z61g6upb.log). No certifica FPS,
autenticación real, IME ni multimonitor.

Cierre: shell recargado vía IPC (true). Input-motion final corregido para usar
keyClick de QtTest sobre el foco real (sin argumento item), espera inicial150ms
 y watchFiles:false; PASS explícito offscreen en output-0s8itey9.log. QA visual
final de escritura no completada por el agente; no se presenta como comprobada.

## 2026-10-05 · Escritura limpia en todos los textboxes

Solicitud explícita de mejorar sensación al escribir. Inventario vigente: tres
IslaTextField (Launcher, Clipboard, Appearance) y tres TextField (WiFi, Auth,
LockSurface). Se preservaron ediciones previas. InputCaret comparte presentación
sin almacenar texto: posición/altura nativas de Qt, sólido mientras se escribe
y navega, anchura1.5→2px, reposo alpha1↔0.25 con tokens y cursorFlashTime.
Selección/readOnly/ocultación/ventana inactiva detienen el trabajo; reduceMotion
sólido. InputPlaceholder unifica hints, evita doble placeholder del lockscreen,
oculta inmediatamente al escribir o componer y reaparece140ms base al limpiar.
Floating label transforma escala0.72/posición sin animar font.pixelSize, padding
alineado; launcher/clipboard mejoran contraste de ayuda y el botón limpiar
launcher aparece discretamente sin cambiar el ancho del campo.

Lockscreen: simplificada entrada de puntos a scale0.92/traslado2px/opacidad en
Motion.fast, sin giro ni doble bounce; sincronización de modelo inmediata y
borrado por rango acotado, ancho mínimo para materializar primer delegado.
Guarda de composición al enviar; modelo contiene sólo slots numéricos.

Validación: textbox-motion PASS offscreen (output-4a32z142.log) y Wayland
(output-_wj61gso.log): cursor x exacto incluso al insertar Unicode largo y
scroll, escritura, selección, borrar, Home/End, hints, máscara, ocultación y
reduceMotion. Input-motion PASS Wayland (output-jbgzwjjd.log); Auth PASS
(output-bc8_i_7x.log), carga13 surfaces PASS (output-1ceben9o.log). Lockscreen
typing PASS offscreen y Wayland (output-4r09i__b.log/output-yr6tnjrp.log);
lockscreen-motion y lockscreen-regression PASS. Qt6 qmllint sale0 con avisos de
metadata genérica Qt.styleHints y scope; runtime valida cursorFlashTime.

Capturas sintéticas inspeccionadas: /tmp/isla-textboxes-20261005 (campo común,
floating, protegido y WiFi), /tmp/isla-launcher-typing-20261005 (escribir, borrar
y reabrir), /tmp/isla-lock-typing-20261005 (seis puntos centrados). Son muestras,
no medición de FPS ni certificación de cada frame. No conexión WiFi/PAM real;
no se probó IME real ni pegado desde el clipboard personal (sí inserción larga
y Unicode por API nativa). Queda valoración subjetiva al escribir físicamente.


## 2026-10-05 — Isla no respondía al arrancar

Reproducido en shell real Wayland mediante reinicio del proceso: primera llamada
IPC launcher a ~50ms devolvía true pero no mostraba panel. Instrumentación temporal
mostró focusedMonitorName vacío, monitores ausentes o incompletos y workspace null
un segundo después, sin acciones posteriores.

Causa: shell.qml llamaba refreshMonitors/refreshWorkspaces desde onCompleted.
Quickshell 0.3.1 inicia su sincronización después de consultar j/status; el refresco
QML usa canCreate=false y el nativo canCreate=true. Si el primero queda en vuelo,
requestingMonitors/requestingWorkspaces hacen que el nativo se descarte, dejando
modelos vacíos hasta que nuevos eventos crean objetos. Referencia de implementación:
https://raw.githubusercontent.com/quickshell-mirror/quickshell/master/src/wayland/hyprland/ipc/connection.cpp
(constructor, refreshMonitors y refreshWorkspaces). Eliminar la consulta anticipada
permite la carga nativa; Qt.callLater no bastaba y no se conservó.

SurfaceRouter conserva sólo el último destino si aún no hay monitor enfocado;
el mismo toggle cancela, hide/present limpian y al llegar foco continúa por la
ruta normal, incluido docking. Pill marca wsReady al completar construcción
en vez de absorber el primer cambio real desde workspace 1.

Validación: arranque frío con trazas confirmó foco DP-1, workspace1 y launcher
abierto tras la primera llamada. Arranque frío final sin instrumentación repitió
primera llamada a50ms; captura /tmp/isla-startup-final.png inspeccionada, panel
visible. Antes /tmp/isla-cold-before.png sólo mostraba reposo. No se cambiaron
workspaces reales, volumen, reproducción ni wallpaper. Router regresión PASS
(output-49p4d2xp.log): petición antes del foco, último destino, cancelación por
toggle/hide y rutas previas. Motion PASS final (output-luv9c8a6.log) incluye
wsReady tras construcción; qmllint cinco archivos PASS (output-rfjsqngw.log),
git diff --check PASS. Un intento de simular activeWsName desde fixture falló
por readonly y fue retirado; prueba final usa readiness real del componente.
Las capturas no certifican fluidez ni login de sesión nuevo/multimonitor. Trazas
startupDebug retiradas; shell final activo y surface de prueba cerrada.


## 2026-10-05 — Monitores adaptables y cadencia de escritorio

Usuario pidió configuración adaptable y reportó sensación inferior a240Hz.
Preferencia explícita: sólo externo cuando conectado; laptop al desconectarlo.
Configuración activa ~/.config/hypr/modules/monitors.lua cambió regla fija DP-1
1920x1080@239.96 en1920x0 y eDP-1 desactivado permanente por fallback highrr,
posición/escala auto, VRR fullscreen2 y política nativa de eventos. Paneles
eDP/LVDS/DSI descubiertos en sysfs; sólo reaplica al cambiar estado, sin daemon.
Misc usa hardware cursors auto2 y VRR fullscreen2; autostart retiró dpms DP-1 fijo.
EnvVars calcula GPU primaria desde salida externa conectada y conserva todas
las cards detectadas. Orden calculado por boot, sin card0/card1 persistentes.
Respaldo: ~/.local/state/hypr-monitor-backups/20261005-011132/.

Antes: salida MSI239.964Hz, Intel card1 primaria, NVIDIA salida secundaria con
copias multigpu LINEAR. Probe Qt temporal Window/FrameAnimation dio mediana
16.7ms; mide callbacks QML, NO presentación física/FPS global.
Usuario interrumpió, reinició y reportó enorme mejora de fluidez. Verificación
posterior: NVIDIA card0 primaria, Intel card1 secundaria; DP-1 239.964Hz,
eDP-1 desactivada y cero configerrors. Cursor auto2 vigente pero hardwareCursors
InUse false; no atribuir mejora a cursor hardware activo. VRR false en escritorio
coherente con política fullscreen. No reiniciamos/cerramos sesión nosotros.

Prueba runnable ~/.config/hypr/tests/monitors.lua PASS: nombres distintos eDP-2/
DP-3/HDMI, unplug simulado habilita panel, replug desactiva, eventos redundantes
no generan reglas nuevas y GPU renumerada7/4 conserva ambas priorizando externa.
luac cuatro módulos pasó antes del reinicio. Desconexión física, otro monitor y
medición de presentación posterior pendientes; mejora subjetiva confirmada por
usuario. Cambios sólo configuración Lua activa, paquete legacy del repositorio
no migrado.


## 2026-10-05 — Win+B Zen y transparencia Spotify

Configuración Lua activa: binds.lua añade SUPER+B → zen-browser (binario
/usr/bin/zen-browser presente). windowRules.lua añade spotify-glass para clases
Spotify/spotify, opacity0.88 activa/0.82 inactiva. Respaldo en
~/.local/state/hypr-monitor-backups/zen-spotify-1791177589/. luac PASS, reload
ok, configerrors vacío y único Win+B registrado como dispatcher __lua. La
primera comprobación esperaba arg literal, pero Hyprland serializa callbacks
Lua por ID; check corregido PASS. Spotify no estaba abierto, transparencia
real sin QA visual; no se lanzaron apps para verificar.

- Ajuste Spotify posterior: usuario no percibía transparencia inicial. Clase real Spotify/XWayland confirmada; opacity0.72 override activa/fullscreen y0.65 override inactiva. luac/reload/configerrors pasan. Ventana real enfocada para QA y captura /tmp/isla-spotify-after.png inspeccionada: wallpaper oscuro se percibe tenuemente bajo zona central, texto/arte también reciben opacidad global. No se modificó tema Spicetify ni reproducción.

## Apps del lateral derecho (2026-10-05)

Petición: iconos lado a lado sin nombre, lateral compacto y apertura/cierre animados.
TopSystemStatus obtiene las apps del workspace visible por monitor, deduplica por
class y ordena para mantener identidad estable con ScriptModel. MotionList aplica
entrada opacidad/escala/traslado corto, retirada y recolocación; SmoothedAnimation
retargetea el ancho del único PillMaterial. Sin apps quedan volumen/red/batería;
una app ocupa144px con batería frente a233px previos, y cada app añade26px.
El ancho está acotado al espacio lateral; overflow permite desplazamiento horizontal.
ReduceMotion/ocultación deshabilitan transiciones. Iconos sin recurso usan fallback;
los nombres permanecen sólo en accesibilidad. Corregida referencia Image.status
ocultada por id status del Row: ahora está explícitamente calificada.

Validación: top-system-status-regression.qml PASS en Wayland y offscreen con
ISLA_CONFIG temporal; identidad/deduplicación, expansión intermedia, salida,
retarget, vacío, ancho acotado, reduceMotion y ocultación. Check de icono visible
tras carga incluido. qmllint Qt6 sin avisos y git diff --check pasan.
QA Wayland sintética de0/1/2/3 apps, entradas/salidas y captura real del icono
ChatGPT inspeccionadas (/tmp/isla-status-shots, /tmp/isla-status-live-detail.png).
Shell recargado. No se cerraron apps del usuario ni se cambiaron workspaces;
multimonitor y overflow con muchas apps reales no verificados visualmente.
Cambios preexistentes de Pill/SurfaceRouter/shell y sus regresiones preservados.

### Nombre temporal y hover de app única (2026-10-05)

Feedback: sólo con una app, revelar nombre al aparecer y al hover; varias apps
conservan iconos únicamente. TopSystemStatus retiene nombre accesible/resuelto,
Timer finito de1800ms cuando aparece una identidad nueva como única app y hover
pasivo en área de apps. El ancho SmoothedAnimation incluye texto acotado120·s;
texto recortado/elidido y opacidad ligada al espacio disponible, con retirada
Motion.fast. Pasar de varias apps a una existente no reinicia presentación;
múltiples apps y ocultación cancelan el timer. currentIndex=-1 evita scroll
implícito de ListView que ocultaba el primer icono tras contraer la etiqueta.

Fixture ampliada: introducción→contracción automática, entrada/salida de hover
mediante QtTest, varias apps sin nombre incluso con hover y retorno2→1 sin
repetir intro. PASS Wayland, qmllint sin avisos, diff check. Offscreen de esta
revisión falla la aserción de icono visible (Image.Null); no se cuenta como pase.
Capturas
single-intro/single-hover/single-compact/two inspeccionadas; shell recargado.
No QA multimonitor ni hover físico continuo medido; no se alteraron apps reales.

## Modularización: módulos laterales opcionales (2026-10-05)

Petición: los módulos añadidos a ambos lados son opcionales para la futura app
 de configuración; la pill central siempre permanece. Continuar modularización.

- Settings.js/Config exponen `modules.workspaceRail`, `systemStatus`, `apps`,
  `audio`, `network`, `battery`, `animateChanges`, booleanos/default true. Defaults
  conservan apariencia actual, JSON legado y contrato de sesión/persistencia.
  El ejemplo/schema/validación y documentación están actualizados. No hay app
  nueva ni ajuste para apagar la pill principal; atajos/surfaces siguen disponibles.
- TopBarModules compone ambos laterales por monitor. OptionalModule encapsula
  Loader, exposición de 200ms con tokens Motion y traslado superior8·s; al
  desactivar libera interacción inmediatamente, conserva contenido durante la
  retirada y lo descarga al terminar. Invertir empieza desde exposición actual.
  Es fade/traslado de módulos independientes, no motor de masa de las gotas.
  Ocultación temporal conserva módulo habilitado. Movimiento reducido o quitar
  animateChanges resuelve en curso de inmediato. Estado de interacción gobierna
  regiones Wayland; pill/geometría central no depende de laterales.
- TopSystemStatus adapta servicios y entrega datos a TopAppStrip, TopAudioStatus,
  TopNetworkStatus y TopBatteryStatus. Conservados intro/hover de app única,
  identidad por clase, overflow y tooltip de batería. Apps se descarga al apagar;
  tracker de audio local se libera. Ancho depende de controles presentes; incluso
  sólo red cabe en monitor estrecho. Todo desactivado descarga contenedor.
- ShellRuntime concentra adaptación router↔Auth/WinMap/Notifs, bindings Motion,
  inicio de singletons y refresh allowlist Hyprland. shell.qml queda composición,
  router/ventanas e IPC. Conservado fix previo de arranque frío sin refresh inicial.
- Pruebas: settings.cjs, settings-integration.py y verify-config PASS. Nueva
  optional-modules-regression PASS offscreen y Wayland: carga/retirada/descarga,
  inversión, entrada, interacción, clic QtTest mixer en composición, controles
  individuales, espacio estrecho, ocultación temporal, sin animación y reduceMotion
  activado durante salida. top-system-status-regression Wayland PASS conserva
  prueba preexistente de apps. surface-router-regression PASS por extracción.
- QA: capturas comparables de fixture en /tmp/isla-module-shots inspeccionadas;
  shown/exiting/reversed/unloaded/network-only. Capturas grim shell real
  /tmp/isla-modules-live{,-exiting,-disabled,-network}.png inspeccionadas: central
  permanece, laterales se retiran, sólo red compone vidrio compacto. Previews IPC
  restaurados mediante discard, documento idéntico/dirty=false; no save. Shell
  recargada; Configuration Loaded y Polkit registrado, sin errores nuevos de módulos.
- Qt6 qmllint retorna0; módulos nuevos/hojas sin diagnósticos tras tipar Loader.item.
  Adaptador Config/PanelWindow/imports Quickshell y scopes del overlay conservan
  warnings del tooling/anteriores. git diff --check PASS. No equivaler exit0 de
  Quickshell con pase: se verificaron líneas PASS de cada fixture.
- Fallos hallados y corregidos: Loader.status Ready puede coexistir brevemente con
  item=null al destruir; guardas explícitas/tipos. Desactivar Behavior no terminaba
  una animación ya iniciada; OptionalModule usa animación de exposición explícita,
  stop/retarget desde posición actual. Timer de render vacío se evita en reposo.
- Límites: QA visual en un monitor real; hotplug/multimonitor físico y uso prolongado
  pendientes. No se alteraron volumen, red, reproducción ni estado de energía para
  validar. Se conservaron cambios ajenos existentes en Pill/router/apps/tests.

### Continuación: adaptador de estado de la pill

- Extraído IslandStatusAdapter desde Pill: observa Pipewire/Brightness/UPower y
  Caps Lock, debounce16ms, rebind500ms, poll teclado1000ms y recordatorio60s.
  Expone señales de chips y fallback, Caps Lock readonly, escala y estado de
  fallback. Pill conecta presentación y delega wheel; conserva showVolumeOSD
  y wsReady=true. Imports de servicios extraídos retirados de Pill.
- observeServices defaulttrue conserva comportamiento; false aísla la fixture
  sintética, detiene polling/conexiones/tracker sin escribir servicios reales.
- PASS island-status-adapter-regression (debounce, último valor, chip/fallback,
  escala y API), status-regression y motion-regression. Qt6 qmllint exit0,
  warnings únicamente imports preexistentes sin uso en Pill; diff check PASS.
- Shell real recargada, launcher abierto/cerrado y captura
  /tmp/isla-modular-launcher.png inspeccionada. Log Configuration Loaded y Polkit
  registrado; settings error vacío/dirty=false. No volumen/mic/brillo/Caps reales
  provocados para QA; su emisión probada sintéticamente. Multimonitor físico y
  optimización de sondeos compartidos quedan pendientes; extracción conserva
  sondeos por instancia. Material/geometría siguen a cargo de la pill.

## Modularización progresiva: geometría, material, workspaces y estado compartido (2026-10-05)

Objetivo: preservar comportamiento mientras se separan responsabilidades,
preparando consumidores y configuración para la app futura. Sin app nueva.

- WorkspaceModel adapta monitores/workspaces nativos de Hyprland por screenName,
  expone activo/cantidad/ocupación/urgencia y activate con validación de rango.
  TopWorkspaceRail recibe esos datos y emite workspaceRequested/requestWorkspaces;
  TopBarModules conecta adaptador y router. Modelo descargado con Loader opcional.
  Física, gap, esfera, tipografía y despacho Lua conservados. Renombrada propiedad
  `state` del delegado (colisionaba con Item.state) a workspaceState y scope Bound.
- PillGeometry es cálculo sin servicios/archivos, con catálogo/escala/tokens y
  métricas semánticas de contenido inyectados. Fórmulas conservadas: carga pendiente,
  calculadora/lista/cap/retorno launcher, álbum media, auth y prioridad notificación.
  API Pill mantiene bindings; SmoothedAnimation, límites y progreso de contenido
  siguen en Pill. No duplicar animaciones ni entregar surfaceItem al cálculo.
- MaterialChoreography recibe curva/duraciones/reduceMotion y posee epoch/sweep/pulse.
  Pill mantiene awakenMaterial y valores readonly. Comprobación adicional en morph
  detectó dependencia del orden de bindings: onSurfaceChanged consultaba surfaceOpen
  derivado antes de propagar nueva geometría. Guard ahora surface.length>0; epoch
  aumenta al abrir, hover no despierta barrido, cierre no inicia otro pulso.
- DesktopStatus singleton concentra Caps Lock/poll teclado1000ms, Pipewire tracker/
  rebind500ms, Brightness y UPower/recordatorio60s. Conserva validación sink.ready,
  límites0–1 y señales de batería existentes. Adapters por monitor sólo debouncean16ms
  y deciden chip/fallback/escala. observeServices=false desconecta target y lectura;
  monitorServices=false se usa únicamente en proceso fixture para inyección segura.
  Se eliminan sondeos por pill; no se midieron FPS ni se afirma mejora perceptual.
- Captura temprana de reload mostró controles de estado fuera del vidrio mientras
  ancho estaba pendiente. TopSystemStatus reserva ancho según módulos activos,
  incluso antes de ser visibles; mantiene slots durante retirada y revela cada
  control sólo cuando su posición cabe dentro del vidrio. Separador espera espacio.
  Nueva prueba cubre ancho inicial y activar audio sobre contenedor sólo red.
- PASS workspace-model-regression (dos monitores sintéticos, fallback, urgencia/
  ocupación y clic QtTest con señal sin dispatch real), workspace-motion Wayland,
  optional-modules-regression ampliada, top-system-status-regression Wayland.
- PASS pill-geometry-regression (medidas numéricas conocidas, prioridades y escala2/
  fallback/desconexión de contenido); material-choreography-regression y morph,
  notification-regression por extracción. PASS adapter-regression anterior y
  desktop-status-fanout-regression (dos adapters, debounce/fallback/escala,
  batería, Caps Lock y un tercero desconectado; sólo señales/estado sintéticos).
- verify-config PASS. Qt6 qmllint de todos los componentes nuevos/adaptados exit0;
  sólo cuatro imports previos sin uso en Pill. diff --check PASS. Pruebas requieren
  PASS y ausencia de FAIL; no se interpreta exit0 de QS como pase automáticamente.
- QtTest apps se destruyó por hot reload mientras otra extracción editaba módulo;
  añadida settings.watchFiles=false a fixtures apps/opcionales/modelo. Ejecución
  posterior completa PASS. La compilación provisional de DesktopStatus QtObject
  rechazó hijos; corregido a Singleton antes de validar integración final.
- QA real: reload, reposo, entrada100ms y asentamiento de calendar/launcher y retorno
  inspeccionados en /tmp/isla-modular2-{rest,calendar-enter,calendar,launcher-enter,
  launcher,return}.png. Laterales/material/medidas conservan composición. Logs
  Configuration Loaded y Polkit registrado sin errores nuevos. Documento de
  ajustes idéntico al inicial/error vacío/dirty=false; ninguna escritura save.
- Límites: datos reales de clima aún consultando en captura (no validar clima);
  no se alteró audio/brillo/red/Caps/reproducción/energía ni se autenticó para QA.
  Fanout multimonitor es sintético, no hotplug/monitor físico. Quedan adaptadores
  de servicios dentro de surfaces y composición de contenido en Pill; evaluar
  siguientes separaciones por responsabilidad con el mismo contrato, no crear
  otra fuente de defaults ni fragmentar controladores por número de líneas.

## Modularización de surfaces: espacios y ajustes rápidos (2026-10-05)

- WorkspacesSurface queda como composición de WorkspaceModel y WorkspacesView.
  Vista preserva diez tarjetas/header/marcador direccional/stagger, recibe datos
  y emite workspaceRequested. Modelo común incorpora windows y minimumCount
  (rail default5, panel10), mantiene navegación a espacios vacíos, aislamiento
  por monitor y dispatch Lua existente. Activo>10 no amplía grid; marker acotado.
- UtilsSurface preserva márgenes/PillSurface/requestPage, compone
  QuickControlsAdapter y QuickControlsView. Adaptador conecta Brightness,
  KeepAwake y powerprofilesctl; vista usa propiedades y señales conservando
  error de brillo, rueda consumida, semántica accesible y tarjetas/stagger.
  Selección de perfil validada contra opciones permitidas; optimismo anterior
  y ausencia de confirmación del comando se mantienen en esta fase.
- WorkspacesView inicialmente colocada como hermana de Surface no resolvía
  tipo con Loader, incluso proceso nuevo/import explícito. Movida a components
  con import ../components existente: carga de13 surfaces PASS y shell real
  abre sin error. No se reinició la shell; reload fue suficiente tras corregir.
- Workspace-model-regression y nueva workspaces-surface-regression PASS
  (última con ISLA_CONFIG temporal). Click panel10 sólo captura señal, no
  cambia desktop. Qt6 lint WorkspaceModel/WorkspacesView/Surface exit0 limpio.
  Motion-regression PASS con ISLA_CONFIG temporal: interrupción/swap/reduce/unload.
- QA Wayland: panel espacios inspeccionado en /tmp/isla-workspaces-modular.png;
  Utils estable en /tmp/isla-utils-modular.png, swap a espacios120ms y retarget
  Utils120ms en /tmp/isla-quick-controls-{swap,return}.png; Apariencia y regreso
  estable en /tmp/isla-quick-controls-{appearance,settled}.png. Misma composición,
  glass/material/entradas visibles; no se alteró brillo, KeepAwake, perfil ni
  workspace real. Cerrado al terminar. Config loaded/dirty=false/saving=false/
  error vacío; ninguna escritura. Logs recientes Configuration Loaded limpios.
- La separación habilita reutilización de vistas, no añade preferencias
  persistidas ni crea la app. Pendientes: Mixer/conectividad/restantes surfaces,
  composición de cabecera Pill, catálogo editable y sesión de Config reusable;
  pruebas de acciones reales/hotplug multimonitor no realizadas.
- Cierre: quick-controls-regression PASS con datos mock, escala1.25 y acciones
  capturadas (fixture sólo vista, no adapter/procesos), watchFiles=false y salida
  QtTest controlada. Añadida escala a tres GlassCard y referencias root.s
  explícitas para evitar dependencia de scopes internos. Carga13 surfaces
  posterior PASS. Qt6 lint conjunto exit0 con único warning previo del error
  de brillo (opacity inicial y NumberAnimation); diff --check PASS.
- Última captura tras limpiar scopes/escala (/tmp/isla-quick-controls-final.png)
  mostró lockscreen por inactividad, no panel: NO cuenta como QA visual final.
  No se intentó desbloquear. QA visual anterior sí inspeccionó paneles reales
  antes de ese ajuste; escala1.25 validada por fixture, revisión física final
  pendiente en sesión desbloqueada. Router cerrado por IPC, logs sin errores
  nuevos de componentes.


## 2026-10-05 — cierre de separación integral de surfaces

Solicitud: completar todos los surfaces restantes, preservando comportamiento y
preparando reutilización para la app. Cerradas las 14 entradas: Appearance, Auth,
Calendar, Clipboard, Connectivity, Launcher, Media, Mixer, Notifs, Overview,
Session, Utils, Wallpaper y Workspaces. Tabla de componentes/contratos en
SHELL_ARCHITECTURE.md; PillContentAdapter separa datos de la cabecera.

Vistas reciben datos y emiten intenciones; composición/controladores poseen
procesos, servicios y acciones. Preview cliphist movido fuera de ClipboardView;
NotifsView usa NotifCardView, iconos resueltos por composición y retención por
señales. AuthPrompt conserva compatibilidad/backend y delega presentación.
AppearanceEditor usa borrador y guardado confirmado, Config único. No preferencias
nuevas ni app de ajustes construida. Contratos públicos y geometría conservados.

Validación: PASS en límites estáticos de las 14 vistas y NotifCardView; contratos
Media/Overview/Appearance; calendario/parser sin red; mixer/conectividad/notifs;
launcher; sesión; Auth simulado; MediaSession; overview; motion; input-motion;
wallpaper; clipboard simulado (carga, previews, copia exacta, wipe/error/reduced,
guarda de duplicados); carga de las 14 surfaces. verify-config incluye el gate.
Lint Qt6 de 43 archivos termina exit0, con warnings existentes de scope/tipos
Quickshell y controles; log /tmp/isla-all-surfaces-qmllint.log, no se declara limpio.

La fixture de carga inicialmente instanció Auth real: se restauró la shell y
se corrigió inyección fakeAuth antes de completar. Nueva carga PASS sin registrar
agente ni socket; Auth real comprobado registered=true, inactivo, socket presente.
No autenticación real ni secretos utilizados.

QA Wayland en sesión desbloqueada: 13 paneles abiertos/capturados/inspeccionados;
Auth sólo fake. Sesión y media recapturados a ancho completo para revisar alas;
notificaciones pobladas, clipboard con preview de imagen, wallpaper/biblioteca,
overview con captura real y apariencia/controles/workspaces inspeccionados.
No se ejecutaron acciones de energía/red/audio/brillo/wallpaper/clipboard durante
QA nativa. Clima seguía consultando; media sin reproductor. No demuestra PAM,
conexión de dispositivos, reproducción real, persistencia personal nueva ni
multimonitor físico. Ajustes personales no guardados por esta fase.

Fase de separación completa. Próximo trabajo: catálogo editable e interfaz de
configuración sobre Settings/Config, sin otro motor ni superficies faltantes.


## 2026-10-05 — composición restante y catálogo para la app

Solicitud: cerrar los tres puntos anunciados sin omitir ninguno. Completados:

1. OverlayInputPolicy recibe datos de monitor/surface/companions y calcula foco,
   fullscreen, modalidad, Escape/Auth grab, máscara y backdrop. IslandOverlay
   conserva recursos nativos, conexión router, montaje y routing de teclado.
   No cambian valores de regiones ni política durante cierre/arranque.
2. PillHeaderView reúne reloj/chips y cabecera/divisor/media del launcher con
   datos y señales. PillMorphMotion posee width/height/radius, lastSurface,
   closeness/exposición y respiración; mismos SmoothedAnimation/duraciones y
   bypass de ancho cuando el chip workspace ya lo anima. Pill mantiene API
   pública y composición con Geometry/Material/Notification/Status/Content.
3. Settings.schema añade metadatos de edición a los 30 campos actuales.
   Settings.catalog/Config.catalog/IPC settings catalog cubre pill obligatoria,
   6 módulos opcionales, 14 surfaces, dependencias/capacidades y orden/secciones.
   systemStatus expresa ANY hijo y parentModule; defaults/reglas no cambiados.
   Capacidad de bloqueo identifica wrapper de Isla, no hyprlock. availabilityIsLive
   false: inventario, no sondeos nuevos. Flags/Config son el único contrato.
   Campos sin consumidor pillBlur/showGlyphs inactive; clockSeconds partial
   (dato tick por segundo, reloj compacto sin segundos). time12h cal/lock; pill12h.

Pruebas PASS: nueva pill-composition-regression (clic reloj, ancho workspace,
retarget/reversión, settle/exposición, bypass ancho, breath/reduced); nueva
OverlayInputPolicy con monitores sintéticos/foco/fullscreen/companions/backdrop;
optional-modules (timeout8s insuficiente, timeout20s PASS); motion-regression;
surface-choreography; notification-regression; Config reactive/update/reject/
discard/atomic save en ISLA_CONFIG temporal; settings.cjs y settings-integration.py
con IPC catálogo/cobertura defaults/límites/dependencias/nombres físicos de surfaces.
Gate de límites ampliado con Header/Morph/OverlayPolicy. Diff check pasa.

Lint Qt6 de Pill/Header/Morph/OverlayPolicy/Overlay/Config exit0. Header/Morph/
Pill/Policy sin warnings; 16 warnings de Overlay (PanelWindow metadata y scopes
previos de router) y Config (QProcess::ExitStatus metadata). Log íntegro:
/tmp/isla-composition-final-lint.log. No se declara lint libre de avisos.

QA nativa Wayland: capturas reposo, apertura intermedia/final launcher, Escape y
retorno. wtype real: escribir 2+2 calcula4, Escape/reabrir a80ms conserva query;
Escape en sesión; Right en overview selecciona tarjeta2 sin cambiar workspace;
Escape vuelve a reposo. Capturas /tmp/isla-composition-*.png inspeccionadas.
Geometría/material/cabecera coherentes, sin rediseño. Muestreo de capturas no
certifica cada frame ni FPS. Música real ausente; media inyectada en prueba.
Multimonitor sólo datos simulados; fullscreen sólo política simulada. No acciones
nativas de sesión/audio/red/clipboard/wallpaper para QA.

Durante escritura por archivos, auto-reload vio PillMorphMotion aún no creado;
Quickshell retuvo configuración previa y la carga siguiente recuperó. Biblioteca
Settings requirió reload explícito al cierre para servir los últimos metadatos;
IPC posterior confirma clockSeconds partial. Log final Configuration Loaded,
sólo warning anterior de avatar inexistente. Config personal loaded=true,
dirty=false, saving=false, error vacío. No guardados personales.

Fase cerrada: tres puntos completos. El siguiente trabajo es construir la app
sobre catálogo y get/update/discard/save, no otra separación obligatoria.

## 2026-10-05 — investigación de shells y planificación de configuración

Solicitud: investigar a profundidad shells con apps de ajustes, incluir
Caelestia y Serpantinum y proponer ideas creativas para Isla mientras el usuario
se ausenta. Entrega: docs/SETTINGS_APP_RESEARCH.md, con fuentes, comparativa de
seis proyectos, alcance actual/pendiente, personalización de pill y fases.

Fuentes: documentación oficial y código de Noctalia, DankMaterialShell,
HyprPanel, illogical-impulse, Caelestia y Serpantinum. Investigación independiente
de settings_references complementada localmente con documentación/código.
Noctalia v5+ distinguida de Quickshell legacy; HyprPanel archivado abril2026.
Caelestia Nexus GUI/búsqueda comprobadas en fuente; Serpantinum Guide y editor
izquierda/centro/derecha comprobados. DMS 1.6 septiembre2026 ya incluye Dank
Island, satélites y editor de reposo: no se atribuye exclusividad a ese patrón.

Propuestas: laboratorio de escenas/interrupciones; presupuesto de atención;
acceso contextual al ajuste; presets de densidad/comportamiento; explicación
de arbitraje en preview; recuperación visible de cambios. Priorización app
sobre Config + módulos + laboratorio inicial. No aprobación ni implementación
de diseño; ninguna preferencia nueva añadida sólo para planificar.

Contrastado con SHELL_ARCHITECTURE, Config y MOTION_LANGUAGE: 30 campos,
seis módulos opcionales, 14 surfaces; Config preview es global de sesión,
save asíncrono requiere observar estado. Overrides por monitor, composición
reordenable, perfiles y preview totalmente aislado no existen todavía.
pillBlur/showGlyphs inactivos, clockSeconds parcial, compactclock12h y
radiusScale no equivalente a radio exterior libre explicitados en propuesta.

Validación documental: 11 enlaces de fuente GitHub transformados a raw
respondieron200, incluyendo rutas fijadas por commit. Diff check de los tres
documentos pasa. No tests de shell repetidos: esta fase sólo cambia documentación.
No se instalaron/ejecutaron shells externas ni se inspeccionaron sus interfaces
interactivamente; conclusiones de GUI son de documentación/código. Ajustes
personales intactos. No se copiaron recursos ni código externo.

## 2026-10-05 — publicación de modularización e investigación

Autorización explícita del usuario para subir cambios. Publicados en origin/main
(Edgardy715/egaldidots): 8438bf1 modularización/opcionales/catálogo y
425efcf investigación/plan de app. verify-config.sh PASS; staged diff check
PASS tras retirar whitespace de LauncherController. Push confirmado; HEAD y
origin/main coinciden, checkout versionable limpio. Memoria local excluida de Git.
La raíz ~/.config/quickshell es checkout completo de egaldidots; bar contiene
Isla, paquetes rofi/hypr/etc son dotfiles del repo. No se movieron carpetas ni
se reinstalaron enlaces; launchers dependen de la ubicación actual.


## 2026-10-06 — Agency Agents integrado con calidad y ahorro

Petición: descargar/configurar Agency Agents para trabajo organizado, resultados
verificables y reducción de consumo sin sacrificar calidad.

- Fuente original: https://github.com/msitarzewski/agency-agents, commit
  5baafd5f1452e9785c413065b033ec083ab27757, clon superficial completo (7.4 MiB)
  en /home/zdito/.local/share/agency-agents/upstream; licencia MIT preservada.
- Skill local ~/.codex/skills/agency-agents/SKILL.md y rutas AGENTS global/proyecto.
  Dos TOML nuevos: agency_reviewer y agency_ui_reviewer, Sol/medium; conservados
  los cuatro economy, config principal Astra/low, permisos, MCP, hooks y límite 2.
- Adaptados Code Reviewer, Reality Checker y UI Finish-Gate Reviewer: evidencia
  y casos relevantes, sin rondas mínimas, métricas inventadas ni mandatos web.
  Catálogo restante consultable por búsqueda y carga del perfil pertinente.
- Aceptación: descarga trazable → SHA/licencia y git status limpio upstream;
  integración → TOML y skill válidos; ahorro estructural → carga bajo demanda,
  contexto nuevo, roles acotados, sin recursión; calidad → requisitos/evidencia,
  corrección y revalidación de hallazgos, límites explícitos.
- Validación: tomllib para seis perfiles y config, nombres únicos, fuentes presentes,
  delegación recursiva deshabilitada; quick_validate: Skill is valid! Python sistema
  carecía de yaml; ejecutado con uv --with pyyaml aislado, sin dependencia del proyecto.
  Revisión independiente economy_researcher de tres escenarios: etiqueta trivial,
  persistencia compleja y falta de Wayland; sin defectos concretos, lectura estática.
- Límite: no se ejecutaron los nuevos roles, aún no expuestos en catálogo de esta
  sesión. Verificar descubrimiento en chat nuevo. No se afirma ahorro porcentual
  ni perfección; medición comparativa pendiente de tareas equivalentes reales.
- Guía/mantenimiento/reversión: ~/.local/share/agency-agents/SETUP.md. Backup:
  ~/.local/share/agency-agents/backup-20261006-153025. Archivos de configuración y
  memorias ignorados por Git; sin cambios al producto ni publicación.


## Edots · app de configuración (2026-10-06)

- Solicitud: app de escritorio funcional con prioridad al diseño/movimiento y
  logos suministrados; usar infraestructura del proyecto y minimizar consumo.
- Decisión: Qt Quick/QML, FloatingWindow en proceso de shell y Config compartido.
  Sin Electron, servidor, nuevas librerías ni escritor de JSON paralelo.
- Implementación: EdotsWindow, SettingsPage/SettingRow, EdotsButton, IslandStudio;
  búsqueda global, campos del schema, disabled explicados para ajustes inactivos,
  validación por fila, drafts conservados y confirmados al guardar, discard y
  guardado asíncrono. Avatar vía ruta existente. Logo original copiado sin editar.
- Movimiento: selección lateral retargetable, entrada de página finita, botones e
  iconos compartidos; preview reutiliza material/morph y retira/revela contenido
  al cambiar escenas. ReduceMotion y ocultación completan transiciones.
- Acceso: IPC island settings y open.sh; install.sh genera launcher desktop.
  Instalado en la sesión actual, sin tocar preferencias guardadas.
- Requisito → evidencia: Config real → tests settings.cjs + settings-integration.py;
  búsqueda/drafts/invalid/discard → settings-regression.qml con ISLA_CONFIG temporal;
  UI → capturas Wayland /tmp/edots-minimum-verified.png y /tmp/edots-review-settled.png;
  sintaxis → qmllint archivos nuevos, diff check.
- Revisión independiente detectó viewport mínimo corto (preview ahora plegable),
  borrador oculto omitido (commitDrafts atómico), y swap de escena instantáneo
  (retirada/revelado). Revisión independiente confirmó correcciones. Una segunda captura detectó
  doble swap de iconos: animateChanges false en los tres iconos del escenario
  evita solaparlo con sceneExposure. Cinco frames Wayland 37–438ms revisados
  en /tmp/edots-motion-fixed; veredicto SHIP para Música→Panel, sin medir FPS.
- Límites: escenario sintético, no reproductor ni simulación completa de todas
  las surfaces. No overrides por monitor fuera del contrato actual. No prueba de
  FPS ni uso prolongado; captura y offscreen no certifican interacción física.
  Cerrar conserva preview de sesión; reinicio usa archivo persistido.

- Cierre: preview temporal terminado; Edots de producción abierto mediante
  open.sh. No se guardaron cambios de preferencias personales. Documentación y
  launcher listos; cambios permanecen locales, sin commit ni publicación.


## Edots · referencias y mejora (2026-10-06)

- Petición: investigar Caelestia/Noctalia/Serpantinum y mejorar app existente.
- Investigación: código primario Caelestia Nexus SHA6f7ce62 y Serpantinum
  Guide f11dab18; docs actuales Noctalia v5 (distinta de QML v4 legacy).
  Sin ejecutar shells externas ni copiar código. URLs y tabla de adaptación en
  docs/SETTINGS_APP_RESEARCH.md. Investigación acotada delegada; UI coordinador.
- Cambios: seis páginas por tarea; preview sólo Movimiento, editor por zonas en
  Composición; fuentes instaladas editables+muestra; avatar/nombre juntos;
  esconder inactive/partial salvo Avanzado/búsqueda; NFD+AND; defaults por campo
  sin borrar drafts ajenos; scroll vuelve al inicio al cambiar grupo/búsqueda.
- Evidencia: settings-regression.qml extendida cubre campos cruzados, hide/show,
  búsqueda sin acentos/multitérmino, reset acotado, defaults/borradores, picker
  inicial Google Sans Flex, font inexistente y actualización Inter. Pasa con
  ISLA_CONFIG temporal/offscreen; qmllint/diff pasan. Capturas Wayland de seis
  páginas1100×820 y tres780×600 en /tmp/edots-v2. Composición/fonts finales:
  composition-fixed.png y fonts-fixed.png. No FPS ni prueba física exhaustiva.
- Hallazgos corregidos: selector inicialmente mostraba primera fuente del modelo
  (sin cambiar Config); syncText tras init/cambio+regresión verifica valor real.
  Presets ya no desactivan reduceMotion. Rótulo Avanzado reconoce ajustes
  parciales. Import components usa alias para no ocultar Slider nativo.
- Alcance: mantiene contrato y Config único escritor; no drag/reordenamiento
  porque Isla aún no lo admite, ni perfiles/servicios ficticios. Si falta ~/.face
  preview avatar usa icono; warning QML conocido por archivo ausente. Documentación
  de uso actualizada. No se guardaron preferencias personales durante pruebas.

- Revisión final independiente: SHIP en hallazgos v2 (presets, rótulo, valores
  fuentes, composición y layout mínimo). Popup de fuentes/teclado no inspeccionado
  visualmente. Preview temporal cerrado, shell recargada y Edots real abierta.


## Edots · movimiento expresivo (2026-10-06)

- Petición: más animación y acabado agradable en toda la app.
- EdotsPageMotion separa página solicitada/presentada: salida Motion.fast y
  entrada Motion.emphasized, dirección ±20px, cambio de contenido oculto.
  No se duplica estado de Config ni vistas editables. Retarget parte de actuales.
- EdotsWindow anima bloque completo: título, preview, controles. Nav lente
  conserva SmoothedAnimation, deformación máxima3.5%. EdotsButton añade color,
  radio y halo hover finito, usa InteractionMotion expressive para presión.
  SettingRow responde al hover, anima altura para personalizado/error y escala
  handle del slider; hit targets conservados, sin loops decorativos.
- Pruebas: settings-motion-regression.qml pasa retarget sin salto de exposición,
  último destino, reduced motion en vuelo y hidden; settings-regression pasa;
  qmllint archivos afectados pasa. ISLA_CONFIG temporal, sin guardar preferencias.
- Capturas reales /tmp/edots-page-motion/0..5.png (46–658ms) muestran retiro de
  Apariencia y entrada Movimiento, selección continua y final legible. Eliminado
  enabled falso del contenedor durante swap por oscurecer botones adicionalmente.
- Límites: secuencia no mide FPS, ni todas las combinaciones entrada/foco;
  valoración subjetiva del usuario pendiente. Revisión independiente cerrada: bloqueo de input verificado en código, sin clic físico durante fade.

- Revisión detectó input sobre contenido casi invisible: MouseArea de bloqueo
  durante exposición<0.9, wheel consumida, Tab/ShiftTab retenidos y foco del
  editor retirado al navegar; conserva apariencia sin disabled global. Lint pasa.
  Secuencia interrumpida0→4→1→2 en /tmp/edots-page-motion-final confirma destino
  final visible; no se inyectó clic físico en medio del fundido.

- Cierre motion: preview temporal cerrado, shell recargada y Edots real abierta;
  cambios locales sin guardar preferencias personales ni publicar Git.


## 2026-10-07 · Edots como surface y controles refinados

Requisito → implementación/evidencia:
- Diseño de app aprobado por usuario tras reemplazar ventana Apple lateral:
  EdotsWindow pasa a FocusScope, navegación horizontal y paleta/fuentes Theme.
  SettingsSurface/IslandOverlay montan contenido persistente; FluidCompanion
  centra la gota y conserva el único motor, retorno y borradores. Win+I activo
  en Hyprland y Meta+I en overlay exclusivo. Catálogo de 15 surfaces; test IPC
  actualizado para settings. Shell recargada durante integración, sin otro
  escritor ni cambio de Config.
- Todos los iconos: EdotsIcon reutiliza AnimatedSymbol; ocho geometrías originales
  completan AnimatedIconData. Regresión comprueba cobertura, gesto de aparición,
  parada oculto y reduceMotion. Sin loops decorativos. Logo original sin editar.
- Combobox: reproducido popup nativo de 688px/translúcido sobre toda la app;
  EdotsComboBox limita a 280px y bounds de Edots, abre arriba/abajo, material
  opaco, delegates con muestras, selección/check y flecha animada. Sincronización
  conserva fuente actual/desconocida/borradores. Abrir no confirma texto anterior.
  Shortcut Alt+Down añadido porque Qt ComboBox editable no lo ofrece por defecto.
- Composición: delegate deshabilitaba hijos al ocultar systemStatus. Retirado ese
  gate; checked/accent enlazados a Config, rebind tras acción nativa; padre y
  preferencias de hijos independientes. Pruebas clicked y eventos Qt confirman
  quitar/restaurar Estado, Apps y rail sin modificar hermanos.
- Controles: EdotsTextField nativo para búsqueda/editores/combo; cursor y hint
  compartidos, material/borde/foco/errores animados. EdotsButton presión/resorte,
  foco/estado; texto sobre acento elige blanco/negro por luminancia del fondo
  actual. Switch con knob/check y foco, slider con grip/track, arrastre inmediato.
  El laboratorio tenía ancho negociado excesivo: máximo 330/270px conserva
  columna de ajustes y evita desplazamiento fuera de pantalla.

Validación: verify-config.sh (contrato y límites) PASS; settings-integration.py
PASS (incluye persistencia/conflictos); settings-regression y motion-regression
PASS; settings-companion-regression PASS; module-composer-regression PASS.
settings-controls-regression con Window/QtTest en Wayland: clics de módulos,
selección de fuente por delegate, flechas/Enter, Escape, fuente manual/Tab,
selección/borrado de texto, switch ratón/teclado, slider, popup dentro de bounds,
reduced/hidden PASS. QtTest embebido puede devolver 0 al fallar: exigir marcador
PASS y ausencia de FAIL; helpers explicitan diagnóstico. QML lint/diff pasan.

QA: captura Wayland provisional y producción centrada, secuencia de apertura IPC
con tiempos reales, búsqueda Ctrl+F con wtype, captura popup 1000×700/760×560,
Composición y Movimiento. Popup en mínimo abre sobre campo después de scroll.
Revisión independiente corrigió contraste y reduced del logo; pase de controles
no halló defecto material y pidió evidencia nativa completada después. Revisor
alcanzó límite de uso antes de un cierre adicional; no se afirma aprobación final
independiente ni FPS, ratón físico, multimonitor o IME real. Capturas temporales
/tmp/edots-surface; pueden desaparecer. No commits ni publicación solicitados.


Cierre runtime de esta fase: Config dirty/saving false y error vacío antes y
después de QA; reload cargó sin errores nuevos salvo avatar ausente conocido.
Apertura IPC y cierre Meta+I con wtype comprobados. Navegación a Tipografía,
búsqueda y Alt+Down vía teclado real de Wayland abrieron el combo integrado,
con fondo opaco y límite dentro de la gota. Captura production-popup.png;
Escape/campo de búsqueda limpiados, app dejada abierta. Bind global Super+I
registrado; apertura global desde teclado virtual no se confirmó, sin extrapolar
esa prueba al teclado físico. La selección nativa de Qt con eventos de prueba
sí cubre clic, navegación, Enter, Escape y Tab en configuración temporal.

## Composición: restauración efectiva (2026-10-07)

Reporte del usuario reproducido: systemStatus=false con apps/audio/network=true;
los botones mostraban preferencias guardadas como activas aunque el padre bloqueaba
la barra. ModuleSelection.js comparte la activación de padre al habilitar hijos
entre ModuleComposer y SettingsPage; compositor muestra selección efectiva y
conserva hermanos al restaurar. Config.update sigue conservando su contrato de
patches sin introducir dependencias implícitas para IPC.

Pruebas con ISLA_CONFIG temporal: optional-modules-regression PASS (descarga,
restauración e interrupción), settings-controls-regression PASS con clics nativos
y teclado, module-composer-regression PASS comprobando TopBarModules y exposición
del rail/estado. Se amplía esta última a Window Wayland; la prueba anterior de
solo flags no detectaba el bloqueo de padre. Shell recargada con dirty=false;
no se guardaron ni cambiaron las preferencias personales.

## Barra visible durante Configuración (2026-10-07)

El reporte adicional precisó que la restauración sí ocurría, pero solo era
visible al cerrar Edots. IslandOverlay ocultaba TopBarModules ante cualquier
surface abierta. OverlayInputPolicy.sideModulesPresented permite la excepción
settings y sigue ocultando los módulos ante otras surfaces o fullscreen.
ModuleComposer regression ahora usa esta política con settings abierto.

PASS: overlay-input-policy-regression, module-composer-regression en Wayland,
qmllint y diff --check. QA visual de shell real: Configuración abierta con rail
izquierdo y red derecha visibles; captura /tmp/isla-settings-live-bar.png
inspeccionada. Recarga con Config.dirty=false; preferencias no alteradas.

## Movimiento y avatar de barra (2026-10-07)

OptionalModule reutiliza curvas emphasized de Motion: entrada 350 ms, salida
140 ms (escaladas), desplazamiento 6 px y escala 0.94→1; retarget desde exposición
actual, salida conserva Loader, reduceMotion sin desplazamiento/escala.
TopUserStatus reutiliza MotionButton/UserAvatar: esquina derecha, ruta/nombre
injectados por TopBarModules desde Config, click abre sesión. Avatar independiente
del contenedor de indicadores; reserva 50*s de espacio lateral. UserAvatar revela
imagen cargada con fade breve. Sin nuevas dependencias ni flags de configuración.

Prueba optional-modules-regression extendida: cambio vivo de ruta/nombre con
ISLA_CONFIG temporal, click sesión, ocultamiento y restauración, inversión,
indicadores en ancho reducido (90px + 50px avatar), reduceMotion. Ajuste de espera
de expansión+revelado a tryVerify(1500): animación de 420+350 ms no completa a
665ms, el fallo previo era 0.9986/true. PASS y qmllint/diff pasan. Capturas Wayland
shown/exiting/reversed/network-only inspeccionadas en /tmp/isla-avatar-motion.
QA shell real confirmó avatar de inicial Z arriba a la derecha; configuración
actual apunta a /home/zdito/.face inexistente. No se cambió imagen ni preferencias
persistidas. Shell recargada.

## Avatar en editor y opción de Composición (2026-10-07)

EdotsWindow añade TopUserStatus al inicio del header; imagen/nombre reactivos
y activación lleva a Tu perfil. Se conserva marca Edots. Settings.js incorpora
modules.userAvatar default true y entrada independiente en catálogo, sin
dependencia de Estado. ModuleComposer añade botón Avatar y el schema genera
también su switch de ajustes. TopBarModules controla Loader y libera/reincorpora
50*s de espacio siguiendo exposición animada. El avatar del editor permanece
disponible aunque el de barra esté oculto.

PASS node settings.cjs (defaults/validación/catálogo), optional-modules-regression
(ocultar/restaurar avatar y liberar espacio), module-composer-regression, qmllint
y diff --check. QA shell real header inspeccionado en
/tmp/isla-avatar-header.png. Recarga sin cambios de usuario pendientes; ningún
perfil/ruta/persistencia personal modificado.

## Avatar consistente en Tu perfil (2026-10-07)

La tarjeta de perfil usaba Image+icono genérico en un rectángulo separado.
Se reemplaza por UserAvatar circular de 80px con la misma ruta y nombre que
header/barra, entrada de imagen existente y fallback de inicial consistente.
qmllint y diff --check PASS; QA producción abrió perfil desde avatar del header
con teclado y se inspeccionó /tmp/isla-profile-avatar.png: avatar grande visible
junto al nombre y campos, sin recortes. Ruta actual ausente muestra Z.

## Selectores para todas las rutas (2026-10-07)

SettingRow incorpora Elegir… para field.path. SettingsPage centraliza FileDialog
y FolderDialog, el schema etiqueta carpetas con picker=folder. Filtros imágenes
para avatar, JSON para colores, todos para script. URL local codificada/decodificada
(espacios, unicode, #), onAccepted usa updateField y elimina draft/error como
edición manual; Cancel no cambia valores, Guardar persiste según flujo existente.

Se fuerza DontUseNativeDialog para usar popup Qt Quick dentro de layer-shell y
conservar foco exclusivo; no liberar teclado a una ventana externa (ensayo
retirado). SettingsSurface expone pathPickerOpen; Escape/MetaI del overlay y
CtrlF/CtrlS del editor se desactivan mientras selector abierto. Ocultar editor
cierra diálogos.

PASS: settings-path-picker-regression (clic real en browse, Escape con espera
350ms para entrada del popup, cancelación, entrega de señales accepted de
archivo/carpeta, URL especial, cierre oculto), settings-controls-regression
controles previos, node settings.cjs, qmllint y diff. Selección real por wtype
CtrlL /home/zdito/Edots app icon.png Enter en preview con ISLA_CONFIG temporal
confirmó Config.userAvatar actualizado sin guardar. Captura navegador de archivos
inspeccionada /tmp/isla-native-file-picker.png; campo/botón producción inspeccionado
/tmp/isla-path-search.png. Navegación por Tab en producción no llegó al botón de
forma fiable (activó Espacios; no selección ni cambio de preferencias); Escape
comprobado en fixture, no alegar QA completa de diálogo en overlay. Fixture
preview terminada y surface de Espacios cerrada. Preferencias personales intactas.

## Bloqueo selector/layer-shell: corrección real (2026-10-07)

La captura del usuario demuestra que DontUseNativeDialog crea una ventana
normal, no un popup dentro de PanelWindow: el overlay quedaba encima y retenía
fullRegion+teclado exclusivo. La conclusión de la fase anterior era incorrecta.
OverlayInputPolicy.externalDialogOpen ahora fuerza máscara hidden y desactiva
kbFocusWanted/exclusiveFocus. IslandOverlay conecta settingsPickerOpen, oculta
focusScope con opacity=0 sin esconder PanelWindow ni cerrar su hijo, desactiva
backdrop. Cerrar/aceptar devuelve pintura, máscara y foco. EdotsWindow cierra
diálogos al perder contentReady para evitar ventanas retenidas al cerrar app.

Nueva fixture settings-layer-picker-regression usa IslandOverlay y monitor real
con ISLA_CONFIG temporal y target pickerLayerTest (open/state/quit). QA Wayland:
open userAvatar dio picker=true/settings=true/focus=false; captura
/tmp/isla-layer-picker-fixed.png confirma selector visible sin app por encima.
Escape dio picker=false/settings=true/focus=true. Reabrir y wtype CtrlL ruta
/home/zdito/Edots app icon.png Enter aceptó selección real, actualizó Config
temporal y restauró foco. FolderDialog wallpaperDir abrió y Escape restauró
igualmente. Fixture cerrada; ningún cambio personal guardado.
PASS overlay-input-policy-regression (máscara y foco externo/restauración),
qmllint y diff. No se simularon clicks físicos del compositor; la máscara vacía
fue comprobada por prueba de política y selección real por teclado. La prueba
anterior de Window normal no cubría esta integración.

## Selector integrado con miniaturas y preview (2026-10-07)

Usuario rechazó diseño y falta de preview. Se sustituyen FileDialog/FolderDialog
por EdotsPathPicker con Popup.Item explícito y FolderListModel nativo. Misma
capa/superficie, material Theme, controles/íconos Edots y Motion, entrada .97→1,
fade en imagen/miniaturas, movimiento reducido. Galería virtualizada, imágenes
asíncronas a resolución acotada, vista previa grande y confirmación; selección
no muta Config. Archivo/directorio, filtros imágenes/JSON, navegación arriba,
ubicación con ~, accesos rápidos y archivos ocultos, error/empty. Carpetas se
seleccionan con clic y se abren con doble clic/Enter; flechas actualizan preview.
Config.userAvatarUrl centraliza URI correcta para imágenes con #/unicode/espacios
en barra/editor/perfil/sesión/lock.

El workaround de ventana externa ya no aplica: se retira externalDialogOpen,
liberación de foco/máscara y ocultamiento del overlay. Escape/atajos de editor
continúan suspendidos mientras popup activo, que conserva foco modal nativo.

PASS settings-path-picker-regression (Popup.Item, clic en Elegir, imagen Ready
y source correcta, cancelación Escape, confirmación, carpetas, URL especial y
cierre), overlay-input-policy-regression, qmllint y diff. Prueba con
IslandOverlay real: pickerLayerTest.preview simula clic Qt en entrada real del
grid y confirma Image.Ready; state picker=true/focus=true. wtype Escape da
picker=false/settings=true/focus=true. Capturas inspeccionadas
/tmp/isla-gallery-open.png y /tmp/isla-gallery-final.png; se corrigió en un pase
la distribución (sidebar/preview acotados, grid ancho mínimo180) y truncado de
Wallpapers. Test en Window800 da selector752px, además QA capa real1000px.
Sin medición FPS ni simulación de clicks físicos del compositor. Fixture temporal
terminada; nada personal guardado.

## Batería: carga con accent (2026-10-07)

El relleno de BatteryIndicator usa Theme.accent; el contorno y el estado de
carga conservan sus señales existentes. Cambio compartido por barra/BatteryChip.
qmllint y diff --check comprobados; sin cambios de configuración personal.

## Recorte y acabado de foto de perfil (2026-10-07)

UserAvatar conserva consumidores, fuente y fallback. La imagen antes tenía un
margen rectangular de 3px dentro del clip exterior; ahora un ClippingRectangle
interior con margen 2px recorta la foto en su propio círculo. Aro pasa a
Theme.foreground alpha 0.18 y fondo acento 0.10. Sin cambios de datos personales.
qmllint y git diff --check PASS; recarga real y QA Wayland barra/sesión con foto
actual inspeccionadas en /tmp/isla-avatar-{before,after}.png y
/tmp/isla-avatar-session-{before,after}.png. Panel de prueba cerrado.
settings-regression offscreen con ISLA_CONFIG temporal NO PASS: timeout 124 y
errores global search, font initial selection, arrival gesture: palette. Log
/home/zdito/.cache/codex-economy/output-yu56m39y.log. No se atribuyen al avatar ni
se modifican esas rutas fuera de alcance. Lockscreen/perfil no inspeccionados
visualmente en esta fase; reutilizan componente.

## Avatar interactivo desde reposo (2026-10-07)

Causa: IslandOverlay.pillRegion incluía workspace/status pero omitía userModule.
Se añade región del avatar con geometría del Loader y tamaño cero cuando no es
interactive, usando el mismo patrón. MotionButton ya habilitaba hover y onClicked
abría sesión; no se añade otro mecanismo. Gate surface-boundaries.cjs comprueba
regiones de los tres módulos. Gate, qmllint IslandOverlay y diff --check PASS.
Recarga real realizada; cursor llevado al avatar por dispatcher y hover/borde
visible inspeccionado en /tmp/isla-avatar-hover-real.png. No clic físico inyectado.

## Avatar abre configuración de perfil y hover integrado (2026-10-07)

TopUserStatus muestra ToolTip propio oscuro, radio 10, tipografía Theme, margen
10 y demora 250ms, alineado al borde derecho. Tooltip Basic blanco rechazado
por usuario; paleta heredada no afectaba al tooltip compartido, se usa instancia
nativa con contentItem/background. QA real /tmp/isla-profile-tooltip-styled.png.
TopBarModules solicita profile; IslandOverlay incrementa profileRequest y abre
settings si aún no está abierto/pendiente. SettingsSurface aplica petición al
crear o reutilizar editor, EdotsWindow.showProfile selecciona página 4 y limpia
búsqueda; header reutiliza método. No se modifican datos del perfil.
optional-modules-regression Wayland PASS (clic QtTest solicita profile);
settings-companion-regression offscreen PASS (petición repetida y limpieza de
búsqueda), qmllint de archivos editados y diff --check PASS. Logs
/home/zdito/.cache/codex-economy/output-6l9ex69l.log y output-bkdeao_1.log.
No clic físico end-to-end en producción; hover sí comprobado en Wayland.

## Auditoría integral y rediseño pill · 2026-10-08

Dirección aplicada: reposo translúcido, expansión sobria que protege lectura,
jerarquía compartida y continuidad del motor existente. Se corrigieron vacío de
launcher después de debounce y su geometría, Timer que sobrescribía entered del
header, Tab interceptado en overview/fondos, nombres accesibles repetidos,
contraste secundario y copia de carpeta fija. PillMaterial recibe artUrl por
propiedad; elimina contorno exterior y reduce halo al crecer. Sin dependencias,
funciones nuevas, cambios de paleta persistida ni restauraciones globales.

Impeccable fallaba por permiso de ejecución: chmod u+x reparado, context funciona;
criterios aplicados con evidencia nativa. detect QML devuelve [] sin cobertura
web; no se usa como certificado. Skills/MCP y fuentes concretas registradas en
docs/PILL_INTERFACE_AUDIT.md. PRODUCT.md/DESIGN.md documentan mundo existente y
limitación de plataforma Linux/Wayland, usando brief explícito del usuario.

Evidencia persistida en /home/zdito/.local/state/isla-audits/20261008:
comparison.png y carpetas before/after, tests y motion-clean con timing real.
Antes: quince estados; después asentado, media sintético playing/paused/título
largo/art, no player final, notificación propia/restauración, teclado y seis
filas launcher. Escala1.25/font1.4/reduceMotion validados y Config.discard restauró
document/effective iniciales con dirty=false; fixture MPRIS detenida.

Regresiones pertinentes PASS (detalle en reporte), incluida nueva
pill-interface-regression offscreen/Wayland; qmllint y diff --check PASS. Gate
verify-config.sh falla por ruta preexistente en optional-modules-regression:47;
no se modificó fuera de alcance. Independiente agency_ui_reviewer detectó diálogo
crash de hot reload anterior (g51gqmlmt report13:37:41, Qt Shape/derefWindow).
No causa demostrada. Se repitieron dos secuencias muestreadas67/62frames + seis
ciclos rápidos sin edits/reload: misma instancia g51tmnlmt y ningún crash nuevo;
revisión final sin otro defecto confirmado. No dar hot reload por corregido.

Límites: sin FPS continuo, estabilidad prolongada/multimonitor, AT, polkit real,
acciones de sesión destructivas, audio/player real, ni todos los errores/carga
con servicios fallando. QA visual no sustituido por offscreen. Pendientes reales
crash de recarga indeterminado y gate global por fixture ajena; evidencia y
aceptación por requisito están en docs/PILL_INTERFACE_AUDIT.md.


## 2026-10-08 — Vidrio reactivo sobre fondos claros

Petición corregida: conservar reacción a colores de la app; limitar apariencia
lavada sobre páginas blancas. Se retiró por completo el ensayo de xray de
~/.config/hypr/modules/windowRules.lua; reload ok y configerrors vacío.
PillMaterial compactAlpha = max(0.62, Flags.glassAlpha): transmite hasta 38%
del fondo frente a 66% con alpha personal 0.34. No cambia datos guardados.
bodyAlpha interpola continuamente hacia la protección de lectura existente
(0.868 con alpha0.34); ajustes más opacos conservados. Rail, reloj y estado
comparten el material y reciben el mismo ajuste. Glow/acento y movimiento intactos.

Capturas reales comparables de barra: /tmp/isla-material-contrast/
before-reactive.png y after-reactive.png, mismo escritorio y app, 1920x64.
Regresión Wayland con ISLA_CONFIG temporal pill-interface: PASS material
escalado, preferencia opaca, bounds/header y estados de launcher.
No se acredita prueba de todas las apps/paletas ni HDR/multimonitor.


### Corrección posterior — franja inferior del material

El usuario rechazó el primer ajuste: la banda blanca inferior seguía dando
apariencia de segunda capa. Se conserva blur reactivo, sin xray. PillMaterial
retira progresivamente la sombra externa en compacto (opacity = 0.32 *
readingExposure) y eleva alpha del final del gradiente a mínimo0.94, manteniendo
parte superior reactiva y alpha1 cuando se elige opacidad total. TopWorkspaceRail
reduce alpha de la sombra de la lente de0.78 a0.12, conservando color y movimiento.
Capturas Wayland /tmp/isla-material-edge/before.png, rail-final.png, final.png:
borde inferior más oscuro y continuo. El usuario cambió workspace durante QA;
no atribuir diferencias de selección/fondo al material ni declarar comparación
pixel exacta. Pill-interface PASS con asserts de sombra compacto/expandido,
lint Qt6 PASS de ambos componentes. No todas las apps/paletas/HDR comprobadas.


### Material compacto uniforme — sustituye remate oscuro anterior

Usuario indicó que el resultado con alpha inferior0.94 se veía extraño. Se
retira ese remate: los tres stops compactos comparten bodyAlpha0.62; lift y
oscuridad adicionales crecen solo con readingExposure hacia panel expandido.
Mantiene blur de app, sin xray, sin sombra exterior compacta y halo tenue de rail.
Captura nativa /tmp/isla-material-uniform/after.png inspeccionada y lint Qt6
PASS. El workspace actual difiere de la captura enviada: QA de estado actual,
no comparación exacta con aquel fondo. No se declara aceptación del usuario
ni cobertura de todas las apps/paletas. No repetir regresión numérica: no cambió
bodyAlpha, geometría o interacción desde el último PASS.


## 2026-10-08 — Deriva leve del glow interior

Petición explícita de movimiento decorativo suave prevalece sobre restricción
histórica de no animar decoración en reposo. InnerGlow compartido recibe fase
continua con FrameAnimation visible; sinusoidal x±0.06 e y[-0.04,0], periodo
4×Motion.breathe (12s a motionScale1). Solo mueve foco radial; no alpha, tamaño,
bordes ni contenido. Al ocultar pausa sin reiniciar fase; reduceMotion estático.
Se mantienen exclusiones actuales de glow para paneles grandes y material lateral;
no se añaden nuevas luces ni cambia la lente de workspace.
Regresión inner-glow-regression Wayland PASS: movimiento visible acotado,
pausa oculto, reduceMotion y resume; configuración temporal. Lint Qt6 PASS.
Capturas nativas reloj /tmp/isla-glow-drift/frame-{1,2}.png separadas3s.
No se midió FPS continuo o consumo GPU; RadialGradient actual se conserva.


## 2026-10-08 — Hover de reloj sin cambio de material

Reproducido hover nativo sobre hora: halo exterior visible en captura
/tmp/isla-clock-hover/hover-before.png; código cambiaba focusX de0.5(rest)
a0.26(hover) sin interpolación. PillMaterial conserva focusX0.5 en ambos
estados y no activa halo exterior por materialAwake en modohover. Pulsos
de apertura siguen existentes; glow interior conserva deriva y transición
de intensidad. Capturas reposo/hover corregidos rest-after/hover-after,
apertura calendario viaIPC calendar.png. motion-regression PASS (interrupción,
swap, reduceMotion, unload) y lint Qt6 PASS. Sintaxis heredada movecursor
falló; alternativa Lua hl.dsp.cursor.move verificada ok. No clic simulado
ni pruebas de pantalla táctil.


### Causa específica de la capa de hover del reloj

Aclaración del usuario: capa transparente sobre hora salía fuera de la pill.
Causa demostrada: IslandRestStatus.clockHit MotionArea tiene margins=-6s;
su rectángulo genérico de feedback pintaba toda el área ampliada. Se deshabilita
feedbackEnabled solo para ese hit target y se conserva escala de presión
del texto, hit target ampliado, nombre accesible y foco teclado por subrayado.
No se modifica MotionArea compartida ni otros controles. Capturas reales
/tmp/isla-clock-feedback/rest.png y hover.png verifican ausencia de la capa.
Pill-interface Wayland PASS: nuevo assert feedback deshabilitado, área amplia,
señal de clic calendario y foco. Primer test buscaba clock en SurfaceHeader
y falló; corregido con fixture IslandRestStatus real. Lint exit0 con avisos
preexistentes de acceso no cualificado en delegate workspaceReel.
La lectura previa de halo/foco no identificaba esta causa; estos ajustes
anteriores se conservan sin atribuirles la reparación del feedback.


## 2026-10-08 — Rediseño de clima en calendario

Dirección: temperatura protagonista46px, icono40px, columna sobria sin hero
de132px ni bloques superpuestos; lugar, condición/sensación y métricas legibles.
Flickable acotado220px preferidos/180mínimos, scroll vertical para fuentes o
contenido largo; pronóstico36px/fila máximo/mínimo diferenciados. Sin dependencias.
Servicios en CalendarData/composición; vista recibe propiedades y emite refresh.

Fallos demostrados/corregidos: datos incompletos antes producían undefined+unidad;
validación numérica por campo, pronósticos incompletos descartados. Código
desconocido ya no etiqueta lluvia. Error antes silencioso: último dato se conserva
pero aviso stale y hora actualización se muestran encima del hero, visible sin
scroll. Actualización manual con botón deshabilitado durante carga, guard de
proceso en marcha. Selección usa humedad/viento del pronóstico (muestra — cuando
faltan), retorno Ahora explícito. Cerrar durante transición restablece target
y permite reabrir/seleccionar; shrink de forecast vuelve a actual. Rótulo vacío
de pronóstico oculto. Localidad de wttr.in aproximada por IP; sin selector nuevo.

Revisión independiente finish_review detectó aviso stale inicialmente fuera
del viewport; movido arriba, assert de visibilidad y captura error corregidos.
Primer QA mostró Flickable ancho0 y calendario ocupando todo: ancho preferido
y contentWidth explícitos repararon composición.

Pruebas PASS: calendar-data-regression (parciales/primer error/stale/unknown/
interrupción/cierre además leap/year/grid); weather-view-regression Wayland
(ancho, refresh/carga, métricas forecast vs actual, Ahora, aviso stale visible,
vacío, fontScale1.75/reduceMotion); lint Qt6 de Data/View/Surface. Native shell
wttr.in mostró Ciudad Nueva31°, captura /tmp/isla-weather-redesign/final.png;
antes before.png. Preview error sintético Wayland error-state.png marca datos
simulados; no equivale a corte de red real. Tres ciclos de apertura/cierre
interrumpidos nativos realizados, shell misma instancia sin caída observada.
Fuentes grandes probadas en fixture, no todas las paletas ni multimonitor.
No agregada relación entre día elegido en grilla y clima fuera del pronóstico
disponible; no pronóstico inventado. Datos provienen de wttr.in existente.


## 2026-10-08 — Equilibrio de transparencia pedido por usuario

Rechazado exceso de opacidad62% compacto/86.8% paneles; aclaración pide
un punto intermedio, no volver exactamente al original. Fórmula compartida
bodyAlpha = glassAlpha + (1-glassAlpha)*(0.15+0.25*readingExposure). Con
preferencia guardada0.34: compacto0.439, panel0.604; degradados expandidos
tienen pequeños incrementos originales (+0.08 arriba/+0.04 abajo). Reposo
permanece uniforme sin remate oscuro; sin capa de hover reloj. Alpha1 sigue1,
no se guarda configuración nueva. Regresión material escalado/preferencia
opaca PASS; lint Qt6 PASS. QA calendario /tmp/isla-alpha-balance/calendar.png
con alpha expandido0.604; barra definitiva bar-final.png. No todas las
apps/fondos claros/paletas ni contraste cuantitativo sobre cada fondo.


## 2026-10-09 · Unidad compacta centrada

Petición: reunir workspaces y apps/estado/perfil en el cuerpo central, usando
la imagen sólo como idea. Propuesta implementada sin cambios de configuración
personal ni servicios, conserva cambios ajenos previos.

- Composición → TopBarModules sobre Pill; espacios izquierda, reloj centrado,
  apps/audio/red/batería/avatar derecha. Un solo PillMaterial exterior;
  TopWorkspaceRail/TopSystemStatus reciben integrated. Altura56 y reserva
  compartida compactRestHeight; las gotas y fixtures antiguas mantienen38.
- Geometría → Pill recibe restSideWidth/restHeight; PillGeometry equilibra
  lados y notificación vuelve a ancho completo. PillMorphMotion admite paneles
  más estrechos usando denominadores con signo.
- Interacción → regiones añaden desplazamiento del contenedor; contentFits
  usa ancho real y ancho del reloj para ocultar/liberar controles durante morph.
  Presupuesto de avatar según lifetime active, independiente de exposición:
  evita realimentación ocultar avatar→ensanchar estado→falta de espacio.
- Config → módulos opcionales y rutas/atajos existentes conservados. Reunión
  compacta es la composición actual, sin crear un selector adicional.

Aceptación y evidencia:

- Cuerpo único centrado → shell real recargada; /tmp/isla-compact/final.png
  y final-desktop.png, mixer.png y calendar.png inspeccionadas.
- App overflow/pantalla estrecha → compact-island-regression PASS Wayland con
  ISLA_CONFIG temporal, 14 apps simuladas/620px; narrow.png y many-apps.png.
- Paneles más estrechos/reduceMotion → compact fixture PASS;
  pill-composition-regression PASS con reposo760→panel340.
- Módulos/toggles/input de componentes → optional-modules-regression PASS
  offscreen; selección perfil/audio validada por QtTest.
- Notificación/reposo → pill-geometry-regression PASS, añade retorno al ancho
  compacto completo y altura56.
- Movimiento/interrupción → motion-regression PASS; boundaries.cjs PASS;
  git diff --check PASS.
- Revisión independiente agency_reviewer → sin defectos sustentados tras
  contentFits/reserva estática; regresiones compact/modules y tres capturas.

Límites: qmllint255 sin diagnóstico tanto combinado como subconjunto (logs
output-l7pfbgbm y output-1kpz49fj); no certificar lint. Carga shell real y
fixtures acreditan runtime. No QA físico multimonitor, clic de máscara Wayland,
notificación real ni medición FPS. La imagen adjunta tenía PNG dañado y no
pudo decodificarse; la dirección usa el brief textual y UI real. Sin publicación
ni commit. Valoración visual del usuario pendiente.


## 2026-10-09 · Versiones seleccionables y música dentro de compacta

Corrección del alcance por usuario: compacta es una versión opcional, no
sustitución del diseño separado. Música debe incorporarse al mismo cuerpo.

- Contrato → appearance.barLayout enum split/compact, defaultsplit. Settings
  valida opciones; catálogo/ejemplo actualizados. Edots Composición dispone
  selector live y búsqueda global; ventana<680 ofrece fila choice con etiquetas
  legibles. Config.update/discard/save conserva writer único.
- Composición → TopBarModules.compact alterna geometría/fondos previos y
  unidad central. Reserva vertical segúnlayout, Pill restSideWidth sólo compact.
- Música → CompactMediaStatus hoja de datos/acciones; MediaSession y Players
  conectados desdeTopBarModules. Portada/resumen/visualizador compartidos;
  play-pause verifica capacidad. Presupuesto compartido con rail; mínimo76px
  deja cover/control sin minitexto ilegible en estrecho. Consumer CAVA propio
  sólo en playing/presented; se libera al pausar/ocultar/split/destruir.
- Panel → compact media morfea Pill; split conserva FluidMediaCompanion.
  Escape resuelve letras sobre el contenido correcto; docking de launcher y
  ajustes usa el mismo router.
- Fix revisión → switch de layout con media abierta provocaba ciclo cuando
  onMorphClosenessChanged destruía Loader dentro de surfaceGrowth. callLater
  con guard de estado difiere unload y protege reapertura.

Aceptación → evidencia:

- Enum/default/invalid/persistencia → settings.cjs, settings-integration.py PASS
  por implementador; ISLA_CONFIG temporal.
- Selector/config/búsqueda/ventana pequeña → module-composer-regression PASS;
  settings-regression PASS por implementador tras corregir expectativa avatar
  obsoleta (dos campos existentes); no atribuir a layout fallos de fixture previa.
- Música playing/paused/toggle/CAVA/layouts/620px/14apps → compact-island
  PASS Wayland output-kkbvxat8; captura music-playing tras esperarframe/iconpause,
  music-paused, music-narrow inspeccionadas. Playback real intacto.
- Split módulos → optional-modules PASS output-bal9pkvb.
- Routing real → layout-routing PASS Wayland output-o5dakhur, sinBindingloop:
  open-media split→compact, launcher/settings dock, vuelta split, close.
- Fix unload → motion PASS output-qjjoqyaa, pill-composition PASS
  output-36wn0z63; revisión independiente puntual cerrado.
- QA → shell real media-integrated-verified (centro), media-split-verified
  (derecha), music-real-final (reposo compacto con media pausada). Large
  selector composition-large; 760×560 composition-small, fondo nativo opaco
  de fixture temporal. FixtureQA eliminada al terminar.
- Límites de capa → surface-boundaries PASS incluyendo CompactMediaStatus
  y región media; git diff --check PASS. Lint CompactMediaStatus/PillSurfaceHost
  y controles de Edots PASS; lint overlay/TopBarModules combinado255 sin
  diagnóstico, límite preexistente, no certificar todo el lint.

Preferencia actual personal al iniciar: sinbarLayout/dirtyfalse → split. Sólo
previews IPC paraQA; discard final restaura documento original, no save.
No cambios a reproducción, workspace, wallpaper ni red. Sin commits/publicación.
Pendiente: valoración del usuario, multimonitor físico, clic de máscara y
waveform con reproducción real; no FPS ni análisis de todos los fotogramas.


## 2026-10-09 — Compacta densa según nueva referencia

Petición: eliminar el espacio vacío de la compacta y acercar los grupos del
concepto, manteniendo la composición separada como alternativa en ajustes.
PillGeometry suma restLeftWidth/restRightWidth reales con padding y gaps
condicionales. TopBarModules coloca espacios/música/reloj/estado/perfil; el
cuerpo completo sigue centrado. Separadores finos, media máximo256px y
presupuesto lateral hasta500px. El reloj no fuerza simetría.

Revisión independiente compact_review detectó revelado prematuro durante
retorno: contentFits y header ahora exigen el ancho natural completo (1px de
tolerancia). Revisión posterior sin hallazgos. Fixture muestrea retorno cada16ms,
verifica ancho natural y reloj solo sin reserva. El control de música se activa
por señal clicked para evitar eventos de ratón dependientes del foco Wayland;
los intentos con mouseClick fueron inestables y no certifican clic físico.

Validación: compact-island-regression Wayland PASS actualizado, log
/home/zdito/.cache/codex-economy/output-9v1m6ffd.log; incluye14apps,620px,
pausa/reanudación mock, panels, split/compact y reduced motion. Geometría PASS
output-_lkc62k8.log; header/composición PASS output-4e3l7_lf.log; routing nativo
PASS output-pqswf2ye.log antes del ajuste final del umbral. git diff --check limpio.
QA real: /tmp/isla-compact/dense-real-desktop.png, recorte dense-real-pill.png
inspeccionado; Spotify pausado, música real sin modificar. Preview de Config
descartada tras captura; no guardado de configuración personal. Advertencias
fixture .face ausente y tracking Hyprland; sin error QML en pasada final.
Límites: reproducción/CAVA real y clic físico no verificados en esta fase;
mock cubre acciones y consumidor. qmllint de adapters tiene limitación previa
de salida255 sin diagnóstico; carga runtime y pruebas son la evidencia.

### 2026-10-09 — Música compacta sin botones de transporte
Petición del usuario: retirar play/pausa del reposo. Eliminados MotionButton,
canToggle y toggleRequested de CompactMediaStatus y conexiones de TopBarModules.
Resumen aprovecha el ancho y visualizador se alinea al extremo; toda la zona
abre el panel de música, donde permanecen los controles. Fixture actualizada
comprueba ausencia del botón y cambios de reproducción mock desde el player.
PASS Wayland output-zncisclv.log, git diff --check limpio. Captura real inspeccionada
/tmp/isla-compact/no-transport-pill.png, visualizador presente. No se cambió la
reproducción real; preview de configuración descartada. No se verificó clic físico.

## 2026-10-09 — Refinamiento de UI compacta con skills
Aplicadas apple-inspired-ui, fluid-island-motion e impeccable/layout/craft-floor.
Context launcher leído: contexto Isla existente; detector web no acredita QML.
Evaluación propia y revisión aislada compact_review: reserva fija de música,
lente workspace demasiado dominante y artista pequeño. Cambios acotados:
TextMetrics título/artista calcula ancho natural hasta256px; portada36 sin aro,
metadatos13/11, nav integrado40 y slots/lente28. Gradiente selección integrado
más tenue y sin sombra; split intacto. Eliminadas propiedades de progreso sin uso.
Revisión final detectó fragmento «Una...» en620px: umbral de texto64px ahora
oculta fragmentos manteniendo portada y nombre accesible completo.

PASS final Wayland compact-island-regression: output-875xicdm.log; incluye
ancho menor para título corto,14apps,620px, paneles, pausa/reanudación mock,
retorno sin overlap, layout switch y reduced motion. git diff --check pasa;
detector layout devuelve[] pero no valida esta plataforma. Capturas real sin
música /tmp/isla-compact/refined-pill.png y fixtures music-playing/music-narrow;
recorte presentación refined-media-fixture.png con datos simulados. Revisadas.
No se modificó reproducción real; preview Config descartada. No prueba de clic
físico ni contraste en todos los fondos/temas. Propuesta pendiente de valoración,
no registrar como aprobada. Límites de avatar .face fixture previo sin afectar QA.

## 2026-10-09 — Auditoría de transiciones, ambos modos y recuperación de shell

Requisitos: animación limpia split↔compact en ambos sentidos; prioridad del
usuario Notificaciones/música; Configuración debe nacer del centro de pill y
viajar al centro de pantalla. Aplicadas fluid-island-motion, pill-frame-inspection,
pill-detail-audit y agency para revisión independiente acotada compact_review.

Hallazgos/correcciones:
- P1 cambio instantáneo de anchors/material/host: BarLayoutTransition retira
  módulos y reloj (incluido launcher/auth), espera absorción de companion y
  regreso de media antes de commit; phase2 espera morph real. Conserva ruta,
  retarget e inversión; reduceMotion resuelve directo. El motor físico previo
  sigue siendo único dueño de geometría. Sin contenido duplicado en ambos hosts.
- P1 Configuración con destino centrado pero nacimiento/retorno laterales:
  FluidCompanion.centered usa centro para start/capX/close/followBody; evita
  captureTarget20 lateral. Sesión/media no-centered conservan su trayectoria.
- P1 centro de notificaciones con dos escritores: ShellRuntime posee
  Notifs.centerOpen por Binding a ruta y clearToasts al entrar. Quitadas
  mutaciones constructor/destructor de NotifsSurface; el Loader tardío no
  sobrescribe navegación ni limpia toasts tras abandonar la ruta.
- P1 fallo de carga descubierto por usuario: Behavior sobre reservedH readonly
  impidió cargar IslandReserve y shell.qml. Lint había pasado y fixtures no
  incluían reserva: evidencia insuficiente para arranque completo. Corregido
  reservedH a property real animable, reserva sigue compact committed dentro
  Scope por monitor; fixtures native ahora instancian IslandReserve. Quickshell
  principal arrancada explícitamente, Configuration Loaded, IPC responde,
  Polkit agent registrado. Log actual sin errores QML; sólo icono input-keyboard
  ausente al abrir controles, anterior al cambio. No declarar pruebas de overlay
  como prueba de arranque completo en el futuro.

Requisito → evidencia:
- Ambos modos/11 surfaces/media abierta/reversión/reduced motion:
  layout-motion-regression PASS output-9my30llc.log (antes de incluir reserva).
  Arranque completo actual + IPC/log verifica reserva y ShellRuntime finales.
- Gota split simulada absorbida antes de commit, notificación concurrente con
  calendar/layout, media pausada y desaparecer/reaparecer, OSD y reversión:
  layout-interruptions-regression con reserva PASS output-gp4tk83i.log final.
- Gates reales y retirada launcher/auth: bar-layout-transition-regression
  PASS output-pdzlxrz2.log.
- Centro de origen/puente/destino/absorción, anchos100/760, reapertura conserva
  velocidad, reduced motion: centered-companion-regression PASS
  output-j59eslun.log. Lateral sesión PASS output-74mlxl4p.log y media
  PASS output-ijqugfss.log, geometría PASS output-1je77zlq.log.
- Notificación: cola/expiry/restauración/auth priority PASS output-5svcwaku.log;
  vista con datos simulados/acciones sin invocación nativa PASS output-vil49yl1;
  lifecycle stale no pisa centro PASS output-knkx6d7s.log.
- qmllint coordinador/header/reserva/ShellRuntime/NotifsSurface PASS
  output-hxa19d02.log; combinado con FluidCompanion da255 sin diagnóstico
  (limitación de adapters/plugins). Carga real y tests son evidencia adicional.
  git diff --check limpio.

QA nativa final tras recuperar main (evidencia previa /tmp no disponible, no
usarla para certificar este arranque):
/home/zdito/.cache/isla-layout-audit/2026-10-09/final-1 (88 muestras; captura
0.119–0.248s) y final-2 (239 muestras;0.015–0.158s). Script y tiempos JSON en
ese directorio. Secuencias iguales: split→compact→split en reposo, media abierta
con cambio ambos sentidos, Notifs↔media rápido, Settings close/reopen y cambio
modo con Settings abierta. Recorte más corto en final2 para densificar muestreo;
comparar región común. Inspeccionadas muestras/contornos/contenido y contacto,
Settings native mid9.876s/final11.861s: origen/puente central y panel1000×700
centrado final. No salto visible de módulos en muestras examinadas; contenido
se retira antes de cambiar host. Reservas/ventanas siguen el morph. Es grim
irregular con start/end registrados, NO todos los frames del compositor ni FPS
medido. wf-recorder no disponible; no inventar continuidad perfecta entre muestras.

Revisión independiente cerró guard launcher/auth, centered/metaball sin nuevo
hallazgo lógico; constata límites de capturas y pruebas comunicadas. Config
personal restaurada con discard tras QA, dirtyfalse y layoutsplit. No guardado,
ni cambio de reproducción, red, workspace o acciones de notificaciones. Main
sigue activa; fixtures y capturas terminaron.
Límites: música real ausente en pasada final (mock cubre reproducción/pausa),
no clic físico/lector de pantalla/varios monitores ni captura continua a60fps.
No afirmar ausencia de todos los bugs de datos nativos sin ese estado disponible.

## 2026-10-09 · Entrada al bloqueo y música en reposo
- Petición: animar llegada al lockscreen y mostrar reproductor cuando suene algo
  en la vista inicial del reloj; investigar Quickshell moderno y fluidez.
- Quickshell instalado 0.3.1. Consultada documentación oficial vía Context7
  `/websites/quickshell_v0_3_1`: WlSessionLock.secure confirma cobertura de todas
  las pantallas; MPRIS ofrece propiedades/capacidades reactivas. No se retrasó
  adquisición/liberación del lock ni se tocaron PAM/launcher/autenticación.
- LockSurface: entrada OutCubic con Motion.morph desde fondo oscuro opaco;
  wallpaper escala 1.025→1, reloj se revela/desplaza 18u y pill se revela.
  Entrada espera secured. ReduceMotion resuelve inmediatamente.
- Reutilizado LockMedia bajo reloj cuando player.isPlaying. Retirada retargetable
  con pausa, auth y desaparición; Loader persiste hasta finalizar exposición.
  Composición inyecta Players en superficie real/preview y todos los destinos;
  LockMedia no activa el reloj de posición (no dibuja progreso). Sin Cava,
  procesos nuevos, animaciones infinitas ni dependencias añadidas.
- Revisión independiente lock_review: detectó descarga prematura del Loader y
  último consumidor singleton en tarjeta estrecha; corregidos. QA además detectó
  guardia fija de altura 540 que ocultaba tarjeta aun cabiendo con escala;
  reemplazada por comprobación real y añadida visibilidad a regresión.
- PASS nueva regresión offscreen y Wayland; final nativo log output-qn5o5bkc.
  Casos: seguridad, exposiciones intermedias, pausa/resume interrumpidos, auth,
  retorno, desaparición (item vivo durante retirada), estrecho, reduceMotion.
  Motion anterior PASS output-x7o4qemn; typing/privacy output-7ad_vejs;
  launcher/backup/fallback output-egx0z1l9. Config completo preview cargó/salió
  output-f2qo35c_ (sólo avatar ~/.face ausente); shell principal sigue PID6552.
- Capturas nativas con wallpaper existente y música simulada inspeccionadas en
  ~/.cache/isla-lock-audit/2026-10-09: entering, clock-player, auth-player,
  narrow-player. Son muestras, no FPS ni grabación continua. No se bloquearon
  sesiones reales ni se ejecutó PAM real; multimonitor y reproducción real
  quedan sin verificar. git diff --check limpio.

## 2026-10-09 · Propuesta de rediseño de multimedia del bloqueo
- Usuario rechazó composición/diseño de la tarjeta anterior. Rehecha LockMedia:
  portada cuadrada 80u con radio14u (antes círculo52u), título17u/artista13u,
  hasta dos líneas de título, ancho reposo420u y tarjeta184u con material único.
  Alas del formulario usan composición vertical centrada sin etiqueta redundante.
  Controles conservan capacidades, teclado, nombres accesibles y MotionButton.
- Altura deriva de contenido/controles; textos grandes no pisan transportes.
  Loader de reposo toma implicitHeight real, evitando duplicar altura fija.
  Fuente ausente usa icono; imagen asíncrona acotada con ClippingRectangle nativo.
  No se añadió progreso, visualizador ni polling. PAM/security sin cambios.
- Impeccable context y layout/craft-floor, Apple-inspired-ui y convenciones
  Fluid consultados. Primer lote Wayland: reposo, alas y estrecho; ajuste único
  posterior de altura y separación para contenido extremo, confirmado en captura
  05-large-text-player con título largo, fontScale1.5, portada y siguiente disabled.
- PASS lockscreen-entrance-regression Wayland output-_wbfrpqd, ampliada con
  geometría metadata/controles; motion anterior output-csh31bj8; diff check limpio.
  Capturas ~/.cache/isla-lock-audit/2026-10-09. Diseño propuesto, pendiente de
  aceptación del usuario. Música simulada; no se adquirió bloqueo ni usó PAM.

## 2026-10-09 · Segunda composición de multimedia (propuesta)
- Usuario volvió a rechazar el diseño: sustituida composición horizontal por
  panel vertical de álbum. Portada176u centrada en reposo, título19u debajo,
  artista secundario y controles planos; ancho320u. Material oscuro translúcido
  sin borde ni muestreo/blur local. Ala integrada usa portada100u/título15u.
- Reutilizados controles/capacidades/transiciones. Altura automática a partir
  de portada, texto y controles. Sin cambios de PAM, acciones ni polling.
- PASS Wayland lockscreen-entrance-regression output-d2069ghz (seguridad visual,
  pause/resume, retirada, auth, estrecho, reducedMotion y textos largos1.5).
  Inspeccionadas capturas de reposo, ala/formulario y extremo con imagen y texto.
  git diff --check limpio. Capturas en ~/.cache/isla-lock-audit/2026-10-09.
- Esta propuesta reemplaza visualmente la anterior, aún no aceptada por usuario.
  Música simulada; bloqueo/PAM real no ejecutados en esta fase.

## 2026-10-09 · Composición según referencia aportada por usuario
- Nueva dirección explícita: reloj izquierda + música derecha sobre fondo,
  adaptación sobria/nativa a Isla y sin swipe. Referencia usada como concepto;
  no copiados saludo, frase, corazón, shuffle/repeat ni decoración Android.
- Reposo ancho: reloj124u Light y fecha18u, música hasta600u con portada160u,
  título24u, artista16u, timeline y controles planos. Sin material/caja externa.
  Anchos estrechos/texto ampliado apilan reloj/media; sin música reloj vuelve al
  centro por restingMedia animado. Ancho del reloj intrínseco y alineación estable
  evitan salto al finalizar retirada. Formulario/alas preservan comportamiento.
- Timeline reutiliza MediaSession y capacidades MPRIS; Slider Qt Basic con foco,
  nombre accesible, drag cancelable y seek con límites. Se muestra únicamente con
  canSeek. PositionTimer sólo con vista visible, no embedded, reproducción y
  capacidades; ninguna animación continua nueva ni dependencias.
- Primera carga detectó colisión Slider con componente local: import Basic
  cualificado Controls.Slider. Primer QA amplio detectó visible↔altura en tarjeta
  inferior: cálculo geométrico depende de showTimeline y no visibilidad efectiva.
  Corregidos y runtime final sin warnings de bindings.
- PASS nueva fixture Wayland fullscreen1920x1080 output-pym_b925; incorporados
  separation reloj/media, seek a120s y capacidades/long title. Motion anterior
  output-3ehy6rrp. Capturas finales revisadas ancho, estrecho y texto1.5/imagen.
  Imagen/tema existentes usados para cover de prueba, no álbum real.
- Sin swipe, sin autenticación/bloqueo real ni modificación de reproducción.
  QA visual por muestras, no FPS. Propuesta pendiente aceptación del usuario.

## 2026-10-09 · Material del bloqueo alineado con Isla
- Usuario señaló diferencias de material/color respecto al shell actual.
  LockGlass conserva sample local seguro del wallpaper pero reemplaza gradiente
  blanco/negro + GlassCard con borde propio por PillMaterial real de Isla, con
  escala/radio del host. Sin fondo duplicado; vidrio usa Flags.glassAlpha,
  Theme.cardTop/cardBot, borde, sheen y acento idénticos a pill.
- Clock, media, controles, campos y separadores usan Theme.foreground,
  iconSecondary, alpha*, hair/border/accent. Timeline usa acento dinámico.
  Fondo opaco y velo derivados de Theme.background, sin azul fijo. PowerMenu
  reutiliza LockGlass. Colores semánticos de rechazo/éxito conservados.
  Composición y PAM/security intactos.
- PASS fixture Wayland output-zwgwl8dy; motion output-h800kojh; configuración
  completa preview carga y sale. Captura nativa de auth inspeccionada (material
  ahora sobrio/oscuro con borde/acento del tema actual). diff check limpio.
  No bloqueo/PAM real ni evaluación con todos los wallpapers/temas.

## 2026-10-09 · Reloj en reposo con cambio descendente
- Petición: horas/minutos bajan al cambiar, como número de workspace.
- ClockReel usa dos textos recortados: anterior sale abajo y nuevo entra arriba,
  con Motion.emphasizedLarge (duración del reel workspace) y easeStandard.
  Horas/minutos animan por separado; colon/AM-PM quietos. Mantiene fuente,
  color, escala, foco subrayado y MotionArea del calendario compartido en ambos
  layouts. Reserva dos dígitos y max ancho AM/PM para no variar ancho de pill.
- Actualización rápida conserva transición activa y luego toma último destino;
  hidden/reduceMotion detienen y sincronizan. Ningún Timer/FrameAnimation
  permanente añadido; NumberAnimation corre únicamente al cambiar texto.
- PASS nueva fixture Wayland output-0uvx6yra: rollover, pendiente durante vuelo,
  anchura, minuto sin cambios, reduceMotion y hide/show. Primer test detectó
  anchura AM/PM diferente: fijada a mayor advanceWidth. Status output-l9fvabsu,
  interacción/material/calendar/foco output-hgnekyaq. Shell auto reload Loaded
  sin errores nuevos; diff check limpio.
- Muestras nativas grabToImage antes/durante/después inspeccionadas en
  ~/.cache/isla-clock-audit/2026-10-09. Son muestras ampliadas, no FPS ni vídeo.
  No se modificó reloj del sistema; fechas inyectadas en fixture.

## 2026-10-09 · Cinco representaciones configurables de workspaces
- Usuario aportó referencias de números y puntos/barras, y pidió más de tres
  diseños elegantes, incluyendo Pac-Man. Implementados numbers (default previo),
  dots, bars, capsules y pacman. Color/ocupación/urgencia de Theme; slots simbólicos
  más densos. Mantienen regiones de clic, nombres de escritorio y foco de teclado.
- Un único motor de lens conserva trayectoria física/retarget/reducedMotion.
  Numbers conserva orb y puntos de ocupación; símbolos cambian tamaño/forma con
  proximidad al lens. Pac-Man es Shape.CurveRenderer único siguiendo trayectoria,
  con puntos ocultándose a su paso; ningún Canvas/loop nuevo ni dependencias.
- appearance.workspaceStyle en Settings.js; TopBarModules inyecta al rail para
  ambos layouts. Selector en Configuración→Apariencia; SettingRow choice ahora
  Flow para envolver opciones si no caben en ventana estrecha. Default personal
  conservado, sólo ISLA_CONFIG temporal usado para probar persistencia.
- PASS fixture Wayland output-lxhv24t3: cinco estilos en ambos layouts, selector,
  unknown reject, discard, save completo y reload. settings.cjs PASS; lens motion
  output-b_lchbvs; composer output-xhhzbkl3. Primer composer detectó búsqueda
  compacta extra por descripción nueva; descripción neutral para ambos layouts.
- Captura nativa cinco filas en ~/.cache/isla-workspace-styles/2026-10-09/styles.png
  inspeccionada antes/después de densidad. Shell auto recargó Configuration Loaded.
  Diff check limpio. No se cambiaron workspaces reales; movimiento/estados
  inyectados en fixtures. Acabado pendiente aceptación usuario.

## 2026-10-09 · Pac-Man mastica durante el desplazamiento
- Boca abre/cierra con ciclo180ms sólo durante viaje, amplitud ligada a velocidad
  del lens. Orientación izquierda/derecha sigue velocidad, también al retargetear.
  Descanso18°; reducedMotion/oculto detienen. Reutiliza FrameAnimation físico
  existente; sin Timer/loop extra ni trabajo permanente en reposo.
- PASS pacman-motion-regression Wayland output-cex1gscj: movimiento, dirección,
  retarget, settle, reduceMotion e hide; lens anterior output-jr6_vxqz. Capturas
  boca abierta/cerrada nativas ampliadas inspeccionadas en
  ~/.cache/isla-pacman-audit/2026-10-09; muestras, no vídeo/FPS. Shell recargó
  Configuration Loaded; diff check limpio. Workspaces reales no modificados.

## 2026-10-09 · Mordida de Pac-Man más perceptible
- Usuario indicó movimiento casi imperceptible. Eliminada atenuación de apertura
  ligada a velocidad: durante viaje boca recorre 4–44° por lado, ciclo240ms
  (antes18±17° × velocidad,180ms). Mordida visible también en desplazamientos
  cortos/desaceleración. Al terminar vuelve suavemente18° en90ms; oculto y
  reduceMotion sincronizan directo. Sin loops nuevos ni cambios de workspaces.
- Regresión ampliada exige máximo>40°, mínimo<8°. PASS Wayland output-azrflxc3:
  extrema apertura/cierre, retarget/dirección, descanso, hidden/reduceMotion.
  Muestras nativas abiertas/cerradas revisadas; no medición FPS/vídeo.

## 2026-10-10 · Diagnóstico de Configuración pendiente de reproducción
- Usuario reportó funcionamiento incorrecto sin precisar caso. Pregunta enviada
  sobre apertura, controles, superposición o guardado. Ventana real abre por IPC;
  screenshot nativa apariencia muestra controles distribuidos y sin QML errors.
- settings-integration.py PASS output-83usqaic (save atómico/watch/discard/etc.).
  Native controls inicialmente FALLÓ popup.visible porque ventana fixture tiled
  dejó fontRow fuera del viewport. Fixture pasa a fullscreen para tener área
  suficiente: PASS output-82ca36vf (combo pointer/keyboard, texto, sliders,
  switches/módulos). Se modificó sólo geometría de prueba, no se declaró arreglada
  la app por esto. Configuración real reabierta; ajustes personales intactos.
- Falta ejemplo concreto del usuario para reproducir fallo real. diff check limpio.

## 2026-10-10 · Selección exclusiva de estilos en Configuración
- Capturas del usuario mostraron cinco opciones resaltadas y barra en números.
  Selector choice permitía estado nativo checkable separado de Config. Se quitó
  toggling nativo: checked/accent/Accessible.checked derivan sólo de root.value;
  activación envía choice.modelData explícito. Rol RadioButton conservado.
- Fixture anterior preactualizaba Config y llamaba clicked(), ocultando fallos
  de entrada. Ahora QtTest.mouseClick nativo sin preactualización y comprueba
  exclusividad en las cinco opciones. PASS Wayland output-g497cxra; composer
  output-k8dpry_h; save/reload/discard temporal siguen pasando. Fixture previa
  fresh pasaba aun con código anterior, por lo que no se afirma reproducción
  completa del estado acumulado del usuario; fix elimina esa divergencia posible.
- Shell recargado para limpiar estado visual obsoleto. Config personal no escrito.
  Diff check limpio. No se ejecutaron clics reales sobre configuración personal.
## 2026-10-10 · Auditoría QA integral, entrega sin correcciones

Petición adjunta: inventario y cobertura de toda Isla, código conectado y
comportamiento real, fallos reproducibles y traspasos; no corregir producto.
Coordinador inspeccionó UI/movimiento/pruebas e integró auditorías acotadas de
Config (economy_implementer) y servicios (agency_reviewer); dos subagentes máximo.
No se crearon monitores ni chats externos. Cambios previos conservados.

Entrega principal: `docs/ISLA_QA_AUDIT.md`; informes por área, 12 traspasos
autocontenidos y evidencia persistida en `docs/audit-2026-10-10`.
11 defectos de producto reproducidos: SVC01/02/04/05, CFG01/02, UI01–05.
SVC01 P0 por escala explícita de pérdida de datos: nmcli falso confirma
delete previo al fallo de add/fallback; no se destruyó un perfil personal.
UI01 P1: wtype Qt.quit() en launcher aislado cierra el proceso sin Enter.
Otros P2: trigonometría inversa rota, Accessible sin activación, slider brillo
sin teclado, Escape sin foco compositor en siete paneles2/2, dimensiones
Infinity aceptadas, borrador aplicado sobre cambio externo3/3, rutas XDG lock,
retención de previews tras limpiar, selección de energía no aplicada.
QA01: gate verify-config exit1 antes de Node por ruta literal en fixture.
SVC03 sigue sospecha: carga de historial podría sobrescribir avisos del arranque;
no se confirmó intercalación efectiva, no se presenta como fallo reproducido.

Requisito → evidencia → pendiente:
- Inventario/matriz única → informe incluye 15 surfaces y servicios/scripts →
  ninguna categoría completa certificada; límites por criterio explícitos.
- Función/estado/interrupción →58 ejecuciones QML,54 nombres,56 clean iniciales →
  lyrics sin endpoint y layout a25s inválidos; repeticiones localHTTP/100s PASS.
- Persistencia/editor →settings integración y eventos QtTest+archivo externo →
  CFG02 no pulsó Guardar; overwriting posterior de disco inferido, no realizado.
- Servicios/seguridad →fakes nmcli/cliphist/powerprofilesctl, Auth bridge/backend/
  transport cuatro recargas, lock launcher, AuthPrompt y LockSurface preview →
  PAM/Polkit/sudo/WlSessionLock y energía/red reales no ejecutados.
- QA nativa →14 pares grim apertura/Escape, wtype y router IPC antes/después;
  compact620px y lock380px/texto grande con datos simulados →puntero físico,
  multimonitor, contraste cuantificado, IME/AT-SPI pendientes.
- Animación/recursos →morph/retarget/absorption/reduced/unload/fanout PASS →
  no análisis fotograma a fotograma, FPS/CPU/GPU continuo ni soak medidos.
- Entrega →logs completos copiados desde caché/tmp, fixtures y roles mínimos →
  agente corrector puede usar cada traspaso sin releer conversación.

Impeccable context reconoce incorrectamente Linux como web: se conservaron
PRODUCT/DESIGN y se adaptaron criterios generales sin detector/score web.
Qt Accessible oficial sustentó contrato de activación. Skills de auditoría
no autorizan fixes en esta fase: prevaleció el brief de sólo diagnóstico.
Primeros probes propios con imports fuera del root y cierre QtTest prematuro
fallaron; se corrigieron sólo esas fixtures. No son bugs de producto.

Validación final/documentación y límites se registran en informe/evidence.
Se cerraron procesos y superficies temporales; shell personal PID1645 permaneció.
No se escribieron ajustes personales ni se aplicaron wallpaper/volumen/perfiles.


## 2026-10-10–11 · Correcciones de la auditoría integral

Usuario autorizó corregir todos los puntos. Todos los IDs del informe anterior
quedan atendidos; cierre y evidencia en docs/audit-2026-10-10/fixes/REPORT.md.
Se conservaron los cambios previos del árbol, sin commit ni cambios personales
intencionados. Base Sol/medium; dos agentes existentes: configuración implementó
CFG-01/02 y revisó servicios/interacción; servicios implementó SVC/UI04, después
alcanzó cuota. Coordinador terminó pruebas y documentación el 11. Revisión
independiente de fuente/logs: sin hallazgos accionables confirmados.

Cambios:
- UI01/02: Calculator.js analiza gramática matemática limitada512, sin eval;
  constantes, funciones completas, precedencia y resultados finitos. Controller
  mantiene su API; tests Node y entrada QtTest real sin efectos Qt.quit.
- UI03: MotionArea/CtrlBtn/Toggle acciones Accessible, guardas enabled/visible;
  Toggle emite señal para que el propietario mantenga estado.
- UI04: brillo semántica Slider, Tab/flechas/increase/decrease y foco visible;
  prueba QtTest Tab/ShiftTab, cuatro pasos netos0, disabled, cero live duplicados.
- UI05: foco modal exclusivo mientras solicitado, release al cerrar/fullscreen.
  wtype Escape en14rutas noAuth verifica cierre y release; política y regresiones
  split/compact/interrupciones/superficies pasan. Auth se probó con backend falso.
- CFG01: límites uiScale0.25–3, topGap/appGap0–4. Documentos fuera se rechazan.
  CFG02: base por borrador y conflicto con recarga externa; bloquea Enter/Save,
  conserva texto; edición/restablecer/descarte resuelven. Watcher real con
  reemplazo atómico temporal+QtTest, IPC, save/discard/unknown pasan Wayland.
  Captura de SettingsPage opaca revisada, no Edots entero.
- SVC01: reemplazo delete/add retirado; nmcli device wifi connect argv. Fakes
  éxito/fallo, espacios SSID/password, BSSID normalizado, callback único y refresh.
- SVC02: Session.lock usa XDG_DATA_HOME/fallbackHOME argv; wrappers falsos.
- SVC03: sospecha reproducida por reload FileView con entrada viva; merge conserva
  y persiste fresh+old. mkdir retrasado prueba pendingSave/stateReady; ningún
  D-Bus real. Conserva protección de no persistir ante lectura noFileNotFound.
- SVC04: wipe exitoso cancela previews y retira directorioPNG; fallo conserva.
  Fakes superficie viva éxito/fallo/decode lento y regresión clipboard pasan.
- SVC05: perfil solo lectura confirmada; busy/error y readback, timer mientras
  abierto. Fakes QtTest Wayland set fallo/éxito, externo, recuperación lectura
  pasan. Captura mantiene Balanceado ante fallo Rendimiento; inspeccionada.
- QA01: optional-modules fixture usa asset portable del repositorio o env.
  verify-config final incluye test parser y pasa.

Pruebas pertinentes y logs recuperables en fixes/. No repetir toda suite54:
regresiones de áreas modificadas y vecinas pasan. Primeros fallos propios de
fixtures (QtTest acentos, nombre inexistente y timing loaded mkdir) se corrigieron;
logs iniciales conservados. El 10 document/effective/dirty personal coincidían
con snapshot previo; reinicio del11 eliminó /tmp, comparación no repetida.
Shell personal PID1709/instancehb1gr8qmt carga el código y Config.loaded sinerror,
dirtyfalse. Portal emite advertencia appID preexistente; Polkit registrado.
Procesos temporales cerrados; qslist solo shell personal al cierre.

Límites: no red/energía/clipboard personal/PAM/WlSessionLock reales; no hardware,
multimonitor físico, AT-SPI/IME, soak ni profiling continuo. Tests Accessible no
certifican lector de pantalla. Eliminación PNG no es borrado forense. No se
probó ausencia de ejecutables nmcli/powerprofilesctl. Qt5 qmllint de /usr/bin
rechaza sintaxisQt6 sin diagnóstico; usar /usr/lib/qt6/bin/qmllint. Informe
principal actualizado como histórico con enlace a correcciones.


## 2026-10-11 · Configuración abierta y navegación a otras superficies

Usuario pidió corregir posibles fallos al abrir otras surfaces mientras Edots
está abierto. Cambio directo, dos archivos de producto; sin delegación por
alcance acotado. Skill fluid-island-motion y Qt/QML; memoria/motion/arquitectura
vigentes conservados. No se alteraron otros cambios ni configuración personal.

Reproducción Wayland: settings→launcher, foco launcherSearch=true, petición
profileRequest al editor retenido→focusfalse. Evidencia before.txt bajo
 docs/settings-surface-switch-2026-10-11/. EdotsWindow.activate ahora exige
contentReady/visible/enabled y no sustituye campo ya activo; onPageChanged
oculto no pide foco. Timer de IslandOverlay sólo forceActiveFocus si su scope
no tiene ya foco activo. Retención de editor/drafts y motor sin cambios.

Nueva settings-surface-switch-regression.qml + runner Python en copia temporal
con ISLA_CONFIG/XDG_STATE_HOME. PASS13destinos (launcher y12otras surfaces),
split/compact×normal/reduced, cerrar picker de archivos/fuentes al navegar,
preservar borrador/instancia, texto destino, CtrlS sin commit oculto, callback
tardío y retargetrápido. Entrada QtTest en Wayland, no clic físico. Escape14
con wtype y release tambiénPASS. Vecinas settings-controls/companion/motion y
AuthPrompt backendfalsoPASS. GatePASS, diffcheckPASS. Qt6lint exit0 con warnings
existentes; no linter sin diagnósticos. Shell personalPID1709 sigue cargada.
Capturas del FocusScope inspeccionadas: salidaSettings y launcherconcursor;
no Popup separado ni pruebas frameaFrame/FPS.

Fallos propios de fixture: assert+quit duranteQtTest produjo crash inicial;
cierre posterior porTimer trascatchloevita. Captura ProxyWindowContentItem
sinengine se cambió porFocusScope. Primer findChildfontPicker seleccionaba
control oculto de otra fila; búsqueda ahora exige visible/enabled. Tests finales
pasan; no atribuir esos problemas a producto. Advertencias DelegateModel al
cerrarFolderListModel y objetos encreación en algunassalidas registradas.
Informe docs/settings-surface-switch-2026-10-11/REPORT.md, logs antes/después y
comandos en TESTING. Sin authPAM, multimonitor físico ni IME comprobados.

## 2026-10-11 — Configuración, música y continuidad entre surfaces
Usuario aclaró que la absorción de gota musical al abrir Settings y la doble transformación al pasar a Calendar parecían extrañas; pidió UI/UX Pro Max. Settings retirado del grupo docking Router y de mediaPanelOpen. SettingsReturning mantiene Pill en reposo hasta companion idle, gates Media expanded y Session open/expanded; Auth excluido de espera y Pill z5 evita quedar detrás de Settings z4. Calendar integra IslandMediaSummary fuera del scroll, composición conecta Players y requestPage media. Calendar suprime gota externa una vez termina retorno de Settings. Sin nuevas opciones, timers de producto ni motores.
QA: settings-media-routing realoverlay/Wayland en copia Players falsa pasa cuatro modos, pausa/remoción, click, retarget y Auth visual; capturas inspeccionadas. Settings-switch13 destinos/borradores/foco, nativeEscape14, routing, layoutinterruption, Settingscompanion, Weather, Calendarfont1.75, gate y Qt6lint exit0; diffcheck. Revisión independiente rootlogic por config_audit, root inspeccionó footer. Offscreen PanelWindow sin backend corregido ejecutando Wayland. Evidencias/límites en docs/settings-media-ux-2026-10-11/REPORT.md. No PAM ni MPRIS real múltiple/multimonitor/perf/frameaudit; conservar pendientes históricos.

## 2026-10-11 — Edots UI/UX Pro Max integral
Usuario autorizó mejorar toda Configuración aplicando criterios skill. Root integró navegación adaptive 6/3×2, márgenes/preview según espacio, tipografía, buscador accesible/estado vacío, feedback de guardado, foco de primer error (query si estaba oculto, scroll al campo+motivo), validación path localizada y Theme.error con variante light/dark. Controles compartidos agente config_audit: fontScale/foco/Accessible/focusEditor; root amplió targets44 y ancho de símbolo escalado. Picker sidebar/preview y texto/actions adaptativos. Composer amplio ya no duplica controles en SettingsPage (animateChanges accesible en Movimiento). Sin cambiar persistencia, fuentes/paleta ni superficies ajenas.
Aceptación → evidencia: seis páginas/tamaños/fontMax/Save/error viewport y palettecontrast→settingsUX; controles/teclado→controls; selector→picker; drafts/atomic/watch/conflict→integration; destinos/foco→surface-switch; Escape14→native; motion→neighbors; arquitectura→gate; acabado→capturas y revisión independiente settings_ui_review. Hallazgos propios/revisor corregidos y afectados revalidados. Detalles/rutas en docs/settings-ux-2026-10-11/REPORT.md. Fallo de orquestación layer-picker host manual como autoejecutable documentado, no productFAIL; draft standalone DRAFT_READY no cuentaPASS, integration sí loconduce. Límites AT-SPI/hardware/multimonitor/perf/arbitrarywallpapers pendientes.

## 2026-10-11 — Paridad de animaciones con navegación de teclado
Usuario reportó que flechas en energía no animaban iconos y pidió paridad en superficies/controlables. MaterialIcon AnimatedSymbol combina hover explícito con interaction.engaged; MotionButton InteractionMotion incluye highlighted además de activeFocus; Session tile.highlighted enlaza selección semántica. Así se corrige en shared componentes sin añadir animaciones ni alterar acciones de energía. Revisados callers con hover explícito (Calendar, Connectivity, Wallpaper, Notifs, Overview, Launcher); ya suministran interaction. Nueva keyboard-icon-regression Wayland: flechas seleccionan/play gesto, Tab/Shift+Tab replay en control con hovered:false, reduceMotion stops y actions==0. Interaction-regression existente PASS puntero/keyboard/accessibility/disabled/interruptions. Log docs/keyboard-icons-2026-10-11/regression.log; diffcheck PASS y shell personal recarga correcta. No se ejecutó apagado, reinicio, suspensión ni bloqueo; no auditoría frame-by-frame de todas las superficies.

## Segundo cerebro Obsidian y Prompt Master (2026-10-11)

- Prompt Master 1.8.0 instalado desde nidhinjs/prompt-master con instalador de skills,
  incluye references/templates.md y patterns.md. Disponible en próximo turno.
- Obsidian 1.14.4 AppImage oficial descargada y extraída en ~/.local/opt/obsidian;
  launcher ~/.local/bin/obsidian y entrada de escritorio. Sin sudo ni plugins externos.
- Bóveda ~/Documents/Segundo Cerebro/Isla: Inicio, guía de recuperación y cinco
  enlaces simbólicos a mapa, historial, arquitectura, movimiento y pruebas originales.
  Core search/backlinks/graph activos. Editar enlaces modifica fuentes originales.
- AGENTS global/proyecto apuntan al mapa y recall.py para chats locales; notas nuevas
  se consultan con --file explícito. No sincronización ni acceso desde chats remotos.
- Validación: destinos de enlaces, JSON y referencias de skill PASS; recall léxico
  devuelve sección nueva y evidencia previa. Cliente real Obsidian abierto en Inicio,
  confirmado por Hyprland. Recuperación híbrida léxica/semántica también PASS.
- Sin medición de reducción de tokens, QA visual detallada ni prueba de edición
  en Obsidian. Motor existente reutilizado; ningún código de shell modificado.

## Segundo cerebro: cobertura del repositorio (2026-10-11)

- Bóveda con 1035 fichas, 114 índices de carpeta y nueve mapas temáticos.
  Fichas: ruta original, tamaño, líneas, declaraciones/imports/encabezados extraídos
  y referencias candidatas por nombre. Cifras variables según archivos actuales.
- tools/brain.py usa rg con hidden/no-ignore para catálogo; excluye .git, cachés
  Python, node_modules, .venv y .obsidian. Archivos ignorados/binarios solo por ruta.
  Lectura textual respeta ignore; mapa/historial/AGENTS incluidos explícitamente.
- --search consulta literalmente 523 fuentes textuales actuales; guarda todos los
  resultados en ~/.cache/isla-brain/search.txt y limita solo salida al contexto.
- tools/test_brain.py PASS: privacidad, binarios, lectura actual, limpieza de fichas
  obsoletas y conservación de notas propias. Enlaces internos verificados excluyendo
  código inline del parser de enlaces. Búsqueda pendingFocusSurface recupera fuente
  SurfaceRouter.qml y líneas exactas. AGENTS global/proyecto y guía actualizados.
- Límites: fichas regenerables, sin demonio; búsqueda lee disco actual. Referencias
  textuales no son call graph. No QA visual detallada de Obsidian ni ahorro medido;
  chats remotos necesitan acceso explícito a archivos. No cambia código de shell.

## Skill segundo-cerebro (2026-10-11)

- Skill personal instalada en ~/.codex/skills/segundo-cerebro/SKILL.md.
  Descripción permite selección implícita para preguntas/trabajo de Isla y memoria.
  Sin scripts nuevos, plugins, demonios ni dependencia de Obsidian abierto.
- Ruteo según necesidad: mapa/decisiones/búsqueda literal/fuentes actuales; rango
  conocido permite lectura directa. Explicita que fichas no entran en recall por
  defecto, referencias son candidatas y búsqueda negativa no prueba ausencia.
- Mantenimiento por fase, preservación de notas propias, sin secretos; regeneración
  una vez tras cambios en archivos/declaraciones. Informe de búsqueda se sobrescribe:
  usar rg en concurrencia. Ahorro requiere medición, chats remotos requieren acceso.
- AGENTS global/proyecto ahora enlazan skill y conservan puntero a bóveda; reemplazada
  explicación repetida del mecanismo por selección progresiva. Guía de bóveda enlaza skill.
- quick_validate.py PASS usando .venv existente (PyYAML falta en Python del sistema).
  Contraste manual de rutas/CLI y casos: historia -> recall, símbolo -> fuente actual,
  rango conocido -> directo, consulta ajena -> no activar. Sin evaluación independiente
  ni medición de tokens. No se modificó código funcional del shell.

## Integración de skills de memoria y ahorro (2026-10-11)

- Enlaces relativos recíprocos entre segundo-cerebro y ahorro-tokens.
  Recuperación/mantenimiento de Isla en segundo-cerebro; salidas y medición en
  ahorro-tokens. Lectura condicional, sin duplicar contexto ni disparar benchmarks.
  Flujo genérico de ahorro preservado para proyectos ajenos a Isla.
- Validación de ambas skills y resolución de enlaces locales; sin medición de ahorro.

## Integración de recuperación en main (2026-10-11)

Integrada codex/desktop-recovery conservando Edots, clipboard de Isla y launcher
XDG de Session. Instalador admite checkout directo en ~/.config/quickshell sin
mover bar; plugin Wpscan colgante se respalda. Prueba bootstrap AUR usa PATH
acotado para evitar helpers del host. Revisión independiente sin riesgos nuevos.
14 pruebas simuladas con GNU Stow real pasan; gate Config/arquitectura/calculador,
lockscreen-launcher, Starship y bash -n pasan. Plugin compila con Qt6 en temporal
según revisión; import QML, instalación real, paquetes Arch/AUR y login limpio
no comprobados. Logs en ~/.cache/codex-economy/output-nysrqjh0.log y registros
de esta sesión. Merge y push a main; rama secundaria conservada.

## Limpieza pública del repositorio (2026-10-11)

Usuario autorizó limpiar y subir; pidió retirar material sólo para IA y
comentarios narrativos. Se desversionaron 230 archivos sin borrarlos del disco:
220 evidencias fechadas, informes/investigación/diseño de docs, PRODUCT/DESIGN
y herramientas brain locales. Se conservaron Auth, Edots, Recovery y Architecture
como guías públicas y todas las pruebas reutilizables de bar/scripts. Exclusiones
en .git/info/exclude evitan reintroducir material local. README pasa de349 a110
líneas aproximadamente; changelog, testing y docs se reescriben para uso/mantenimiento.
Limpieza de comentarios delegada y revisada: 11 archivos, ningún cambio ejecutable,
atribuciones y razones técnicas conservadas. Gate Config/boundaries/calculador
PASS; todos los enlaces relativos Markdown apuntan a archivos versionados.
No nueva QA visual ni ejecución completa de suites: no cambia comportamiento.
No reescritura del historial, informes accesibles en commits anteriores.

## 2026-10-11 · Experimento de resortes retirado tras caída de sesión

Petición: aplicar consejos del video sobre springs selectivas. Isla ya tiene
motor físico en gotas/workspaces y recuperación SpringAnimation en botones.
Experimento: Toggle recorrido y Slider agarre con SpringAnimation, prueba
interaction ampliada; configuración activa externa de Hyprland añadió
springWindow(mass1/stiffness400/dampening38) en windowsIn/out con popin94/96.
La sesión cayó tras hyprctl reload y volvió a caer durante la restauración con
reload, según reporte del usuario. No repetir recargas como prueba en sesión real.

Restauración comprobada: ~/.config/hypr/modules/animations.lua coincide por cmp
con ~/.local/state/isla-motion/2026-10-11/animations-before.lua. Experimento QML
retirado de los tres archivos propios (checkout inicialmente limpio); patch
conservado en la misma carpeta de estado. Wallpaper guardado reaplicado con
awww img --transition-type none; awww query confirma wallhaven-qr327r.png en DP-1.
No más recargas del compositor. configerrors vacío y procesos Hyprland/qs/awww
presentes en comprobación final. Journal muestra portal status11/SEGV durante
reinicios, sin evidencia suficiente para atribuir la causa raíz a un parámetro.
No declarar springs nuevas aprobadas ni tests del experimento como validados.
Pendiente: diagnosticar caída/recarga en entorno aislado antes de reintentar.
La API v0.56.2 exige dampening, aunque wiki actual dice damping; speed no define
la duración de spring. Fuente versionada verificada por investigador:
https://github.com/hyprwm/Hyprland/blob/v0.56.2/src/config/lua/bindings/LuaBindingsConfigRules.cpp

## 2026-10-11 · Diagnóstico de las dos interrupciones por reload

Journal11:23:31–33 contiene error fatal global wl_output(73) unavailable en Dolphin,
Broken pipe XWayland y errores de clientes; 11:28:58–59 repite pérdidas de clientes.
No Hyprland core en coredumpctl; portal PID2000/3108 caen con stacks marshal/exit
idénticos, compatibles con daño secundario. No GPU/Xid/OOM en ventana kernel
consultada. Primera sesión conserva compositor hasta logout posterior.
Monitors.lua externo reinicia panels=false y config.reloaded deshabilita eDP;
mock Lua aislado confirma orden repetida incluso con eDP ya apagado. Reporte
upstream12996 coincide con clase de carrera wl_output/disable/reload y versión.
Hipótesis principal: reconfiguración de monitores al reload mata clientes,
no evidencia de spring causando crash compositor. Falta log previo exacto de
crear/destruir salida para atribución definitiva. Informe/evidencia en
~/.local/state/isla-motion/2026-10-11/diagnostico/INFORME.md. Solo lectura/mocks,
sin reload ni nuevo fix de monitores. No eliminar callback sin definir estabilidad
reglas durante carga. Config anterior conservada.

## 2026-10-11 · Corrección de monitores preparada sin aplicar en sesión

Candidato externo ~/.local/state/isla-motion/2026-10-11/correccion/monitors.lua:
lee estado conectado de salidas DRM al cargar, registra regla explícita del panel
antes de reconciliación; elimina start/config.reloaded callbacks, conserva
monitor.added/removed y compara estado para no repetir órdenes. Sin curvas nuevas.
Test Lua simulado en misma carpeta: docked/undocked inicial, forma idéntica de
regla al recargar, hotplug/duplicados/sin status PASS; luac sintaxis PASS.
Original respaldado monitors-original.lua; cmp confirma activo intacto.
APLICAR.md incluye instalación solo con sesión cerrada en TTY, guard pgrep y cmp
para no sobrescribir cambios posteriores; no se instala ni reload ahora porque
watcher puede disparar recarga al editar activo. Pendiente validación hardware y
compositor aislado; DRM connected no garantiza modesetting exitoso, bug upstream
puede seguir afectando otros cambios físicos. No declarar fix runtime validado.

## 2026-10-11 · Mitigación instalada sin reload, reinicio por usuario

Usuario autoriza aplicar y reiniciar después. Fuente exacta v0.56.2 identifica
misc:disable_autoreload con refresh exclusivo CONFIG_WATCHER. Runtime:
hyprctl eval hl.config misc.disable_autoreload=true + scheduled prop refresh;
getoption booltrue. /proc Hyprland1505 inotify fd10/71 ambos cero watches.
Solo entonces copia monitors.lua preparada al archivo activo, tras guardcmp con
original y luac. Copia exacta verificada. No reload ni cambios de monitores.
Watcher queda deshabilitado SOLO runtime hasta siguiente inicio; archivo misc
no cambiado. configerrors vacío corresponde configuración cargada anterior,
no valida candidato runtime. Corrección activa en disco, pendiente siguiente
inicio y QA hardware; backup original conservado. APLICAR.md actualizado.

## 2026-10-11 · Cerrar sesión en Win+M compatible con UWSM/Lua

Win+M abre SessionSurface, confirmación usa singleton Session.logout(). Comando
legacy hyprctl dispatch exit0 no corresponde a API Lua0.56.2. Cambio mínimo
Session.logoutCmd: si uwsm disponible y sesión gestionada activa, uwsm stop;
fallback loginctl terminate-session con XDG_SESSION_ID obligatorio (sin ID falla
antes de llamar). No cambia binding ni confirmación/UI. Callers SessionSurface e
IPC mantienen interfaz. Nuevo test Python con PATH mock prueba cuatro ramas sin
cerrar sesión. Session-regression fake actions PASS; prueba load singleton en
copia aislada PASS (primer montaje faltaba services JS, resuelto copiándolo).
qmllint exit255 sin diagnóstico, no contado PASS. Live qs log confirma carga
tras hot reload de Isla, compositor no recargado. uwsm stop -n confirma target
wayland-wm@hyprland.desktop.service sin detener. TESTING actualizado. No logout
real: usuario lo ejecutará tras guardar trabajo. Watcher Hyprland permanece
runtime deshabilitado hasta siguiente inicio, mitigación monitores en disco.

## 2026-10-11 · Nuevo inicio tras mitigación confirmado

Usuario confirma logout/login. Comprobación read-only: Hyprland PID34038 iniciado
11:52:59 AST, qs34141/awww34151 desde11:53. ConfigLua correcta, configerrors vacío,
monitors.lua activo coincide porcmp con candidato probado. DP-1 activo1920×1080,
eDP-1 disabled. misc.disable_autoreload=false/default restaurado por nuevo inicio.
Esto valida carga e inicio con dock actual; no prueba todavía reload/hotplug ni
elimina riesgo upstream. No reload ejecutado. Usuario confirma logout funcionó.

## 2026-10-11 · Modernización compatible instalada, activación pendiente

Usuario eligió conservar Isla y estilo actual, mejorar movimiento y manejo.
Investigación wiki actual + foros (mantenedor discusión15495 stiffness tras0.56,
13009 splits,13141 reglas demasiado amplias) contrastada con fuente commit instalado.
Cinco módulos externos cambiados: animations/layout/binds/windowRules/input.
Detalle, fuentes y rollback: ~/.local/state/isla-motion/2026-10-11/modernizacion/INFORME.md.
Verificación nativa copia sin autostart exit0/config ok, binds sin duplicados;
revisión hypr_springs de APIs/config sin bloqueos. Comparación antes de instalar
protege cambios concurrentes. Autoreload apagado runtime y cero inotify watches
antes de copiar; contenido verificado. No reload, monitores sin cambios, errores
de sesión actual vacíos. Nuevos valores aún no cargados: QA visual y prueba real
de atajos/gestos requieren logout/login usuario. No scrolling/plugin/dependencias.

## 2026-10-11 · Investigación vidrio y efectos, sin aplicar

Reporte/evidencia: ~/.local/state/isla-motion/2026-10-11/diseno/INVESTIGACION.md.
Wiki Latest acrylic/variants no compatible0.56.2: prueba parser negativa exit1
unknown decoration.blur.variant. Glow inactivo/motionblur parser positivo exit0.
HyprGlass declara rama0.56, clases/namespaces/presets, hook privado de capas;
no instalado ni probado. Kitty fondo65%, reglas Thunar/Spotify ya transparentes.
Recomendación: nativos mate/foco primero, HyprGlass piloto kitty después; Isla
requiere máscara alpha correcta y QA. No config activa/reload/cambios visuales.

## 2026-10-11 · Vidrio aplicado

Usuario autorizó aplicar mejoras visuales/animación. Instalados decorations/animations/windowRules/glass.lua + require antesautostart y Kitty user.conf. HyprGlass branch0.56 commit84c1a5a build-j2 exit0, dependencias presentes; copia binario path correcto. Parser nativoPASS (guard plugin nil), mockwhitelistPASS/Kitty configPASS. Revisión hypr_springs valida API y reparse plugin init. Fullscreen off, maximizado conserva vidrio. Autoreloadapagado y watches0; monitores intactos. RESULTADO.md en ~/.local/state/isla-motion/2026-10-11/vidrio-aplicado contiene rollback/evidencia. Pendiente runtime real/GPU/QA al login; no reload. Sin cambios QML/repositorio.

## 2026-10-11 · HyprGlass más visible

Usuario apenas percibe efecto. Plugin cargado match/shaders ready; solo ChatGPT abierto, whitelist Kitty sin clientes => inactive esperado. Aumentado preset refracción0.55/spread0.45/aberración0.06/specular0.40/fresnel0.35. Guardado glass.lua con autoreload apagado/watches0; aplicado SOLO hg.preset en runtime vía eval-r, sin reload ni duplicar reglas/load. Kitty lanzado mediante typed Lua exec. Backup glass-suave.lua y preset-visible.lua en vidrio-aplicado. QA visual subjetiva pendiente.

## 2026-10-11 · Aproximación referencia visual aplicada en vivo

Usuario pide acercarse a captura terminal transparente/glow amplio. Kitty fondo0.50,
rounding20/power2 (regla por ventana máximo20 en0.56.2: intento25 rechazado,
corregido y verificado aislado exit0). Glow global35/shadow28; paleta pywal intacta.
Preset HyprGlass blur0.65/brightness0.8/contrast1.2/vibrancy0.35, refracción0.30
spread0.20; evita lente exagerada. Fuente captura contrast2 no copiada literalmente
para conservar legibilidad. Backup referencia-glass; candidato nativo y Kitty
PASS, API runtime preview PASS, configerrors vacío y plugin active/shadersready.
Autoreload apagado/watches0 antes guardar. Sin reload. Kitty preview lanzado
con override0.50; captura grim preview.png inspeccionada: wallpaper visible,
halo pywal rojizo y contornos redondos; fondo actual oscuro limita brillo
frente al cielo azul de referencia. GPU/movimiento sostenido no medidos.

## 2026-10-11 · Kitty estética y movimiento

Usuario pide estética/animación impresionante conservandoKitty. Solo config externaKitty user.conf+shaders/isla-motion.pipeline+reduced-motion.conf; noQML niHyprland. Tres grupos shaders nativos personalizados: trail16samples por movimiento, reflejofoco250ms bajo brillo, tabwipe200ms; tiempos cortos y eventos evitan fondo continuo. Slang local exactov2026.18.2 instalado researcher, checksumofficial/ldd/buildGLSLPASS. Ajustes tipografía12.5/padding16/tabs índices y estado/pywal. Parser completo/pipeline/GLSL/reducedmotionPASS. Corregido custom_shaders vacío inválido a none. Preview2tabs socket-onlyruntime.logvacío y captura grim inspeccionada. Atajos CtrlShiftF8/F9 enviados solo preview. Kittyprevio77070SIGUSR1reloadconfig, sin compositorreload. Backup/reporte ~/.local/state/isla-motion/2026-10-11/kitty-estetica. GPU/QA movimiento240Hz no medidos.

## 2026-10-11 · Brillo escritura Kitty

Añadido grupo bloom estático native shader pipelineisla-motion threshold0.30/strength0.07. Halo sobre píxelesluminosos (texto e iconos), no identificación semántica de glyphs. CompilaciónGLSL realPASS; Kitty reload mediante helper oficial SIGUSR1, noHyprland. runtimepreviewlogvacío, capturabloom.png inspeccionada. Backup pipeline-sin-bloom.pipeline en kitty-estetica; CtrlShiftF8 apaga shaders. Sin mediciónGPU; shader24samples solo repinta cuandoKittyactualiza/otros eventos animación.

## 2026-10-11 · Flujo scrolling

Usuario pide probar workflowNiri dentroHyprland. Reemplazado general.layout defaultscrolling, config layoutcolumns50%/right/noWrap/fit/follow/fullsingle, dwindle.smart_splitfalse. P/J ahora colresize+conf/center; arrows layoutfocus evitan fullscreenfocus escapar monitor; CtrlLeftRight swapcol, O consume_or_expelprev, ShiftO promote. Existentesworkspacekeys/shiftarrows yFS intactos. ParsernativePASS/bindsduplicatecheckPASS. Primerpreview syntaxfalló antes ejecutar; reparado+luacPASS. Aplicado medianteevalconfigbindsunbind y scheduledrefreshLAYOUTS, fuente confirmado noMonitorStatus; nofullreload. Configerrorsvacío/layoutscrolling. Backup3módulos y rollbackruntimecurado en ~/.local/state/isla-motion/2026-10-11/scrolling. No Niri completo; QAoverview/scratchpad/multimonitor prolongada pendiente.

- Límite QA scrolling: captura actual muestra pantalla bloqueada; no permite
  evaluar columnas. Solo runtime/config verificados; QA visual pendiente desbloqueo.

## 2026-10-11 — Fastfetch Edots
Sustituido sombrero por PNG Edots del asset existente bar/settings/assets/edots.png, copiado a ~/.config/fastfetch/edots.png. Composición compacta EDOTS / FLUID DESKTOP con layout y wallpaper actuales, módulos nativos y paleta. Ajustado ancho de claves y colores ANSI por nombres (los números 7/8 activaban atributos). CLI sin errores y logo visto en Kitty; encabezados finales blancos para contraste. Respaldo original y captura en ~/.local/state/isla-motion/2026-10-11/fastfetch-isla/. Otros terminales no verificados; sin recargar Hyprland.

### Fastfetch: Edots ASCII solicitado
Logo redibujado con caracteres ASCII, arco y tres puntos en degradado ANSI truecolor cian-violeta. Config usa type=file y edots.txt, conservando módulos. Fastfetch --pipe --show-errors exit 0 y QA real en Kitty, captura preview-edots-ascii.png en respaldo. Config PNG previa conservada como ~/.config/fastfetch/config-antes-ascii.jsonc.

## 2026-10-12 — Hyprland en Edots
Petición autorizada: primera versión de flujo y animaciones desde la app, con preview/guardar/revertir. Servicio HyprlandSettings independiente de Config, inicializado por ShellRuntime; helper Python ejecuta solo eval validado, nunca reload ni escribe módulos. HyprlandPage inyecta controlador y reutiliza SettingRow/EdotsButton; navegación 7 tabs responsive y búsqueda enlaza sección. Guardado atómico en isla/hyprland.json, aplicado al iniciar Isla; preview pendiente señalado al navegar a otra página. Curvas y herencia preservadas, duración de springs protegida, recovery explícito con backup.
Requisitos→evidencia: controles→hyprland-settings-ui.py PASS; persistencia/fallos/serialización→hyprland-settings.py PASS con fake/hostQML; integración existente→settings-ux.py y settings-surface-switch.py PASS; formato/boundaries→verify-config PASS; runtime→speed+0.1 y restauración exacta de values/raw en Hyprland0.56.2; visual→desktop-real.png y snapshots 1000/640, font1/1.75. Revisión independiente corrigió bool vs int, rollback postquery, recuperación de JSON inválido y curvas externas.
Informe y capturas: ~/.local/state/isla-motion/2026-10-12/hyprland-settings/. No preferencias personales guardadas ni reload de compositor. Pendientes: login real con persistencia, cambio de layout real, multimonitor y GPU; dos escritores simultáneos mantienen ventana entre digest y rename.

## 2026-10-12 · Expulsión/contracción: continuidad física y óptica

Petición: investigar y mejorar expulsión/captura de pill/shell con inspección
frame a frame, interrupciones y rendimiento. Se aplican skills invocadas,
memoria selectiva y revisión independiente. Cambios ajenos Hyprland conservados.

- Motor: solución exacta amortiguada con parámetros existentes y frameTime;
  settled incluye velocidades; absorbiendo retargetea; reduceMotion live resuelve.
- Geometría/material: cuello smoothstep1.02→1.30 hasta0 y retorno desde1.30;
  bordes/brillo continuos de ambos cuerpos, sin doble Behavior durante unión.
  Bridge síncrono y acos seguro. Ocultación por cápsula completa0.08·s.
  Revelado de tarjeta requiere ancho y alto.
- Aceptación temporal → companion-continuity/absorption PASS, refrescos
  30/60/144/240 y stall80ms, inversiones/captura/opción live.
- Aceptación óptica → dos ciclos threaded Wayland nativos, pinzamiento y captura
  con PTS/frames originales, revisión independiente sin nuevo corte sustentado.
- Integración → centered/session/settings/media/motion/material PASS,
  routing media/surface-switch/layout-motion Wayland PASS, gate/diff PASS;
  Isla principal carga tras reload propio. Sin reload Hyprland.
- Perf → dt de fixture cerca4.2ms mediana; no benchmark GPU/FPS renderizados.
  Candidate QSG_USE_SIMPLE sin ventaja consistente; entorno intacto.
- Límites → qmllint255 sin diagnóstico; contenido sintético/cámara no acreditan
  todos los frames; multimonitor/escala fraccionaria física/GPU sostenido pendientes.

Fuentes primarias, intervalos exactos, intentos descartados, scripts, clips y
logs: ~/.local/state/isla-motion/2026-10-12/shell-smooth/RESULTADO.md.
No se promete perfección universal. No hay monitores ni tareas recurrentes.

## 2026-10-12 · Settings: pausa de apertura y absorción tosca
Usuario reporta lag y rechaza forma de retorno. Coste aislado con SettingsSurface
real: apertura síncrona270ms y primer tick303ms; reapertura4–5ms. Async bajo
demanda quitaba pausa pero Ready tardaba~1.2s: descartada como solución aislada.
Loader retenido ahora precarga en reposo, surfaceItem sólo Ready y loadReveal
completa con reduceMotion. Fixture sin grabación: primer tick5ms y contenido99%
186ms (no FPS/GPU). Arranque bajo grabación puede acabar carga después de abrir.

Segundo problema: cardRadius interpolado inflaba esquinas intermedias; Loader
redimensionaba toda UI durante morph. Radio min(24*s,halfDims), editor a cardW/H
fijos con escala uniforme y recorte. Retarget/resorte intactos. Tests assert
radio y dimensiones estables en cierre, cold-load/reopen/retain/reduceMotion.
PASS continuidad, settings-async Wayland, centered, surface-switch13 destinos
con focus/drafts normal/reduced split/compact, verify-config y diff. Main shell
Configuration Loaded; warnings .face/portal/DelegateModel existentes.
QA: dos ciclos antes/después con editor real y contrato open de producción,
clips+PTS/frames originales en shell-smooth/settings-swallow-real-*. Primeros
clips settings-swallow-* tenían open:drop.open y no acreditan fade producción.
Revisión independiente sin defecto sustentado en diff; lag extremo de carga
vs timer foco no forzado como caso dedicado. Lint255 previo sin diagnóstico;
GPU sostenido/multimonitor físico/escala fraccionaria pendientes.

Contacto real mostró retirada demasiado temprana: sólo expandedContent escalado
usa exposición geométrica0.06–0.70; otras surfaces siguen0.45–0.80. Assert
contenido>.5 a tamaño40% y cold/retain/reduced PASS tras cambio. Final clip
settings-swallow-final conserva dos ciclos y contrato real.


## Auth: feedback e interacción — 2026-10-12

Petición: mejorar funcionalidad, estética, colores y detalles de movimiento de la surface de contraseña.
Alcance: bar/components/AuthPromptView.qml y bar/auth-prompt-regression.qml; composición
AuthPrompt→AuthSurface y backend Auth revisados, sin cambios al transporte ni PAM. Cambios ajenos conservados.

- Color/foco → acento dinámico en borde/caret/acción, rojo error, verde éxito y ámbar Caps Lock;
  icono semántico en detalle y selección temática. Capturas Wayland ready/rejected/success inspeccionadas.
- Reintento → sendRejected recibe color y recoil existentes; cambio de desafío limpia edición y rechazo
  para no suprimir errores posteriores. Aserciones nuevas incluidas en fixture.
- Morph/teclado → slot deshabilitado al cerrar o con exposure≤0.95; recuperación diferida
  del foco al habilitar. Fixture cubre cierre interrumpido, reapertura, Tab, Enter, Escape,
  cuentas, double-submit, sudo, limpieza del secreto y reduceMotion; PASS.
- Validación: ISLA_CONFIG temporal /tmp/isla-auth-polish/config.json; backend simulado sin
  registrar Auth. Evidencia /tmp/isla-auth-polish/{ready,rejected,success,reopening,closing,verifying}.png.
  Log final ~/.cache/codex-economy/output-gw0aqgjc.log. git diff --check PASS.
- Límites: qmllint salió255 sin diagnóstico; carga QML Wayland válida. Warnings Mesa/textinput
  en fixture, sin FAIL final. No autenticación PAM/sudo real, AT-SPI, paletas alternativas,
  contraste medido ni FPS. Mensajes largos conservan elipsis y tooltip completo existentes.


## 2026-10-12 · Settings: eliminar bola y comprobar lag

Usuario precisa que Settings se convierte en bola antes de ser consumido.
Cambio sólo de captura centrada en FluidCompanion, z de Settings al retornar y
centered-companion-regression; cambios previos ajenos preservados. Destino cápsula
inscrita, clamp cardW, seguimiento X/Y/W/H y derivados ante layout/altura.
Máscara inversa sólo al contacto sobre módulo completo, sin editor permanente
en capa ni fade para ocultar costura. Reopen conserva velocidades.

Requisitos → evidencia: bola → baseline/final con editor real, dos ciclos por
100×38/760×56; captura/inversión/layout/reduced →centered/continuity/absorption PASS;
retención/carga →settings-companion y settings-async Wayland PASS; gate/diff PASS.
Revisión independiente acotada, ajustes a targets derivados y máscara aplicados.
Principal reload Configuration Loaded. Lint255 sin diagnóstico; cold-open de
settings-surface-switch falla antes y después y queda pendiente.

Usuario pregunta por lag durante pruebas: sin recorder con/sin máscara da medianas
17.88/18.74ms y p9532.36/36.94ms; no evidencia de penalización principal del recorte
en esa comparación. Quickshell CPU172.9% instantáneo2s. Driver NVIDIA módulo615.71.09
vs NVML615.78 impide nvidia-smi; sin afirmar causalidad ni cambiar driver/reiniciar.
No captura/prueba temporal activa al cerrar.

Intervalos, logs, clips, prototipos descartados y límites en
~/.local/state/isla-motion/2026-10-12/shell-smooth/SWALLOW_CAPSULE.md.

## 2026-10-12 — Resolver lag: GPU Intel

Raíz llvmpipe comprobada. Mesa Intel EGL validado en fixture y shell principal;
launch env persistido en ~/.config/hypr/modules/{autostart,binds}.lua.
Restart PID98030→406955, Config dirty:false antes, sin tocar ajustes de usuario.
CPU proceso3s370.89%→22.00%, sin threads llvmpipe. QSG_INFO Intel UHD CML GT2.
settings-surface-switch ahora PASS,13 destinos split/compact normal/reduced;
Lua y configerrors PASS. Capturas grim negras, no QA visual; respuesta usuario
pendiente. NVIDIA mismatch sigue y no se cambian paquetes. Evidencia gpu-lag/RESULTADO.md.

## Reversión urgente — Intel produjo pantalla negra

Usuario confirmó negro excepto cursor. Eliminadas variables Mesa/DRI_PRIME de los tres lanzamientos; terminada shell Intel PID406955, original PID419833 restaurada. Configuration Loaded y captura restored.png verifican fondo, ventanas y barra visibles. La caída CPU no constituyó solución válida; lag sigue pendiente. No cambiar compositor/paquetes ni repetir Intel sin validación de integración.

## Solución NVIDIA aplicada — 2026-10-12

Se extraen32 archivos gráficos del paquete local nvidia-utils615.71.09 a ~/.local/share/isla/nvidia-compat/615.71.09 (207MiB), sin cambiar paquetes/módulos/compositor. NVML aislado responde GTX1660Ti615.71.09; EGL Wayland NVIDIA. ProbeWindow visible, captura /tmp/isla-nvidia-probe/screen.png y log run.log.

Nuevo scripts/start-isla.sh selecciona cache sólo ante mismatch del módulo y symlink EGL del sistema, verificando EGL/JSON/GBM. Hereda LD_LIBRARY_PATH existente. Coincidencia tras reboot o falta de cache conserva launch normal. Autostart y dos recovery binds llaman wrapper; IPC no cambia.

Main PID425867 confirma NVIDIA GTX1660Ti615.71.09 y sin hilos llvmpipe. Imágenes nvidia-desktop.png, nvidia-settings.png, nvidia-final.png confirman escritorio y editor visibles en DP-1. Config dirty:false antes de restart. CPU3s278.31%→46.00%, sin grabador. No benchmark FPS ni claim de240FPS sostenidos. Fixture mismo timing.qml: primer cierre evento2≤450ms, software n21 mediana20.48ms p9532.36 max34.98; NVIDIA n94 mediana4.49ms p956.71 max10.27. Son intervalos del driver de animación, no presentación física. Logs software /tmp/isla-swallow-perf/run.log y hardware nvidia-timing.log.

PASS nvidia-launcher: driver/cache ausentes, cache parcial, mismatch, matching, cambio de versión al reboot y argv; sh syntax, Lua syntax y git diffcheck. PASS settings-surface-switch13 destinos split/compact normal/reduced, log /home/zdito/.cache/codex-economy/output-yga6x2ks.log exit0. Revisión independiente sin defecto actual, refuerzo gate JSON/GBM aplicado y test repetido PASS.

Límite: no se reinició equipo ni se reparó el mismatch global de NVIDIA. Bridge local resuelve aceleración de Isla en esta sesión; paquetes instalados nuevos permanecen. Confirmación humana de fluidez pendiente.

## 2026-10-12 — Scrolling: columna fuera de vista durante cambio de workspace

Reproducción real DP-1: Zen x16 y Spotify x1913 pertenecen ambos workspace2. Cambio2→3 vacío con workspaces slide muestra Spotify casi a pantalla completa en before-100ms.png y después fondo. No traslado de ventana.

Se sustituye únicamente workspaces.style slide→slidevert en ~/.config/hypr/modules/animations.lua y se aplica con hyprctl eval hl.animation, sin reload ni restart. Velocidad3.2/serpantinum preservadas; columnas siguen horizontales. after-100ms.png muestra Zen saliendo verticalmente y fondo, sin Spotify. Ventanas permanecen workspace2 en coordenadas originales; workspace original restaurado. Lua syntax/configerrors PASS.

Es mitigación de la geometría de transición horizontal del compositor, no parche binario. No validado en otros monitores ni tras login. Capturas y copia animations.before.lua en ~/.local/state/isla-motion/2026-10-12/scrolling-workspace/. No archivo isla/hyprland.json que sobrescriba el cambio al iniciar.

## Investigación: expansión tipo Niri sin cambiar Super+Tab

Hyprland real0.56.2 efb50993780079460b0cbed1363e2166a2de1d9f, scrolling nativo, plugin cargado hyprglass0.10.0. Nativo workspaces tiene slide/slidevert/fade/slidefade; cursor zoom_factor mínimo1 no permite alejamiento. Isla Super+Tab actual conserva overview strip live.

Fuente primaria yayuuu/hyprland-scroll-overview README y docs/wiki/Dispatchers.md: plugin renderiza overview tipoNiri, escala0.5, columnas/workspaces, API Lua open/close/selection invocable desde eventos. Eso da base para transición automática, no prueba que abrir/cambiar/cerrar temporizado dé continuidad nativa. hyprpm.toml main tiene pins0.54.3–0.55.4; ningún pin0.56.2 observado. Compatibilidad build/ABI y coexistencia hyprglass no probadas. No instalado ni cargado.

Fuentes https://github.com/yayuuu/hyprland-scroll-overview y docs/wiki/Dispatchers.md. Investigación descargada /tmp/isla-scroll-overview-research/. Siguiente fase posible: comprobar build compatible aislado y renderplan sin tocar bindsSuperTab, antes de adoptar efectos en compositor.

## 2026-10-13 — Bloqueo de scrolloverview y recuperación

Prototipo extendido upstream7ff22457dc016239eff1b19c3ea57de93404b5c9: zoom-out/pan/zoom-in pasivo, retarget y getter de destino pendiente; patch scripts/scrolloverview-workspace-transition.patch y test bar/tests/workspace-motion.lua. Build v3 y pruebas nativas de destinos2/3vacío/1, cambios rápidos y reversión inicialmente PASS; evidencia ~/.local/state/isla-motion/2026-10-12/niri-transition/. Estos PASS NO certifican carga persistente.

Instalación root copió .so permanente; unload temporal respondió ok, load permanente bloqueó IPC y usuario confirmó escritorio congelado. Sin ptrace/sudo; no se pudo recuperar sin reiniciar. Usuario reinició por su cuenta. Auto-load/config plugin retirados de ~/.config/hypr/modules/workspace_motion.lua; binario movido a ~/.local/share/isla/scrolloverview/scrolloverview.pending.so. Entry point hyprland.lua restaurado, Super+Tab intacto, rueda usa fallback nativo, slidevert permanece. Comprobación tras reinicio: IPC responde, sólo hyprglass0.10.0 cargado, configerrors vacío. Lua workspace-motion PASS. Tarea incompleta; causa del bloqueo de recarga no demostrada. No volver a cargar en sesión activa antes de resolver y aislar riesgo.

## 2026-10-13 — Overview manual Niri y rediseño de bloqueo (en curso)

Nueva autorización: Super+Tab vista manual Niri; Super+Shift+Tab overviewQS. Ya no se requiere zoom automático al cambiar workspace. Aceptación: plugin compatible probado en compositor aislado, carga segura sin bloquear host; teclas separadas y navegación/cierre; bloqueo con tipografía y material coherentes, entrada/error/success/media/keyboard/reducedMotion y QA Wayland. Agente workspace_transition posee integración plugin/binds; swallow_review posee componentes LockSurface/Glass/Media/Button; coordinador backend/QA/métrica/integración.

Baseline bloqueo NVIDIA615.78.08 kernel y userspace coinciden. Launcher test PASS; motion PASS. Capturas ~/.local/state/isla-motion/2026-10-13/lockscreen/before/. Fixture nuevo performance doce ciclos:1176 intervalos mediana4ms,p955,max7; intervalo de driver, no FPS físicos. Plugin host permanece desactivado hasta prueba aislada.

### Cierre de ambas tareas

Implementación manual terminada y activa: stock scrolloverview, loader externo de startup, rutas ordenadas Niri/Isla, fallback únicamente cuando falta plugin. Host aprobado tras prueba anidada; seis ciclos, ocho toggles, Escape/Return, navegación y asignación de clientes PASS. Revisión independiente P2 clic con Super sostenida corregida con ignore_mods=true; recarga de configuración sin errores ni descarga de plugin. Tests Lua/loader/rutas PASS logs output-a8w871u_ y output-r7zsyyoq. Inyección virtual no certifica atajos físicos; registro64/65 y universal verificados.

Bloqueo rediseñado y validado nativo: jerarquía tipográfica, fecha española, acceso central, media ancho/estrecho y material coherente sin blur redundante. Entradas interrumpidas, escritura/selección, errores, success/reducedMotion y escala1.75 PASS. Wallpaper blanco QA legible. Grabación detectó dots/placeholder al vaciar, corregido y regression typing+motion PASS; captura final after/final/04-rejected.png limpia. Perf antes/después mediana4ms p955 max7, intervalos driver no FPS; no ganancia medida afirmada. Backend PAM/session-lock intacto; launcher PASS.

Estado final compositor responde, submap default, ambos plugins cargados, overview cerrado, foco ChatGPT restaurado, compositor anidado ya no existe. Pendientes de validación real: PAM/session-lock, teclas y clic físicos, otros monitores/MPRIS/paletas, próximo login. Documentación de detalle en los dos informes anteriores.

## 2026-10-13 — Menú de energía del bloqueo

Petición: menú más fluido, opciones con iconos y microinteracciones coherentes. Cambio acotado a LockSurface: origen BottomRight del popup, reveal único para escala/opacidad y stagger derivado por fila, curvas Motion, salida corta y transición interrumpible. MotionButton expresivo y MaterialIcon Lucide comparten interacción; luna/reinicio/power y check al confirmar. Descripciones, encabezado Energía, fuente Theme y ancho escalable. Base Theme.background0.94 bajo material evita contaminación visual al solapar acceso con texto1.75. Autenticación y acciones backend intactas; se conserva doble confirmación y se limpia al cerrar/restaura foco.

Nueva fixture power prueba frames intermedios, settle, close/reopen, foco de contraseña, guardas de reboot/poweroff, señales ficticias, texto1.75 y reduceMotion. PASS output-rj5s5y9z; core PASS output-oig_p5qs, motion PASS output-ht53955e. Primer reintento ajustó espera de fixture (240ms no bastan para transición350ms), sin cambiar el motor. Qt6 lint exit0 output-ncokberi con advertencias de contexto exterior; binario qmllint por defecto Qt5 incompatible, no válido para esta verificación. diffcheck PASS.

QA Wayland capturas 02-open/03-confirmation/04-large-text inspeccionadas; grabación nativa3.65s native.mkv en ~/.local/state/isla-motion/2026-10-13/lockscreen-power/. No medidaFPS ni acciones de energía reales ni bloqueo real. Ventanas fixture/grabador cerrados y foco ChatGPT restaurado. Disponible en próximo bloqueo, sin reiniciar compositor.

## 2026-10-13 — Evitar retorno de columna por hover

Usuario quiere conservar navegación lateral y tamaños alternables con Super+P, pero sin que pasar el mouse a otra app devuelva la vista. Causa configurada: input.follow_mouse=1 cambia foco por hover y scrolling.follow_focus=true sigue ese foco. Cambio mínimo input.follow_mouse=2 en ~/.config/hypr/modules/input.lua y aplicado con hl.config live, sin reload/plugins/restart. Según documentación oficial separa foco del puntero/teclado; clic cambia foco. Scrolling.follow_focus y anchos existentes/bind Super+P intactos.

Validación getoption=2, Lua syntax y configerrors vacío. Prueba host con Zen: tres warps nativos por bordes/centro del monitor preservan ventana activa y tamaños de todos los clientes; evidencia ~/.local/state/isla-motion/2026-10-13/click-focus/result.json. Foco y cursor originales restaurados. Sin clics reales/inyección de contenido ni resize de apps del usuario; prueba de cursor IPC no garantiza todo gesto físico. Referencia https://wiki.hypr.land/Configuring/Basics/Variables/ y skill local variables.md follow mouse.

## 2026-10-13 — Entrada de ventanas como lámina

Cambio autorizado de prueba: ~/.config/hypr/modules/animations.lua windowsIn a slide right, velocidad3.6 (360ms), curva softFluid existente sin overshoot. Antes popin94%,260ms serpantinum. Sólo apertura: reflow windowsMove springSmooth y workspaces slidevert conservados. Aplicado vía hl.animation live sin configreload/pluginreload. Documento oficial https://wiki.hypr.land/configuring/core/animations/ confirma slide y dirección forzada.

QA host Kitty clase isla-sheet-qa, captura nativa opening/settled y grabación native.mkv+entry-frame.png en ~/.local/state/isla-motion/2026-10-13/window-sheet/. Prueba PASS cliente visible y cierre, mismos clientes/workspaces después, foco original restaurado. Opening.png precedió mapping del terminal; entry-frame del video y settled evidencian nueva columna/posición final. Registro runtime windowsIn slide right softFluid3.6; Lua syntax/configerrors vacío. Sin medidaFPS ni coordinación personalizada de columnas: se usa animación nativa del compositor.

