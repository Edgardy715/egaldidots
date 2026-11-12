# Cuerpo · Fase 4 · 2026-10-30

Aplicada por petición «Pasa a la fase 4». Fuentes elegidas por el usuario: capturas y grabaciones de Isla.

## Resultado

- Cuerpo recibe hora local, energía de Cava al reproducir, foco/código/FocusSession, inactividad, horario nocturno y reacciones breves a eventos de sistema/notificaciones/grabación. Cava usa consumidor por monitor sólo cuando el cuerpo está expuesto. Política en BodyEvents, servicios en composición.
- Ajustes → Cuerpo reúne activación, respiración (default false), gota de archivos y reacciones. Opciones del rostro anterior sin implementación quedan inactivas; formato de configuración conservado. Respiración de producción limitada a 1.1 px, reloj 33 ms y suspensión existente con reduceMotion/oculto.
- Recording.saved y capturas realmente guardadas en Satty ofrecen una ruta al monitor enfocado. Screenshot hook externo: `/home/zdito/.config/hypr/scripts/screenshot-annotate.sh`; copia anterior junto a este informe. Se notifica tras cerrar Satty; copiar al portapapeles sin guardar no ofrece archivo.
- Mensajero reutiliza el motor/SDF; viewport completo sólo durante viajes. Guardado usa shader local y botón separado bajo el reloj con tooltip y nombre accesible. Input limitado al botón. Un archivo pendiente por monitor; nuevas ofertas mientras ocupado se descartan. Se conserva al ocultar/abrir surfaces durante la sesión. No mueve, borra ni persiste el archivo pendiente tras reiniciar la shell.
- Abrir requiere clic explícito o comando `qs ipc -p ~/.config/quickshell/bar/shell.qml call island bodyOpen` para configurar un atajo. No se añadió un atajo global. Se abre vía argv literal de xdg-open, sin shell.

## Evidencia

- PASS: Node brain/drop/file, límite de respiración, rutas/URL/controles y argv literal.
- PASS: BodyEvents; BodyPill RHI offscreen y Wayland (reloj, foco, eventos, música, toggles, geometría, handoff, interrupción, oculto, accesibilidad).
- PASS: mensajero Qt con abridor falso: clic real/Enter en fixture, activación única, suspensión, ofertas ocultas, reduceMotion, rutas con espacios y caracteres shell, shader sólo de viaje.
- PASS: config, settings UX/motion, composición y política de input. qmllint exit0, advertencias existentes de composición/unqualified y PanelWindow. Logs adjuntos.
- Hook de capturas probado con herramientas simuladas: clipboard-only sin callback; guardado ofrece un archivo existente y ruta literal. `bash -n` PASS.
- QA nativa de producción en Wayland (1920×1080): archivo PNG real ofrecido mediante IPC, recogida, estado guardado y apertura de calendario inspeccionados; capturas native-*.png. IPC bodyOpen sin archivo comprobado (no abre nada). Shell reiniciada con ajustes originales sin dirty y archivo de prueba retirado mediante reload; no se abrió archivo real. La entrega se probó con abridor falso.
- Revisión independiente Sol/medium, incluida optimización del shader y ruta de teclado: sin hallazgos materiales. Claude CLI intentado en modo lectura falló «Not logged in»; no se afirmó revisión Claude.

## Límites y siguiente fase

Fase 5 pendiente: vídeo continuo/QA temporal extensa, interrupciones nativas de entrega, tema claro, multimonitor y bloqueo. No se ha probado grabación real de usuario ni guardado manual en Satty en esta sesión (se verificó señal/conexión y hook simulado). La prueba de teclado del fixture y el comando explícito no acreditan un atajo global configurado. Offscreen no se considera QA visual. Cambios ajenos conservados; sin commit/push.
