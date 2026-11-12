# Prompt · Implementar Tidemark en la pill

> Pégalo como primer mensaje de un chat nuevo, abierto en
> `/home/zdito/.config/quickshell`. Escrito el 2026-10-30.

---

Implementa **Tidemark**, el lenguaje de trazo de Isla, por fases y empezando por el piloto. Responde en español, formato TDAH (acción primero, pasos numerados, sin preámbulo).

## Estado: plan aprobado, nada implementado

El usuario aprobó el plan y las animaciones de referencia (incluido el mute nuevo). No hay código QML tocado ni commits.

## Léelo antes de tocar nada

1. `docs/plan-trazo-pill-2026-10-30.md`: identidad, inventario, piezas, fases y riesgos.
2. `docs/previews/tidemark-lenguaje.html`: **referencia viva del movimiento aprobado**. Ábrela en el navegador y extrae los parámetros del código (muelles omega/zeta, orden de secuencias, morphs). El plan habla de `trim`, pero el piloto aprobado usa muelles y morph; **donde difieran, manda la vista previa**.
3. `PROJECT_MEMORY.md`, `bar/fluid/MOTION_LANGUAGE.md`, `.agents/skills/fluid-island-motion/SKILL.md`, `docs/INTERACTION_SYSTEM.md`, `docs/SHELL_ARCHITECTURE.md`.
4. Código base: `bar/components/ConfirmationIndicator.qml`, `AnimatedSymbol.qml`, `MaterialIcon.qml`, `AnimatedIconData.js`, `bar/Singletons/Motion.qml`.

## Decisiones ya tomadas (no reabrir)

- Nombre: **Tidemark**. Estilo propio: nada de copiar Apple ni Material en aspecto, nombres o curvas.
- Cabeza que lidera + cola fina; acento dinámico del wallpaper en reposo; verde/rojo sólo al resolver; la espera respira con `Motion.easeBreathe`.
- **Mute:** la onda central se endereza y gira hasta ser la barra que tacha el altavoz. Sin cruz. Al quitar mute vuelve a onda.
- **Play↔pause:** el triángulo se parte como una gota (cuello que se estira y se rompe). **Lock:** el shackle sube, gira y baja con un "clac" del cuerpo.
- Interrumpible: cada cambio parte del estado y la velocidad actuales.
- **No animar:** scroll de volumen/brillo/wallpaper/letras, hover repetido, avance de canción, iconos fijos.

## Reglas no negociables

- No tocar `PillMorphMotion`/`Motion.surfaceSpring`, la física de las gotas ni la respiración de la pill.
- Duraciones y curvas sólo desde `Motion`; ningún literal nuevo. Los parámetros de muelle nuevos son tokens en `Motion`.
- reduceMotion resuelve al estado final; oculto = sin animación; reposo de la pill = cero timers, Shapes o layers nuevos.
- Sin bucles ornamentales. Conserva los cambios ajenos sin commit. **Sin commit ni push salvo que lo pida el usuario.**
- Quien escribe no revisa: tras la Fase 1 y la Fase 3, revisión independiente con `isla-revisor`.
- Delega por coste (`isla-explorador`, `isla-implementador`); el diseño de movimiento se queda en el hilo principal.
- QML: skills `qt-qml`, `qt-qml-review`, `qt-qml-profiler`. Ajustes con `Config.update/discard/save`; los componentes hoja reciben datos por propiedades.

## Paso 0 (primero, ~10 min)

Registra el plan aprobado en `TASK_STATE.md` y un estado breve en `PROJECT_MEMORY.md`, indicando que el piloto usa muelles + morph. No escribas en `MOTION_LANGUAGE.md` ni en la skill sin el OK del usuario: propón el texto al cerrar.

## Fases

1. **Fase 0 · Fundación (~1,5 h):** tokens en `Motion` y `Theme` (`signalSuccess/signalError` en lugar de los `#32d975/#ff4d61` de `ConfirmationIndicator`), `LevelStroke`, motor de muelle reutilizable, y `stroke-language-regression.qml` (estado final, interrupción, reduceMotion, oculto = quieto).
2. **Fase 1 · Piloto (~3 h):** glifo de volumen del OSD con mute, FocusTimer play↔pause + anillo de tiempo, lock↔unlock. Aceptación: se ven en vivo, interrumpir a mitad parte del estado actual, y pasan `confirmation-indicator`, `motion`, `interaction-regression`, `lockscreen` y `osd`. Párate y enseña al usuario antes de seguir.
3. **Fase 2 · Extender (~3 h):** wifi/BT, portapapeles, batería, mezclador, play/pause de media.
4. **Fase 3 · Cierre (~1,5 h):** `pill-detail-audit`, perfilado con `qt-qml-profiler`, texto propuesto para la documentación.

## Preguntas que quedan abiertas (pregúntalas al empezar la Fase 1)

1. Nivel del OSD: ¿arco alrededor del glifo o línea horizontal como ahora?
2. ¿Cabeza más gruesa que la cola o trazo uniforme? La vista previa muestra ambos.

Empieza por el Paso 0 y la Fase 0. Distingue en cada informe lo probado, lo no verificado y lo bloqueado; offscreen no es QA visual.
