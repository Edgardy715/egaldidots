# Grabación integrada con OBS · 2026-10-21

Actividades reúne Enfoque y Grabación. Se reutiliza el panel existente con pestañas animadas, cuenta atrás de tres segundos cancelable, botón circular que se transforma en detener y pausa/reanudación. La pill presenta REC y tiempo confirmado por OBS; pausa y desconexión tienen estados propios. Los ojos vuelven al terminar.

## Uso

OBS Studio y Python websockets >=15 están instalados en este equipo. Activa el servidor en OBS → Herramientas → Ajustes de obs-websocket. Isla lee la configuración local, incluida la autenticación, y conecta exclusivamente a 127.0.0.1. No modifica esa configuración ni muestra credenciales. Abre Grabación desde Actividades o `quickshell -p bar ipc call island recording ''`. Configura escena, fuentes y audio en OBS antes de empezar. La pausa depende de lo que permita el formato de salida de OBS.

Cerrar/cambiar de panel cancela una cuenta atrás pendiente; una grabación confirmada continúa. Cerrar Isla no detiene OBS. Ante desconexión se muestra incertidumbre: nunca se afirma que la grabación terminó. Abrir archivo sólo aparece tras una ruta confirmada por OBS y requiere acción del usuario.

## Requisitos y evidencia

- Servicio: `bar/services/obs_recording.py`, singleton `Recording.qml`; 11 pruebas Python con servidor OBS v5 simulado pasan: autenticación, comandos, eventos externos, reconexión, timeout sin reenvío, entrada inválida, EOF y carreras de pausa/inicio.
- Interfaz: `RecordingView.qml`, `ActivityView.qml`, `RecordingGlyph.qml`, Focus/RecordingSurface. Regresión nativa Wayland del panel PASS; integración con Pill PASS, incluyendo cuenta atrás cancelada por pestaña/ruta/cierre, pausa, desconexión incierta, guardado y movimiento reducido. Texto a escala1.5 cabe y se inspeccionó visualmente.
- Regresiones: FocusSession y compact-island Wayland, motion offscreen, settings-integration y verify-config PASS. Diffcheck final PASS. Personalidad/hover se comprobó en Wayland PASS; offscreen no reproduce el hover físico y falló esa aserción.
- Revisión independiente corrigió rechazo genérico de pausa que deshabilitaba controles permanentemente y cuenta atrás al abandonar pestaña. Las respuestas perdidas se reconcilian con GetRecordStatus antes de afirmar estado.
- Producción: se abrió la ruta real y se consultó IPC recording.status; interfaz cargada y servidor deshabilitado correctamente identificado. No se inició OBS ni se grabó el escritorio.

Las capturas de `captures/` y `recording-preview.png`/`pill-preview.png` usan estados simulados en QML. `live-setup.png` corresponde a la interfaz real sin conexión (antes del ajuste final de color neutro del mensaje de configuración). No son prueba de captura/encoder/audio reales. Sin medición FPS ni AT-SPI.
