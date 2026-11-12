# Correcciones de diseño y movimiento

2026-10-26. Primera fase de correcciones del análisis `docs/design-competition-2026-10-26/REPORT.md`. Se conservaron identidad, parámetros del muelle, material y cambios locales ajenos. Sin commit ni cambios de configuración personal.

## Cambios realizados

1. **Tiempo real del muelle.** `PillMorphMotion.step(dt)` ya no descarta lo que exceda 1/30 s. Integra el tiempo normalizado con subpasos de hasta 1/240 s, publica estado al terminar el cuadro y limita una suspensión larga a 2 s normalizados/480 subpasos. Conserva posición y velocidad al retarget, perfiles asimétricos y reducción de movimiento. Ignora intervalos inválidos.
2. **Escritura temprana.** `LauncherView` pide foco al cargar el campo, suprimiendo la espera `Motion.morph + 60` (480 ms con ajustes normales). Mantiene el reintento de 80 ms, condicionado a estar activo: cerrar detiene la adquisición; cancelar cierre inicia una búsqueda nueva. No se aceleró indiscriminadamente la geometría ni el material.
3. **Calendario coherente y fácil de pulsar.** Días, meses y pronóstico comparten cadenas `qsTr` con idioma fuente español, igual que los demás controles. Esto evita mezclar un locale de fechas inglés con la interfaz española y conserva el mecanismo de traducción existente. No introduce selector de idioma ni cambia el locale del sistema. Los objetivos de anterior/siguiente pasan de 28×28·s a 36×36·s, mínimo 32 px, conservando teclado y nombres accesibles.

## Evidencia

- Fallo previo reproducido: `frame-time-before.log`. Tras la corrección, `frame-time.log` pasa en escalas 0.25/1/2, 144/60/30/20/10 actualizaciones por segundo, cuadros aislados tardíos, retarget, suspensión, dt inválido y reduceMotion.
- Comparación del mismo harness histórico (`frame-step-after.log`):

| Actualizaciones simuladas/s | t90 antes → ahora | Fin de integración antes → ahora |
| --- | --- | --- |
| 60 | 267 → 267 ms | 700 → 700 ms |
| 20 | 400 → 300 ms | 1050 → 700 ms |
| 10 | 800 → 300 ms | 2100 → 700 ms |

El t90 se observa sólo al entregar cada actualización; a 10 Hz la resolución temporal es 100 ms. No son FPS medidos ni latencia física del compositor.

- PASS de `surface-materialize`, `surface-swap-close`, `content-hold`, `launcher-input-safety`, `launcher-pending` y `surface-choreography`: registros homónimos. Configuración/Iris temporales y offscreen.
- PASS nativo Wayland de `launcher-focus-regression`: escritura sin forzar foco sobre el campo, cierre sin recuperarlo, reapertura, liberación y reduceMotion. En esta ejecución: listo a 221 ms desde apertura, foco a 19 ms desde carga (`launcher-focus-native.log`). Es una muestra, no un percentil ni garantía para todas las máquinas.
- PASS de `calendar-design-regression` con LANG=en_US.UTF-8 y es_DO.UTF-8: días/meses/pronóstico, títulos, objetivos a escalas 0.8/1/1.25, clic en periferia, límites de año y Enter/Space. PASS de `calendar-data` y `weather-view`, incluidos datos inyectados, errores y texto grande en clima. Registros `calendar-*.log`, `weather-view.log`.
- PASS nativo adicional de coreografía (`native.log`). Su grabToImage opcional no produjo imágenes; no se usa como evidencia visual. Se capturó aparte con grim exclusivamente la ventana del fixture real, 1050 ms después de calendar-open. Inspección visual: fechas españolas, mes legible, botones separados y grilla/clima dentro del panel. `native/calendar.png`, contexto temporal `native-capture.log`. El fixture se cerró.
- Revisión independiente sin hallazgos: `REVIEW.md`. Claude CLI no estaba autenticado y se utilizó el revisor independiente disponible.

## Lo que no queda certificado

Estas correcciones resuelven defectos concretos de los puntos 1, 2, 4 y 5 del análisis; no convierten todas sus recomendaciones de madurez en trabajo completado. Las reglas comunes de composición entre todas las superficies, un perfil semántico de menor transparencia/alto contraste, ratios de contraste medidos, lector de pantalla, recorridos completos GTK/Qt/Electron, multimonitor y percentiles de presentación bajo carga siguen pendientes. La captura actual es oscura; no constituye una matriz de fondos/temas. El foco se probó en Window con Pill real y no certifica por sí solo la política del overlay layer-shell. No se comparó rendimiento con macOS ni se alteró compositor, wallpaper o reproducción personal.

## Reproducción

Ejecutar desde la raíz con ISLA_CONFIG e ISLA_IRIS temporales:

```
QT_QPA_PLATFORM=offscreen qs -p bar/frame-time-regression.qml
QT_QPA_PLATFORM=wayland qs -p bar/launcher-focus-regression.qml
LANG=en_US.UTF-8 QT_QPA_PLATFORM=offscreen qs -p bar/calendar-design-regression.qml
LANG=es_DO.UTF-8 QT_QPA_PLATFORM=offscreen qs -p bar/calendar-design-regression.qml
```

Exigir PASS explícito, ausencia de FAIL y exit 0; ejecutar pruebas de foco nativas en serie. `source.sha256` identifica fuentes/pruebas de esta fase; el diff completo del repositorio contiene trabajo anterior ajeno.
