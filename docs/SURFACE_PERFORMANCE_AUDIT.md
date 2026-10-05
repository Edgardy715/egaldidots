# Auditoría de surfaces · 2026-10-04

## Medición

Hyprland, DP-1 1920×1080 a 239.964 Hz, escala1, movimiento reducido desactivado.
FrameAnimation temporal midió intervalos QML durante 1.3s de cada apertura.
Instrumentación retirada al terminar; bar/shell.qml sin cambios. Los intervalos
no equivalen a FPS presentado por la GPU. Capturas grim son muestras irregulares.

| Surface | Máximo anterior ms | Máximo Loader asíncrono ms | p95 posterior ms |
| --- | ---: | ---: | ---: |
| calendar | 48.94 | 13.68 | 4.73 |
| connectivity | 64.10 | 4.93 | 4.54 |
| overview | 53.43 | 10.24 | 4.68 |
| notifs | 106.69 | 10.17 | 8.04 |
| mixer | 15.38 | 4.98 | 4.54 |
| media | 67.09 | 5.68 | 4.64 |
| wallpaper | 58.64 | 10.28 | 5.53 |
| clipboard | 20.37 | 5.94 | 4.64 |
| utils | 30.28 | 6.31 | 4.75 |
| workspaces | 23.54 | 8.60 | 4.63 |
| launcher | 18.56 | 7.14 | 4.59 |
| session | 29.39 | 10.11 | 6.79 |
| appearance | 10.13 | 8.70 | 7.04 |

Ninguna de las13 aperturas posteriores superó16.67ms en esa pasada. Notifs se
virtualizó con ListView: dos repeticiones posteriores p95 4.85/4.71ms y máximos
12.26/10.35ms frente p95 8.04ms previo. Secuencias rápidas interrumpidas:
máximos20.22/10.95ms; primera con una pausa>16.67ms, segunda sin ninguna.
No se garantiza240FPS ni se atribuye toda variabilidad al render de Isla.

## Cambios

Loader asíncrono en PillSurfaceHost; notificaciones crea sólo tarjetas visibles;
pulso infinito de reposo retirado; consumidor CAVA compacto limitado a visibilidad.
Clipboard: procesos asíncronos, texto legible/PlainText, filtro/selección correctos,
foco exclusivo, errores/estado vacío, copia de bytes exactos. Super+V en binding
Lua activo y paquete legacy. Miniaturas y vista seleccionada con magick, caché
privada temporal eliminada al descargar. Botón Limpiar todo ejecuta cliphist wipe
asíncrono, evita dobles ejecuciones/copia concurrente; sólo vacía lista tras éxito,
y conserva entradas con aviso si falla. No borra el contenido activo de wl-copy.

## Validación y límites

Las13 surfaces se abrieron y revisaron en Wayland; clipboard con teclado,
miniaturas/vista seleccionada y botón inspeccionados. Clipboard fixture verifica
copia exacta texto/PNG, previews, borrado lento sin bloquear frames, fallo y doble
clic; cliphist wipe también probado con base de datos aislada. Historial real
conservado durante QA del botón. No se ejecutaron acciones de energía ni PAM real.

Regresiones aprobadas: motion, interaction-surfaces, clipboard, absorption240Hz,
media-session, media-motion, notification, interaction, surface-router, status,
battery-indicator, auth-prompt, lockscreen, lockscreen-motion, session,
session-companion, wallpaper, overview y top-workspace-motion. Fixture de
lockscreen-motion corregida para activar entrada desde el reposo actual.

Sin MPRIS/streams de aplicaciones ni WiFi activo; brillo/perfiles no disponibles.
Música real, PAM y multimonitor no certificados. CPU reposo ruidosa: no se afirma
ahorro porcentual. Persisten avisos previos de avatar/iconos/imagen ausentes.
Qt6 qmllint: sin errores de sintaxis en archivos revisados, con avisos de tipos
Quickshell/referencias sin calificar; /usr/bin/qmllint es Qt5 y no valida este QML.
JSON y capturas temporales: /tmp/isla-surface-audit-20261004/.

## Microinteracciones añadidas

Retirada breve antes de estado vacío, respuesta de clic común, etiquetas discretas,
metadatos y confirmaciones de sesión animados. Listas nativas con identidad y
transiciones evitan el salto al recolocar. Fixtures comprueban interrupciones,
ocultación y movimiento reducido en Wayland. No se repitió el perfil de13 aperturas
tras esta fase: las métricas anteriores corresponden a la optimización del Loader.
