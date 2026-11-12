# ESTADO

Fase 2 implementada en la demo aislada. Pruebas automáticas y capturas nativas
completadas; revisión temporal continua y arrastre físico pendientes. No se
conectó a producción ni a archivos reales. Sin commit ni push.

El usuario aprobó visualmente la Fase 1 y autorizó continuar. El qsb requerido
existe. No se acredita revisión de Claude: su CLI había fallado por autenticación
en Fase 1; esta fase no convierte esa revisión pendiente en un PASS.

# ARCHIVOS

- Nuevos: `bar/body/BodyDropBrain.js`, `bar/tests/body-drop.cjs`,
  `bar/body-drop-regression.qml` y esta carpeta de evidencia.
- Modificados: `bar/body/BodyEngine.qml`, `bar/body-demo.qml`,
  `bar/body/README.md`; append a `bar/TESTING.md`.
- Shader, qsb, cerebro/muelles de Fase 1 y pill de producción sin cambios.
- `hashes.json` identifica las fuentes verificadas.

# CRITERIOS

1. **Probado.** Node gota a–i y entrega: `node.log`; regresión Node de Fase 1:
   `phase1-node.log`. QML con shader compilado y log vacío:
   `offscreen-opengl.log` y `wayland-regression.log`, exit 0. El caso QML también
   comprueba salida automática por `itemDragging`, espera durante arrastre y
   recogida después de soltar. Offscreen software: `offscreen.log`, shader omitido.
2. **Probado por capturas Wayland.** Monitor DP-1, 1920×1080, escala 1;
   recorte nativo 650×310 en (650,50). Secuencia: `01-cuello-salida.png`,
   `02-lagrima.png`, `03-regreso.png`, `04-persecucion.png`, `05-tragar.png`,
   `06-vuelta-con-archivo.png`, `07-fusion-guardado.png`,
   `08-entrega-viaje.png`, `09-archivo-devuelto.png`. `captures.json` conserva
   estados IPC y tiempos. El fondo es el escritorio del usuario, sin alterarlo.
3. **Probado en geometría y muestras; continuidad temporal no verificada.**
   Un muelle apaga el bulto al salir. Node comprueba histéresis, máximo un residuo
   por salida, absorción y tres ciclos. `interrupcion-1.png` a
   `interrupcion-3.png` documentan tres salidas. Las imágenes aisladas no prueban
   ausencia de parpadeo entre todos los cuadros.
4. **Probado por comandos del motor.** Interrumpir salida con regreso conserva
   posición/velocidad y desplaza menos de 2 px en el siguiente cuadro a 60 Hz.
   Revertir el regreso cambia destino sin reiniciar muelles: prueba Node.
   G utiliza esos comandos en la demo. Pulsación física de G no verificada.
5. **Probado.** Un solo FrameAnimation y una sola integración compartida para
   cuerpo/gota; ningún reloj nuevo. QML comprueba home asentado sin needsFrames
   y active=false sin FrameAnimation/Timer. En captura final, respiración activa:
   gota inactiva, frames=false, Timer de Fase 1 activo. No hay perfil de CPU nuevo.
6. **Probado con límites de git.** El árbol ya contenía muchos cambios ajenos.
   Comparación con status inicial: sólo se añadieron entradas para la regresión,
   test y evidencia de Fase 2; no desapareció ninguna. Como BodyEngine/demo/body
   ya eran untracked, se contrastaron además hashes de Fase 1: sólo cambiaron
   Engine, README y demo. TESTING recibió únicamente el append documentado.

# PRUEBAS

Desde la raíz del proyecto, todas con configuración temporal ISLA_CONFIG:

```sh
node bar/tests/body-drop.cjs
node bar/tests/body-brain.cjs
ISLA_CONFIG=/tmp/isla-drop-test.json QT_QPA_PLATFORM=offscreen quickshell -p bar/body-drop-regression.qml
ISLA_CONFIG=/tmp/isla-drop-final-gl.json QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=rhi QSG_RHI_BACKEND=opengl quickshell -p bar/body-drop-regression.qml
ISLA_CONFIG=/tmp/isla-drop-final-native.json QT_QPA_PLATFORM=wayland quickshell -p bar/body-drop-regression.qml
```

Además, regresión QML de Fase 1 con OpenGL PASS (`phase1-regression.log`).
qmllint exit 0 (`qmllint.log`), con avisos de PanelWindow no creable y propiedad
`state` heredada de QQuickItem en el diseño existente; ambos cargan en runtime.
Wayland emitió un aviso de registro del portal D-Bus del entorno; sin errores
QML ni de shader. Demo cerrada al terminar.

# DECISIONES PROPIAS

- Se reutilizan los cuatro uniformes de gota existentes: no hubo recompilación.
- Semilla local reproducible para paseos; no se usa aleatoriedad global.
- La revisión independiente acotada detectó que revertir `return` dejaba el
  destino en el centro hasta el siguiente paseo. Se corrigió y añadió regresión.
- La inspección visual detectó separación excesiva de la cola a alta velocidad.
  Se limita su posición publicada a 16 px de diseño de la cabeza, conservando
  posición/velocidad del muelle interno. Node verifica ese límite.
- IPC de captura sólo con ISLA_BODY_TEST=1; `scene` aísla el puntero de la fixture.
  Las capturas preceden el último ajuste de sincronización de itemPos al cambiar
  itemDragging; la regresión final OpenGL/Wayland sí incluye ese ajuste.
- La continuidad de esta fase queda aquí por la lista cerrada de archivos;
  PROJECT_MEMORY.md y TASK_STATE.md no se modificaron.

# DIFERENCIAS CON LA PÁGINA

Se conserva el comportamiento de Demo 2, adaptado a píxeles lógicos/Theme y
muelles compartidos. El límite visual adicional de cola evita dos gotas
separadas al acelerar. La desaparición/reaparición del chip usa Behaviors QML,
con duración cero en movimiento reducido. El retorno invierte rumbo al instante
al volver a soltar, conservando velocidad. La capa de pantalla completa con
Region mínima y los archivos reales quedan para Fase 4.

# DUDAS

Pendientes: revisión cruzada de Claude, arrastre físico con ratón y observación
continua de las transiciones/interrupciones. La referencia HTML se consultó como
código; su apertura file:// había sido rechazada en Fase 1 y no se eludió.
Las pruebas del motor y capturas nativas no sustituyen estos puntos.
