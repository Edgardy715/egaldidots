# Gota de grabación izquierda · 2026-10-21

Petición: separar el estado de grabación de la pill principal, como la música, en el lado izquierdo.

## Resultado

FluidRecordingCompanion reutiliza el motor FluidCompanion (resortes, nacimiento, cuello, separación, retorno y absorción). Recibe datos por propiedades; el overlay conecta Recording y navegación. Símbolo de estado + tiempo, pausa/arranque/cuenta atrás/guardado e incertidumbre; al pulsar abre controles. El texto sólo se revela al caber. No reloj nuevo, proceso, sondeo o animación decorativa permanente.

La música conserva su lado derecho. Funciona en split y compact; compact centra la gota de38px respecto a barra56px. Nuevo compactY conserva bodyY por defecto en el motor; hoverWidth/nombre accesible conservan defaults multimedia.

La propiedad recordingDetached evita duplicar REC en el header durante salida, estancia y retorno. Si no cabe a la izquierda (incluidos workspaces), o sesión/settings requieren ese espacio, la gota se absorbe y el estado queda en la pill. Sesión espera a absorción antes de salir por el mismo lado. Fullscreen conserva política existente de ocultar overlay; cambiar layout absorbe antes de intercambiar. Región de entrada sigue visualX/yPos reales; hover no activa máscara completa ni foco de teclado.

## Requisito → evidencia

- Separación física y click → recording-drop-regression Wayland PASS: geometría izquierda, mouseClick real QtTest abre ruta Recording y música forzada a derecha sin cambiar reproducción del usuario.
- Estados/propiedad única → misma fixture: recording, paused, starting, countdown, stopping, unknown; header fallback, absorción final, retorno interrumpido conserva posición/velocidad, reduced.
- Integración → split/compact con centro vertical, sesión/settings, fullscreen simulado y espacio estrecho forzado PASS. OverlayInputPolicy unit offscreen PASS: límites visuales y liberación de input.
- Compatibilidad → media-motion y session-companion offscreen PASS con defaults; recording-integration offscreen PASS en pill sin host (fallback); verify-config y límites de presentación PASS, qmllint sin diagnósticos y diffcheck PASS.
- Revisión independiente sin defectos sustentados; incluye ajuste final de compactY y revelado por ancho.
- QA visual: capturas QML nativas de estados simulados, nacimiento/retorno160ms, split con música, compact, pausa y desconexión. native-compositor.png es captura grim del resultado compuesto y confirma bordes suaves. grabToImage de superficies con efectos muestra contornos blancos/rosas corruptos (también música); esas capturas sirven para geometría/estados, no color final del borde.

Log final integración: ~/.cache/codex-economy/output-_g3214tf.log. No se inició grabador ni se capturó audio/escritorio como vídeo. Fuente de estado simulada aislada, no servicio de producción. Sin medición de FPS/energía ni multimonitor físico; no garantiza continuidad fotograma a fotograma. Capturas permiten inspección acotada y pruebas verifican invariantes. Valoración perceptual del usuario pendiente.
