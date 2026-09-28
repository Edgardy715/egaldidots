# Solicitud de autorización

AuthSurface compone AuthPrompt con el backend Auth. La presentación recibe el
servicio por propiedad y se puede probar sin registrar Polkit ni escuchar el
socket real de askpass. No concede autorización: Polkit/PAM y sudo conservan esa
responsabilidad.

## Entrada e interacción

- TextField nativo, contraseña enmascarada sin mostrar el último carácter,
  selección por ratón, IME sensible sin predicción y prompt proporcionado por el
  flujo. responseVisible de Polkit permite respuestas no secretas cuando procede.
- Enter o botón envían una sola vez; el backend confirma que aceptó el envío.
  Campo borrado al enviar, cancelar, cambiar de flujo/cuenta, cerrar y destruir.
  El rechazo de un envío conserva la respuesta editable sólo si la petición sigue
  vigente. No se escriben respuestas en logs ni archivos de QA.
- Tab recorre campo/acción/cuentas/cancelación; Escape cierra primero el popup de
  cuentas y luego cancela la solicitud. El formulario posee el foco: sin timers
  tardíos que lo recuperen después de una interacción del usuario.
- Las notificaciones esperan durante autorización, sin descartar las pendientes
  ni suspender el foco del formulario.
- Error permite reintento inmediatamente. El banner se retira al editar; no se
  oculta el campo ni existe un timer que borre un error de una petición nueva.
- Se muestra contexto, información adicional, aviso de Bloq Mayús y selector de
  identidad cuando Polkit proporciona varias. El tooltip conserva texto largo.
- Polkit tiene prioridad cuando coincide con sudo. La confirmación se mantiene
  aunque desaparezca el flujo, antes de atender una solicitud sudo pendiente.

## Movimiento y composición

La isla conserva reloj, material y motor de morph. Auth añade ancho400×s y altura
mínima82×s, adaptada a fontScale. Un campo44 y línea de contexto forman el único
bloque de interacción; acción y cancelación conservan sus hit targets.

El contenido depende de la geometría disponible y se revela sólo en los últimos
24×s de anchura. No se dibuja sobre el reloj al abrir/cerrar. Rechazo mueve el
campo entero -4/+3/0, sin separar texto, placeholder e iconos. Éxito cambia el
candado y dibuja el check. BusyIndicator sólo trabaja durante verificación visible;
reduceMotion usa indicador estático y elimina recoil/traslado.

Auth.presenting retiene la confirmación. La composición fija duraciones según
Motion: mínimo750ms Polkit/1100ms sudo, o220ms en reduced motion. Se amplían con
motionScale para no cerrar antes de que el feedback sea legible. Las solicitudes
nuevas/cancelaciones detienen los tiempos anteriores.

## Backend

Polkit bloquea doble envío y respuestas fuera de una conversación activa. Los
estados submitting/error/success se limpian al cambiar identidad o flujo. Sudo
valida mensajes, ID, resultado entero0..255, socket vivo y respuesta de una sola
línea. Ignora duplicados y resultados previos al envío o pertenecientes a otro ID.
La desconexión no borra la confirmación final; espera hasta120s un resultado
tracked pendiente. sudoCanRespond distingue retry vivo de fallo final sin socket.

El listener tiene identidad estable para la recarga. `island.reload` utiliza
`Quickshell.reload(false)` para traspasar recursos antes de destruir la generación
anterior. La recarga hard abría el servidor nuevo antes de destruir el viejo;
su limpieza podía borrar el archivo del socket nuevo aunque siguiera escuchando.
No basta comprobar Polkit registrado: también hay que conectar al socket.

## Validación

```sh
python bar/tests/auth-backend.py
QT_QPA_PLATFORM=wayland timeout 12s quickshell -p bar/auth-prompt-regression.qml
QT_QPA_PLATFORM=offscreen timeout 8s quickshell -p bar/motion-regression.qml
QT_QPA_PLATFORM=offscreen timeout 8s quickshell -p bar/surface-router-regression.qml
QT_QPA_PLATFORM=offscreen timeout 8s quickshell -p bar/notification-regression.qml
```

Exigir PASS y ausencia de FAIL. Backend usa una copia temporal del componente con
Polkit fake y SocketServer inactivo; asserts verifican aislamiento. La regresión
UI usa servicio falso: máscara, foco, Enter, double-submit, rechazo de envío,
reintento inmediato, Tab, popup/Escape, cuentas, responseVisible, prioridad,
éxito, cierre/reapertura, sudo y reduceMotion. FrameAnimation existe sólo en la
fixture y verifica que contenido visible disponga del ancho requerido. Capturas
`/tmp/isla-auth-*.png`; ISLA_AUTH_SHOTS cambia el prefijo.

QA Wayland con material nativo y paleta actual; variante clara con fuente1.75 y
motionScale2 usa ISLA_CONFIG temporal. Esto comprueba UI y contrato, no sustituye
la autenticación real de una operación del usuario ni mide FPS de todo el shell.
Referencia API: [AuthFlow de Quickshell](https://quickshell.org/docs/v0.3.0/types/Quickshell.Services.Polkit/AuthFlow/).


## Puente de terminal e instalación

El paquete Stow `fish` instala `fish/.local/bin/isla-sudo-askpass` como
`~/.local/bin/isla-sudo-askpass` y el wrapper en `~/.config/fish/config.fish`.
Abrir Fish de nuevo después de instalar; la shell Isla debe estar en ejecución
para atender solicitudes. No se modifica la política de sudo ni PAM.

El helper `~/.local/bin/isla-sudo-askpass` usa el prompt argv[1] que proporciona
sudo, con SUDO_PROMPT como fallback. El wrapper de `~/.config/fish/config.fish`
conserva askpass para comandos y opciones normales; omite añadir -A ante stdin o
askpass explícitos, considerando sólo opciones anteriores al comando (incluidos
clusters y valores), y respeta --. El preflight tracked continúa limitado a
comandos ordinarios: resultado de `sudo -A -v`, nunca resultado del comando final.
`sudo -S` conserva stdin y `sudo pacman -S ...` conserva el prompt de Isla.

`python bar/tests/auth-bridge.py` comprueba el helper con socket temporal y el
wrapper con ejecutables falsos. No ejecuta sudo real. Backup de los dos archivos:
`~/.local/state/quickshell-backups/auth-bridge-u0asow7q/`. Terminales fish existentes
necesitan sesión nueva o recarga de su función; no se inyectan comandos en ellos.

Si el helper no puede conectar, explica en stderr que el formulario no está
disponible; stdout queda vacío. Cancelar sigue siendo silencioso. No incluye
respuestas ni detalles de la solicitud en el diagnóstico.

`python bar/tests/auth-transport.py` requiere Wayland y arranca una copia de Auth
con Polkit falso y un socket en runtime temporal. Ejecuta el mismo método de
recarga de shell.qml y comprueba entrega de una respuesta simulada al arrancar y
tras cuatro recargas. No registra un agente ni toca el socket del escritorio.
