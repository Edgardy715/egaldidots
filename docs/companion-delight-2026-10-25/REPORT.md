# Compañero: tacto e historia · 2026-10-25

## Plan y resultado

Primera fase de las ideas propuestas, completada: (1) superficie que responde al roce, (2) una historia breve e interrumpible, (3) pruebas nativas e invariantes y revisión independiente. Se conserva el personaje vectorial actual; sin nuevas dependencias, ajustes, servicios ni loops idle. Cambios previos ajenos conservados; sin commit/push.

- Ojos y placa comparten la presión suavizada existente: escala horizontal hasta0.92, vertical1.08, desplazamiento lateral máximo1.1s y vertical0.8s, radio/luz local. La liberación vuelve al reposo; target y ancho del chip siguen fijos. Seguimiento desactivado conserva presión sin desplazamiento lateral.
- Cuarto clic dentro de la secuencia existente (cada intervalo<1.1s) inicia `holdSneeze`: anticipación, contener el estornudo y guiño, 1.74s. También sustituye el estornudo en la oportunidad existente de travesura (sin aumentar frecuencia). Acercamiento, roce, otro gesto y estados de ocultación/reduced/suspensión/bloqueo cancelan la escena. Dormir la sustituye por el bostezo previsto.
- Revisión detectó sonrisa heredada del tercer clic que tapaba la anticipación; corregida deteniendo cheerHold y cheerful. Test reproduce los cuatro clics y comprueba que los párpados se ven durante anticipación. Segunda revisión sin nuevos hallazgos; detalles en independent-review.md.

## Validación

| Evidencia | Resultado |
|---|---|
| `ISLA_CONFIG=<temporal> QT_QPA_PLATFORM=offscreen timeout 45s quickshell -p bar/companion-delight-regression.qml` | PASS explícito: fases, tres interrupciones, cancelación, escalas1/1.5/3, límites de placa, layout y opt-out; offscreen-result.txt |
| `python docs/companion-delight-2026-10-25/capture.py` | PASS Wayland y seis capturas nativas; wayland-result.txt. Script acotado al layout1920×1080 usado, crop de fixture |
| `ISLA_CONFIG=<temporal> QT_QPA_PLATFORM=wayland timeout 100s quickshell -p bar/personality-regression.qml` | PASS explícito, clic/teclado, momentos finitos, reduced, visibilidad y opt-out; personality-result.txt |
| `ISLA_CONFIG=<temporal> QT_QPA_PLATFORM=offscreen timeout 50s quickshell -p bar/companion-continuity-regression.qml` | PASS; continuity-result.txt |
| `sh bar/tests/verify-config.sh` | PASS; config-result.txt |
| `qmllint` sobre seis QML afectados | Exit255 sin diagnóstico, limitación conocida del sistema; NO es PASS. Carga real de componentes y pruebas anteriores sí verificada |
| `git diff --check` de archivos afectados | PASS |
| `quickshell -p /home/zdito/.config/quickshell/bar ipc call island reload` | true; Configuration Loaded sin errores de carga en cola inspeccionada, live-reload.txt |

El primer test nativo falló por exigir touch>0.3 a140ms; valor observado0.2685, target0.72 e interactive=true. Se exige ahora progreso>0.15, deformación y asentamiento posterior, sin depender de un fotograma preciso. Se eliminó además una advertencia del fixture de personalidad debida a reactAtNight ausente en opciones de prueba. Persisten avisos de foco textinput/seguimiento de workspace del entorno de pruebas, sin FAIL.

Capturas inspeccionadas: [roce](touch-left.png), [anticipación desde cuatro clics](anticipation.png), [guiño](relief.png). También reposo, roce a derecha y asentamiento. Escala real s1 y ampliaciones1.5/3; superficie discreta sin recorte visible. Capturas de fases no equivalen a análisis de todos los fotogramas ni medición de FPS.

## Límites

Prototipo: falta valoración con ratón físico, tema claro y sesión larga. Interacciones de pruebas sintetizadas; no se alteraron música, grabación ni workspace. Las demás ideas propuestas (luciérnaga, aprendizaje persistente, continuidad de personaje entre surfaces y memoria larga) quedan fuera de esta primera fase.

Diff contra el estado inmediatamente anterior en change.patch; sources.json identifica los archivos finales. No se toma el diff completo de git como propio.
