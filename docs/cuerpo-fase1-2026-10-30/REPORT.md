ESTADO: parcial — implementación y pruebas terminadas; comparación visual lado a lado con HTML y revisión humana de la transición pendientes.

ARCHIVOS:
- `bar/body/BodySprings.js`, `BodyBrain.js`, `BodyLight.js`, `BodyEngine.qml`, `BodyShader.qml`, `README.md`, `shaders/body.frag`, `shaders/body.frag.qsb`.
- `bar/body-demo.qml`, `bar/body-regression.qml`, `bar/tests/body-brain.cjs`.
- Append «Cuerpo» a `bar/TESTING.md`.
- Este directorio: informe, diez capturas finales, detalle adicional, logs, manifiesto de capturas, delta de estado y hashes de evidencia.

CRITERIOS:
1. **Probado** — qsb Qt 6 termina con exit 0 y sin salida; binario final de 9060 bytes. Comando reproducible en PRUEBAS.
2. **Probado** — Node pasa a–i, más reposo y música. `node.log`: `PASS: body a–i; muelles, interrupción, dt, sueño, toques, reduce, brote, luz, reposo y música`.
3. **Probado con límite** — `offscreen.log` pasa las pruebas del motor y registra explícitamente SKIP del shader porque el backend software deja ShaderEffect Uncompiled. `offscreen-opengl.log` pasa también con ShaderEffect Compiled y log vacío. Offscreen no es QA visual.
4. **Probado** — demo Wayland cargada, shader Compiled (valor 0), log del shader vacío en las diez escenas (`captures.json`). Sin warnings QML ni shader. `wayland.log` contiene dos avisos del entorno Qt: registro del portal D-Bus y foco text-input Wayland. No se ocultan ni se clasifican como errores del shader.
5. **Probado** — diez capturas nativas mediante grim en DP-1 (1920×1080, escala 1, ~240 Hz): reposo, curiosa derecha, tímida, dormida, contenta, 06/12/18/02 y música. Recorte final `680,50 560x100`, sin manipulación de píxeles. Escenas fijadas por IPC de prueba, no por movimiento físico del ratón. `captures.json` registra estado y tiempo de cada toma. La captura de reposo se hizo antes de terminar de asentarse; las escenas horarias posteriores muestran Timer activo.
6. **No verificado íntegramente** — inspeccionadas capturas Wayland: borde frío, brote derecho unido, encogimiento tímido, menor altura dormida y aura contenta/música. El navegador rechazó `file://…/isla-cuerpo.html` por política de URL; no se intentó eludirla. El contraste con la referencia fue de código, no una comparación visual lado a lado. No se afirma fidelidad visual aprobada.
7. **Probado por simulación / no verificado a ojo en movimiento** — QtTest conserva posición y velocidad al interrumpir ánimo, limita ΔhalfW a <1 px al siguiente paso y comprueba continuidad de dirección de luz al cambiar hora. Capturas estáticas no prueban continuidad temporal ni sustituyen revisión humana.
8. **Probado** — 31 avances / 1050 ms (~29,5 fps) en Timer de reposo; FrameAnimation apagada. Sin avances con active=false; ambos bucles apagados con reduceMotion. Prueba repetida en offscreen software, OpenGL y Wayland. No se midió consumo GPU.
9. **Probado dentro del alcance observable** — `status-delta.txt`: sólo entradas nuevas de esta tarea; ninguna entrada previa desaparece. `bar/TESTING.md` ya estaba modificado al inicio, por eso no figura como entrada nueva; se añadió la sección al final. No hubo operaciones de índice, commit ni push.
10. **Probado** — sin console.log de depuración ni colores hex en QML/JS de producción, UI española, sin dependencias nuevas ni imports multimedia en hojas. El console.log del test Node es su resultado de consola. README de 33 líneas. Qt6 qmllint exit 0, con aviso estático sobre PanelWindow; la misma instancia carga correctamente en Wayland.

PRUEBAS:
```sh
(cd bar/body/shaders && /usr/lib/qt6/bin/qsb --qt6 -o body.frag.qsb body.frag)
node bar/tests/body-brain.cjs
ISLA_CONFIG=/tmp/isla-body-test.json QT_QPA_PLATFORM=offscreen quickshell -p bar/body-regression.qml
ISLA_CONFIG=/tmp/isla-body-test-gl.json QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=rhi QSG_RHI_BACKEND=opengl quickshell -p bar/body-regression.qml
ISLA_CONFIG=/tmp/isla-body-wayland-test.json QT_QPA_PLATFORM=wayland quickshell -p bar/body-regression.qml
ISLA_BODY_TEST=1 ISLA_CONFIG=/tmp/isla-body-demo.json QT_QPA_PLATFORM=wayland quickshell -p bar/body-demo.qml
/usr/bin/qmllint bar/body/*.qml bar/body-demo.qml bar/body-regression.qml
/usr/lib/qt6/bin/qmllint bar/body/*.qml bar/body-demo.qml bar/body-regression.qml
```
Los cinco primeros comandos pasan con los límites anteriores. Demo cerrada después de las capturas.
El qmllint solicitado (`/usr/bin`, versión 1.0) devuelve **255 sin diagnóstico** con la lista de archivos; el de Qt6 devuelve **0**, con aviso `PanelWindow is not creatable` en `qmllint-qt6.log`.
Un intento exploratorio de offscreen Vulkan falló porque el plugin offscreen no crea instancia Vulkan; la validación final usa OpenGL y Wayland.

DECISIONES PROPIAS:
- S/K se llaman designScale/fusionRadius tanto en QML como en el bloque GLSL: QML rechaza propiedades que empiezan en mayúscula. Conservado el orden std140.
- La fórmula pedida para shadowA era transmisión del fondo HTML: usada literalmente como alfa opacaba toda la superficie. Se convirtió a `.5*(1-smoothstep(...))`, cero fuera de la sombra.
- Aura RGB multiplicada por auraA, para respetar premultiplicación. Revisión independiente detectó que el RGB literal podía exceder su alfa; corregido y shader recompilado, reiniciado y recapturado.
- Dirección de luz suavizada por muelles y normalizada antes del shader.
- Para respiración, tolerancia de reposo de hw/hh de 3,5·k px y 6·k px/s; el resto conserva 0,02 px y 0,2 px/s. Evita mantener FrameAnimation sólo por el destino oscilante. Atención, contenta y música conservan cuadros continuos.
- Temporizador único de vencimiento para dormir en auto cuando breathe=false y ya no corre ningún bucle. Movimiento reducido no lo activa.
- Umbral minúsculo para asentar atención exactamente; radio del brote cero al retirarse la inclinación, y núcleo recalculado tras integrar para evitar geometría obsoleta.
- `manualStep` y contador para QtTest; selector de escenas IPC sólo habilitado con ISLA_BODY_TEST=1. Facilita evidencia nativa sin tocar servicios reales.
- Revisión acotada de lectura por economy_researcher; hallazgo de premultiplicación corregido. Revisión cruzada Claude intentada, pero CLI devolvió `Not logged in · Please run /login`; no se presenta como revisión completada.
- Respetada la lista de archivos permitidos: no se actualizaron PROJECT_MEMORY/TASK_STATE. Este informe conserva decisiones, evidencia y pendientes.

DIFERENCIAS CON LA PÁGINA:
- Paleta Theme y textura del wallpaper, frente a PAL y paisaje procedural de exploración. Sólo se refracta el fondo, no las ventanas visibles detrás de la demo.
- Transparencia real, sombra como alfa y aura premultiplicada; en HTML se compone directamente sobre el fondo pintado. Aura final menos intensa por la corrección de cobertura.
- AA dependiente del DPR, coordenadas locales Qt, cuatro gotas reservadas e inactivas.
- Luz por hora local/teclado y controles de escritorio en lugar de slider y tarjetas HTML; sin integración en la pill real.
- Muelles y cálculos del HTML portados; respiración de reposo a ~30 fps en vez de rAF permanente. Bulto se apaga explícitamente al retirar atención.
- El encargo exige wallMix animado a 400 ms pero también rama `wallMix > .5`: se conserva esa rama, por lo que el cambio de fuente ocurre al cruzar el umbral, sin fundido real entre ambos fondos.
- Verificación local: Wallpapers.current contiene ruta absoluta (asignación de ruta/readlink -f); la demo la convierte a URL file. apply-wallpaper.sh delega a matugen/generate.py, líneas 387–391: awww img sin override de resize/gravity. `awww img --help` confirma crop por defecto. Cover centrado es compatible con ese escalado; el centrado no se comparó píxel a píxel en fondos de otra relación de aspecto. La imagen de refracción se carga reducida (960×540) según el encargo.

DUDAS:
- Falta abrir la referencia en un navegador autorizado y aprobar comparación visual lado a lado y continuidad en movimiento. La política del navegador impidió hacerlo aquí.
- Diferencias de fórmula/nombres descritas arriba resuelven contradicciones técnicas del encargo. El plan permite margen ≥80·S, mientras el encargo pide 90·S y coloca cy=90·u: la demo sigue esa posición explícita; las capturas no muestran cortes del cuerpo.
