# Configuración, música y continuidad entre superficies

Petición: mantener el contexto musical al abrir Configuración, mejorar su salida hacia otros paneles e incluir música en el calendario. Aplicada UI/UX Pro Max sobre la arquitectura QML existente; sin motor de animación ni ajustes nuevos.

## Comportamiento

- Settings abre directamente sin absorber media. En split conserva la gota; en compact conserva el resumen del cuerpo en reposo.
- Al reemplazar Settings, la pill permanece en reposo mientras su companion termina el retorno. Luego despliega la ruta vigente. Media y Session también esperan; un retarget a Settings cancela el retorno sin perder el editor.
- Auth aparece inmediatamente por encima de Settings (z5 frente a z4), con el editor saliente deshabilitado.
- Calendar recibe metadatos desde composición Players, reutiliza IslandMediaSummary y conserva el pie musical fuera del scroll del clima. Pausa mantiene el resumen; desaparición lo retira. La fila abre Media mediante requestPage, con feedback/foco/Accessible de MotionArea. La gota externa se absorbe al desplegar el calendario para evitar duplicación.

## Evidencia

- `routing.log`: composición IslandOverlay real en Wayland, Players simulado sólo en copia temporal. Split/compact × normal/reduced; Settings conserva música, salida escalonada hacia calendar/media/session, vuelta durante retorno, prioridad visual Auth sin PAM, clic Calendar→Media, pausa y desaparición.
- `focus.log`: 13 destinos, selector de archivos/fuentes, borrador retenido, foco/teclado y Ctrl+S oculto, retarget rápido en los cuatro modos.
- `native-input.log`: wtype entrega Escape y libera teclado en 14 superficies sin Auth.
- `calendar.log`: pie fijo al hacer scroll, metadata larga, clic, retirada, fontScale1.75 y reduced. La fixture usa dimensiones reales del panel; sus nombres split/compact comparten la misma geometría aprobada del calendario.
- `neighbors.log`: layout routing/interruptions, Settings companion y Weather PASS.
- `config-gate.log`: límites de arquitectura y ajustes PASS. `qmllint.log`: Qt6 exit0 con avisos de accesos dinámicos/unqualified existentes. `git diff --check` PASS.
- Cuatro capturas `*-settings-music.png`/`*-calendar-music.png`: inspección de composición QML renderizada en Wayland; fondo transparente aparece negro en estos PNG. No son capturas del escritorio completo ni análisis fotograma a fotograma.
- Revisión independiente del retorno y prioridad Auth; corregido posible solapamiento elevando Pill durante Auth.

## Límites

Música simulada, no verificado con cada reproductor MPRIS ni varios monitores. No se ejecutó PAM, bloqueo, energía ni cambios de red. Auth sólo probado en ruta/z, no autenticación real. Sin perfil de rendimiento ni certificación AT-SPI. La tanda offscreen falló en IslandOverlay por falta de backend PanelWindow (`offscreen-limit.log`); repetida correctamente en Wayland. Avisos conocidos: avatar local ausente y servidor de notificaciones ya registrado en fixtures aisladas.
