# Rail workspaces · expansión 2026-10-18

Petición: evitar salto al superar workspace5, con continuidad como panel apps.
TopWorkspaceRail no tenía transición de ancho; TopSystemStatus usa
SmoothedAnimation/Motion.morph. Aplicado mismo patrón al rail. Fits usa destino,
selección acotada al ancho actual, nuevas celdas se revelan al disponer de espacio.
Cambios rápidos retargetean; hidden/reduced/animateChanges=false resuelven ancho.
TopBarModules propaga la preferencia existente animateChanges; no nuevos ajustes.
Se preservaron modificaciones anteriores de tamaño de lente integrado y urgent.

Pruebas: workspace-width-regression.qml Wayland PASS5→6, posición intermedia,
límite lente, inversión9→5→8, split/integrated, reduced durante resize, ocultar,
deshabilitar. Capturas start/mid/end inspeccionadas. top-workspace-motion-regression
Wayland PASS selección/hover/retarget/hidden/reduced. compact-island-regression
PASS offscreen invariantes actuales, módulos/overflow/panels/layout. Gate/lintQt6
y diff--check PASS. Sin cambios al workspace real ni FPS/AT-SPI.

Logs: output-_vynxsdn.log (resize), output-mrl04p7d.log (lente),
output-8bo11oj5.log (compacta), output-yims_hht.log (lint) en cache codex-economy.
Probe temporal del host compacto confirmó que conserva su gate de contenido al
quedarse sin espacio; no certifica exposición continua de todos los módulos
compactos al cambiar su presupuesto. No se alteró ese contrato de seguridad.
No revisión independiente adicional: cambio local con regresión y QA nativa.
