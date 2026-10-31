ESTADO: parcial

ARCHIVOS:
- bar/body/PillBody.qml
- bar/body/BodyShader.qml
- bar/body/shaders/body.frag
- bar/body/shaders/body.frag.qsb
- bar/body/README.md
- bar/components/PillMaterial.qml
- bar/components/FluidCompanion.qml
- bar/Pill.qml
- bar/water-body-regression.qml
- bar/water-decor-regression.qml (nuevo)
- bar/TESTING.md (append)
- docs/agua-w4-2026-10-31/REPORT.md (nuevo)

CRITERIOS:
1 — probado en estructura/cableado — WaterDecor y WaterBody verifican que el
Loader de decoraciones está descargado, no sólo invisible, con shaderActive.
No existen MediaAmbient/halo/InnerGlow/franja/tinte/sombra bajo agua. Fluid ya
descarga todo su PillMaterial desde W3; WaterDecor verifica recepción dirigida
al body. El arte, recepción, barrido y acento están en body.frag. La ejecución
de esos píxeles en RHI permanece no verificada.
2 — no verificado — hay un único cálculo de normal/luz y borde del SDF unido;
no se añade borde de tarjeta. WaterDrop conserva su captura de fila del cuello
(variación adyacente <=32/255). Ninguna rama RHI llegó a ejecutarse: no existe
contexto OpenGL en offscreen. Sin evidencia visual de costura, luz o borde.
3 — probado — WaterDecor integra manualmente wave/tide de Motion, comprueba
retarget sin reinicio de valor/velocidad, impulso repetido y asentamiento.
Recepción y barrido usan SpringValue manualStep=true, avanzados por el
FrameAnimation de asentamiento existente de BodyShader; no se añade un reloj
FrameAnimation al código. Los relojes internos de SpringValue quedan apagados
por manualStep. No cambia geometría ni tiempos de los muelles de layout.
4 — probado parcialmente — fallback software/waterBody=false/reduceMotion y
resolución de los muelles a destino pasan. Error real de ShaderEffect está en
WaterDecor/WaterBody RHI, no ejecutado por falta de contexto. 23 fixtures PASS;
los otros dos fallos también aparecen sobre b4adc10 aislado (ver PRUEBAS).
5 — probado en lógica — WaterDecor verifica integradores detenidos, settling=false
y layer.enabled=false; WaterBody verifica seis cuadros quietos, parada del reloj,
invalidación y ausencia de layer. El arte no tiene desplazamiento continuo bajo
agua. La captura estática W1 usa live:false. Coste/actividad real GPU no verificados.
6 — probado por inspección/medición acotada — sin bucles de cuadro nuevos ni
pasadas de blur: dos imágenes de hasta 256 px, cinco taps fijos por imagen,
sólo dentro del cuerpo y de la máscara ambiental; se reutiliza step de SpringValue.
El .qsb pasa de 15 535 a 22 500 bytes. Los 23 fixtures PASS tardan 0.10–5.94 s
por proceso en esta ejecución (tres procesos de prueba concurrentes; no es FPS
ni benchmark de runtime). CPU/GPU, VRAM, frame time y consumo en sesión sin medir.

PRUEBAS:
Entorno: raíz del proyecto, base b4adc10, ISLA_CONFIG=/tmp/agua-w4-nonexistent.json
(inexistente), XDG_RUNTIME_DIR=/tmp/agua-w4-runtime (0700),
XDG_CACHE_HOME=/tmp/agua-w4-cache, QT_QPA_PLATFORM=offscreen,
QT_QPA_PLATFORMTHEME vacío. Cada fixture usa timeout -k 5 90 quickshell -p bar/<x>.qml.

- cd bar/body/shaders && /usr/lib/qt6/bin/qsb --qt6 -o body.frag.qsb body.frag → PASS.
  Se sustituyó textureSize por aspectos enviados desde QML para compilar ESSL 100.
- node bar/tests/body-brain.cjs → tres mensajes PASS.
- /usr/lib/qt6/bin/qmllint bar/body/PillBody.qml bar/body/BodyShader.qml
  bar/components/PillMaterial.qml bar/components/FluidCompanion.qml bar/Pill.qml
  bar/water-body-regression.qml bar/water-decor-regression.qml → exit 0, salida vacía.
- git diff --check → PASS.
- Selección rg -l 'PillMaterial|FluidCompanion' bar/*regression*.qml más fixtures
  de pill/media/notificación/cuerpo relacionados → 25 ejecuciones software:
  PASS: absorption, auth-prompt, body-pill, centered-companion,
  companion-continuity, content-hold, material-accessibility, media-ambient,
  media-motion, media-palette, media-presentation, neon, notification-drop,
  pill-composition, pill-geometry, pill-interface, session-companion,
  settings-companion, surface-materialize, surface-swap-close, water-body,
  water-decor y water-drop (sufijo -regression.qml).
- settings-async-regression.qml → exit 255, “No PanelWindow backend loaded”.
- swiftify-media-regression.qml → FAIL explícito, TypeError al leer family de
  undefined (el fixture sale con exit 0; no se contabiliza como PASS).
- Repetición de esos dos fixtures sobre git archive b4adc10 bar extraído en
  /tmp/agua-w4-base, mismo entorno → mismos errores y códigos. No son regresiones
  introducidas por W4; no se modifican fixtures fuera del alcance.
- QT_QUICK_BACKEND=rhi QSG_RHI_BACKEND=opengl, mismos comandos para water-body,
  water-drop y water-decor → exit 255 en los tres: “QRhiGles2: Failed to create
  context” / “Failed to initialize graphics backend for OpenGL”. NO PASS RHI.
- Revisión independiente read-only (agency_reviewer, Sol medium) → detectó retirada
  prematura de ambiente al cerrar. Corregida selección de superficie saliente;
  prueba de cierre/reversión PASS; segunda revisión sin hallazgos en esa corrección.

Logs recuperables de esta sesión: /tmp/agua-w4-results.json,
/tmp/agua-w4-summary.log, /tmp/agua-w4-<fixture>-sw.log,
/tmp/agua-w4-<fixture>-rhi.log, /tmp/agua-w4-lint.log y
/tmp/agua-w4-baseline-{swiftify-media,settings-async}.log.
La fuente y el .qsb final se mantienen juntos; no se reinició ni operó la shell real.
No commit/push. Docs ajenos sin rastrear y :memory:.ses conservados.

DUDAS:
Claude: ejecutar QA Wayland/RHI de costura pill–cuello–tarjeta, acento continuo,
portada al abrir/cerrar/invertir/cambiar pista, recepción repetida, barrido de
notificación, error real de shader, quietud y coste GPU. ¿El ambiente estático y
el filtro de cinco taps conservan la composición aprobada? No hay bloqueo para
revisar el diff; el cierre visual queda pendiente de esa evidencia.

Implementación y decisiones

El inventario de abajo se escribió antes de modificar código. Bajo agua se
sustituyen halo/franja/velo/tinte/recepción/barrido por contribuciones al mismo
tinte y borde exterior del campo. La luz W2 permanece intacta. El ambient usa
el slot/blend de ArtworkImage compartido, sin otro reloj; estados de carga de
ambas imágenes invalidan la captura aun si sus dimensiones coinciden. Se
conserva la superficie media saliente al cerrar y al invertir. Se mantienen
portada nítida, contenido, input y controles fuera del material.

No se reproducen FBO decorativos ni deriva ambiental perpetua: el ambiente queda
quieto al asentarse para cumplir reposo silencioso. La recepción es un campo
radial y el barrido una banda de amplitud nula en los extremos de cada epoch.
Con agua desactivada, software, error o reduceMotion se carga el material anterior
con sus efectos. PROJECT_MEMORY/TASK_STATE no se editan por la lista explícita
de archivos permitidos; este informe contiene el relevo para Claude.

Inventario previo a editar código (base b4adc10)

PillMaterial en tarjeta media: MediaAmbient (arte 256px, textura 192x128,
FastBlur 22, alfa .32, dos imágenes/mezcla de ArtworkImage y desplazamiento
ambiental mientras playing/settled), velo negro vertical .35/.10/.35,
relleno cardTop/cardBot, borde foreground, sombra, halo exterior con FBO,
InnerGlow, ReceptionPulse radial, franja superior de acento, barrido diagonal,
aro notifBreathGlow, sheen, DepthLight/DepthShade y AccentTint .035.
La tarjeta Fluid pone materialAwake=true, mode=media; no cablea materialPulse,
materialSweep ni notifBreathGlow: barrido/aro están apagados allí. InnerGlow se
anula al superar 300px/80px. Recepción se solicita por feedback de surface.
Borde y sombra se atenúan con joined/edgeExposure. Arte compacto/portada y
controles son contenido, permanecen fuera del material.

En pill/notificación: materialPulse/materialSweep proceden de MaterialChoreography;
ReceptionPulse se solicita por respond/feedback. notifBreathGlow/notifBreathRadius
proceden del morph y dibujan aro/respiración; materialAwake incluye notifMorphing.
La notificación Fluid usa surfaceName=notification y expandedContent, sin arte,
barrido ni aro propios; la recepción del material sí puede venir de feedback.
Con shaderActive W3 apaga relleno/borde/sombra/sheen/profundidad, pero conserva
instancias de halo, arte, InnerGlow, recepción, franja, barrido, velo, aro y tinte
en la pill. En gotas W3 descarga PillMaterial completo (y pierde sus decoraciones).
