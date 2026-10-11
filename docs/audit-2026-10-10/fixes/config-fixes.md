# CFG-01 y CFG-02: corrección y comprobación

- **CFG-01:** `Settings.js` limita `uiScale` a 0.25–3 y `topGap`/`appGap` a 0–4. Los tres defaults siguen en 1; el archivo personal actual validó sin cambios. `settings.cjs` y el IPC comprueban cada máximo y rechazan `1e308`. Los límites mantienen finita la geometría de `IslandReserve` en alturas físicas de monitor. Al tener mínimo y máximo, Edots presenta estos tres ajustes como controles deslizantes existentes.
- **CFG-02:** `SettingsPage` guarda el valor base por borrador y deriva un conflicto si cambia el valor efectivo de ese campo. Muestra un aviso, conserva el texto y bloquea Enter/Guardar; una edición nueva toma el valor recargado como base. Restablecer o Descartar limpian el borrador. No se cambió el contrato de recarga ni el guardado atómico de `Config`.

## Pruebas

- `node bar/tests/settings.cjs`: PASS ([log](config-unit.txt)).
- `settings-integration.py` sobre copia temporal de `bar/`: PASS IPC y fixture `config-draft-conflict-regression.qml` ([log](config-integration.txt)). QtTest escribió en el campo real; Python sustituyó `ISLA_CONFIG` externamente; FileView recargó; Enter no sobrescribió; otra edición permitió guardar; descarte desde otro conflicto y clave desconocida también pasaron. La copia aisló la prueba de recargas automáticas causadas por ediciones concurrentes del repositorio.
- `settings-integration.py` sobre otra copia con `QT_QPA_PLATFORM=wayland` e `ISLA_DRAFT_CAPTURE_DIR`: PASS ([log](config-wayland.txt)); captura revisada del campo, el borrador y el aviso completo ([PNG](config-draft-conflict-wayland.png)). Eventos generados por QtTest en ventana Wayland.
- `settings-regression.qml` offscreen con `ISLA_CONFIG` temporal: PASS ([log](config-edots.txt)).
- `sh bar/tests/verify-config.sh`: PASS ([log](config-gate.txt)).
- `qmllint bar/settings/SettingsPage.qml bar/config-draft-conflict-regression.qml`, `python -m py_compile bar/tests/settings-integration.py` y `git diff --check`: PASS sin diagnósticos.

La primera ejecución de la integración en el árbol compartido perdió una respuesta IPC durante una recarga automática de Quickshell; la ejecución aislada pasó. La primera versión de la fixture usó un carácter acentuado que `QtTest.keyClick` no admite; se cambió a texto ASCII y pasó. Ninguno de esos fallos permanece. Un archivo previamente aceptado con valores superiores a los nuevos máximos ahora se rechaza como documento completo; los valores personales actuales son 1 en los tres campos. No se probaron clics físicos ni la app Edots completa; la captura Wayland corresponde a una ventana de prueba con `SettingsPage`.
