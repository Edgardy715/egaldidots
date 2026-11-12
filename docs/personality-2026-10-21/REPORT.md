# Isla · respuestas del material y compañero

Fecha: 2026-10-21. Implementación de las referencias Nusa/Coucou adaptada al lenguaje Fluid. La aclaración del usuario retira Shelf: interesa el pulso de recepción aplicado a surfaces existentes, no gestionar archivos.

## Comportamiento

- ReceptionPulse: lavado radial de acento y color secundario con frente expansivo desde el borde inferior, recortado dentro de PillMaterial. Duración base1150ms escalada por Motion; eventos consecutivos se agrupan sin reiniciar bruscamente la onda. Sin Canvas, reloj permanente, deformación del texto ni assets externos. Ocultar o reducir movimiento termina el efecto.
- Resultados confirmados: guardar/mover/crear colección del portapapeles; conexión Wi-Fi con contraseña y cambio real de SSID mientras la surface está abierta; guardado atómico de Config; iniciar/continuar enfoque y completarlo. Una pulsación fallida no se presenta como éxito.
- Charging: IslandStatusAdapter entrega eventos de batería. Transición observada desde otro estado a charging muestra Cargando·porcentaje, expresión y pulso durante3200ms sin abrir surface ni adquirir foco. Estado inicial se toma de DesktopStatus para no celebrar cada inicio. No se probó enchufar cargador físico.
- Compañero original junto al reloj: dos ojos que siguen el puntero dentro de la pill con springs acotados, parpadeo finito al entrar (cooldown2400ms), expresión al recibir/conectar/completar y postura de trabajo/pausa. Sin seguimiento global ni animación idle infinita. Ajuste appearance.personality, por defecto habilitado, visible en Movimiento.
- Pulsar compañero abre Enfoque; acceso adicional en Ajustes rápidos y `quickshell -p bar ipc call island focus ''`. Timer15/25/45min o1..180 personalizado, iniciar/pausar/continuar/cancelar. Deadline real, precisión de pausa en ms y final único. Cuenta suspensión según tiempo transcurrido; sesión temporal, descartada al reiniciar shell. Tiempo restante compacto; resultado completado permanece hasta iniciar/cancelar o elegir nueva sesión según vista.
- Informativas no inician morph mientras una surface está abierta (incluye companions separados). Si siguen vigentes, se presentan al cerrar; caducadas permanecen sólo en historial. Críticas conservan prioridad y autenticación bloquea su presentación. La cola consume la notificación realmente mostrada por identidad, incluso si desaparece durante salida; no descarta su reemplazo.

## Integración

PillSurface.feedbackRequested(kind) → PillSurfaceHost/FluidCompanion → PillMaterial.receive(). Config.saved sólo se emite tras FileView.onSaved; no al aceptar petición ni preview. Las hojas reciben datos; Pill conecta servicios y estado. Theme/Matugen y geometría/motor Fluid conservados.

Nuevos componentes: ReceptionPulse, IslandCompanion, IslandActivityChip, FocusTimerView; singleton FocusSession y FocusSurface. Rutas, geometría, catálogo, ejemplo de configuración y controles actualizados. Cambios preexistentes preservados. No se añadieron dependencias, sonidos, software externo ni configuración personal persistida. No se integraron servicios externos de agentes de IA.

## Evidencia

- personality-regression.qml: Wayland PASS de pulso finito, eventos de carga simulados por la señal del servicio, feedback de surface, ojos, opt-out, reduced/hidden. Capturas en captures/; GIF reception-preview.gif es una secuencia muestreada de la fixture nativa, no una grabación de FPS.
- focus-session-regression.qml: Wayland y offscreen PASS de validación, deadline/suspend, pausa/resume ms, finish único, cancel, custom, teclado/reduced y elegir duración después de completar.
- compact-island-regression.qml: Wayland PASS de límites de módulos, overflow, monitores estrechos, panels, media, cambio de layout y reduced. Primer intento15s expiró antes de terminar; ejecución50s completó PASS.
- motion-regression.qml: offscreen PASS de interrupciones, contenido, reduced y unload.
- notification-regression.qml: offscreen PASS de fases, cola, caducidad, cierre, restauración y prioridad auth.
- notification-attention-regression.qml: PASS de defer informativas, crítico/auth, caducidad y promoción con XDG_STATE_HOME aislado.
- notification-priority-regression.qml: PASS integrado de reemplazo normal→crítico y destrucción real de NotifData durante salida, sin consumir el crítico antes de mostrarlo.
- verify-config.sh y settings-integration.py: PASS de esquema/catálogo, límites de composición, IPC, guardado atómico, conflictos, discard y extensiones.
- qmllintQt6: exit0; avisos de tipos Bluetooth y de singleton Config del analizador, no errores de carga en fixtures. git diff --check PASS.
- Sesión real: settings.get confirma personality=true y catálogo nuevo ya cargado; captures/live-bar.png muestra el compañero en barra split existente, sin cambiar reproducción, wallpaper ni energía.

Revisión independiente encontró dos problemas corregidos: duración visual retenida00:00 al elegir siguiente sesión; crítico consumido por avance de la notificación anterior, incluida la variante de objeto destruido. Las regresiones cubren ambos.

## Límites

No FPS/GPU, cargador físico, nuevas conexiones Wi-Fi/BT, entrega D-Bus real ni AT-SPI. Las capturas/inputs nativos de fixtures no certifican esos recorridos de hardware. No hubo implementación de bandeja de archivos tras la aclaración. El cronómetro no persiste al reiniciar y una alteración del reloj del sistema modifica el deadline de tiempo civil. La notificación de carga conserva el tratamiento compacto, sin nueva ventana ni permiso.

## Afinado posterior · sustituye el acabado inicial

El usuario rechazó intensidad y tooltip. Se elimina el aro, se limita el campo
al borde inferior y se reduce la luz a alfas0.12/0.075/0.025; duración950ms con
InOutSine. Hover sin texto flotante: luz tenue local, apertura ocular mínima y
presión compartida; foco visible/nombre accesible conservados.

Personality Wayland PASS, incluyendo entrada de puntero, foco y ancho estable;
qmllintQt6/diffcheck PASS. Capturas refinement/ inspeccionadas. El GIF inicial
es histórico y queda sustituido por refinement/reception-preview.gif.
