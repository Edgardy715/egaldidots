# Prompt para la nueva conversación: pulir el compañero de la isla

Copia todo lo que hay debajo de la línea en una conversación nueva abierta en `/home/zdito/.config/quickshell`.

---

Lee `PROJECT_MEMORY.md`, `bar/fluid/MOTION_LANGUAGE.md` (sección «El compañero es la cara de la isla») y `docs/companion-legacy-ideas-2026-10-24.md`. Usa la skill `.agents/skills/fluid-island-motion/SKILL.md`.

## Contexto
- El único pet de la shell es **IslandCompanion** (`bar/components/IslandCompanion.qml`): dos ojos vectoriales junto al reloj, la «cara de la isla». Los pets pixel art (Mimo, Pip) se eliminaron el 2026-10-24; copia en `~/.local/state/isla/pets-archive-2026-10-24.tar.gz`. No los restaures ni los menciones en ningún archivo.
- Hoy ya hace: reposo, hover (mira), enfoque (párpados bajos, mirada abajo), pausa (línea), atención (ojos grandes, color de acento), nod al confirmar, celebración de 2 saltos al terminar, vaivén al empezar música, párpado plano de noche (23–6), sueño tras 180 s de ausencia (IdleMonitor) con saludo al volver, caricia (3 inversiones del cursor en 1,4 s).
- Vista previa: `qs -p bar/companion-preview.qml` (`ISLA_COMPANION_TOUR=1` reproduce los momentos). Prueba: `bar/personality-regression.qml`.
- Reglas que NO cambian: sin bucles idle infinitos, momentos finitos que terminan quietos, nada corre oculto, `reduceMotion` y `appearance.personality=false` lo apagan, SmoothedAnimation/resortes para geometría, el compañero recibe datos por propiedades (Players, Cava, FocusSession se conectan desde la composición), no cubre contenido ni ensancha la pill.

## Separación acordada (2026-10-25)
- El acceso a Enfoque y Grabación vive en **Super+U → Ajustes rápidos → Actividades** (ya existente), por elección del usuario.
- La pet no abre surfaces. La caricia se hace rozando físicamente la cara con el cursor, nunca mediante clic. Clic y activación por teclado disparan otros gestos; pueden variar aleatoriamente. Clics repetidos pueden provocar una reacción propia.
- El texto de actividad y el indicador de grabación son informativos e independientes de su zona de interacción. La grabación no sustituye la cara. Conserva esta separación al ejecutar los pasos siguientes.

## Objetivo
**PROTOTIPO, no implementación final.** Pulir el compañero con mucho más detalle y personalidad, sin cambiar su dirección (una sola cara, vectorial, ligada a eventos reales del sistema). Todo cambio de diseño que no esté descrito aquí es decisión mía: márcala en el informe como «decisión propia».

## Trabajo (en este orden)
1. **Rediseño de la cara (más identidad):**
   - Ojos con carácter propio: pupila/brillo interior sutil (un punto de luz que sigue la mirada con retardo), forma ligeramente asimétrica por defecto (un ojo apenas más abierto) para que no parezca simétrico-de-plantilla, y párpados superior e inferior independientes.
   - Parpadeo natural sólo ante interacción o transición de estado (no loop), con parpadeo doble ocasional tras eventos importantes.
   - Colores desde Theme/Matugen (acento para atención, `primary` suave para alegría); nunca colores fijos.
2. **Animaciones más ricas (todas finitas):** anticipación + sobrepaso + asentamiento en cada gesto; squash/stretch coherente; mirada con inercia (sacádica corta y luego deriva); micro-respiración visible sólo mientras hay interacción (no loop). Añadir: guiño ante una confirmación sutil, «ojos grandes» al llegar una notificación importante y mirada hacia el lado donde aparece, bostezo al dormirse y estiramiento al despertar, entrecerrar contentos ante clics repetidos.
3. **Reacciones nuevas ligadas a eventos que ya existen** (ideas rescatadas del sistema anterior, en `docs/companion-legacy-ideas-2026-10-24.md`): seguir el puntero cuando está sobre la pill (retardo mínimo 250 ms entre cambios), mirar la celda hovered del rail de espacios, concentración al enfocar terminal/editor (parpadeo lento, mirada fija; app detectada por el toplevel activo, conectado desde composición), seguir la posición del seekbar durante la música, rebote de pupilas al ritmo con Cava sólo mientras suena y el panel de música está visible, bostezo nocturno raro (máx. cada 2 min, ≤12 % por oportunidad) y sueño con timeout configurable.
4. **Personalidad (comportamiento):** carácter «tranquilo, atento, un poco curioso». Define una pequeña tabla de rasgos (reacción rápida/lenta, cuánta curiosidad) y una **travesura ocasional** muy rara (guiño, girar pupilas, estornudo) con cadencia máxima ~1 cada 10 min, nunca durante lanzador, grabación o notificación, y desactivable.
5. **Ajustes propios** (sección nueva en `bar/Singletons/Settings.js`, solo para este pet, con validación y valores por defecto): `appearance.personality` se mantiene; añadir bajo una sección «Compañero»: tiempo para dormir, reacciones (código, música, noche), travesuras (nunca/raras/normales), seguir puntero. Mantén `Config` como fuente y prueba con `ISLA_CONFIG` temporal. Actualiza los tests de ajustes.
6. **Prototipo explícito:** en `companion-preview.qml` (cabecera visible «PROTOTIPO — no es la implementación final») y en la sección de MOTION_LANGUAGE.md, deja claro que es un prototipo y qué decisiones siguen abiertas.
7. **Pruebas y QA:** amplía `personality-regression.qml` (cada gesto nuevo termina quieto; reduced/hidden los cortan; sleep/wake; travesura respeta bloqueos), corre las regresiones que tocan la cabecera (absorption, companion-continuity, bar-layout-transition, clock-reel, pill-composition, pill-interface, status, media-motion; las que cargan IslandOverlay con `QT_QPA_PLATFORM=wayland`), `tests/qml-performance.py`, y captura con grim la barra viva y el preview ×3 de cada expresión nueva. Inspecciona las capturas de verdad (no sólo offscreen).
8. **Cierre:** registra decisiones, pruebas y límites en `TASK_STATE.md`, actualiza `PROJECT_MEMORY.md`. Sin commit salvo que lo pida.

## Entrega
Resumen corto: qué quitaste, qué añadiste, decisiones propias, qué probaste y qué quedó sin verificar (por ejemplo: sueño real tras el timeout, caricia con ratón real, tema claro). Verifica con `rg -i "pixel art|mimo|\bpip\b|eshell pets" --glob '!TASK_STATE.md' --glob '!docs/**'` que no reaparece nada del sistema borrado.

Si hay más de una forma razonable de resolver algo que cambia la dirección (no un detalle), pregúntame antes; si es un detalle de diseño, decide tú y márcalo.

## Estado del prototipo (2026-10-25)

Implementado y revisado; decisiones, evidencias y límites en `docs/companion-polish-2026-10-25/REPORT.md`. Este documento conserva el encargo como referencia; la distinción caricia/clic anterior incorpora la corrección expresa del usuario. Sigue pendiente su valoración perceptual.
