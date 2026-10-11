# Isla · auditoría QA, ingeniería de calidad y UI/UX

**Actualización 2026-10-11:** se implementaron las correcciones de todos los
hallazgos tras la autorización del usuario. La sospecha SVC-03 se reprodujo en
condiciones controladas y se corrigió, incluida la espera del directorio de estado.
Resultado, regresiones y límites: [informe de correcciones](audit-2026-10-10/fixes/REPORT.md).
El contenido siguiente conserva el diagnóstico y la evidencia anteriores.

Fecha: 2026-10-10, America/Santo_Domingo. Alcance: árbol de trabajo existente, incluidos sus cambios sin commit. **No se implementaron correcciones de producto.** Se añadieron informes, traspasos y evidencia; las reproducciones ejecutables viven en copias/configuraciones temporales. Ninguna auditoría garantiza encontrar todos los defectos.

Resultado: **11 defectos de producto reproducidos**, **1 defecto del gate de pruebas** y **1 sospecha de carrera pendiente**. El cierre del launcher y el fallo de foco se reprodujeron mediante teclado Wayland; otras usan eventos QtTest, componentes/servicios reales con dependencias falsas, o validación aritmética. Cada caso delimita su nivel de evidencia. La categoría completa no queda certificada porque algunas pruebas pasen.

## Prioridad y traspasos

Se utiliza la escala pedida: P0 pérdida de datos/exposición de secretos/seguridad crítica; P1 función principal inutilizable; P2 fallo funcional o de interacción; P3 defecto visual menor. En SVC-01, P0 corresponde a la eliminación de configuración de red previa al fallo de reemplazo. Se probó el orden con comandos falsos; no se destruyó un perfil personal ni se midió frecuencia en NetworkManager real.

| Prioridad | ID | Resultado demostrado | Traspaso autocontenido |
|---|---|---|---|
| P0 | SVC-01 | Wi-Fi elimina un perfil existente antes de comprobar el reemplazo | [Servicio de red](audit-2026-10-10/handoffs/SVC-01.md) |
| P1 | UI-01 | Escribir `Qt.quit()` en búsqueda cierra el proceso sin Enter | [Evaluador del launcher](audit-2026-10-10/handoffs/UI-01-02.md) |
| P2 | UI-02 | asin/acos/atan son transformadas incorrectamente y dan null | [Evaluador del launcher](audit-2026-10-10/handoffs/UI-01-02.md) |
| P2 | UI-05 | Escape no cierra siete paneles abiertos por IPC, 2/2 por panel | [Foco Wayland](audit-2026-10-10/handoffs/UI-05.md) |
| P2 | CFG-02 | Borrador anterior reemplaza valor externo ya recargado, 3/3 | [Conflicto de borradores](audit-2026-10-10/handoffs/CFG-02.md) |
| P2 | SVC-05 | Perfil seleccionado difiere del aplicado después de fallo | [Perfil de energía](audit-2026-10-10/handoffs/SVC-05.md) |
| P2 | CFG-01 | Editor/validador acepta 1e308; consumidores producen Infinity | [Límites geométricos](audit-2026-10-10/handoffs/CFG-01.md) |
| P2 | UI-03 | Tres primitivas no activan su acción accesible | [Activación accesible](audit-2026-10-10/handoffs/UI-03.md) |
| P2 | UI-04 | Slider de brillo sin Tab/flechas/semántica de slider | [Brillo accesible](audit-2026-10-10/handoffs/UI-04.md) |
| P2 | SVC-02 | Session.lock no sigue XDG_DATA_HOME del instalador | [Launcher del bloqueo](audit-2026-10-10/handoffs/SVC-02.md) |
| P2 | SVC-04 | Limpiar portapapeles conserva previews PNG mientras sigue abierto | [Copias del portapapeles](audit-2026-10-10/handoffs/SVC-04.md) |
| P2, pruebas | QA-01 | verify-config termina antes de sus tests por ruta personal en fixture | [Gate portable](audit-2026-10-10/handoffs/QA-01.md) |
| Sospecha | SVC-03 | Restauración del historial podría reemplazar notificaciones recién recibidas | [Investigación pendiente](audit-2026-10-10/handoffs/SVC-03.md) |

Detalles con pasos, frecuencia, líneas, causa, aceptación, regresión y rol mínimo: [UI/interacción](audit-2026-10-10/ui-findings.md), [configuración](audit-2026-10-10/config-findings.md), [servicios](audit-2026-10-10/services-findings.md), [calidad de pruebas](audit-2026-10-10/test-findings.md). UI-01 y UI-02 se entregan juntos para no competir sobre el mismo evaluador.

## Inventario real y riesgos

| Área existente | Composición y fuentes principales | Riesgo que guio la cobertura |
|---|---|---|
| Bootstrap y ventanas | shell.qml, ShellRuntime, IslandOverlay, IslandReserve, SurfaceRouter | Inicio, foco, prioridad Auth, regiones y reserva |
| Pill separada/compacta | Pill, PillGeometry, PillMorphMotion, BarLayoutTransition, PillSurfaceHost | Retarget, dimensiones reales, contenido y descarga |
| Módulos opcionales | TopBarModules, OptionalModule, TopWorkspaceRail, TopSystemStatus, TopUserStatus | Jerarquía padre/hijos, overflow, interacción oculta |
| Gotas | FluidCompanion, FluidMediaCompanion; adaptaciones media/session/settings | Absorción, origen, interrupción y velocidad conservada |
| Workspace/overview | WorkspaceModel, WorkspacesView, OverviewView, WinMap | Foco de monitor, ocupación, urgencia y selección aplicada |
| Reloj/calendario/clima | ClockReel, IslandRestStatus, CalendarView, CalendarData | Cambio de fecha/minuto, extremos, datos tardíos/error |
| Launcher | LauncherView/Controller, Apps | Entrada arbitraria, búsqueda, calculadora y cierre |
| Media/letras | Players, MediaSession, MediaView, MediaTimeline, LyricsController/Data/View, Cava | Capacidades, source/track cambiantes, red bajo demanda |
| Notificaciones | Notifs, NotifData, NotifsView/CardView, IslandNotification | Prioridad/restauración, expiración y privacidad |
| Mixer y estado | MixerAdapter/View, DesktopStatus, PipeWire, UPower | Capacidades, rebinding, debounce y eventos externos |
| Conectividad | ConnectivityAdapter/View, Nmcli, Bluetooth de Quickshell | Secretos, errores de comando, configuración previa |
| Ajustes rápidos | QuickControlsAdapter/View, Brightness, KeepAwake | Estado aplicado vs optimista, errores/recuperación |
| Wallpaper | WallpaperController/View, Wallpapers, pipeline/scripts | Selección exacta, cache/imagen, fallos de aplicación |
| Portapapeles | ClipboardController/View/PreviewAdapter, cliphist/wl-copy | Copia exacta, limpieza y retención de contenido |
| Sesión/autenticación/bloqueo | Session, SessionView, Auth, AuthPromptView, lockscreen y wrappers | Acciones sensibles, secretos, seguridad del bloqueo |
| Configuración | Config/Settings/Flags, EdotsWindow, SettingsPage, pickers/composer | Persistencia, conflictos, límites y fuentes de verdad |
| Instalación/recarga | settings/lockscreen install/open/lock scripts, askpass/Fish, IPC reload | Rutas XDG, fallbacks y traspaso de recursos |

Hay **15 surfaces reales**: Appearance, Auth, Calendar, Clipboard, Connectivity, Launcher, Media, Mixer, Notifs, Overview, Session, Settings, Utils, Wallpaper, Workspaces. La fixture interaction-surfaces carga 14; Settings se verifica con sus fixtures propias. No se omitió Settings por la cifra histórica de 14. Los servicios/funciones anteriores incluyen capacidades no visibles como panel independiente.

## Matriz única de cobertura

Los estados se refieren al **criterio concreto de cada fila**. «Probado» significa que ese escenario se ejecutó y sus comprobaciones terminaron; no significa validación total del área. Estados: probado, fallo confirmado, sospecha, no verificado, bloqueado. No hubo un bloqueo del entorno que impidiese la auditoría general. Las acciones sensibles quedaron sin verificar por el límite explícito del alcance; no se realizaron para obtener evidencia.

| Área/criterio | Estado | Evidencia de esta ejecución | Pendiente o límite |
|---|---|---|---|
| Carga de 14 surfaces y Settings | probado | interaction-surfaces, settings-regression; shell personal viva + IPC | Arranque frío/login y recuperación del proceso completo |
| Apertura de 14 paneles no-auth | probado | native-smoke.json y capturas inspeccionadas | Apertura por clic físico en hit targets |
| Escape sin clic previo en siete paneles | fallo confirmado | UI-05, 14/14 retenciones; launcher control 2/2 cierra | Otros compositores y recuperación al hacer clic |
| Split↔compact, 11 rutas, media abierta, inversión/reducedMotion | probado | layout-motion-full PASS; layout-routing; layout-interruptions | Continuidad perceptual fotograma a fotograma |
| Compacta, 620px, 14 apps, títulos/media simulada | probado | compact-island y capturas compact-detail | Monitor físico estrecho, acentos extremos y contraste medido |
| Opcionales, padre/hijos, salida/unload/input | probado | optional-modules; pruebas de compositor/config de agente | Todas las combinaciones simultáneas de módulos |
| Gotas, absorción y retorno interrumpido | probado | absorption, media-motion, centered-companion, bar-layout-transition | Grabación nativa continua y máscaras con puntero físico |
| Workspace: activo/ocupado/urgente/dos monitores simulados | probado | workspace-model, workspaces-surface, top-workspace-motion | Multimonitor físico, dispatch real y cambio externo simultáneo |
| Cinco estilos y Pac-Man, selección/save/reload temporal | probado | workspace-styles, pacman-motion | Todas las escalas y ocupaciones reales |
| Overview selección/grupos/bounds | probado | overview, surface-data-contract; captura y Escape nativo | Cambiar workspace real, cerrar/focalizar ventanas reales |
| ClockReel, minuto/retarget/hidden/reduced | probado | clock-reel y status | Cambio de zona horaria/DST y localización completa |
| Calendario, bisiesto/escala/weather parcial/vacío/error/stale | probado | calendar-data, weather-view; calendario real capturado | Caída/recuperación real de wttr.in y localizaciones múltiples |
| Launcher búsqueda/debounce/empty/close | probado | launcher-controller, pill-interface, input-motion | Todas las apps reales y pérdida/recuperación del índice |
| Evaluador: código no matemático y trigonometría inversa | fallo confirmado | UI-01, UI-02 | Resto de gramática, límites de complejidad y fuzzing |
| Media: capacidades, seek, cambio track/player, ancho/artwork | probado | media-session, media-layout, media-timeline, datos falsos | Reproducción, seek y dispositivos MPRIS reales |
| Letras bajo demanda, error/vacío/cache/cancelación/tardía | probado | lyrics-local.py/txt, lyrics-view, lyrics.cjs | LRCLIB real; la primera ejecución sin servidor es inválida |
| Cava/Timers y observadores al ocultar | probado | consumer/motion tests, desktop-status-fanout, microinteraction | CPU/GPU/FPS/energía continuos no medidos |
| Notifs prioridad/restauración/expiración y routing | probado | notification, notification-routing, notifs-surface | Notificación real inyectada durante arranque/recarga |
| Carrera de carga del historial | sospecha | SVC-03, flujo inspeccionado | Reproducción de la intercalación; permisos efectivos en disco |
| Mixer: controles/salidas/mic/streams con datos simulados | probado | mixer-surface y surface-data-contract | Cambios de hardware y escrituras PipeWire reales |
| UPower/OSD/Caps/debounce/fanout | probado | status-adapter, desktop-status-fanout, top-system-status | Batería real, hotplug y OSD simultáneo en multimonitor |
| Conectividad: vistas/datos y callbacks | probado | connectivity-surface; lectura del panel real | Wi-Fi/Bluetooth reales, secretos/errores hardware |
| Conservación del perfil Wi-Fi ante fallo | fallo confirmado | SVC-01, nmcli falso delete→add fallo | NetworkManager desechable y colisión de nombres |
| Selector de energía frente a comando fallido | fallo confirmado | SVC-05, clic QtTest en selector real | Cambios externos y servicio real; recuperación tras fallo |
| Brightness keyboard/Accessible | fallo confirmado | UI-04, QuickControlsView real con señales falsas | Dispositivo físico y error de escritura real |
| KeepAwake y brillo bajo carga real | no verificado | Inspección del adaptador/servicio, panel visible | Inhibición y escrituras de sistema deliberadamente no ejecutadas |
| Wallpaper navegación/preview/aspect/selección | probado | wallpaper-regression, captura real sin aplicar | Aplicación, error del script y refresh pywal reales |
| Portapapeles copiar texto multilínea/PNG, clear éxito/error/repeat | probado | clipboard-regression.sh, fake cliphist/wl-copy | Portapapeles personal no modificado |
| Borrar también derivados del clipboard | fallo confirmado | SVC-04, PNG sigue presente después de wipe | Permisos/retención frente a otros usuarios no comprobados |
| Session confirmación/cancelación/reapertura/teclado | probado | session-regression, panel real + Escape | Logout, apagado, reinicio, suspensión no ejecutados |
| Lock entrada/secured/media/auth handoff/typing/reduced | probado | lockscreen tests + cinco capturas preview | Adquisición real WlSessionLock/PAM, bypass/compositor restart |
| Session.lock y XDG personalizado | fallo confirmado | SVC-02, wrapper marcador no invocado | Sin adquirir bloqueo ni invocar launcher personal |
| Auth submit/cancel/retry/socket y cuatro recargas | probado | auth-backend/bridge/transport + auth-prompt | Agentes/respuestas falsas; PAM/Polkit/sudo reales sin verificar |
| Config: defaults/tipos/rangos declarados/unknown keys | probado | settings.cjs e integración | Rangos de todos los números derivados: CFG-01 |
| Config: aplicación/save/discard/reload/restart host temporal | probado | settings-integration.py, config-regression | Reiniciar la sesión personal no se realizó |
| Invalid JSON/cambio externo/borrado/error de mkdir | probado | integración + probe de error; archivo/dirty conservados | Disco lleno/rename denegado/carrera entre escritores |
| Valores válidos desbordan geometría | fallo confirmado | CFG-01, editor QtTest acepta topGap=1e308 | Impacto visual real de Infinity no provocado |
| Borrador después de edición externa | fallo confirmado | CFG-02, QtTest+reemplazo externo+watcher 3/3 | No pulsó Guardar: sobrescritura en disco posterior inferida |
| Settings: búsqueda/borradores/nav/controles | probado | settings-regression e interacción de probes; captura integrada | Pickers nativos completos y ventana física de 760×560 |
| Nombres/roles y activación Accessible | fallo confirmado | UI-03; probes offscreen y Wayland | AT-SPI/Orca real, orden de lectura integral |
| Tipografía/material/jerarquía en estados capturados | probado | 14 pares nativos, compact y lock revisados | Capturas son muestreo; no certifican contraste ni animación |
| Contraste cuantificado, localización, IME, todos los textos largos | no verificado | Inspección/fixtures cubren sólo casos representativos | Medición sobre paletas/fondos adversos y tecnología de asistencia |
| Instalación wrappers y rutas XDG aisladas | probado | lockscreen-launcher.py, auth-bridge.py | Instalación completa sobre entorno limpio desechable |
| Gate global de configuración | fallo confirmado | QA-01, exit1 antes de Node | Se ejecutaron por separado sus tests Node, sin omitir el fallo |
| Soak/load representativa, fugas, profiling, reload shell completa | no verificado | Recargas Auth aisladas; lógica de ocultación probada | No extrapolar a estabilidad de horas ni a SIGSEGV histórico |

## Pruebas, evidencia y metodología

Se ejecutaron **58 regresiones QML en las dos tandas, 54 nombres distintos**: 56 terminaron con exit 0, PASS y sin FAIL/TypeError/ReferenceError/Binding loop. Las otras dos ejecuciones se corrigieron como **condiciones de prueba**, sin cambiar código de producto: servidor local para letras y presupuesto 100s para layout-motion; ambas repeticiones terminaron correctamente. Además se ejecutaron las capturas compact/lock y probes dirigidos. El archivo [suite-assessment.json](audit-2026-10-10/evidence/suite-assessment.json) conserva los resultados iniciales, no oculta las repeticiones ni llama PASS a un timeout.

Las suites de configuración, límites de composición, media-source, lyrics, Auth backend/bridge/transport, launcher del lockscreen y clipboard tienen logs propios. El script [services-repro.py](audit-2026-10-10/evidence/services-repro.py) comprueba errores con ejecutables falsos y asserts; la reproducción de borradores usa archivo externo real con watcher. Los originales de output.py se copiaron a evidence para no depender sólo de caché o `/tmp`. El [índice de pruebas](audit-2026-10-10/evidence/TEST_RESULTS.md) enlaza la evidencia y comandos.

QA nativa: IPC abre la superficie real como precondición; `wtype` envía Escape/entrada a Wayland. `grim` captura antes/después; se inspeccionaron los 14 pares y los montajes. Al final se cerraron las superficies y procesos temporales; la shell personal conservó PID1645. Una respuesta IPC `true` o exit0 de wtype no se consideró prueba de cierre: UI-05 se redujo con lectura del estado del router. No se preparó el estado que los clics de selección debían producir en CFG-02/SVC-05.

Capturas compact/lock: componentes reales en ventanas Wayland con media falsa, casos de ancho 620/380 y fuente grande; las cinco muestras de lock son estados disparados por Timer100ms de la fixture, sin timestamps de presentación. **No se realizó análisis fotograma a fotograma, no se midió FPS ni se acredita fluidez continua.** Las muestras de ventanas no equivalen a interacción física ni a adquirir un bloqueo seguro.

Referencias: contrato local `MOTION_LANGUAGE.md`, arquitectura y skills del proyecto; [Qt Accessible](https://doc.qt.io/qt-6/qml-qtquick-accessible.html) para activación semántica; [Apple Motion](https://developer.apple.com/design/human-interface-guidelines/motion) como referencia de intención, sin derivar requisitos numéricos para Linux. Impeccable sirvió de lista de criterios generales; su detector no soporta esta plataforma y no se usó para puntuarla. No se asignó un score de accesibilidad/rendimiento sin lector de pantalla ni medición. No se afirma experiencia laboral/certificación en Apple, Google u OpenAI.

## Límites y siguiente trabajo

Corregir primero la eliminación prematura del perfil Wi-Fi y el evaluador. Después, foco Wayland, conflicto de borradores y selección efectiva de energía; resolver los controles accesibles y privacidad de derivados sin ampliar producto. QA-01 desbloquea el gate para las correcciones. SVC-03 necesita investigación antes de un fix.

Las pruebas de los traspasos deben mantener configuraciones/datos temporales. Repetir sólo lo afectado y una comprobación vecina; no tratar un PASS de fixture como cierre de los pendientes nativos. Quedan pruebas sensibles, hardware, multimonitor físico, arranque frío, carga continua, contraste medido, IME/localización y secuencias de animación completas. Estos límites no demuestran ausencia de fallos en esas áreas.

Cierre documental: `git diff --check` pasó; enlaces locales de todos los informes/traspasos resuelven; comparación IPC final confirma document/effective/dirty personales sin cambios frente a la instantánea de auditoría. Sólo permanece la instancia original de la shell.
