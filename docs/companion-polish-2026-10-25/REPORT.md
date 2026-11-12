# Compañero de Isla: prototipo · 2026-10-25

Implementación del encargo `docs/PROMPT-companion-polish.md`, con la corrección
expresa del usuario: **caricia por roce del cursor; clic para otra acción**.
No se hizo commit. Se conservaron los cambios previos de Claude.

## Comportamiento y composición

- La cara ya no navega. Enfoque y Grabación quedan en **Super+U → Ajustes rápidos
  → Actividades**. REC y texto son informativos, fuera del control de la cara.
- Tres inversiones del cursor sobre la cara en 1,4 s producen una caricia.
  Clic o teclado eligen guiño, curiosidad o giro de pupilas; repetición sonríe.
- Asimetría leve, punto interior con deriva, párpados independientes y color de
  Theme. Guiño, curiosidad, pupilas traviesas, estornudo, bostezo y sonrisa;
  sueño/despertar, celebración y música conservan su integración.
- Todos los momentos son finitos. Un gesto reemplaza al anterior, incluido el
  parpadeo. Ocultar/desactivar/reducir movimiento los corta sin alegría diferida.
- `CompanionBehavior.qml` concentra la política; la cara recibe contexto. Pill y
  IslandOverlay conectan puntero, rail, toplevel, música, Cava y notificaciones.
  No se añadió consumidor de Cava ni servicio al componente de la cara.
- Config.companion y la nueva página **Edots → Compañero**: sueño entero 60–1800 s
  (180 por defecto), reacciones código/música/noche, puntero y travesuras.
  appearance.personality sigue siendo el interruptor general.

## Decisiones propias

- Caricia: mínimo 1,8 s entre activaciones para evitar sonrisas reiniciadas sin fin.
- Tres clics con menos de 1,1 s entre cada uno activan la reacción contenta.
- Tabla de rasgos: respuesta 260 ms; curiosidad 0,65 de amplitud del rail.
  Resorte en mirada y deriva interior de 380 ms, respiración sólo dentro del gesto.
- Travesuras raras: 8 % por oportunidad cada 10 min; normales: 28 %. Estornudo,
  giro o guiño según el sorteo. Nunca con launcher/auth/grabación/notificación;
  un bloqueo interrumpe también un momento iniciado. Bostezo nocturno: 10 % cada
  2 min como máximo. Sin animación idle continua.
- La notificación es central y aparece debajo: mirada abajo, sin alterar su
  prioridad ni la ocultación habitual de la cabecera durante la expansión.
- Alegría usa un tinte suave del acento disponible en Theme. Sin colores fijos.
- Página nueva al final de Edots para conservar los índices existentes. El
  tiempo se edita en pasos enteros y se muestra sin decimales.

## Validación

- `node bar/tests/settings.cjs`: PASS.
- `python bar/tests/settings-integration.py`: PASS con ISLA_CONFIG temporal;
  defaults, límites/tipos, persistencia, descarte, campos desconocidos y seis
  controles reales de Edots. Rounding 333,5→334 y visualización entera cubiertos.
- `bar/tests/verify-config.sh`: PASS.
- Personalidad: PASS offscreen y Wayland nativo; nuevos gestos finitos y exclusivos, caricia
  distinta de clic/teclado, reduced/oculto, bloqueos, cadencia/probabilidad,
  muestreo del puntero y contexto musical/código. La prueba nativa detectó una
  espera demasiado ajustada (300 ms); se conserva la comprobación del retardo
  mínimo y se espera el resultado eventual hasta 1 s para tolerar el compositor.
- Absorption, companion-continuity, bar-layout-transition, clock-reel,
  pill-composition, pill-interface, status y media-motion: PASS. Las cuatro que
  cargan IslandOverlay se ejecutaron sobre Wayland con configuración temporal.
  Resultados resumidos adjuntos `*-result.txt`.
- `QT_QPA_PLATFORM=wayland python bar/tests/qml-performance.py --output ...`: PASS.
  `performance.json`: playbackChanges=0, metadataReads=0, hiddenBandCalls=0;
  glow y Cava inactivos en fullscreen. Es una medición del fixture, no una
  comparación de ahorro de CPU/memoria de la sesión.
- Revisión independiente: Claude local no disponible (sesión sin login).
  Revisor Codex detectó solapamiento de blink y temporizador de alegría en reduced;
  ambos corregidos y verificados por el mismo reproducer, sin hallazgos pendientes.
- `git diff --check`: PASS. Búsqueda exacta de referencias al sistema retirado,
  excluyendo TASK_STATE.md y docs: sin coincidencias.

## QA visual real

Capturas con grim del compositor, inspeccionadas: preview ×3 durante expresión,
liberación y reposo; seis controles en Edots y barra viva a tamaño real. Se corrigió
el recorte independiente del párpado inferior y la lectura del guiño durante sonrisa.

- [Expresión](preview-expression.png), [liberación](preview-release.png),
  [reposo](preview-rest.png).
- [Ajustes](settings.png), [barra viva](live-bar.png).

## Límites y decisiones abiertas

Sigue siendo un prototipo. No se comprobó caricia con ratón físico, ausencia real
hasta el timeout, tema claro ni percepción prolongada durante una sesión de trabajo.
Las reacciones a código/música y bloqueos tienen evidencia de fixture; no se cambió
el reproductor, workspace o grabación del usuario para ensayarlas. Quedan abiertos
a valoración la amplitud a tamaño real, punto interior, tiempos y frecuencias.
