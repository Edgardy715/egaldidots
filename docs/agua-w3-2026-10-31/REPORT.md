ESTADO: parcial

Implementación W3 terminada y validación software en PASS salvo el fixture que
requiere PanelWindow. No se declara aceptación visual ni de rendimiento: RHI
no inicia en este entorno. QA Wayland y revisión cruzada de Claude pendientes.

ARCHIVOS:

- `bar/body/PillBody.qml`: dominio compartido, coordenadas y cinco entradas.
- `bar/body/BodyShader.qml`: diez uniforms y su invalidación de caché W1.
- `bar/body/shaders/body.frag` y `body.frag.qsb`: cajas redondeadas y unión suave
  antes del único cálculo de relleno, borde, normales, luz y sombra.
- `bar/components/FluidCompanion.qml`: datos del campo, muelle de cuello y
  Loader de respaldo; reloj geométrico existente, sin cambiar sus tiempos.
- `bar/Pill.qml`, `bar/windows/IslandOverlay.qml`: sólo cableado de las cinco gotas.
- `bar/water-drop-regression.qml`: nuevo fixture determinista y rama de píxeles RHI.
- `bar/body/README.md`, `bar/TESTING.md`: contratos, comandos y límites.
- `docs/agua-w3-2026-10-31/REPORT.md`: este informe.

CRITERIOS:

1 — probado (contrato/software y compilación); render RHI no verificado.
`water-drop` comprueba que los Loader de PillMaterial y FluidNeck están inactivos,
con item=null y sin instancias legacy, y que el layer de recorte está apagado.
Verifica las cinco entradas, caja/radio, coordenadas derecha/izquierda/centrada y dominio con margen,
incluido el brote desplazado al nuevo origen. El campo recibe cinco parejas
vec4(caja)/vec2(radio,fusión); el shader compila con qsb. La disponibilidad fingida
del fixture sólo comprueba el contrato, no renderiza agua en software.

2 — no verificado.
Una sola evaluación de material sigue a la unión en scene(); no hay placa ni
cuello dibujados aparte en la rama de agua. La prueba RHI captura una fila
horizontal que cruza la unión (y=80, x=150..205): luminancia Rec.709 adyacente
<=32/255 y centro del hueco >50/255. El umbral admite lente, gradiente y dithering;
no certifica todo el contorno. No pudo ejecutarse por falta de contexto OpenGL.
Sombra/borde/luz continuos, temas y ausencia visual de costura requieren Claude.

3 — probado para histéresis e interrupción; límite literal entre cuadros no verificado.
Conserva umbrales de nacimiento <1.02 y separación >1.30; al retornar se reúne
por debajo de 1.30 (también conserva el vínculo mientras existe solape). La
prueba comprueba crecimiento de fusión y preservación de valor/velocidad al
romper el vínculo. La fusión usa Motion.strokeSpring.lift (W1), manualStep,
y se integra desde el FrameAnimation existente. Abrir→cerrar→abrir durante el
movimiento conserva posiciones y velocidades; las comparaciones instantáneas
exigen <=1 px y preservación exacta de vx/velocidad del cuello. El recorrido
normal medido a 60 Hz alcanzó 49.19248184553669 px/cuadro en el fixture de tarjeta
expandida. No se presenta ese recorrido como salto ni como un PASS del límite
literal de 1 px entre cuadros. No se cambian los muelles de traslación/tamaño
para forzar ese límite. La continuidad en imágenes renderizadas queda pendiente.

4 — probado software/off/reduceMotion/disponibilidad; error real no verificado.
Al desactivar disponibilidad vuelven ambos Loader; con renderer software real
se conserva el respaldo. waterBody=false también lo restaura. reduceMotion
resuelve posición/tamaño a destino y detiene integración/reloj sin esperar
muelles. La rama RHI incluye error real de fragmentShader y vuelta al respaldo,
pero no pudo ejecutarse. Las regresiones ejecutables permanecen en PASS.
settings-async está bloqueada por su backend PanelWindow, antes de cargar el test.

5 — probado para quietud CPU/software; caché RHI no verificado.
Tras asentarse se habilita el reloj normal (manualStep=false), se comprueba que
no corre y que no cambia geometría durante 100 ms. No se habilita layer de la
gota en la rama compartida. water-body R1 mantiene PASS para seis cuadros de
quietud y render directo sin layer. Las nuevas entradas invalidan renderInputs;
la rama RHI verifica textura live:false, reloj detenido e invalidación por
cambio de xPos, pero no llegó a ejecutarse.

6 — probado estructuralmente; rendimiento real no verificado.
No se añaden FrameAnimation, Timer ni bucles por cuadro al código de producción.
El cuello se integra en el reloj de gota existente. El shader añade cinco llamadas
fijas con descarte de cajas vacías; todo el campo pasa por el mismo material.
El qsb crece de 13210 a 15535 bytes. No son medidas de GPU: faltan CPU/PSS de
sesión, utilización GPU, frames perdidos y estabilidad 30 min. El dominio único
puede abarcar una tarjeta centrada y amplía la textura congelada; coste pendiente.

PRUEBAS:

Entorno: raíz `/home/zdito/.config/quickshell`, ISLA_CONFIG temporal inexistente
`/tmp/agua-w3-missing.json`, XDG_RUNTIME_DIR=`/tmp/agua-w3-runtime` (0700),
XDG_CACHE_HOME=`/tmp/agua-w3-cache`, QT_QPA_PLATFORM=offscreen,
QT_QPA_PLATFORMTHEME vacío. Cada prueba lanza un proceso nuevo. No se escribe
configuración personal ni se reinicia/toca la shell real.

- `(cd bar/body/shaders && /usr/lib/qt6/bin/qsb --qt6 -o body.frag.qsb body.frag)`
  → salida 0; binario actualizado.
- `QT_QPA_PLATFORM=offscreen timeout -k 5 90 quickshell -p bar/<x>-regression.qml`
  con el entorno temporal anterior → **17 PASS explícitos, sin FAIL, salida 0**:
  water-body (incluido R1), water-drop, body-pill, body, frame-time, pill-geometry,
  pill-composition, content-hold, surface-swap-close, surface-materialize,
  absorption, centered-companion, companion-continuity, media-motion,
  notification-drop, session-companion y settings-companion.
- `rg -l 'FluidCompanion|FluidNeck|FluidMediaCompanion' bar/*regression*.qml`
  → además de los anteriores, settings-async. Intentado: salida 255,
  `settings-async-regression.qml[12:5]: No PanelWindow backend loaded.`
  Bloqueo de entorno; no es un PASS ni un fallo de aserción de W3.
- `QT_QUICK_BACKEND=rhi QSG_RHI_BACKEND=opengl` más el entorno offscreen y
  `timeout -k 5 90 quickshell -p bar/water-{body,drop}-regression.qml`
  (dos lanzamientos) → ambos salida 255 antes de las aserciones:
  `QRhiGles2: Failed to create context`, `Failed to initialize graphics backend
  for OpenGL.` No existe `/dev/dri`; no se intentó usar la sesión Wayland real.
- `node bar/tests/body-brain.cjs` → 3 PASS, salida 0.
- `/usr/lib/qt6/bin/qmllint bar/body/PillBody.qml bar/body/BodyShader.qml
  bar/components/FluidCompanion.qml bar/Pill.qml bar/windows/IslandOverlay.qml
  bar/water-drop-regression.qml` → salida 0, sin errores; 34 advertencias en
  IslandOverlay (PanelWindow/unqualified access en líneas existentes).
- `git diff --check` → PASS.
- Lectura independiente economy_researcher de FluidCompanion/PillBody/Pill/
  IslandOverlay y BodyShader → sin hallazgos confirmados; no ejecutó pruebas
  ni sustituye revisión de Claude o QA visual.

Logs recuperables de esta sesión: `/tmp/agua-w3-<x>-sw.log`,
`/tmp/agua-w3-water-{body,drop}-rhi.log`, `/tmp/agua-w3-test-results.json`,
`/tmp/agua-w3-cache/codex-economy/output-l7dy4z4a.log` (qmllint).
El wrapper de logs inicialmente no pudo escribir en ~/.cache (read-only);
se repitió con XDG_CACHE_HOME temporal y terminó correctamente.

No se modifica Settings, BodyEngine, FluidMediaCompanion, PillMaterial ni
FluidNeck. El contenido conserva sus controles/arte compacto; los efectos de
arte ambiental y recepción alojados en el PillMaterial retirado de la gota
quedan para W4. No se aborda Sol/W2 ni retirada del respaldo/W5. PROJECT_MEMORY,
TASK_STATE, docs previos y :memory:.ses quedan intactos por la allowlist explícita.
Sin commit ni push. Offscreen no es QA visual.

DUDAS:

- Claude: ejecutar la rama RHI y QA Wayland de unión/borde/luz/sombra, ida/vuelta,
  interrupción y caché (incluyendo gotas izquierda, centrada y notificación).
- Confirmar si “<=1 px entre cuadros” exige desplazamiento absoluto o ausencia
  de discontinuidad añadida: el movimiento normal existente supera ese valor.
- Ejecutar settings-async con backend PanelWindow disponible y medir coste GPU/
  CPU/PSS antes de cerrar W3. No se activa waterBody por defecto.
