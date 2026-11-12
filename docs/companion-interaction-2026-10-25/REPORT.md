# Compañero: interacción y continuidad · 2026-10-25

Segunda fase del prototipo, con las seis ideas aceptadas por el usuario. Sin
dependencias nuevas ni commit; conservados los cambios previos de Claude.

## Resultado

- Roce horizontal, vertical o diagonal: cierra progresivamente los ojos y sigue
  la mano con una inclinación breve. Tres inversiones suaves en 1,4 s activan
  la caricia; intervalo mínimo de 1,8 s. Más de 550 unidades lógicas/s provoca
  cosquillas, con su propia pausa de 1,8 s. La presión se libera tras 260 ms.
- Aproximación con mirada, curiosidad tras 750 ms sobre la cara y mirada que
  permanece 850 ms al retirarse. Desactivar seguimiento elimina inclinación y
  mirada persistente; no elimina la interacción física.
- Clic y teclado: curiosidad, juego y reacción contenta al insistir, con ventana
  de 1,1 s entre clics. Tras una caricia, el primer clic puede ser un guiño.
  El control sigue separado de Super+U → Ajustes rápidos → Actividades.
- Afecto local durante 30 s, sin persistencia, puntos ni necesidades: saluda con
  alegría al volver pronto. No añade un temporizador continuo.
- Despertar corto de reconocimiento; tras al menos 60 s dormido, estiramiento.
  Momento nocturno raro: intenta mantenerse despierto y termina bostezando,
  reutilizando la oportunidad existente de dos minutos (2,5 % para este gesto).
- Cada gesto sustituye al anterior y vuelve al reposo. Oculto, suspendido o con
  movimiento reducido detiene gestos y temporizadores. No cambia el ancho de la
  barra ni añade consumidores de audio o servicios a la cara.

Fuentes: IslandCompanion.qml, IslandActivityChip.qml y CompanionBehavior.qml;
fixtures companion-preview.qml y personality-regression.qml. Contrato de movimiento
actualizado en bar/fluid/MOTION_LANGUAGE.md.

## Evidencia

- Personalidad: PASS offscreen y Wayland nativo, incluyendo entrada de ratón
  sintetizada horizontal y vertical, clic/teclado, liberación, exclusión entre
  gestos, afecto, despertar, seguimiento desactivado y oculto/reduced.
- Absorption, companion-continuity, bar-layout-transition y pill-composition:
  PASS en Wayland con configuración temporal. Resultados adjuntos.
- Rendimiento del fixture: PASS; cero cambios de reproducción, lecturas de
  metadatos y muestras ocultas; glow y Cava detenidos en fullscreen. Véase
  performance.json/measurements.json. No representa una comparación de CPU.
- Revisión independiente de riesgo, dos rondas: encontró superposición de roce
  con otros gestos y una animación de roce encolada después de caricia. Corregidas
  centralizando cancelación y desactivando el Behavior antes de restaurar su
  binding. El coordinador repitió el reproducer: touch=0 inmediatamente y a
  40/260 ms tras caricia; un nuevo roce aún alcanza su objetivo y se libera.
- git diff --check: PASS. Configuración real del usuario sin editar.

El fixture de personalidad omite reactAtNight en una asignación de prueba y
produce un aviso undefined→bool; no es un error de carga ni de las opciones
validadas de producción. Wayland también emite avisos de foco de QtTest.

## Inspección visual nativa

Capturas reales con grim del compositor, no renders offscreen: [composición y
curiosidad](curiosity.png), [roce](stroke.png), [caricia](affection.png),
[retorno](return.png), [despertar](stretch.png), [sueño](doze.png),
[reposo](rest.png) y [barra viva](live-bar.png).

## Límites

Sigue siendo un prototipo. Falta valorar con ratón físico, ausencia real prolongada,
tema claro y durante una sesión larga. La respuesta física tiene pruebas con
eventos sintetizados y los estados con fixtures; no se alteró la música, workspace
o grabación del usuario para comprobarlos.
