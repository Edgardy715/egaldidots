# Portal de actualizaciones · 2026-10-29

Edots → Actualizaciones reúne oficiales CachyOS, AUR (paru), Flatpak opcional e
Isla desde upstream Git. El usuario pidió cobertura general; las apps instaladas
manualmente o con actualizador propio se indican fuera de cobertura.

Consulta al iniciar (45 s) y cada seis horas, con control para desactivarla y
otro para avisos. Los resultados parciales conservan fuentes válidas. El aviso
respeta DND/centro abierto y no se repite para la misma huella durante 24 h,
incluso tras reiniciar. Su acción local identificada abre el portal también
cuando se restaura del historial.

Instalaciones mediante Kitty --hold con confirmaciones nativas; la UI sólo
confirma apertura de terminal. Bloqueo flock de consultas/instalaciones del
puente, timeout 45 s por comando de consulta (secuenciales), argumentos fijos.
Git exige upstream, árbol limpio y sin commits locales, ff-only; no hace stash
ni reset. No se instalaron actualizaciones reales. La finalización en terminal
requiere Comprobar manualmente; Isla puede requerir reinicio.

## Evidencia

- `sh bar/tests/verify-config.sh`: PASS esquema/defaults/catálogo/fronteras.
- `python bar/tests/system-updates.py`: 10 PASS, PATH simulado y Git temporales:
  códigos, errores parciales, timeout, concurrencia, limpio/sucio/divergido,
  lanzamiento sin instalación.
- `python bar/tests/settings-integration.py`: PASS, incluye preferencias de
  actualizaciones guardadas/descartadas en config temporal.
- `python bar/tests/updates-service.py`: PASS en dos procesos con mocks:
  parcial, avisos, dedupe persistido, acción, bridge; prueba lógica offscreen.
- `python bar/tests/updates-notice.py`: PASS con Notifs real, bus privado,
  estado temporal, DND/centro y acción restaurada después de reinicio.
  Log recuperable output-q43zyyr3.log, PASS líneas 82 y 176.
- `python bar/tests/updates-ui.py`: PASS Wayland 1000×700 y 640×560, fuentes
  1/1.75; navegación, búsqueda, acciones, error/busy, protecciones, scroll y
  toggle con discard. Capturas inspeccionadas: portal.png, compact-175.png.
- `python bar/tests/settings-ux.py`: PASS navegación y geometría existentes.
- Consulta real IPC: oficiales 0, AUR 4, Flatpak ausente, Isla 11 commits locales
  sin subir y árbol sucio (bloqueada). Apertura IPC y portal real comprobados
  mediante captura Wayland. No se conserva captura del escritorio personal.
- Diff-check acotado PASS; árbol previo con muchas modificaciones preservado.

Revisión independiente Sol medium: un P2 (acción restaurada sin efecto) corregido
mediante identidad local persistida, regresión real añadida y segunda revisión
sin hallazgos nuevos. Claude CLI intentado primero según skill pareja, sin sesión
(`Not logged in`); revisor disponible sustituyó esa revisión, no se simula Claude.

Límites: no prueba de instalación real ni medidas de progreso en terminal; sin
certificar plataformas distintas de CachyOS/Arch o apps externas a esos gestores.
La captura compacta al 175% necesita scroll para acceder al contenido extenso.

## Pulido y comprobación de movimiento · 2026-10-29

La lista de paquetes despliega altura y opacidad con SmoothedAnimation del
proyecto, conserva geometría al invertir y resuelve inmediatamente al ocultar
la página/ventana o activar movimiento reducido. El indicador de consulta gira
sólo visible y durante una consulta; se detiene oculto y con movimiento reducido.
La cabecera usa AnimatedLabel y distingue consulta, apertura de terminal,
pendientes, éxito y errores parciales. No presenta una consulta incompleta como
equipo al día. El servicio también rechaza instalar fuentes sin pendientes, con
error o una shell con cambios locales, además de la protección en UI/helper.

Evidencia nueva, fuentes actuales:

- `ISLA_TEST_OUTPUT=/tmp/isla-updates-polish python bar/tests/updates-ui.py`: PASS
  Wayland; cuatro combinaciones tamaño/fuente, acciones, navegación/búsqueda,
  estados intermedios de abrir/cerrar, inversión rápida, reduceMotion en vuelo,
  ocultar página/Window y navegación interrumpida con movimiento habilitado.
  Log `output-p3nmc1de.log`; sin errores QML ni avisos del nuevo movimiento.
- `python bar/tests/updates-service.py`: PASS dos procesos aislados; nuevas
  guardias, JSON inválido/error del proceso, conservar resultado conocido y
  recuperación posterior. Log `output-4eisfps0.log`; offscreen sólo lógica.
- Compilación Python y diff-check acotado PASS. qmllint devolvió 255 sin
  diagnóstico en estos archivos; no se cuenta como pase. Carga QML nativa PASS.
- Consulta y apertura IPC en la shell real: oficiales0/AUR4/Flatpak ausente;
  Git local bloqueado. Captura con grim inspeccionada, no archivada por contener
  escritorio personal. Cierre del portal al terminar. No instalaciones reales.
- Revisión independiente de interacción/estados y cinco capturas: sin hallazgos
  verificables. El último caso pendiente de ocultar Window se resolvió mediante
  la regresión Wayland final. Claude sigue sin sesión; revisión nativa Sol medium.

Capturas de fixture inspeccionadas: `polish-opening.png`, `polish-expanded.png`,
`polish-checking.png`, `polish-partial-error.png`, `polish-compact-175.png`.
Son muestras intermedias y finales; no equivalen a medición de FPS ni validación
de cada cuadro. Las confirmaciones/instalación real siguen pendientes del usuario.

Memoria sincronizada: `python tools/brain.py` PASS (2294 fichas, 255 carpetas,
934 fuentes), log `output-ew4xbpds.log`.
