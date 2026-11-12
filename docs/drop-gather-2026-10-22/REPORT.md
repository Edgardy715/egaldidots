# Gotas: brote y recogida sin «cuadrado» (2026-10-22)

Petición: «al salir y regresar la gota se ve como un cuadrado»; reproducir en
vivo settings o una gota con canción simulada y corregir lo que se vea.
Continúa docs/drop-neck-2026-10-22/ (cuello GPU).

## Lo que se veía (Wayland real, grim ~60 fps, `tools/cap.sh`)

- Settings (centrada 1000×700) y sesión (lateral 640×470) salían y volvían
  como tarjeta: unidas a la pill hasta ~515×366 al nacer y ~587×393 al volver;
  entraban en la pill a ~266×154, más anchas que ella (cuernos/bloque).
  `before-settings-open.webp`, `before-settings-close.webp`.
- Con recogida añadida pero destino de retorno centrado = cápsula del ancho de
  la pill (110×38): unida bajo la pill dibujaba un trapecio de fondo plano a
  través del casco del cuello. `mid-capsule-return-trapezoid.webp`.
- Sesión al recogerse: rectángulo de ~170×120 con esquinas 24 ya sin
  contenido, se leía como baldosa. `before-session-gather.webp`.

## Cambio (bar/components/FluidCompanion.qml)

- Fase `brotando`: una tarjeta expandida nace como yema redonda (moduleH) a
  1.45·(r_pill+r_yema) del centro de captura, se separa y sólo entonces florece
  a tarjeta (`media`). Muelle ω26 ζ0.96 (ζ=1 exacto da NaN en spring()).
- Fase `recogiendo`: al cerrar, la tarjeta se recoge hacia esa yema y vuelve
  (`returnHome`) al bajar de gatherSize 66·s. Muelle ω19 ζ0.98.
- Retorno siempre redondo (returnW = returnH): se hunde en la pill como gota con
  meniscos cóncavos. Revierte «cápsula inscrita» del 2026-10-12; aquella queja
  («bola») era el editor encogiéndose visible; ahora el contenido ya se ha
  desvanecido antes y la mancha no lleva contenido.
- cardRadius: sobre 24 interpola con max(size², 4·contenido); tarjetas vacías
  de tamaño medio son mancha, esquinas 24 antes de contenido >0.25.
- Pruebas actualizadas: centered-companion (brote, recogida, retorno redondo) y
  companion-continuity (sólo se infla el radio con contenido tenue).

## Evidencia (después)

- `after-settings-birth.webp`: gota con cuello que se pellizca, yema, floración.
- `after-settings-close.webp`, `after-settings-contact.webp`: mancha que sube,
  cuello fino, meniscos, absorción redonda; sin trapecio.
- `after-session-birth.webp`, `after-session-gather.webp`: igual en lateral.
- Media con reproductor MPRIS falso y mudo (`tools/fake-mpris.py`, nombre
  `islasim`; no toca la reproducción real): `media-sim-compact-birth.webp`
  (nacimiento compacto), `media-sim-open.webp`, `media-sim-close.webp`.
  Media no usa brote: la tarjeta crece desde la gota ya separada.
- Offscreen PASS: absorption, centered-companion, companion-continuity,
  media-motion, session-companion, settings-companion (0 NaN). Wayland PASS:
  recording-drop, layout-interruptions.

## Revisión independiente (isla-revisor)

- Grave, corregido: reabrir en retornando/absorbiendo saltaba a `media` y la
  tarjeta crecía unida (medido hasta 601×425 centrada, 219×168 lateral, esta
  con cristal apilado sobre la pill). Ahora `bloom()` único (reapertura y
  syncHoverSize, que recibe `expanded` después de `open`): si está unida, dentro
  de la pill u oculta, vuelve a `brotando` con la velocidad actual. Tras el
  arreglo, máx. unida ≈ yema (40×40). `after-reopen-during-absorb.webp` en vivo.
- Menor, corregido: con bodyBusy la yema salía al primer cuadro; `brotando`
  termina sólo con stretch ≥ 1.30 (o asentada).
- centered-companion comprueba que la reapertura unida brota y florece libre.

## Límites

- Al primer contacto del retorno (1–2 cuadros, ~30 ms) el cuello aún es fino y
  la gota entra con lados casi verticales; luego aparecen los meniscos.
- Tarjeta lateral grande (>~200 px) conserva esquinas 24 mientras se encoge:
  es tarjeta, no gota, por diseño (contenido legible).
- grim a ~60 fps con compositor real; no es medición de frame pacing.
