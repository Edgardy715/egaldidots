# Afinado visual de grabación · 2026-10-21

El usuario confirma funcionamiento y rechaza el acabado visual. Se conserva el grabador directo, sus estados y la pill. Cambios acotados a RecordingView, subtítulo de pestaña en ActivityView y expectativas geométricas del test existente.

- Se retira el botón circular gigante y su etiqueta suelta: barra principal con símbolo disco/detener que transforma tamaño/radio; pausa secundaria compacta.
- Tiempo y estado forman un solo grupo. Audio del sistema y micrófono comparten dos filas con iconos e interruptores, sin textos Sí/No ni desaparición del grupo al comenzar. Se bloquean durante captura para representar la configuración fijada.
- Movimiento finito, targets estables, nombre accesible, teclado, foco y reduced/hidden conservados. Sin nuevos shaders, procesos, sondeos ni loops.
- Subtítulo de Grabación: Pantalla y audio; Enfoque conserva su composición.

Validación: RecordingView Wayland PASS, RecordingIntegration Wayland PASS (rutas, countdown, pill, estados, guardado y escala1.5), qmllint sin diagnósticos, verify-config y diffcheck PASS. Inspección de capturas nativas con estados simulados ready/countdown/active/stopping/large; revisión independiente sin hallazgos importantes en ready/countdown/stopping/large. No certifica FPS ni captura real. El backend no cambia y no se repitió su batería.

Las capturas de esta carpeta son fixtures QML, no grabaciones. standalone-active.png pertenece al panel aislado con ventana redimensionada por compositor; recording-active.png representa composición integrada. El usuario debe valorar esta propuesta visual; no declarada aprobada.
