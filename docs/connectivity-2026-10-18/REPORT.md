# Conectividad · rediseño 2026-10-18

El usuario pide composición/UI/UX a la altura de media y bloqueo; confirma dos
vistas dentro de Conectividad. Se conserva el sistema visual Isla, sus servicios,
el material y el motor compartido. Valoración perceptual del usuario pendiente.

## Resultado

- Cuerpo460×520, con altura adicional para fuente grande, frente360×400 anterior.
- Cabecera única, selector Wi-Fi/Bluetooth con estado, control de radio claro.
- Red actual destacada y otras redes ordenadas por señal, sin límite arbitrario8.
- Bluetooth con nombre/estado arriba y acciones debajo, sin reducir nombre para
  encajar botones. Batería y conexión/transición visibles; conserva filtro BLE.
- Cambio de vista retira antes de sustituir, retargetea al último destino,
  resuelve al ocultar/reduced, reinicia scroll. Loops sólo para trabajo visible.
- Lista con scrollbar discreta; Tab/ShiftTab revelan el control enfocado.
- Credenciales con texto más legible, colores Theme, secreto limpio al enviar,
  estados error/busy/success y foco al entrar.

## Evidencia por requisito

| Requisito | Evidencia | Estado |
| --- | --- | --- |
| Dos vistas, jerarquía y nombres legibles | 01-wifi,04-bluetooth,07-large-text,host-split/compact PNG | QA Wayland y revisión independiente |
| Acciones existentes | connectivity-design-regression.qml: toggle,scan,disconnect,connect,pair,forget y payloads mock | PASS Wayland |
| Transición/interrupción/reapertura/reduced | Fixture diseño y connectivity-host-regression.qml; muestras03-switch/12-reduced-reopen | PASS invariantes; no FPS |
| Teclado y scroll | Tab/ShiftTab sin expose hasta último dispositivo; Space activa acción,07b-keyboard-last-device | PASS Wayland; hallazgo revisado cerrado |
| Credenciales | Envío limpia secreto; busy deshabilita input;08–11 PNG; textbox-motion-regression.qml | PASS |
| Host | Geometría460×520, split/compact, reapertura interrumpida, descarga | PASS Wayland |
| Compatibilidad | connectivity-surface-regression.qml, verify-config.sh, qmllintQt6, git diff--check | PASS |

Logs originales de esta sesión en cache output: diseño `_ehh3xua`, host
`aa9dlena`, input `cigbi3rb`, compatibilidad `69xdxmqp`, gate `zo2b4er2`, lint
`ggd66oyh` (todos output-*.log). Los fixtures usan ISLA_CONFIG temporal y mocks
para acciones; host sólo lee servicios existentes. Se exige línea PASS, no sólo
exit0, porque QtTest/Quickshell puede finalizar sin mostrar fallo por defecto.

Revisión independiente agency_ui_reviewer/Sol medium: composición/estados
coherentes. Encontró P2 foco recortado; corrección central ligada al foco de la
ventana y prueba sin scroll manual. Verdict posterior: hallazgo resuelto, ship
al alcance de corrección; sin ampliar a certificación universal.

## Contrato visual y documentación

DIRECTION.md registra el contrato local. Es extensión de Theme/Matugen y motor
Isla, no una sustitución del sistema global; DESIGN.md raíz conserva autoridad.
Sin detector web: no emite veredicto útil sobre QML nativo. Capturas propias
Wayland de fixtures; no assets raster nuevos distribuidos con el producto.

## Límites

Sin conexiones reales, cambios de radios, pairing BlueZ ni contraseñas personales;
sin FPS/GPU, grabación continua de todos los frames, lector de pantalla/AT-SPI o
multi-monitor físico. Fuente1/1.5 y estados representativos; no certifica toda
combinación de idioma/tipo/escala. Warnings del driver textinput Wayland al
cambiar foco de fixture, sin errores QML/binding loops en ejecución final.
Se preservaron modificaciones previas, incluida Nmcli.qml y resto de shell.
