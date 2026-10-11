# Índice de evidencia y resultados

Tandas QML: `ISLA_CONFIG=/tmp/isla-audit-<fixture>.json QT_QPA_PLATFORM=wayland python ~/.codex/token-economy/output.py run -- timeout 25s qs -p bar/<fixture>-regression.qml`. Una prueba terminó antes de su comprobación por límite externo; otra requería endpoint simulado. Ninguna se contó como PASS por su código de salida. Las repeticiones dirigidas resolvieron ambas condiciones.

| Ejecución | Exit | Evaluación | Log íntegro |
|---|---:|---|---|
| interaction-surfaces | 0 | PASS comprobado | [interaction-surfaces.raw.log](interaction-surfaces.raw.log) |
| interaction | 0 | PASS comprobado | [interaction.raw.log](interaction.raw.log) |
| pill-interface | 0 | PASS comprobado | [pill-interface.raw.log](pill-interface.raw.log) |
| pill-composition | 0 | PASS comprobado | [pill-composition.raw.log](pill-composition.raw.log) |
| pill-geometry | 0 | PASS comprobado | [pill-geometry.raw.log](pill-geometry.raw.log) |
| overlay-input-policy | 0 | PASS comprobado | [overlay-input-policy.raw.log](overlay-input-policy.raw.log) |
| surface-router | 0 | PASS comprobado | [surface-router.raw.log](surface-router.raw.log) |
| surface-choreography | 0 | PASS comprobado | [surface-choreography.raw.log](surface-choreography.raw.log) |
| surface-data-contract | 0 | PASS comprobado | [surface-data-contract.raw.log](surface-data-contract.raw.log) |
| calendar-data | 0 | PASS comprobado | [calendar-data.raw.log](calendar-data.raw.log) |
| weather-view | 0 | PASS comprobado | [weather-view.raw.log](weather-view.raw.log) |
| launcher-controller | 0 | PASS comprobado | [launcher-controller.raw.log](launcher-controller.raw.log) |
| overview | 0 | PASS comprobado | [overview.raw.log](overview.raw.log) |
| wallpaper | 0 | PASS comprobado | [wallpaper.raw.log](wallpaper.raw.log) |
| media-session | 0 | PASS comprobado | [media-session.raw.log](media-session.raw.log) |
| media-layout | 0 | PASS comprobado | [media-layout.raw.log](media-layout.raw.log) |
| media-timeline | 0 | PASS comprobado | [media-timeline.raw.log](media-timeline.raw.log) |
| lyrics-controller | 1 | No válido para concluir producto; ver repetición | [lyrics-controller.raw.log](lyrics-controller.raw.log) |
| lyrics-view | 0 | PASS comprobado | [lyrics-view.raw.log](lyrics-view.raw.log) |
| mixer-surface | 0 | PASS comprobado | [mixer-surface.raw.log](mixer-surface.raw.log) |
| connectivity-surface | 0 | PASS comprobado | [connectivity-surface.raw.log](connectivity-surface.raw.log) |
| notifs-surface | 0 | PASS comprobado | [notifs-surface.raw.log](notifs-surface.raw.log) |
| notification | 0 | PASS comprobado | [notification.raw.log](notification.raw.log) |
| notification-routing | 0 | PASS comprobado | [notification-routing.raw.log](notification-routing.raw.log) |
| session | 0 | PASS comprobado | [session.raw.log](session.raw.log) |
| workspaces-surface | 0 | PASS comprobado | [workspaces-surface.raw.log](workspaces-surface.raw.log) |
| workspace-model | 0 | PASS comprobado | [workspace-model.raw.log](workspace-model.raw.log) |
| top-workspace-motion | 0 | PASS comprobado | [top-workspace-motion.raw.log](top-workspace-motion.raw.log) |
| optional-modules | 0 | PASS comprobado | [optional-modules.raw.log](optional-modules.raw.log) |
| compact-island | 0 | PASS comprobado | [compact-island.raw.log](compact-island.raw.log) |
| bar-layout-transition | 0 | PASS comprobado | [bar-layout-transition.raw.log](bar-layout-transition.raw.log) |
| centered-companion | 0 | PASS comprobado | [centered-companion.raw.log](centered-companion.raw.log) |
| clock-reel | 0 | PASS comprobado | [clock-reel.raw.log](clock-reel.raw.log) |
| pacman-motion | 0 | PASS comprobado | [pacman-motion.raw.log](pacman-motion.raw.log) |
| layout-routing | 0 | PASS comprobado | [layout-routing.raw.log](layout-routing.raw.log) |
| layout-motion | 124 | No válido para concluir producto; ver repetición | [layout-motion.raw.log](layout-motion.raw.log) |
| layout-interruptions | 0 | PASS comprobado | [layout-interruptions.raw.log](layout-interruptions.raw.log) |
| input-motion | 0 | PASS comprobado | [input-motion.raw.log](input-motion.raw.log) |
| textbox-motion | 0 | PASS comprobado | [textbox-motion.raw.log](textbox-motion.raw.log) |
| extra-motion | 0 | PASS comprobado | [extra-motion.raw.log](extra-motion.raw.log) |
| extra-absorption | 0 | PASS comprobado | [extra-absorption.raw.log](extra-absorption.raw.log) |
| extra-media-motion | 0 | PASS comprobado | [extra-media-motion.raw.log](extra-media-motion.raw.log) |
| extra-status | 0 | PASS comprobado | [extra-status.raw.log](extra-status.raw.log) |
| extra-top-system-status | 0 | PASS comprobado | [extra-top-system-status.raw.log](extra-top-system-status.raw.log) |
| extra-island-status-adapter | 0 | PASS comprobado | [extra-island-status-adapter.raw.log](extra-island-status-adapter.raw.log) |
| extra-desktop-status-fanout | 0 | PASS comprobado | [extra-desktop-status-fanout.raw.log](extra-desktop-status-fanout.raw.log) |
| extra-workspaces-surface | 0 | PASS comprobado | [extra-workspaces-surface.raw.log](extra-workspaces-surface.raw.log) |
| extra-workspace-styles | 0 | PASS comprobado | [extra-workspace-styles.raw.log](extra-workspace-styles.raw.log) |
| extra-notification-routing | 0 | PASS comprobado | [extra-notification-routing.raw.log](extra-notification-routing.raw.log) |
| extra-microinteraction | 0 | PASS comprobado | [extra-microinteraction.raw.log](extra-microinteraction.raw.log) |
| extra-material-choreography | 0 | PASS comprobado | [extra-material-choreography.raw.log](extra-material-choreography.raw.log) |
| extra-launcher-controller | 0 | PASS comprobado | [extra-launcher-controller.raw.log](extra-launcher-controller.raw.log) |
| extra-config | 0 | PASS comprobado | [extra-config.raw.log](extra-config.raw.log) |
| extra-lockscreen-entrance | 0 | PASS comprobado | [extra-lockscreen-entrance.raw.log](extra-lockscreen-entrance.raw.log) |
| extra-lockscreen-motion | 0 | PASS comprobado | [extra-lockscreen-motion.raw.log](extra-lockscreen-motion.raw.log) |
| extra-lockscreen-typing | 0 | PASS comprobado | [extra-lockscreen-typing.raw.log](extra-lockscreen-typing.raw.log) |
| extra-lockscreen | 0 | PASS comprobado | [extra-lockscreen.raw.log](extra-lockscreen.raw.log) |
| extra-interaction-surfaces | 0 | PASS comprobado | [extra-interaction-surfaces.raw.log](extra-interaction-surfaces.raw.log) |

Repeticiones necesarias:

- [layout-motion-full.txt](layout-motion-full.txt): límite100s, exit0, PASS, sin FAIL; reemplaza sólo la evaluación incompleta de layout-motion inicial.
- [lyrics-local.py](lyrics-local.py) y [lyrics-local.txt](lyrics-local.txt): servidor HTTP local, exit0/PASS; reemplaza el escenario sin endpoint de lyrics-controller.
- [compact-visual.txt](compact-visual.txt), [lock-visual.txt](lock-visual.txt): exit0/PASS; segunda ejecución justificada por capturas no obtenidas en la tanda lógica.

Pruebas adicionales y evidencia dirigida:

- settings.cjs: [output-4zrib7e0.log](output-4zrib7e0.log); settings-integration.py: [output-dqilngl6.log](output-dqilngl6.log); settings-regression: [output-0lhg4eve.log](output-0lhg4eve.log). Todos PASS.
- verify-config.sh: [output-95wzp9i3.log](output-95wzp9i3.log), exit1 antes de ejecutar Node; QA-01.
- auth-backend.py: [output-3039n2a6.log](output-3039n2a6.log); auth-bridge.py: [output-e4z327d0.log](output-e4z327d0.log); lockscreen-launcher.py: [output-_d70th8i.log](output-_d70th8i.log); clipboard-regression.sh: [output-iox7qhmm.log](output-iox7qhmm.log). Todos PASS.
- [auth-transport.txt](auth-transport.txt): socket aislado + arranque y cuatro recargas PASS. [auth-prompt.txt](auth-prompt.txt): backend inyectado, foco/typing/cancelación/retry/reduced PASS.
- Node lyrics.cjs, media-source.cjs, surface-boundaries.cjs: PASS; [node-checks.txt](node-checks.txt).
- [services-repro.py](services-repro.py)/[services-repro.txt](services-repro.txt): asserts sobre código real y ejecutables falsos, SVC01/02/04/05 reproducidos 1/1.
- [config-run1.log](config-run1.log), [config-run2.log](config-run2.log), [config-run3.log](config-run3.log): borrador por QtTest + reemplazo externo + watcher; 3/3. [config-bound.log](config-bound.log): el editor acepta1e308.
- [launcher-probe.txt](launcher-probe.txt), [launcher-native.txt](launcher-native.txt), [launcher-native-observation.md](launcher-native-observation.md): cierre del proceso y funciones inversas, UI01/02.
- [accessibility-probe.txt](accessibility-probe.txt), [accessibility-wayland.txt](accessibility-wayland.txt), [brightness-probe.txt](brightness-probe.txt): UI03/04; acción Accessible aislada, no AT-SPI.
- [focus-native-state.json](focus-native-state.json): Escape real Wayland y estados antes/después, UI05; 2/2 por siete paneles, launcher control2/2.
- [native-smoke.json](native-smoke.json), [native-open-montage.png](native-open-montage.png), [native-escape-montage.png](native-escape-montage.png): 14 pares grim inspeccionados; incluyen escritorio personal, mantener evidencia local.
- [compact-detail.png](compact-detail.png), [lock-montage.png](lock-montage.png): capturas con datos simulados, inspeccionadas. No medición FPS ni bloqueo real.

Los `.raw.log` son originales preservados de output.py; `.txt` conservan la salida del runner (que puede usar RLE reversible) y la referencia del original. suite.json/extra guardan duraciones externas; no son tiempos de render.
