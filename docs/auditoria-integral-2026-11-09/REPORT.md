# Auditoría integral Azog/Isla — 2026-11-09

Sin commit, push, reset ni stash. Rama `feat/hyprland-glass-keybinds` con trabajo previo sin commit que no es de esta auditoría.

## Veredicto

| Área | Estado |
|---|---|
| Suite de regresiones QML | 129 → 142 PASS de 168 (offscreen y Wayland según test) |
| Scripts de configuración | `verify-config.sh` pasa (antes fallaba en 2 puntos) |
| Hallazgo P1 (sombra en tarjeta de notificación) | corregido, sin QA visual |
| Bug de límite de componente (FluidRecordingCompanion) | corregido |
| Regresión `pull-gesture` | resuelta: test obsoleto (el reloj ya no está en el centro de la pill) |
| P2/P3 (escala tipográfica, `URGENTE` i18n) | aplicados; 10 regresiones PASS, sin QA visual |

## Probado

| Cambio | Prueba | Antes | Después |
|---|---|---|---|
| `NotifCardView.qml`: tarjeta tonal, sin `layer` ni sombra | notifs-surface, notification, notification-drop, notification-routing, notification-priority | PASS (con sombra) | PASS |
| `FluidRecordingCompanion.qml`: el texto de foco ya no lee `FocusSession` (se pasa `focusRemainingSeconds` desde `IslandOverlay.qml`) | verify-config.sh (surface-boundaries) | FAIL | PASS |
| Mismo cambio | focus-session, recording-integration, recording-view, recording-drop (Wayland) | PASS | PASS |
| Tests obsoletos actualizados (lockscreen-entrance, lockscreen-motion, interaction-surfaces, settings-surface-switch, swiftify-media, settings.cjs, settings-integration.py, verify-config.sh) | cada test | FAIL | PASS |
| Suite completa | 168 regresiones, scripts | 129 PASS | 142 PASS |

Suite completa: `scratchpad/final/latest.txt` (última ejecución por test).

## No verificado

- **QA visual** hecho en Wayland para toasts y panel de notificaciones (después; sin captura "antes"). Textos reescalados (Session, Overview, Media, Lyrics, Wallpaper) sin QA visual.
- **Primer frame del mixer** (25–43 ms): qmlprofiler **bloqueado** (Quickshell rechaza `-qmljsdebugger`; con wrapper vía `QML_DEBUG_ARGS` no conecta). Requiere medir con un contador interno.
- **Flujo de app y explorador de archivos**: no se probaron en Wayland.
- **Revisión independiente** (`isla-revisor`) hecha sobre los cambios de la auditoría, no sobre el diff completo con trabajo previo. 6 hallazgos, aplicados. `settings.cjs:120` queda con comparación de conjunto + `activities` primero (decisión: el orden de pantalla no se fija).
- **Hot reload (RangeError)**: no reproducido en esta sesión.

## Bloqueado / entorno

Los tests `IslandOverlay`/`PanelWindow` necesitan `QT_QPA_PLATFORM=wayland` y el `XDG_RUNTIME_DIR` real. Ejecutados así: 13 tests (incluidos `recording-drop`, `layout-motion`, `fullscreen-hide`, `settings-async`, `media-dock-surfaces`).

## Fallos abiertos

Los 25 fallos de la suite masiva eran sobre todo de ejecución: se ejecutan con su wrapper de `bar/tests` (fixtures, Wayland). Con wrapper pasan **22 de 25**:
cava-envelope, clipboard, clipboard-design/library/workflow, hyprland-settings, launcher-media-clearance, matugen-reload, media-palette-recovery, overlay-native-input, settings-media-routing, settings-navigation (Wayland), settings-surface-switch, updates-service, wallpaper-apply-protocol, wallpaper-scanner, wallpaper-source.

| Test | Estado | Pista |
|---|---|---|
| `qml-performance` (wrapper) | **resuelto**: test obsoleto. `PillMaterial` fija `InnerGlow.drifting=false` en reposo/estado (deliberado, "sin frames en reposo"), así que el glow no avanza. El test ahora exige reanudar sólo si `light.drifting`. Límite: con la pill en reposo "glow pauses en fullscreen" no distingue pausa de reposo. | `bar/qml-performance-regression.qml`; el aviso `Pill.qml:530` (`Cava.bass` undefined) no volvió a aparecer en la ejecución |
| iris-memory | **PASS** con `ISLA_IRIS` temporal (sin él leía `~/.config/isla/iris.json` real: días=4) | no era bug |
| lyrics-controller | **PASS** vía `bar/tests/lyrics-backend.py` | necesita wrapper |
| config-draft-conflict | **PASS** vía `bar/tests/settings-integration.py` | necesita wrapper |
| matugen-palette | **PASS** con `ISLA_PALETTE_FIXTURES=docs/design-accessibility-2026-10-26/palettes.json` | necesita fixtures |
| top-system-status | **PASS** en Wayland con runtime real | PipeWire/runtime |
| iris-continuity | **FAIL obsoleto**: la parte de "perch" exige `legacyCompanionEnabled`, fijo en `false` (`Pill.qml:17`); el viaje nunca anima. La parte de atención PASS | actualizar o retirar el caso perch |
| personality | **FAIL obsoleto**: depende del hover de las mascotas, retiradas en c5efa1e | retirar o reescribir |
| settings-layer-picker | **no es un test**: fixture visual sin aserciones (abre Ajustes y espera); el timeout rc=124 es lo esperado | usar sólo para capturas |

## Cambios de esta auditoría

- `bar/components/NotifCardView.qml`: sin `QtQuick.Effects`, sin `bodyShadow` ni `layer`, sin `Theme.sheen`; tarjeta `Theme.tonalFill`; aro sólo si es crítica.
- `bar/components/FluidRecordingCompanion.qml`: nueva propiedad `focusRemainingSeconds`; `label` ya no lee `FocusSession`.
- `bar/windows/IslandOverlay.qml`: conecta `focusRemainingSeconds: FocusSession.remainingSeconds`.
- `bar/tests/verify-config.sh`: `rg` excluye sólo `files-nav-regression.qml` (falso positivo de `/home/with space`).
- `bar/tests/desktop-integration.py` (quita `appearance`), `overlay-native-input.py` (texto 13), `NotifCardView.qml` (insignia URGENTE crece con la fuente), `WallpaperView`/`IslandMediaSummary`/`OverviewView` 12.5→13: hallazgos de la revisión independiente.
- `bar/tests/settings.cjs`, `bar/tests/settings-integration.py`: expectativas al estado actual (Amalgam, orden de secciones, 180 s, paso de 10).
- `bar/settings-surface-switch-regression.qml`: quita superficie `appearance` (ya es página de Ajustes); texto "10 destinations".
- `bar/swiftify-media-regression.qml`: play/pause es glifo dibujado, no `fontInfo`.
- `bar/lockscreen-entrance-regression.qml`, `bar/lockscreen-motion-regression.qml`, `bar/interaction-surfaces-regression.qml`: esperas acotadas y nombres actualizados.

## Hallazgos abiertos (P2/P3, sin aplicar — requieren aprobación)

- ~20 textos fuera de la escala tipográfica (11·13·15·20·28·40): p. ej. `IslandMediaMetadata.qml:54` (12.5), `IslaTextField.qml:27` (14), `SessionView.qml:104/161/209`, `OverviewView.qml:201/309/354`, `IslandNotification.qml:159` (10.5), `MediaView.qml:100` (22), `CalendarView.qml:560` (46).
- `PillMaterial.qml` y `VolumeChip.qml`: `Behavior` sin comprobar `reduceMotion` (verificar).
- "URGENTE" en `NotifCardView.qml` sin `I18n.tr`.
- `menuSelectionAnchor` tiene efecto real (`kit/IslaComboBox.qml:145`). `mischief` y `followFocus` también (`components/CompanionBehavior.qml:36,89-92`), pero están `availability: "inactive"` en `Settings.js:73,76` y sus descripciones aún dicen "Iris".

## Mejoras propuestas (no aplicadas)

1. `bar/tests/run-all.sh`: runner único que aplique el modo correcto (offscreen / wayland) por test.
2. Tests que hoy dependen de `PanelWindow` deberían declarar `QPA=wayland` en su cabecera.
3. Captura recortada antes/después como parte del cierre de cada cambio visual.

## Pendiente de decisión

- Aprobar la lista P2/P3 y las mejoras.
- Autorizar la bisección de `pull-gesture`.
- Confirmar si se quiere `isla-revisor` sobre el diff completo.

## Iris: código muerto (corrección)

Iris ya no existe en la shell. `Pill.legacyCompanionEnabled` está fijo en `false` (`Pill.qml:17`), así que `perchWanted`, `irisPresent` y `IrisMemory.noteActivity()` nunca se activan. Los PASS de `iris-memory` (y la parte de atención de `iris-continuity`) sólo prueban código inalcanzable. Restos candidatos a retirar (no aplicado, requiere aprobación): `Singletons/IrisMemory.qml`, bloque perch/Iris de `Pill.qml:721-861`, `iris-*-regression.qml` (4), `personality-regression.qml`, `docs/iris-*` (3, sin seguimiento en git) y `~/.config/isla/iris.json`. `CompanionBehavior`/`IslandCompanion` pueden seguir vivos para Amalgam: separar antes de borrar.

## Retirada de Iris (aplicada, sin commit)

Borrados: `IrisMemory.qml`, `Visitors.js`, `IslandCompanion.qml`, `CompanionBehavior.qml`, `companion-preview.qml` y 6 regresiones (`companion-delight`, `iris-memory/continuity/delight/system`, `personality`). Editados: `Pill.qml` (perch, cara, atención, props huérfanas; `bassTarget` ahora `(Cava.bass || 0)`, desaparece el aviso `Unable to assign [undefined]`), `PillHeaderView`, `IslandRestStatus`, `IslandActivityChip`, `IslandOverlay` (props sin lector), `body-pill-regression`, `TESTING.md`, `en.js`, `fluid/MOTION_LANGUAGE.md` (sección Iris sustituida por nota).
Conservado: `Settings.js` (claves companion/mischief/followFocus/remember por compatibilidad), `docs/iris-*`, `~/.config/isla/iris.json`, `focusPoint` de surfaces (sin consumidor en Pill), `companionBlocked/CodeFocused` (los usa el cuerpo).
Prueba (Wayland, config temporal): body-pill, compact-island, pull-gesture, pill-composition, media-dock-surfaces, fullscreen-hide, qml-performance PASS; `verify-config.sh` PASS.
QA visual en la shell real: Session y Overview legibles, sin recortes (captura 0,6x); Media, Lyrics y Wallpaper **no verificados**.

## Revisión y limpieza posterior a la retirada de Iris

`isla-revisor` (una vez): 0 P0/P1/P2, 6 P3. Aplicados: `SHELL_ARCHITECTURE.md`, `TESTING.md` (ISLA_IRIS), retirada del mecanismo `focusActive/focusPoint` de las surfaces (PillSurface, Launcher/Wallpaper surfaces, Launcher/Wallpaper/Lyrics/Media/Overview views) y de `responseMood`/`expressionHold` en `Pill.qml`. Se conservan los textos de `Settings.js`/`en.js` (ajustes ocultos).
Prueba: launcher*, wallpaper*, lyrics-view, media*, overview, pill-composition, body-pill, interaction-surfaces, activities, drop-gesture, verify-config y qml-performance PASS; con wrapper: lyrics-backend, wallpaper-apply-protocol, wallpaper-scanner, wallpaper-source, launcher-media-clearance PASS. Sin QA visual de Launcher, Wallpaper, Lyrics y Media tras este último cambio.
