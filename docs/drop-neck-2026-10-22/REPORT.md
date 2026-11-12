# Cuello GPU de gotas (2026-10-22)

Petición: tragar/expulsar gotas (media, grabación, sesión, settings) más fluido,
discreto y limpio, con menos CPU/memoria.

## Defectos de partida (A/B en Wayland real)

- El cuello `FluidMetaballBridge` (CurveRenderer) se veía como barra opaca
  oscura sobre el vidrio translúcido y teselaba la curva en CPU cada frame.
- La máscara inversa del solape (`OpacityMask`, maskSource fuera de escena)
  nunca renderizaba: la gota se veía doble dentro de la pill (lente oscura).
  Además sólo se activaba en settings centrada al retornar.

## Cambio

- `bar/fluid/FluidNeck.qml` + `shaders/fluid_neck.frag`: unión smin de las SDF
  de pill y gota pintada sólo fuera de ambos cuerpos, mismo degradado/alfa de
  vidrio, recortada al casco convexo exacto de ambos rounded box (búsqueda
  ternaria de 14 pasos sobre la interpolación centro/extensión/radio, sólo en
  píxeles candidatos). Sin casco, smin inflaba lados convexos (elipse, extremo
  cuadrado al absorber); con la cápsula entre núcleos de la 1.ª versión, una
  tarjeta centrada ancha recibía una columna recta de ~40 px.
- `shaders/fluid_cut.frag` como `layer.effect` (smooth) del módulo de gota:
  recorta con la misma SDF la parte dentro del cuerpo receptor, para todas las
  gotas mientras solapan unidas o en nacimiento/separación/retorno/absorción.
  Sin textura de máscara ni Qt5Compat en FluidCompanion.
- Revisión independiente (isla-revisor) y correcciones: material por extremo
  (alfa por readingExposure, degradado de 3 paradas y banda de acento de pill y
  gota, fundidos por d1/(d1+d2)); halo/borde/brillo de la gota a cero en los
  7·s previos al contacto (`edgeClearance`), así el layer no los corta ni hace
  pop; bordes AA contiguos con complemento compensado x=(1-c)/(1-c·a) en cuello
  y recorte: la línea dorada de fondo en la costura pill/gota pasa de +6–10 a
  +2–4 niveles de gris.
- PillMaterial: la sombra sólo crea layer/MultiEffect con opacidad > 0
  (≈8 instancias por pantalla en compacto ya no reservan FBO).
- TopWorkspaceRail: la lente integrada ya no pasa por un MultiEffect inerte.

## Evidencia

- `before-static.webp` / `after-static-right.webp` / `after-static-left.webp`:
  stretch 0.55, 0.8, 1.0, 1.06, 1.12, 1.18, 1.24, 1.32 (orden fila a fila).
- `after-centered.webp`: tarjeta centrada 220×44 bajo pill 120×38, mismos
  stretch: menisco a todo el ancho con filetes, sin columna.
- `after-birth-return.webp`: muelle real a 25 ms por cuadro (F5–F19 nacimiento,
  F31–F55 retorno/absorción). `seam-before-after.webp`: fila superior antes de
  la compensación AA, inferior después (F13, F33, F37, F41).
- Fixture: `fixture/` (Wayland, componentes reales, fondo con rayas).
  `DROP_QML=drop-centered.qml ./run.sh out 0 0`; espera `cfg/isla.json` junto a
  él; el modo legacy apuntaba a una copia temporal ya borrada.
- Regresiones PASS: absorption, centered-companion, companion-continuity,
  media-motion, session-companion, settings-companion. qmllint sin avisos nuevos.

## Límites

- Un `reload` de Quickshell no recarga un .qsb ya cacheado por URL en el
  proceso: tras recompilar shaders hay que reiniciar quickshell (los fixtures
  son procesos nuevos). Mientras tanto el log avisa `'colorTop' does not have a
  matching property` y el cuello en vivo no se pinta.
- Costura residual de 2–4 niveles de gris: el alfa real de cada cuerpo varía
  con degradado y brillo; la compensación usa el alfa medio.
- La pill se supone en reposo para su banda de acento (0.017); despierta es
  0.066 en el extremo de la pill. Diferencia leve dentro del cuello.

- Queda un tono de 1 px donde termina el InnerGlow de la pill bajo la gota
  recortada; no es vidrio doble.
- QA en vivo: apertura/cierre de sesión real sin errores en el log, pero grim
  (~16 fps) no resuelve los ~150 ms unidos; la sesión abre ya expandida.
  Media/grabación compactas en vivo no capturadas (no se tocó la reproducción).
