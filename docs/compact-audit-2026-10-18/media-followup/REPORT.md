# Aro compacto y neón CAVA pequeño

Petición del2026-10-18. Corregido hasProgress:false explícito en compacto: ahora
TopBarModules entrega progreso/capacidad desde MediaSession a la portada.
No se añade reloj; progreso de sesión conserva límites y pausa.

IslandMediaVisualizer, compartido por compacto y FluidMediaCompanion en split,
añade una única capa MultiEffect sobre las cinco barras. Su emisión toma el
acento musical y energía RMS; silencio, pausa, ocultación y reducido la apagan.
El eje, altura, ancho y recorte siguen intactos.

- Compact-island offscreen y Wayland PASS: aro habilitado/progreso, seek en pausa
 120/240=0.5 y desaparición con duración0, más regresiones existentes.
- CAVA Wayland PASS:120alturas a escala1/1.25, deriva máxima5.68e-14; activación
 por energía y desactivación en pausa/reducido.
- qmllintQt6 exit0 (avisos no cualificados heredados), verify-config y diff-check PASS.
- Capturas inspeccionadas: compact-ring.png y cava-neon-detail.png. Esta última
 es ampliación5× de escena Wayland RGBA compuesta sobre #242424 para leer el halo;
 no se presenta como captura del material final del compositor.

Sin mediciónFPS/GPU ni reproducción personal alterada. Los guards del aro
conservan canSeek de MediaSession. Cambios previos de auditoría preservados.
