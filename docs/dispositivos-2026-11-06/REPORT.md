# Momentos de dispositivo (2026-11-06)

ESTADO: parcial (lógica y componentes probados offscreen; cableado en IslandOverlay/Pill y fuentes vivas sin verificar; falta QA Wayland)

## ARCHIVOS
Nuevos:
- bar/Singletons/DeviceMoments.qml (+ línea en bar/Singletons/qmldir): cola, política, Bluetooth, UPower, udisks, Pipewire.
- bar/components/DeviceMomentCard.qml: tarjeta Bluetooth/USB (hoja, sólo propiedades y señales).
- bar/components/DevicePowerMoment.qml: rayo Tidemark + RollingNumber (hoja).
- bar/components/PrivacyDots.qml: puntos naranja/verde con muelle `Motion.strokeSpring.morph` (hoja).
- bar/scripts/isla-device-storage: monitor Python de `udisksctl monitor` (JSON por línea; `--self-test`).
- bar/device-moments-regression.qml.
- docs/dispositivos-2026-11-06/REPORT.md.

Modificados:
- bar/Singletons/Settings.js: sección `devices` (enabled, bluetooth, power, storage, privacyDots; todos true) y entrada en el catálogo.
- bar/settings/EdotsWindow.qml: grupo «Dispositivos» en Avanzado.
- bar/i18n/en.js: textos de dispositivos; se repararon las comas que faltaban del bloque previo (rompían la carga de TODAS las regresiones) y se añadieron «%1 conectado» y «Con batería · %1%».
- bar/Pill.qml: DevicePowerMoment (cede el header mientras dura), PrivacyDots + etiqueta de hover, y el aviso «Cargando» existente se omite cuando el momento de corriente es el dueño (`ownsPowerTransition`).
- bar/windows/IslandOverlay.qml: `deviceCardShown/deviceCardOpen`; `notificationCompanion` muestra la tarjeta de dispositivo (mismo brote centrado) y cede ante notificaciones; Binding de contexto (sólo monitor enfocado), Connections de aviso mínimo, apertura de surface e `interrupt()`.
- bar/components/ConnectivityAdapter.qml y MixerAdapter.qml: consumen la intención para abrir en Bluetooth / página Entrada.
- bar/TESTING.md (append).

## Decisiones
- No hay sexto companion en PillBody (sólo companion0..4): la tarjeta reutiliza `notificationCompanion` (cede ante una notificación real).
- Bluetooth: el backend de Quickshell da una batería por dispositivo; `batteriesOf` acepta además `device.batteries` si existiera. Sin batería: sólo «Conectado».
- USB: un único proceso `udisksctl monitor` (filtra Removable y bus USB), sin sondeo. Sin udisks: emite `error` y no hay momentos.
- Privacidad: enlaces activos de Pipewire; se ignoran apps que casan /quickshell|isla|cava|peak/ (medidores propios). Histéresis simétrica de 400 ms con dos Timers de un disparo.
- Batería baja (<15 %): siempre aviso mínimo (también en pantalla completa y con DND), una vez por conexión.

## CRITERIOS
1. Bluetooth — probado (modelo falso por propiedad) — conectar, hover que pausa 3,5 s, ~3,5 s medido, baterías (una, varias, ninguna), tipos admitidos/descartados, desconexión como aviso, batería baja una vez por conexión.
2. Corriente — probado con `ingestPower` (UPower simulado) — 2 s medidos, sin tarjeta, desenchufar sólo porcentaje, deduplicación, surface abierta → aviso, pantalla completa → nada. UPower real: no verificado.
3. USB — probado — líneas JSON simuladas → tarjeta, deduplicación, abrir (`xdg-open`), expulsar (`udisksctl unmount -b <dev>` y `power-off -b <drive>`), error amable si falla cualquiera, retirada física. `isla-device-storage --self-test` PASS. `udisksctl monitor` real: no verificado.
4. Privacidad — probado con flujos simulados — 400 ms de entrada y salida, enlace de 120 ms sin parpadeo, nombres de app, clic pide Sonido/Entrada, ajuste apagado. Hover real sobre el punto y Pipewire real: no verificado.
5. Cola/prioridad — probado — un momento a la vez, cola acotada (3) y caducidad (8 s), surface abierta, pantalla completa, DND, gesto (se difiere y se muestra al terminar), notificación cede, interruptor general.
6. Ajustes — probado: defaults, rechazo de tipo inválido, interruptores; textos en es/en (comprobación de claves). Regresiones de gotas/notificaciones/actividades: ver PRUEBAS.
7. Reposo silencioso — probado/documentado: sólo Timers de un disparo (`cardTimer`, `powerTimer`, `drainTimer`, `returnTimer`, `micTimer`, `camTimer`); sin FrameAnimation propio (el de SpringValue sólo integra mientras se mueve); único proceso nuevo: monitor udisks, sólo con `devices.storage`.

## PRUEBAS
- `python /tmp/gestos-f1-validate.py dispositivos bar/device-moments-regression.qml` → exit 0, 7 PASS (ajustes, Bluetooth, corriente, USB, privacidad, cola, reposo).
- `python3 bar/scripts/isla-device-storage --self-test` → PASS.
- Regresiones del criterio 6 (ISLA_CONFIG inexistente, XDG_* temporales), antes y después: activities, body-drop, centered-companion, drop-gesture, notification, notification-drop, notification-priority, notification-routing, water-drop, settings, connectivity-host, connectivity-surface, compact-island → todas exit 0 con PASS en ambos. También exit 0 con PASS tras los cambios: config, island-status-adapter, mixer-surface. `settings-navigation-regression` se queda colgada (>90 s, sin PASS) tanto en la línea base como después: preexistente, no verificado. `recording-drop-regression` falla igual antes y después: «No PanelWindow backend loaded» (IslandOverlay no se instancia offscreen; ambiental).
- `qmllint` sobre lo tocado: 0 errores. Avisos nuevos sólo de estilo («Unqualified access» en delegates/inline components de DeviceMomentCard y PrivacyDots); en ConnectivityAdapter los 3 avisos ya existían.
- Antes de editar, TODAS las regresiones fallaban por una coma ausente en en.js (línea ~929); reparada.

## No verificado
- Cableado de IslandOverlay/Pill (no hay backend PanelWindow offscreen): aparición real de la tarjeta, tragado de gota, máscara de entrada, hover pausa en pantalla.
- Fuentes vivas: Quickshell.Bluetooth, UPower, Pipewire y udisks reales; ningún disco se montó ni expulsó.
- Toda la parte visual (píxeles, muelles, posición del punto de privacidad y de su etiqueta): requiere QA Wayland.

## Observación
La shell real (PID 1563) vigila los archivos y recargó la configuración con el código nuevo: ya lanzó su propio `isla-device-storage`. No se reinició ni se tocó; el monitor sigue vivo hasta que esa shell se reinicie o recargue.

## Limitaciones
- Una sola batería por dispositivo con el backend actual.
- El monitor de udisks no se reinicia solo tras un fallo.
- El medidor del Mezclador de la propia shell se excluye por nombre; otra app que lea el micrófono para un medidor encendería el punto.
- Batería baja en pantalla completa: el aviso se emite, pero la pill está retraída y puede no verse.
- El chip de batería existente sigue mostrándose; sólo se evita duplicar el aviso «Cargando».

## DUDAS
- ¿Posición del punto de privacidad (borde derecho interior) y etiqueta bajo la pill son lo que quieres? Es la hipótesis visual a revisar en QA.
