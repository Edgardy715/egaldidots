# Material vivo · informe

ESTADO: parcial (todo implementado y probado salvo el coste de GPU en ms/cuadro, no verificado; sin QA Wayland)

## Lo que ya existía (no duplicado)
- `MediaPalette.qml`/`artwork_palette.py`: color dominante (`extracted`); ahora se instancia también desde `Pill`.
- Arte ambiental W4 en `body.frag` (`artFirst/artSecond`), cruce de portada propio: no se tocó.
- Cava en el cuerpo: `advanceDecor`/`decorMoving` ya era el reloj de decoraciones; se reutiliza como reloj de graves.
- Respiración limitada a 1,1 px: no se tocó (el brillo de graves no mueve geometría).

## ARCHIVOS
- bar/body/WaterReactive.js (nuevo, reglas puras)
- bar/body/PillBody.qml:71-143, 258-268 (tinte, adjust, onda, graves, ligaduras)
- bar/body/BodyShader.qml:53-75 (uniformes + renderInputs)
- bar/body/shaders/body.frag:38-42, 123, 180-190; body.frag.qsb recompilado
- bar/Pill.qml:501-505, 766-768; bar/Singletons/Cava.qml:48,51,96,107 (`bass`)
- bar/Singletons/Settings.js:21; bar/settings/EdotsWindow.qml:86; bar/i18n/en.js
- bar/water-reactive-regression.qml (nuevo); bar/TESTING.md y bar/body/README.md (añadido)

## CRITERIOS
1. Tinte — probado: 10 portadas (blanco, negro, saturadas) x 5 juegos de caras (oscuro, claro, extremos, tema real) -> mezcla 0,12 máx; contraste mínimo tras tinte 7,5 (real) vs 11,0 antes; nunca < min(antes, 7). Cruce con SpringValue (token `level`), sin rebase (nota: no el reloj NumberAnimation de ArtworkImage).
2. Onda — probado (GL): ~450 ms, reinicio sin apilar, 0 cuadros tras terminar; amplitud 10·delta acotada a 1.
3. Graves — probado: ataque 40 ms / caída 220 ms exactos en el test numérico, ganancia 1..1,08; pausa y silencio: 0 cuadros (tras <=2 de asentamiento al cambiar de estado).
4. Fallbacks — probado: reduceMotion, waterBody=false, shader roto y software sin onda, graves ni tinte.
5. Presupuesto — parcial. Probado: 0 cuadros/s en reposo; cuadros sólo con datos de Cava o durante el anillo. NO VERIFICADO: <= 0,15 ms/cuadro de GPU. Intenté A/B (qsb original vs nuevo, GTX 1660 Ti, GL offscreen): `grabWindow` se cuelga offscreen y el contador de `frameSwapped` salió incoherente (A 2,9 fps vs B 22,7 fps con el mismo QML; ondas 0,8 fps en ambos), así que no lo cito como medida. Estimación analítica (no medida): el bloque nuevo son unas decenas de ALU por fragmento sobre ~8 mil píxeles, y el anillo sólo se ejecuta con `rippleAmp>0`.
6. qsb compila (24368 bytes); regresiones PASS salvo `cava-envelope` (ver abajo, falla igual antes de editar).

## PRUEBAS
- `python /tmp/gestos-f1-validate.py mv1 bar/water-reactive-regression.qml` (software) -> exit 0, reglas y fallbacks PASS, parte viva no verificada.
- Igual con `QT_QUICK_BACKEND=rhi QSG_RHI_BACKEND=opengl` -> exit 0, 6 bloques PASS.
- water-body, water-drop, water-decor, body-drop/events/messenger/pill, body, cava-center, cava-response -> exit 0; water-body y water-drop con GL -> exit 0.
- cava-envelope -> exit 1 "initial silence must not publish frames": igual en 3 ejecuciones antes de editar (preexistente).
- `node bar/tests/body-brain.cjs` -> PASS.
- qmllint: sin avisos nuevos en lo tocado (los de EdotsWindow son previos; el test usa un objeto dinámico como water-body-regression).

## DUDAS
- Guarda: interpreté "contraste actual" como min(actual, 7); con estas caras la guarda casi nunca se activa (el tinte 12 % ya cumple).
- Cruce de pista con SpringValue y no con el reloj de portada; ¿aceptable?
- Con reduceMotion no hay tinte (todo el cuerpo cae a PillMaterial). ¿Se quiere tinte estático ahí?
- Dirección de la onda: izquierda a derecha asumida (el icono está a la izquierda).
- Graves quedan activados por defecto sin medir GPU; si prefieres la regla estricta, cambia el default en Settings.js:21.
- QA Wayland pendiente (brillo, tinte, anillo); sin commit ni push.
