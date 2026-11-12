# Música absorbida en wallpapers · 2026-10-18

Causa confirmada: condición `root.width > 1000 * root.s` en resumen y título;
cuerpo estándar1000 menos márgenes40 ofrece960. La ruta absorbía correctamente
la gota, pero la cabecera ocultaba su destino. Se corrige sólo WallpaperView:
resumen visible con mediaHas, texto adaptado al ancho y cover conservado estrecho;
título respeta borde real del resumen. Launcher/overview sin cambios.

Comprobaciones:
- wallpaper-media-header-regression.qml Wayland PASS: ancho real960, UI1/0.8,
  fuente1/1.5, estrecho640 y sinplayer. Capturas wallpaper-media-*.png inspeccionadas.
- media-dock-surfaces-regression.qml Wayland PASS: fuerza gota de fixture presente,
  verifica idle antes de abrir wallpaper/overview/launcher, no reaparece mientras
  abierto, cierre y siguiente ruta normal/reduced. Sin acciones sobre reproducción.
- verify-config.sh PASS, diff--check PASS. Qt6 lint sin errores, warnings
  unqualified de WallpaperView preexistentes; no se refactoriza archivo por esto.

Logs: ~/.cache/codex-economy/output-bzdopez4.log (cabecera),
output-43aayod1.log (docking), output-94_o407a.log (gate).
Sin cambio de fondo ni reproducción personal, sin FPS ni análisis de todos los
frames. Captura de cabecera usa música y biblioteca vacía de fixture. Cambio
acotado sin revisión independiente adicional; QA nativa y regresión determinista.
