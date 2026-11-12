# Agua W0/W1 · ronda 1 · 2026-10-31

ESTADO: parcial

Correcciones 1–8 implementadas. Nueve fixtures pasan en software; falta ejecutar
la rama RHI, capturar Wayland y medir la shell real. Default waterBody=false.
BASELINE.md conserva W0, registrado antes de editar. Este informe sustituye el
estado inicial W1; snapshots previos en /tmp/agua-before y /tmp/agua-r1-before.

ARCHIVOS:

- bar/body/PillBody.qml, BodyShader.qml, BodyEngine.qml
- bar/body/shaders/body.frag y body.frag.qsb
- bar/body/README.md
- bar/Pill.qml (sólo cableado de PillBody/PillMaterial)
- bar/components/PillMaterial.qml
- bar/Singletons/Settings.js
- bar/TESTING.md (append)
- bar/water-body-regression.qml
- docs/agua-w1-2026-10-31/BASELINE.md y REPORT.md

En R1 no se modificaron BodyEngine, Settings ni BASELINE.

CRITERIOS:

1. **Probado en software, no verificado RHI:** waterBody=false con ISLA_CONFIG
   temporal: mismos ocho PASS que W0 (body-pill sólo fallback, frame-time,
   pill-geometry, pill-composition, pill-interface, content-hold,
   surface-swap-close, surface-materialize). Sin configuración personal.
2. **Probado parcialmente:** water-body-regression PASS software. Añade controles
   R1 de decoraciones conservadas (2), seis cuadros quietos/render sin layer (3),
   muelle interrumpible de bulto/gota/geometría expresiva (5), inputs null (8).
   Comprueba shadowExposure=reading*edgeExposure y cero en reposo (1, cableado).
   **No verificado RHI:** grabImage comprueba alfa de sombra ≤0.14 independiente
   del aura, escala de exposición y reposo sin sombra (1), y dithering del
   interior barato constante en el tiempo (7). La rama RHI también comprueba
   rutas launcher/media/calendar/utils, exposición constante, sin FBO de sombra
   del material, caché quieta, alineación física, respiración sin alternar caché,
   contenta sin layer, fallback por error real, reduceMotion e interrupciones.
   Esas aserciones existen pero no se ejecutaron en este entorno.
3. **No verificado:** sin PNG antes/después ni secuencia ≥6 cuadros. Wayland
   rechaza conexión (Operation not permitted); grim falla «failed to create
   display». Reposo, launcher, media, calendario, notificación, claro/oscuro,
   banda/destello, sombra y legibilidad quedan pendientes.
4. **No verificado:** sin acceso GPU/compositor/PID de qs -d en W0 ni R1.
   Cero avances adicionales del motor con entrada fija asentada es una prueba
   determinista, no una medida de GPU, CPU/PSS ni cuadros perdidos.
5. **Probado:** qsb exit 0, body-brain tres PASS, qmllint sin errores nuevos.
   Única advertencia: BodyEngine.qml:78 state oculta QQuickItem.state, ya en W0.
6. **Probado respecto al status inicial:** 700 entradas W0, 702 W1/R1; ninguna
   retirada. Altas sólo water-body-regression.qml y este directorio. Comparación
   de snapshots R1: sólo archivos permitidos; no add/commit/stash/checkout/reset/
   push. Status no certifica hashes de los 700 cambios ajenos preexistentes.

PRUEBAS:

Entorno: XDG_RUNTIME_DIR=/tmp/agua-runtime (0700), XDG_CACHE_HOME=/tmp/agua-cache,
QT_QPA_PLATFORMTHEME vacío, QT_QPA_PLATFORM=offscreen,
ISLA_CONFIG=/tmp/agua-r1-config.json inexistente. Sin guardar config personal.
Cada fixture con timeout 45s; se exige PASS explícito, sin FAIL y exit 0.

| Comando desde raíz | R1 |
| --- | --- |
| qs -p bar/water-body-regression.qml | PASS R1 + PASS software; RHI no verificado |
| qs -p bar/body-pill-regression.qml | PASS fallback |
| qs -p bar/frame-time-regression.qml | PASS tiempo determinista |
| qs -p bar/pill-geometry-regression.qml | PASS |
| qs -p bar/pill-composition-regression.qml | PASS |
| qs -p bar/pill-interface-regression.qml | PASS |
| qs -p bar/content-hold-regression.qml | PASS |
| qs -p bar/surface-swap-close-regression.qml | PASS |
| qs -p bar/surface-materialize-regression.qml | PASS |
| node bar/tests/body-brain.cjs | tres PASS |
| sh bar/tests/verify-config.sh | PASS |
| /usr/lib/qt6/bin/qmllint (lista inferior) | sin errores nuevos; state preexistente |
| cd bar/body/shaders && /usr/lib/qt6/bin/qsb --qt6 -o body.frag.qsb body.frag | exit 0 |

Lista lint: bar/body/PillBody.qml bar/body/BodyShader.qml bar/body/BodyEngine.qml
bar/components/PillMaterial.qml bar/Pill.qml bar/water-body-regression.qml.
Logs /tmp/agua-r1-{water-sw,body-pill,frame-time,pill-geometry,pill-composition,
pill-interface,content-hold,surface-swap-close,surface-materialize,lint}.log.

Intentos W1 RHI/OpenGL, Mesa surfaceless y Vulkan lavapipe fallaron antes de QML
por backend no inicializable. /dev/dri ausente; nvidia-smi no comunica con driver;
pgrep -ax qs sin shell real accesible. No se repiten como supuestas medidas.
gpu-recording.py usa grabador falso; qml-performance.py no llegó a QML_READY.
BASELINE.md conserva comandos y fallos concretos W0.

RENDIMIENTO:

| Medida real | W0 | W1 R1 |
| --- | --- | --- |
| GPU reposo | no verificado | no verificado |
| GPU launcher quieto | no verificado | no verificado |
| GPU morph reposo→launcher→reposo | no verificado | no verificado |
| Cuadros perdidos morph | no verificado | no verificado |
| CPU/PSS shell qs -d | no verificado | no verificado |

No puede concluirse igualdad o mejora. Si empeora, medir captura y liberación de
textura en hardware; conservar render directo durante cambios y comprobar coste
de cachear reposo. No aumentar resolución sin medir memoria/ancho de banda.

DECISIONES PROPIAS:

- R1.1: shadowExposure independiente; alfa min(shadowA,0.14)*shadowExposure,
  reading*edgeExposure, cero en reposo/auth. outsideOpacity=0 sólo apaga aura.
  Margen 90*s existente. El tope queda bajo ignore_alpha=0.15; compositor real
  pendiente. Sustituye la sombra exterior desactivada del primer W1.
- R1.2: materialHalo, InnerGlow, franja y tinte de acento conservan sus reglas
  originales. Sólo ceden relleno, borde/base/sheens y sombra; halo puede mantener
  su propio efecto. bodyShadow no es visible ni tiene layer con shader activo.
- R1.3/4: shader directo sin layer durante movimiento. Seis cuadros consecutivos
  sin cambios antes de sourceItem+copia live:false; sin Timer de 32 ms. Caché
  deshabilitada continuamente mientras respira. Contenta nunca activa layer.
  renderInputs sólo construye array con cacheWhenStill=true (R1.8).
- R1.4/5: SpringValue de reposo con Motion.strokeSpring.lift conserva velocidad;
  multiplica respiración/inclinación, bulto y gota. Radio y fusión de cuello
  disminuyen juntos. No hay segundo muelle de layout sobre PillMorphMotion.
- R1.6: origen/extensión de captura alineados a píxel físico, smooth:true.
- R1.7: mismo grano espacial en interior barato y borde, independiente de time
  con water=true. Rama legacy mantiene su comportamiento.
- No se modifican PROJECT_MEMORY/TASK_STATE ni se crea .pareja: prevalece el
  allowlist del encargo. Evidencia y continuidad quedan en estos documentos.

LÍMITES:

Sin render qsb real, GPU, QA Wayland, captura de sombra/caché o tema claro/oscuro.
Fullscreen/lock dependen de que composición retire running; sólo se prueba el
motor parado. Media conserva arte encima del tinte del shader: puede contribuir
más que antes; comprobar carátula brillante en ambos temas. No se tocaron windows,
FluidCompanion/Neck, lockscreen ni pets. Sin commit ni push.

Revisión independiente del primer W1: agency_reviewer Sol medium, sólo lectura;
R1 responde a la revisión de código aportada por el usuario. No se presenta como
QA visual. Claude no se ejecutó: auth status loggedIn=false, authMethod=none.

DUDAS (para Claude):

1. Ejecutar rama RHI y capturar ≥6 cuadros; verificar sombra sin segunda placa,
   última captura válida y alineación a escala fraccional.
2. Validar respiración/inclinación y retirada de brote/gota al invertir morph.
3. Comparar carátula brillante claro/oscuro; medir GPU/CPU/PSS W0 vs R1 en qs -d
   y comprobar fullscreen/lock.

Procedencia final SHA-256:

- body.frag: d48784f6c35e8c275ae6bcb36b8323b5b491b3fc899ab338bd8517871f7ec54f
- body.frag.qsb: 5435338c2ecfbdd18d3954e1a9716324b1463f1e8c4769eeac45ac4a27c97311

## Revisión Claude tras R1 (2026-10-31)

RHI/OpenGL offscreen: `water-body-regression` pasaba en software y fallaba en RHI. Tres causas de
test y un fallo de Qt, ninguna del producto:

1. `grabImage` en RHI/GL offscreen devuelve fondo opaco (alfa 255): la sombra se mide ahora como
   cobertura relativa a la captura con `shadowExposure=0`.
2. Qt 6.12 sólo reporta `status=Compiled` en la primera instancia de un `.qsb` compartido; la pill
   sí dibuja (comprobado con relleno rojo: `#f90e12` en el centro). Se exige `status !== Error`.
3. `shape()` toleraba 0,001 px, pero el muelle de reposo aún suma su término expresivo acotado
   (`restExposure`≈0,0014 → 0,002 px) durante el morph: tolerancia `.001 + k·s·restExposure`.
4. Cambiar `fragmentShader` en caliente a un archivo inexistente revienta Qt en
   `QQuickShaderEffect::updatePaintNode` (SIGSEGV, bucle del crash handler). El producto sólo
   falla en carga: el test crea un `PillBody` nuevo con el shader roto desde el inicio.

Resultado: water-body RHI PASS, software PASS; body-pill RHI y software PASS; body-brain PASS;
qmllint sin errores. Pendiente: QA Wayland visual y rendimiento real (no verificados).

## QA Wayland tras activar waterBody (2026-10-31)

- Config del usuario: `appearance.waterBody=true` en `~/.config/isla/shell.json`
  (respaldo `shell.json.pre-water.bak`). `qs -c bar` reiniciado; sin errores en el log.
- Reposo: captura igual a la de waterBody=false en la zona de la pill (ver BASELINE.md).
- PSS reposo: 345 MB con water on vs 343 MB con water off. Sin coste de memoria.
- GPU reposo: ~26 % con water on vs ~27 % con water off. Sin diferencia medible, pero
  la cifra total es ruidosa porque incluye el escritorio.
- No verificado: launcher/media/calendario abiertos, morph, secuencia de fotogramas, GPU por
  proceso.
