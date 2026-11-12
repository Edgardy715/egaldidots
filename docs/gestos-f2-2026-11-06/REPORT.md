ESTADO: parcial

Implementación de F2 terminada y validación aislada completada. Los criterios
1–4, 6 y 7 pasan en offscreen. El cierre del criterio 5 queda limitado por tres
resultados que ya fallaban antes de editar; se mantienen los 13 PASS previos y
el fixture nuevo pasa. La revisión independiente y la QA visual/Wayland
corresponden a Claude según el encargo. Offscreen no acredita captura nativa,
composición del cuello ni acabado visual.

Sin commit ni push. No se ha reiniciado ni operado la shell real, ejecutado
`vpointer.py` ni modificado Hyprland. Se conserva el trabajo ajeno. No se han
cambiado shaders, parámetros de muelles, lockscreen ni la arquitectura de
actividades vivas. El estado de entrega se registra aquí; los mapas generales
del proyecto quedan fuera de los archivos permitidos de este encargo.

ARCHIVOS:

- `bar/components/FluidCompanion.qml`: captura en coordenadas estables,
  seguimiento, rubber existente, velocidad compartida con F1, rotura,
  microgota, retorno interrumpible y apertura mediante brote. La captura
  permanece activa mientras se resuelve la ruta; una ruta rechazada vuelve.
- `bar/components/FluidMediaCompanion.qml`: `dismissedUntilTrackChange`,
  transitorio, restablecido por cambio de pista o reproductor.
- `bar/components/FluidRecordingCompanion.qml`: gota protegida de grabación/foco,
  con su etiqueta y ruta correspondientes. Grabación usa la ruta existente
  `recording`/actividad; foco usa `focus`.
- `bar/components/IslandNotification.qml`: arrastre de contenido y conexión del
  mismo motor a la notificación que brota debajo de la Pill.
- `bar/components/PillPullGesture.qml`: modo notificación, muestras y velocidad
  reutilizables, salida horizontal antes del cierre y limpieza entre avisos.
- `bar/components/PillMorphMotion.qml`: habilitar el muelle durante el gesto de
  notificación y retirarlo al asentarse, sin alterar sus parámetros.
- `bar/components/SurfaceRouter.qml`: `openFromDrop`, conservando las guardas
  existentes de navegación.
- `bar/Singletons/Notifs.qml`: pausa anidable de expiración con tiempo restante,
  descarte existente y promoción de la notificación tocada.
- `bar/windows/IslandOverlay.qml`: rutas y captura de gotas/notificación;
  reutiliza el bloqueo de foco y máscara de F1, sin editar OverlayInputPolicy.
- `bar/Pill.qml`: pausa de expiración y coreografía, bloqueo de avance mientras
  se sostiene el aviso, y entrega de descarte/apertura al motor existente.
- `bar/drop-gesture-regression.qml`: fixture nuevo con motores/adaptadores
  reales, Pill/Notifs reales, QtTest y `manualStep`.
- `bar/TESTING.md`: únicamente añadido al final, con ejecución aislada y límites.
- `docs/gestos-f2-2026-11-06/REPORT.md`: este informe.

CRITERIOS:

1. **Probado en offscreen.** `test_notification_contract` comprueba altura 1:1,
   retorno lento/corto, descarte por >40 % y fling <−350·s px/s, y velocidad
   inicial heredada dentro de ±10 %. Horizontal en ambos sentidos: 1:1 antes
   del borde, resistencia, retorno con muelle y recipiente retenido hasta que
   sale el texto. Abajo crece 1:1 y abre notifs. `test_real_notification_routes`
   usa la Pill y Notifs reales: el descarte cierra la entrada, el arrastre
   horizontal recibe eventos reales de ratón de QtTest y abajo coloca primero
   el aviso tocado aunque haya llegado otro. `test_expiration_and_real_pill`
   mantiene la presión más que la expiración, comprueba que no avanza el hold,
   reanuda el tiempo restante y verifica que finalmente expire. Se limpia el
   desplazamiento horizontal antes del siguiente aviso y se desbloquea la cola
   después de asentar. No verificado en layer surface Wayland.
2. **Probado en offscreen.** `test_drops` usa FluidMediaCompanion: movimiento
   exterior 1:1, histéresis geométrica 1.02/1.30, retorno por debajo de la rotura
   con velocidad ±10 %, interrupción continua y descarte tras rotura. La
   microgota asienta en 6·s; el cambio de pista y el de reproductor levantan el
   descarte. El estado no se persiste. Aspecto del cuello/residuo pendiente de
   QA visual.
3. **Probado en offscreen.** Grabación, foco y el motor de sesión soportan un
   desplazamiento exterior de 1000 px con rubber L=14·s, vuelven y no cambian a
   ocultos/descartados. Se comprueba también con movimiento reducido.
4. **Probado en offscreen.** Abajo 25·s abre las rutas media, recording, focus y
   session. Los adaptadores reales y el motor común recorren exactamente
   `brotando → media` y asientan; no se sustituye por un fundido. La política
   conserva `kbFocusWanted=false` y `maskMode=pill` durante la resolución con
   captura, y pasa a foco/máscara de la surface al terminar el release. Si el
   router rechaza la petición, la gota retorna sin tarjeta huérfana. La sesión
   conserva su disponibilidad previa: no se crea una actividad compacta nueva.
5. **No verificado como PASS global.** Clic y hover reales de QtTest pasan:
   un clic emite una sola acción y el arrastre toma el puntero sin emitir clic.
   Los 13 fixtures que pasaban en la línea base siguen pasando, incluido
   pull-gesture. Los mismos tres resultados previos impiden declarar toda la
   selección en PASS; detalle en PRUEBAS. Los 16 fixtures existentes están
   idénticos byte por byte a sus copias anteriores a F2. Captura, clic y hover
   nativos en Wayland pendientes de Claude.
6. **Probado en offscreen y en las condiciones de ejecución del código.** El
   reloj de geometría se suspende mientras se sostiene la gota y se detiene al
   quedar asentada. El fixture vuelve a habilitar el reloj automático después
   de asentar y comprueba que sigue apagado. El muelle horizontal termina su
   integración; su FrameAnimation sólo funciona mientras integra y no hay
   captura. No se añade sondeo periódico ni un segundo reloj de geometría.
7. **Probado en offscreen.** Sin estiramiento ni residuo con reduceMotion;
   descarte de media e itinerarios arriba/horizontal/abajo de notificaciones
   resueltos al soltar. Las gotas protegidas permanecen. Desactivar gestos
   rechaza presses; cambiar reduceMotion o desactivar gestos durante una salida
   horizontal pendiente termina el descarte y libera la captura. Se usa la
   clave `gestures.enabled` de F1, sin claves de configuración adicionales.

PRUEBAS:

Todas las ejecuciones de Quickshell usan `QT_QPA_PLATFORM=offscreen`, tema vacío,
`ISLA_CONFIG` temporal inexistente al empezar y runtime/cache/state en `/tmp`.
La batería final usa un directorio independiente para cada fixture. No hay
acceso funcional a DBus, PipeWire, Hyprland o backend PanelWindow en este
entorno; sus mensajes de disponibilidad no se presentan como QA nativa.

- `QT_QPA_PLATFORM=offscreen timeout 90 quickshell -p bar/drop-gesture-regression.qml`
  con esas variables aisladas → **exit=0, PASS**, incluidas las comprobaciones
  finales de reposo. Log actual: `/tmp/gestos-f2/drop-final.log`.
- Selección `rg -l 'FluidCompanion|IslandNotification|Notifs' bar/*regression*.qml`
  más `bar/pull-gesture-regression.qml`, cada uno con `timeout 90 quickshell -p`
  → comparación siguiente. Se inspeccionaron marcadores y códigos de salida.
- `/usr/lib/qt6/bin/qmllint` sobre los diez QML de producción modificados y
  `bar/drop-gesture-regression.qml` → **exit=0, 0 errores**. Emite advertencias
  (84) de tipado/acceso sin calificar; no se afirma una ejecución sin warnings.
  Log y archivos exactos: `/tmp/gestos-f2/lint-final.log` y
  `/tmp/gestos-f2/lint-final-summary.json`. La línea base de producción también
  terminaba con exit=0 y sin errores.
- Comparación de copias previas → **16/16 fixtures existentes sin cambios** y
  contenido previo de `bar/TESTING.md` conservado como prefijo exacto.

| Fixture (`bar/…-regression.qml`) | Antes de editar | Después |
|---|---|---|
| centered-companion | PASS | PASS |
| companion-continuity | PASS | PASS |
| drop-gesture | nuevo | PASS |
| interaction-surfaces | FAIL, exit 1 | mismo FAIL, exit 1 |
| notification-attention | PASS | PASS |
| notification-drop | PASS | PASS |
| notification-priority | PASS | PASS |
| notification-routing | PASS | PASS |
| notifs-surface | PASS | PASS |
| pull-gesture | PASS | PASS |
| session-companion | PASS | PASS |
| settings-async | sin PASS, exit 255 | mismo resultado, exit 255 |
| settings-companion | PASS | PASS |
| updates-notice | PASS | PASS |
| updates-service | FAIL, exit 0 | mismo FAIL, exit 0 |
| water-decor | PASS | PASS |
| water-drop | PASS | PASS |

Los fallos previos son `FAIL: surface load Workspaces` (la surface ya está
eliminada en el árbol recibido), `FAIL: Updates service` en `test_service` y
`No PanelWindow backend loaded` en settings-async. No se atribuye el fallo de
Updates a una causa no demostrada ni se modifica código ajeno para esconderlos.

Evidencia de la batería: `/tmp/gestos-f2/before/summary.json` y
`/tmp/gestos-f2/final-validated/summary.json`, con logs por fixture en ambos
directorios. El log final del fixture nuevo señalado arriba incluye además las
dos aserciones de reposo añadidas al finalizar. Las fuentes previas permitidas
están en `/tmp/gestos-f2/source-before/`. Los archivos en `/tmp` son evidencia
temporal de esta sesión; comandos y resultados quedan registrados en este
informe y la reproducción en TESTING.md.

DUDAS:

Para Claude: ¿la QA Wayland confirma que la captura sobrevive fuera de la región
inicial, con foco/máscara estables, y que cuello, salida del texto, brote y
microgota mantienen el acabado aprobado? Repetir con notificationDrop activado
y desactivado, media ancha por hover, grabación/foco y movimiento reducido.
No quedan dudas funcionales reproducidas dentro del entorno aislado.
