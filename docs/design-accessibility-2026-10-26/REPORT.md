# Legibilidad y materiales de Isla

2026-10-26. Continuación autorizada de las recomendaciones de diseño. Cambios acotados a materiales, tinta de estados activos y ajustes; se conserva el trabajo local anterior. Sin commit/push ni modificación de la configuración personal.

## Resultado

- Edots → Apariencia incluye **Reducir transparencia**, desactivado por defecto. `Settings.js` valida el booleano; `Flags.glassAlpha` devuelve 1 mientras está activo. Isla, GlassCard, notificaciones y gotas comparten esa fuente. La opacidad elegida sigue guardada y vuelve al desactivar el ajuste. Movimiento, sombras y volumen del material se conservan.
- La tinta de selección se calcula frente a cuatro combinaciones de las caras superior/inferior del líquido y tarjeta. Se conserva una tinta semántica si alcanza el objetivo interno 4.5; en otro caso se elige la que maximiza el menor contraste entre las candidatas semánticas, negro y blanco. Sustituye el salto fijo a intensidad 0.6.
- Se corrigió además un defecto real de QML: nombres `onStateFill`/`onStateFillSecondary` se interpretaban como manejadores de señales, dejando el color negro predeterminado. Se renombraron a `stateContent`/`stateContentSecondary`, incluidos todos los consumidores del calendario, controles y Edots. La revisión independiente reprodujo el fallo.

## Comprobaciones actuales

| Comprobación | Resultado y evidencia |
| --- | --- |
| Defaults, validación, límites de composición y calculadora | PASS, `config-validation.log` |
| IPC, guardado atómico, recarga, conflictos, descarte y restauración del nuevo ajuste | PASS, `settings-integration.log`; repetida con archivos estables |
| Seis paletas Matugen reales, 71 intensidades por paleta, retención de última válida y componentes integrados | PASS, `matugen-palette-regression.log`; datos reproducibles en `palettes.json` |
| Ajustes: opción sin búsqueda, navegación, escalas 1/1.75, tamaños 1000/640, validación y foco | PASS Wayland, `settings-ux-regression.log` |
| Controles del editor | PASS Wayland, `settings-controls-regression.log` |
| Controles rápidos y calendario | PASS, registros homónimos offscreen |
| Material: activar/desactivar, opacidad guardada, descarte, layouts split/compact y editor ampliado | PASS Wayland, `native/dark.log`, `native/light.log` |
| Revisión independiente | Hallazgo de nombres QML corregido; ningún otro defecto sustentado. `REVIEW.md` |

`qmllint.log`: ocho archivos terminan en 0. QuickControlsView y CalendarView terminan en 255 sin diagnóstico, por lo que no se declara lint aprobado para esos dos; sus fixtures de ejecución pasan. Una invocación conjunta también terminó en 255 sin salida. Ningún FAIL se acepta sólo porque el proceso termine en 0.

## Contraste medido y límite

Mínimo entre cuatro caras y las 71 intensidades de cada paleta, calculado con colores compuestos por Qt y luminancia sRGB:

| Paleta | Mínimo |
| --- | --- |
| rose-dark | 4.00:1 |
| rose-light | 4.19:1 |
| blue-dark | 3.99:1 |
| blue-light | 4.21:1 |
| green-dark | 3.98:1 |
| green-light | 4.19:1 |

La prueba exige alcanzar 4.5 o escoger la mejor candidata, y no empeorar respecto de la regla anterior prevista por intensidad. **No garantiza 4.5 para toda intensidad**: ninguna de las cuatro candidatas logra ese objetivo simultáneamente sobre todas esas caras intermedias. Tampoco acredita tinta secundaria con alpha, hover, transiciones ni todo fondo externo. Se evita alterar o recortar la intensidad guardada para ocultar ese límite. Las parejas semánticas base examinadas sí pasan 4.5.

## QA visual nativo

Capturas de la ventana del fixture, recortadas con grim, Qt Wayland/Hyprland, 936×1002: `native/dark.png` y `native/light.png`. Paletas rose-dark/rose-light, texto al 175 %, intensidad 0.6, reducción de transparencia activa. Inspección: las franjas blancas/negras permanecen fuera de los materiales; títulos, descripción de tres líneas y acciones caben sin recortes. El indicador de foco es visible. Se cerraron los fixtures al terminar. No se capturó el escritorio personal.

Es una Window con componentes de producción; no certifica posicionamiento layer-shell, todas las notificaciones/gotas en vivo ni todas las superficies. El foco se prueba por API/QtTest, sin ratón físico ni lector de pantalla. Offscreen valida lógica y no sustituye estas capturas.

## Reproducción

Desde la raíz, crear un directorio temporal y usar sus rutas para ISLA_CONFIG/ISLA_IRIS; no usar shell.json personal. Ejemplo:

```sh
fixture_dir=$(mktemp -d /tmp/isla-accessibility-XXXXXX)
ISLA_CONFIG="$fixture_dir/shell.json" ISLA_IRIS="$fixture_dir/iris.json" QT_QPA_PLATFORM=wayland ISLA_PALETTE_FIXTURES="$PWD/docs/design-accessibility-2026-10-26/palettes.json" qs -p bar/material-accessibility-regression.qml
ISLA_CONFIG="$fixture_dir/shell.json" QT_QPA_PLATFORM=offscreen ISLA_PALETTE_FIXTURES="$PWD/docs/design-accessibility-2026-10-26/palettes.json" qs -p bar/matugen-palette-regression.qml
python bar/tests/settings-integration.py
```

`ISLA_PALETTE_INDEX=0/1` selecciona oscuro/claro para el fixture nativo; `ISLA_CAPTURE_HOLD_MS=4000` permite capturarlo después de PASS. Ejecutar fixtures de foco Wayland en serie. Exigir marcador PASS, ausencia de FAIL y exit 0. `source.sha256` identifica la versión probada, no todo el diff del repositorio.

Pendiente de la auditoría amplia: reglas de composición para todas las superficies, recorridos GTK/Qt/Electron, multimonitor, lector de pantalla y presentación física bajo carga. Este lote no compara rendimiento con macOS ni constituye certificación integral de accesibilidad.
