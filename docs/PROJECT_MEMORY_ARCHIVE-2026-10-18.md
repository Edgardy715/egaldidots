# Isla: mapa de memoria

Estado comprobado: 2026-10-11. Este mapa orienta; el código y la petición actual
prevalecen. El historial completo sigue en TASK_STATE.md. No leerlo entero por rutina.

## Recuperación

`python ~/.codex/token-economy/recall.py 'términos concretos' --root /home/zdito/.config/quickshell`
busca localmente por términos y significado (E5 multilingüe), con hasta cinco
secciones completas y rutas/líneas. `--list` muestra candidatos; `--mode lexical`
evita cargar el modelo. Fuentes actuales se releen; vectores se cachean por contenido.
Agrupa preguntas conocidas con `--query 'otra pregunta'` (repetible): conserva
los mismos candidatos por consulta sin repetir sus cuerpos. No reduce el límite
de cinco ni resume evidencia. `--list` incluye rangos de líneas.
Si no basta, reformular en español/inglés o ampliar --limit/--file/rg. La similitud
no certifica una respuesta: contrastar fuente y distinguir historial de contrato actual.
Busca también el código antes de editar: esta memoria no certifica estado runtime.

## Contratos y rutas

- Compacta densa (2026-10-09): sustituye reserva simétrica por anchos reales
  izquierdo/derecho; cuerpo centrado, reloj entre música y estado, separadores
  finos. Media de ancho natural hasta256px, portada36 sin aro y metadatos13/11;
  workspace compacto28 con selección suave. Sin botones play/pausa en reposo;
  controles en panel. Propuesta de acabado, pendiente de valoración. Umbral de revelado incluye todos los gaps para evitar
  overlap al volver. QA real pausada y fixture Wayland PASS; ver TASK_STATE.md.

- Visual/movimiento: `.agents/skills/fluid-island-motion/SKILL.md` y
  `bar/fluid/MOTION_LANGUAGE.md`. Diseño Apple explícito: skill apple-inspired-ui.
- Arquitectura/configuración: `docs/SHELL_ARCHITECTURE.md`; Settings.js define
  defaults/validación; Flags es fachada readonly; Config.update/discard/save.
- Media: MediaSession separa estado/acciones; hojas reciben datos, composición
  conecta Players/Cava. Geometría compartida en IslandGeometry.
- Navegación: SurfaceRouter; ventanas/adaptadores en bar/windows.
- Iconos: MaterialIcon combina hover con foco/engagement; MotionButton incluye
  highlighted para selección por flechas (Session). Regresión keyboard-icon
  cubre flechas/Tab/Shift+Tab y reduced sin acciones reales de energía.
- Gotas: FluidCompanion motor compartido; FluidMediaCompanion adaptador.
  Sesión izquierda temporal; media derecha; conservar reloj. Interrupciones
  conservan continuidad. No duplicar motores ni confundir tests con QA visual.
- Pruebas y comandos: `bar/TESTING.md`; buscar el componente/regresión concreto.

## Estado y pendientes

- Player correcciones (2026-10-18): paleta cancela extracción obsoleta, reintentos
  finitos y watchdog12s. Barra refleja MediaSession sin reset artificial; cancela
  drag obsoleto y conserva onda/hover. Botón comparte portada/tinta contrastada,
  forma/giro intactos; neón radial interior desde disco. HTTP y Wayland/input,
  paleta, layout, musical y gate PASS; revisión atendida. SinFPS/seekpersonal;
  fundido imagen/color no exacto. docs/media-fixes-2026-10-18/REPORT.md.

- Paleta musical (2026-10-17): MediaPalette compartido extrae color de portada
  con miniatura/caché acotadas. CAVA, progreso gota/panel y neón reciben acento
  con fundido500ms; controles conservan Matugen y fallback ante error/sinimagen.
  Sin nuevas dependencias. Wayland/helperHTTP/Spotify real/regresión/gate PASS.
  Detalles/límites: docs/swiftify-2026-10-17/palette/REPORT.md.

- Swiftify afinado (2026-10-17): usuario aprueba rediseño. Letras atascadas por
  navegación manual retenida: reabrir y3.2s de inactividad retoman seguimiento;
  neón desde glifos activos y descenso encadenado. Reloj realMPRIS error≤0.061s,
  sin cambios/offset. Espectro48radios3.5px/recorrido31px, CAVA compacto intacto.
  SwiftMediaTimeline con onda/trazo4→6px y tirador hover, medidas de referencia.
  Fixtures offscreen/Wayland, MPRIS/CAVA reales, layout y gate PASS; revisión sin
  hallazgos. SinFPS/GPU/alineaciónfonética; afinado pendiente valoración.
  Evidencia: docs/swiftify-2026-10-17/refinement/REPORT.md.

- Swiftify rediseño (2026-10-17, sustituye primera propuesta rechazada): LRCLIB
  conálbum503/sinálbum200 reproducido; recuperación exact→sinálbum→search y
  timeout finito. QMLpúblico PASS69líneas sincronizadas de pistaSpotify real.
  Player720×440, portada circular/espectroradial real, letrasjuntoportada,
  MaterialRounded rellenos locales4KB y botón festoneado5→9lóbulos con giro
  bajo demanda. Theme/Fluid intactos.9HTTP/parser, Waylandinput/estados,
  layout3fonts, continuidadHTTP, split/compact y gate PASS; hallazgos de
  revisión corregidos. SinFPS/GPU/AT-SPI/seekpersonal; valoración pendiente.
  Evidencia: docs/swiftify-2026-10-17/redesign/REPORT.md.

- Portapapeles (2026-10-16, guardado separado): usuario rechaza organizador
  superpuesto mediante captura; ahora Guardar retira lista/buscador y presenta
  página completa. Resumen de entrada + colecciones visibles (Sin colección al
  final), elección explícita si existen destinos; botón nombra destino. Crear
  selecciona nueva colección y alinea foco/Enter. Ver conserva lector separado.
  Workflow/diseño/input Wayland, legacy/biblioteca y lint/gate PASS. Detalles
  docs/clipboard-2026-10-16/save-page/REPORT.md. Acabado pendiente valoración;
  sin cambios de historial personal, sin FPS/AT-SPI.

- Cava (2026-10-15): corregidos frames16bit mal leídos y mezcla global.
  Captura ahora stream exacto del player (parec monitor-stream), sin fallback,
  ASCII65535, ganancia fija y escala perceptual relativa; alpha estable.
  Usuario aprueba pequeño estable y pide crecimiento centrado; corregido vaivén
  por redondeo de anchors con eje geométrico explícito. Regresión120alturas,
  escalas1/1.25: deriva~0 frente0.72px previo; Wayland/live PASS.
  Expandido:24barras finas3px, gap4px, recorrido34px/acento; sin estirarlas
  al ancho del panel. Spotify Wayland y layout/fonts/artwork PASS; valoración pendiente.
  Unit5/parent-death, aislamiento nullsink2tonos, Spotify60Hz y QML Wayland live PASS.
  Primer suavizado rechazado; valoración perceptual final pendiente.
  Evidencia docs/cava-2026-10-15/followup/REPORT.md; límites stream compartido/FPS.

- Confirmación neón (2026-10-15): ConfirmationIndicator compartido, arco variable
  giratorio→círculo/check verde o X roja. Wallpapers incluye error/reintento;
  auth/sudo, Wi-Fi, lock y guardado Edots conectan estado real. Hidden/reduced,
  interrupciones/retry y fixtures Wayland PASS; revisión sin hallazgos. Referencia
  sólo fotograma: timings Apple aproximados, no réplica medida. Evidencia
  docs/confirmation-2026-10-15. Sin PAM/red/fondo reales ni FPS.

- Neón interior (2026-10-14): usuario pide emisión desde componentes internos,
  no contornos de surfaces/botones. Retirados NeonOutline y sus consumidores.
  Glow en relleno de batería semántico, Pac-Man/marcadores/lente, sliders,
  thumb media, iconos de interacción/Keep Awake, knob y OSD; launcher sólo
  marcador interno. Captura Wayland y pruebas pertinentes PASS; sin FPS medidos.

- Sonido apps/dispositivos (2026-10-14): Spotify/Discord identificados por clientes,
  contadores y scroll de apps corregidos. Hardware/Detalles permiten entrada/salida
  independientes con perfiles reales; PS4off aplicado y persistido, Corsair intactos.
  Medición48kestéreo20ms/30Hz, dBFS y ataque rápido; pulso privado61–143ms sin ceros
  falsos.8backend+7policy+nulls+lifecycle+vista/Wayland real+gate PASS; lint255 sin
  diagnóstico. No replug/reboot/FPS. docs/audio-followup-2026-10-14/REPORT.md.

- Sonido (2026-10-14): nueva surface760×600 con Salida/Entrada/Aplicaciones/Hardware,
  dispositivos, rutas, perfiles/puertos, canales vinculados, dB, amplificación,
  formatos digitales, detención de streams y latencia. Backend pactl/libpulse y
  picos reales visibles, coalescing/cleanup; revisión corrigió4P2 y error medidor.
  6tests backend+null sinks reales+controller lifecycle+vista Wayland/offscreen+
  Escape14+motion+gate+lint+15installer PASS. Rename devuelve Not supported en
  PipeWire y se omite; hardware físico/AT-SPI/FPS sin certificar. Diseño
  pendiente de valoración. Informe docs/audio-redesign-2026-10-14/REPORT.md.

- Publicación (2026-10-14): main/origin sincronizados en ea47851 (145archivos), Matugen+wallpapers+media/bloqueo+Edots y limpieza legacy publicados. Launcher versionado conecta wrapper NVIDIA; upgrade respalda links Stow retirados preservando personales. Suite15grupos+4fixtures offscreen+15recuperación final+check vivo PASS; revisión sin hallazgos pendientes. Informes/capturas y patch experimental siguen locales. CI remoto aún sin run al primer chequeo.

- Runtime/limpieza (2026-10-14): retirados rofi/Waybar/swaync/wlogout/pywal16/wpgtk y hooks/configs legacy; NVIDIA compat615.71 obsoleto207MiB retirado (host615.78 coincide). brightnessctl y Stow instalados, launcher Isla restaurado; check vivo+14recuperación+16Matugen+gate PASS. auto-cpufreq conserva power-profiles-daemon masked: selector de perfiles no disponible. Lua activo externo limpiado sinreload, autoreload runtime desactivado hasta login; repo Hypr sigue .conf. Backup/evidencia docs/runtime-cleanup-2026-10-14/REPORT.md.

- Wallpapers aplicación escritorio (2026-10-14): loading→círculo verde/check
  integrado en el preview; surface permanece abierta hasta éxito y se retira1.1s
  después. Grow top1.45s; confirmación espera efecto y commit/recarga.
  Error conserva intento para reintento.16tests+protocolo+QA Wayland y dos cambios
  reales (incluida restauración original) PASS. Sustituye fade800ms anterior.
  Evidencia: docs/wallpaper-audit-2026-10-14/desktop-confirmation/REPORT.md.

- Wallpapers rediseño (2026-10-14): galería centrada, miniaturas mayores, flechas
  próximas, selección móvil/elevación y marcador actual; hit targets fijos. Awww
  fade800ms y target refresco30–240Hz. View/surface Wayland+12Matugen y reapertura
  shell vivo PASS; no cambio real/FPS medidos. Propuesta pendiente de valoración.
  Evidencia: docs/wallpaper-audit-2026-10-14/redesign/REPORT.md.

- Wallpapers (2026-10-14): auditoría aplicada de composición, preview retargetable,
  errores/reintento, cierre/reapertura, reduced hasta awww, URLs/revisiones y scanner
  de caché. Fixtures Wayland+pipeline+11Matugen+scanner/IPC/gate PASS; plugin usuario
  instalado y generador activo actualizado. Sin FPS/AT-SPI/multimonitor físico ni
  cambio real del fondo en QA. Evidencia: docs/wallpaper-audit-2026-10-14/REPORT.md.

- Matugen recarga: corregido argumento extra en IPC reloadColors, avisos ahora muestran stdout; prueba real de dos swaps y paletteStatus verifican adopción sin reiniciar shell.
- Matugen (2026-10-14): migración del checkout y configuración activa completa. Paleta semántica versionada/atómica, Theme/on_* y controles, ajustes/bloqueo, wallpaper/arranque, apps/GTK/Neovim y recuperación/CI. Matugen4.2.0 local oficial verificado; 7 pipeline+14 recuperación y QA seis paletas Wayland PASS. GTK abierto puede requerir reapertura, libadwaita limita CSS; no PAM/login nuevo. Backup ~/.local/state/isla/matugen-migration/20261014-104241. Fuentes/evidencia: docs/matugen-migration-2026-10-14/REPORT.md.

- Player Pixel (2026-10-14): timeline replica fuente AOSP16 seekable (onda20u/amplitud1.5u/8u-s/trazo2u; entrada60+800ms/salida550ms, curvas exactas, thumb4×16u). Sin gaps/crossfade; reset750ms y commit MPRIS atómico visual. Regresiones offscreen/Wayland+QA capturas+revisión PASS; sin certificación Pixel físico/FPS. Fuentes y límites: docs/pixel-media-timeline-2026-10-14/REPORT.md.

- Launcher (2026-10-14): limpia búsqueda también en reapertura de surface retenida (closing→false sin cambio de open). Regresión de entrada PASS offscreen/Wayland; detalle en TASK_STATE.md.

- Settings absorción (2026-10-12): retorno centrado ahora cápsula inscrita en
  pill, sin destino38×38; dimensiones siguen cambio de layout y máscara sólo al
  contacto evita vidrio/contenido duplicados. Dos ciclos split/compact Wayland
  revisados; regresiones de captura/retarget/async PASS. Navegación cold-open
  falla también antes; lag sin recorder y mismatch NVIDIA siguen pendientes.
  Evidencia: ~/.local/state/isla-motion/2026-10-12/shell-smooth/SWALLOW_CAPSULE.md.

- Auth (2026-10-12): foco/acción con acento, estados error/éxito/Bloq Mayús
  semánticos e iconos; rechazo de envío visible y nuevo desafío reinicia edición.
  Controles inhibidos durante morph inseguro/cierre, foco recuperado al revelar.
  Fixture Wayland PASS y capturas espera/error/éxito revisadas. PAM real, paletas
  alternativas y AT-SPI pendientes; qmllint255 sin diagnóstico. Ver TASK_STATE.md.

- Edots UX integral (2026-10-11): navegación responsive 6/3×2, tipografía y
  targets ampliados, error/foco semántico, guardado/feedback claro, selector
  compacto. Composer amplio evita duplicar módulos; previews ceden espacio.
  Wayland seis páginas 1000×700/640×560 y font1/1.75, paletas claras/oscuras,
  formularios/borradores/teclado y revisión visual. Evidencias/límites:
  `docs/settings-ux-2026-10-11/REPORT.md`; AT-SPI/multimonitor/perf pendientes.

- Contexto musical y Configuración (2026-10-11): Settings conserva música y
  ya no espera docking; su retorno mantiene pill en reposo antes del destino.
  Calendar incluye resumen musical fijo y acceso a media; Auth prioridad z5.
  Wayland con Players simulado cubre ambos layouts/motion, pausa/remoción,
  retarget y acceso; pruebas de foco previas se mantienen. Evidencia/límites:
  `docs/settings-media-ux-2026-10-11/REPORT.md`.

- Configuración↔superficies (2026-10-11): Edots retenido ya no toma foco
  al recibir navegación de perfil oculto; callback tardío de IslandOverlay
  conserva el hijo enfocado. Prueba nueva settings-surface-switch cubre
  13 destinos en split/compact y normal/reduced, popups, borrador, Ctrl+S,
  escritura y retarget; Escape14/vecinas pasan. Evidencia y límites en
  `docs/settings-surface-switch-2026-10-11/REPORT.md`.

- Correcciones de auditoría (2026-10-10–11): todos los IDs atendidos; cierre en
  `docs/audit-2026-10-10/fixes/REPORT.md`. Parser sin eval, acciones Accessible,
  brillo por teclado, Escape nativo en 14 superficies, límites geométricos,
  conflicto de borrador, Wi-Fi sin delete previo, lock XDG, limpieza PNG,
  energía confirmada y merge/persistencia Notifs. Gate, regresiones pertinentes
  y revisión independiente pasan. Config personal carga sin error; pruebas de
  escritura/servicios aisladas. Límites hardware/PAM/AT-SPI/multimonitor y profiling
  siguen pendientes; los resultados no certifican ausencia de otros defectos.

- Auditoría integral sin fixes (2026-10-10): `docs/ISLA_QA_AUDIT.md` reúne
  11 defectos reproducidos de producto, gate verify-config fallido y una sospecha
  de carrera Notifs; 12 traspasos en `docs/audit-2026-10-10/handoffs`.
  Prioridad: eliminación prematura de perfil Wi-Fi (P0 según escala del brief),
  eval del launcher ejecuta Qt.quit al escribir (P1), foco Escape en siete
  paneles, conflicto de borrador externo y selector de energía optimista (P2).
  54 fixtures QML distintas en dos tandas; dos condiciones de ejecución iniciales
  resueltas con servidor local/presupuesto suficiente. QA Wayland: 14 pares
  de superficies, probes nativos y previews compact/lock. Sin correcciones ni
  acciones sensibles reales. Pendientes hardware/PAM/WlSessionLock, multimonitor
  físico, arranque frío, AT-SPI/IME/contraste y profiling/frames continuos.
  Evidencia y límites completos en informe; no reutilizar PASS como certificado.

- Transiciones split/compact (2026-10-09): BarLayoutTransition retira módulos
  y reloj antes de commit, espera absorción de media y geometría real; retarget
  conserva ruta y reduced motion aplica directo. Reserva sigue modo committed
  por monitor; reservedH animable, no readonly (fallo de carga corregido).
  Settings nace/retorna desde centro, puente centrado sin extensión derecha.
  Notifs.centerOpen pertenece sólo a ShellRuntime/ruta; Loader no lo pisa.
  Shell completa arrancada y IPC verificado; pruebas/evidencia en TASK_STATE.md.

- Dos versiones + música integrada (2026-10-09, sustituye composición única
  de fase anterior): appearance.barLayout split/compact, default split. Edots
  Composición/búsqueda/ventana pequeña ofrece Separada/Compacta con preview,
  guardar y descartar. Compacta integra portada/título/visualizador sin botones de transporte
  y abre MediaSurface dentro de Pill; split conserva laterales/gota. CAVA
  y ancho compartido se liberan al ocultar/pausar/cambiar. Routing Wayland
  (switch con media abierta, launcher/ajustes/cierre), música mock/620px,
  módulos/Config/persistencia/selector pasan. Fix de unload diferido elimina
  ciclo de binding; revisión puntual cerrada y motion/composición PASS.
  QA actual música pausada y dos layouts, ajustes grandes/760×560. Preferencia
  personal original restaurada sin guardar. Multimonitor/clic de máscara y
  visualizador con reproducción real pendientes. Evidencia /tmp/isla-compact.

- Unidad compacta centrada (2026-10-09): espacios a la izquierda, reloj
  centrado y apps/estado/perfil a la derecha dentro del material único de Pill.
  Reposo56px, anchos laterales equilibrados, fondos exteriores omitidos;
  gotas conservan38px. Gate de espacio real evita solape/input durante morph;
  paneles estrechos y retorno de notificación corregidos. Regresiones de
  composición compacta Wayland (620px/14apps), módulos, geometría y movimiento
  pasan; capturas reales/reposo/mixer/calendario y revisión independiente.
  Propuesta implementada, valoración del usuario pendiente. QA físico
  multimonitor/clic de máscara y notificación real pendientes; lint255 sin
  diagnóstico, carga real válida. Evidencia /tmp/isla-compact.

- Transparencia equilibrada (2026-10-08, sustituye mínimos anteriores): con
  glassAlpha0.34, cuerpo compacto0.439 y expandido0.604. Interpolación continua
  de protección15%→40% del alpha restante; alpha1 permanece1. Preferencia
  guardada intacta. QA barra/calendario, regresión y lint PASS.

- Clima/calendario (2026-10-08): columna compacta con temperatura/ubicación,
  actualización manual, hora/error visibles arriba y pronóstico seleccionable
  con métricas del día y retorno Ahora. Valida campos parciales; conserva datos
  previos señalados ante error. Scroll para contenido grande; cierre interrumpido
  corregido. QA shell con wttr.in real, fixtures Wayland/lint y revisión pasan.
  Evidencia /tmp/isla-weather-redesign; ubicación aproximada del proveedor.

- Hover reloj (2026-10-08): eliminado fondo de MotionArea ampliada del reloj
  (margen6px sobresalía); foco teclado por subrayado, hit target/clic intactos.
  Mismo foco radial que reposo, sin aro exterior
  adicional al hover. Deriva interior y énfasis tenue conservados. QA Wayland
  reposo/hover y apertura calendario; motion-regression y lint PASS.

- Glow interior (2026-10-08): deriva sinusoidal lenta en InnerGlow compartido,
  ciclo 4×Motion.breathe, ±6% horizontal y hasta4% vertical. Conserva fase al
  ocultar; reduceMotion lo fija. Regresión Wayland y lint PASS; capturas reales
  /tmp/isla-glow-drift. No FPS/perfil GPU medido.

- Material sobre apps claras (2026-10-08): blur reactivo conservado (sin xray),
  base compacta uniforme con tinte leve (remate oscuro descartado); sombra
  exterior solo al expandir y halo del rail reducido. Expansión
  mantiene protección de lectura y preferencia opaca. QA barra Wayland y
  regresión pill-interface PASS; capturas /tmp/isla-material-contrast.

- Auditoría/rediseño pill (2026-10-08): material expandido protege lectura;
  header controlado y acotado; vacío launcher; Tab para controles overview/fondos;
  contraste secundario y labels accesibles. QA Wayland, escala/reduceMotion y
  ocho ciclos rápidos sin nueva caída. Reporte docs/PILL_INTERFACE_AUDIT.md;
  evidencia ~/.local/state/isla-audits/20261008. Hot reload SIGSEGV causa pendiente;
  verify-config falla por ruta absoluta preexistente en fixture. No AT/FPS continuo.
  Impeccable ejecutable reparado; detector QML no acredita QA. PRODUCT/DESIGN
  documentan contexto existente; preferencias personales restauradas.

- Avatar→perfil (2026-10-07): hover oscuro «Cambiar foto de perfil» con Theme;
  clic abre Edots/Tu perfil y limpia búsqueda, también con editor ya abierto.
  Sustituye acceso a sesión. Regresiones módulos/companion y lint PASS.

- Avatar input (2026-10-07): región userModule añadida a máscara de reposo;
  recibe hover/clic sin abrir otro panel. Hover real comprobado, gate y lint PASS.

- Avatar (2026-10-07): máscara circular interior ajustada a la foto (margen 2px),
  aro y fondo más discretos. QA real barra/sesión y lint pasan; regresión general
  Edots offscreen falla en búsqueda/selección de fuente/palette (ver TASK_STATE).

- Rutas Edots (2026-10-07): selector propio EdotsPathPicker (Popup.Item) con
  miniaturas asíncronas, preview grande, carpetas y filtros imágenes/JSON.
  Confirmación explícita, Escape, ubicación editable y ocultos; mantiene foco
  y máscara en la capa, sin diálogos externos. QA real y tests de preview/cancel.
  Config.userAvatarUrl codifica nombres especiales en todos los consumidores.

- Tu perfil muestra UserAvatar circular grande, sincronizado con header/barra
  y fallback de inicial (2026-10-07); QA shell real comprobada.

- Avatar Edots (2026-10-07): también arriba a la izquierda en el editor, click
  abre Tu perfil; Composición permite ocultar el avatar de barra con
  modules.userAvatar (default true), sin quitar el acceso de perfil del editor.

- Barra/avatar (2026-10-07): entrada decelerada, salida rápida, escala 0.94→1
  interrumpible; avatar circular independiente arriba a la derecha sigue
  Config.userAvatar/profile y abre sesión. Ruta actual ~/.face ausente: inicial.

- Configuración mantiene visibles los módulos laterales para previsualizar cambios
  en directo (2026-10-07); otras surfaces y fullscreen conservan ocultamiento.

- Edots surface/controles (2026-10-07): usuario aprobó diseño integrado en gota
  centrada con Win+I, navegación horizontal y Theme vivo; propuesta de ventana
  Apple lateral rechazada. FluidCompanion conserva editor al cerrar, router/foco
  integrados. Combobox ahora opaco y limitado al panel, selección nativa + entrada
  manual/teclado; seleccionar un hijo oculto reactiva Estado; selección efectiva y regresión con TopBarModules (2026-10-07). Botones/campos/
  switches/sliders pulidos; cobertura animada de todos los iconos Edots. Gates,
  Config IPC, regresiones y eventos Qt Wayland pasan; QA 1000×700/760×560.
  Evidencia y límites en TASK_STATE.md, documentación actual docs/EDOTS.md.

- Motion Edots (2026-10-06): coreografía completa de salida/entrada de páginas
  en EdotsPageMotion, selección lateral retargetable, feedback de botones/filas/
  sliders. Pruebas de interrupción, reduced/hidden y configuración pasan; QA
  Wayland de Apariencia→Movimiento, sin medición FPS. Ver TASK_STATE.md.

- Edots mejorada con referencias (2026-10-06): Caelestia Nexus, Noctalia v5 y
  Serpantinum Guide verificados en fuentes oficiales; adaptaciones y enlaces en
  docs/SETTINGS_APP_RESEARCH.md. Seis páginas, composición activable por zona,
  ritmos que preservan reduceMotion, fuentes instaladas y preview de perfil,
  búsqueda NFD+AND, reset por campo y opciones limitadas relegadas. Regresión
  QML y lint pasan, capturas Wayland normal/mínimo revisadas. Fuentes configuradas
  verificadas también en runtime; detalles y límites en TASK_STATE.md.

- Edots (2026-10-06): app nativa de ajustes en `bar/settings`, ventana integrada
  en el proceso de Isla (Config único escritor), búsqueda global, borradores,
  guardar/descartar y laboratorio sintético PillMorphMotion/PillMaterial.
  Lanzador instalado; documentación `docs/EDOTS.md`. Pruebas de contrato/IPC y
  regresión Edots pasan; QA Wayland 780×600/1100×780. Revisión independiente cerró borradores,
  mínimo y swap Música→Panel (secuencia Wayland); detalle/límites en TASK_STATE.md.

- Agency Agents (2026-10-06): biblioteca original fijada en
  `~/.local/share/agency-agents/upstream`; skill `agency-agents` enruta trabajo
  sustancial, con dos revisores nativos adicionales y cuatro economy existentes.
  Contexto bajo demanda, aceptación/evidencia y revisión proporcional al riesgo.
  TOML/skill y tres escenarios revisados; descubrimiento de roles nuevos pendiente
  en chat nuevo, sin promesa de ahorro medido. Guía/backup en carpeta de instalación;
  detalle en TASK_STATE.md. Configuración personal ignorada por Git.

- Publicación (2026-10-05): modularización y catálogo en 8438bf1, investigación
  de app en 425efcf, ambos subidos a origin/main (egaldidots). Gate estático y
  diff check pasan; checkout limpio. Raíz actual es repo completo, Isla en bar;
  carpetas no movidas. Detalles en TASK_STATE.md.

- Investigación de app (2026-10-05): seis referencias primarias revisadas:
  Noctalia, DMS, HyprPanel, illogical-impulse, Caelestia/Nexus y Serpantinum/Guide.
  Propuesta y fuentes en docs/SETTINGS_APP_RESEARCH.md: app sobre Config, búsqueda,
  composición con pill obligatoria, laboratorio de escenas y preferencias acotadas.
  DMS 1.6 ya tiene Dank Island; propuestas propias no afirman exclusividad mundial.
  Investigación documental/código, sin ejecutar shells externas ni implementar
  la app. Próximo paso propuesto: interfaz útil y laboratorio inicial; decisiones
  visuales pendientes de selección del usuario. Evidencia/límites en TASK_STATE.md.

- Separación del botón de workspaces (2026-10-01): por feedback posterior, se quitaron ambos puentes metaball entre cuadrícula y rail y se abrió un espacio visual de 24·s. Esfera activa, glow y motor permanecen. Captura Wayland ampliada, lint y regresión del rail pasan; valoración del usuario pendiente. Ver TASK_STATE.md.
- Transición de workspaces pulida (2026-10-01): el círculo usa integración amortiguada exacta por frame con velocidad conservada, deformación por velocidad sin salto de ancho, y las cifras/puntos se retiran del área que cruza. El cambio de workspace cancela hover obsoleto y ocultar resuelve una transición en curso. Borde verdoso y reflejo recto eliminados; cuello ligeramente más abierto. Regresión ampliada y secuencia Wayland 1→5→2→1 revisada fotograma a fotograma y ampliada; preview `/tmp/isla-workspace-polished.gif`. Detalle en TASK_STATE.md. Glow en otras interfaces queda para otra fase.
- Boceto fluido de workspaces (2026-10-01): el rail plano se sustituyó por botón circular de cuadrícula, puente metaball y rail oscuro; el workspace activo ahora es una esfera sobresaliente con gradiente oscuro→acento pywal, brillo y puntos de ocupación. Conserva el motor amortiguado de hover y regreso. Captura Wayland inspeccionada, regresión de movimiento/geometría y lint pasan; el avatar central sigue para una fase posterior según el usuario. Detalle en TASK_STATE.md.
- Movimiento del rail (2026-10-01): el usuario observó que el selector seguía lejos del movimiento actual de Apple. Propuesta nueva: la lente sigue hover y vuelve al activo, con dinámica amortiguada local basada en la ecuación de FluidCompanion, deformación acotada, intensidad según entrada y parada al asentarse/ocultarse. Fixture nueva cubre retarget, reposo, reduceMotion y ocultación con ISLA_CONFIG temporal; captura Wayland de hover y regreso inspeccionada, lint/logs limpios. Falta valoración visual del usuario y clic físico, sin afirmar réplica exacta de Liquid Glass. Ver TASK_STATE.md.
- Rail de navegación refinado (2026-10-01): tras rechazo del segmento genérico, añadido acceso funcional al panel de espacios con icono de cuadrícula y separador; lente de vidrio más definida con deformación acotada durante el viaje, sin loops ni cambiar PillMaterial. El número enfatizado sigue la lente. Captura final y panel abierto inspeccionados, desplazamiento confirmado por trazas temporales luego retiradas, IPC panel abre/cierra, lint y diff pasan. Workspace 4 restaurado. Ver TASK_STATE.md.
- Navegación segmentada de workspaces (2026-09-30): a petición del usuario el rail izquierdo usa selección de vidrio neutro que se desliza, con acento pywal sólo en una línea fina; se retiraron puntos de ocupación y la intensidad de cada número sigue la posición real de la lente para evitar dos activos aparentes durante cambios rápidos. PillMaterial externo intacto. `qmllint`, `git diff --check`, captura Wayland final e intermedias 1→5→2→4→1 inspeccionadas; sin errores nuevos de TopWorkspaceRail. Detalle en TASK_STATE.md.
- Barra superior lateral (2026-09-30): rail de workspaces por monitor y app/volumen/Wi-Fi/batería añadidos al overlay; reloj y avatar permanecen en la pill centrada. Tras feedback visual se equilibraron anchos y ambos laterales reutilizan PillMaterial en modo quieto, sin respiración continua. Datos reactivos de Hyprland, Pipewire, Nmcli y UPower; lente con SmoothedAnimation y reduced motion. QA Wayland en secuencias rápidas 1–5, workspace vacío, cambios Spotify/Zen/ChatGPT/Discord/Satty, hover y capturas inspeccionadas; lint y status-regression pasan. Click se conecta al mismo dispatch Hyprland ya probado por comando, pero no hubo inyector de botón disponible para verificar un clic físico. Logs nuevos sin errores de estos módulos; warnings previos de Notifs/avatar/portal siguen. Detalles en TASK_STATE.md.
- Rediseño selectivo de surfaces (2026-09-30): Mixer aprovecha el área de aplicaciones, muestra iconos/porcentajes/estado vacío y sliders accesibles; Notifs separa DND y limpiar del título; Utils rotula Apariencia y mejora contraste de perfiles; StaggerItem reduce recorrido al activar movimiento reducido. Lint y regresiones de morph/interacción/notificaciones/carga 12 surfaces pasan. Capturas previas de Mixer/Utils/Notifs/Workspaces inspeccionadas; QA Wayland posterior bloqueada por lockscreen, sin desbloquear. Detalles en TASK_STATE.md. Pendiente revisar visual final en sesión desbloqueada y preview de imágenes del portapapeles.
- Auditoría pill (2026-09-30): revisión de código de todas las surfaces y QA Wayland representativa de reposo/calendario/launcher/media vacía/overview/wallpaper. Corregidos barrido material por hover, movimiento reducido en respiración/marquee/spinner/OSD, teclado y semántica del seek, contraste y foco de overview/media. Regresiones de morph/media/overview/carga 12 surfaces, lint y diff pasan; shell recargado. Pendiente QA con música real, medición de contraste de rótulos restantes por paleta y sensación de transición continua. Detalle en TASK_STATE.md. Cambios ajenos preexistentes preservados.
- Serpantinum (2026-09-29): auditoría en `docs/SERPANTINUM_AUDIT.md`. Implementados primero Hyprland `popin 80%`/fade/slide en Lua activo y `.conf` versionado, luego indicador workspace direccional, captura anotable Satty, halo Cava y editor de apariencia. Shell recargado; paneles de apariencia/workspaces inspeccionados. Pendiente QA gráfico de captura y halo con música real y valoración de animaciones en uso. Código Quickshell propio; externo AGPL frente a MIT local, créditos no autorizan copiar sus archivos.
- Wi-Fi/clima (2026-09-29): calendario y clima unidos en panel 660×470, condiciones actuales y pronóstico seleccionable con datos wttr.in; códigos WWO corregidos. Conectividad rediseñada en vistas Wi-Fi/Bluetooth con backend Nmcli/BlueZ existente y panel 360×400. Capturas Wayland de ambas superficies inspeccionadas, regresión dedicada y qmllint pasan. Falta valoración visual del usuario y prueba manual de conexión/contraseña; no se cambiaron radios ni redes durante QA.
- Credenciales Wi-Fi (2026-09-29): WifiCredentials en el mismo vidrio, TextField nativo con máscara/mostrar/pegar/editar, mínimo WPA de 8 y estados conectar/error/éxito. El usuario rechazó la primera animación por tecla; se retiraron destello, aro y subrayado. La referencia serpantinum anima la entrada de la capa de contraseña y usa TextInput.Password sin efectos por carácter. Regresión y lint pasan; conexión real y valoración del ajuste pendientes.

- Controles: revisión global de interacción aplicada sobre Theme/pywal. Motion
  compartido + InteractionMotion/MotionArea/MotionButton; hitboxes fijos, retorno
  físico breve, swaps/gestos semánticos en MaterialIcon y reduced motion.
  Cobertura/validación en docs/INTERACTION_SYSTEM.md; 12 surfaces cargan, pruebas
  de pointer/keyboard/cancel/icon/slider y QA Wayland de controles pasan. Stress
  96 controles: media16.98ms/max22.61ms en fixture; no mide GPU/full-shell.
  Cobertura completada tras aviso de Win+M: gestos de energía/suspensión/reinicio/
  logout y conexiones explícitas de iconos/labels; menú power lockscreen, cover
  real y batería. Preview Wayland verifica las cuatro tarjetas/cancelación; panel
  real abierto/inspeccionado/cerrado. Stress aislado actualizado16.95/max22.09ms.
  Referencia Animate UI aplicada después: 80 nombres Material resueltos a paths
  Lucide locales, AnimatedSymbol con trazos/piezas independientes (Qt6.10+),
  secuencias finitas, reduced motion y parada al ocultar ventana. Galería16,
  carga12 surfaces, controles, lockscreen y Win+M Wayland pasan; shell recargado
  y panel real inspeccionado. Stress96: media18.31/max62.48ms, más coste que
  glifos; no certifica fluidez universal. Evaluación de uso prolongado pendiente.
  Fixtures no forman parte del shell.
- Solicitud sudo/Polkit: AuthPrompt inyectado + AuthSurface wrapper. Campo nativo,
  foco propio/Exclusive, retry inmediato, identidad/contexto/Bloq Mayús, guardas
  de envío y limpieza. Confirmación retenida, motion ligado al ancho disponible;
  notificaciones esperan durante auth. Backend valida socket/IDs/resultados y
  estados de conversación. Helpers askpass/fish corregidos (backup auth-bridge-
  u0asow7q); terminales existentes requieren sesión nueva. QA Wayland normal y
  claro/font1.75/motion2, regresiones backend/bridge/UI/morph/router/notif pasan.
  Shell recargado, Polkit registrado. Autenticación real de esta revisión y uso
  prolongado pendientes; no se usaron secretos ni operaciones privilegiadas.
  Corregido fallo posterior `sudo: no password was provided`: hard reload borraba
  el socket nuevo al destruir el anterior. Recarga con traspaso nativo + identidad
  estable; cuatro recargas/conexiones del shell y transporte aislado pasan.
  Askpass informa conexión indisponible sin exponer respuestas.
  Contrato/pruebas en docs/AUTHENTICATION.md y TASK_STATE.md.
- Lockscreen: primera versión instalada desde `bar/lockscreen.qml`; composición
  central, wallpaper con blur, vidrio local, avatar y tokens Theme/Motion.
  Pill→tarjeta y retorno tras éxito; textbox con rechazo/check. Lock retenido
  durante feedback de éxito; tests de coreografía Wayland/offscreen pasan.
  Perfil: `profile.displayName`, `paths.userAvatar` (default ~/.face). Preview
  Wayland y pruebas simuladas/config pasan; usuario confirmó desbloqueo real.
  Pulido Inter/fecha sobre reloj, tarjeta compacta y controles más discretos;
  Entrada afinada: traslado adelanta expansión, avatar/campo/media escalonados
  por geometría; aceptación visual de esta revisión y multimonitor pendientes.
  Decisiones y límites en `docs/LOCKSCREEN_DESIGN.md` y TASK_STATE.

- Sesión Win+M rediseñada con perfil/avatar, saludo y cuatro tarjetas de
  suspender/reiniciar/apagar/logout; bloquear secundario. Geometría640×470,
  motor gota intacto. Tests fake/companion y QA Wayland pasan; diseño pendiente
  de valoración. Referencia nueva corresponde a sesión, no a lockscreen.
- Sesión izquierda implementada; valoración del gesto por el usuario pendiente.
  Win+M command comprobado, combinación física no certificada. No ejecutar
  logout/reboot/shutdown para probar: acciones falsas y config temporal.
- Versión Fluid publicada en GitHub main, commit e8aec93 (2026-09-26): CHANGELOG y documentación
  actualizados; 12 regresiones QML y tests config/IPC/media aprobados. Archivos
  de IA excluidos localmente. Historial main saneado con autorización: retirados AGENTS, TASK_STATE,
  docs/ORCHESTRATION y tools/check_orchestration en todos los commits. Seis
  versiones conservadas, correos intactos. Respaldo y mapa de hashes privados
  en ~/.local/state/quickshell-backups/history-cleanup-5o4689zt/. GitHub aún
  resuelve un SHA antiguo por enlace directo; main sí está limpio.
- Consumo Codex: herramientas locales en `~/.codex/token-economy/`; auditoría y
  comparaciones en `~/.codex/token-economy/REPORT.md`. A/B de recuperación con
  Sol/medium: 6/6 hechos en ambos, 17,2% menos tokens; solo una pareja, no prueba
  de ahorro semanal ni de calidad universal. Orquestación y Headroom actualizados.
- Recuperación mejorada: `~/.codex/token-economy/MEMORY_RESEARCH.md`. BM25 + E5
  local, fuentes intactas y caché por contenido. Comprobación nueva 3/6 -> 6/6
  secciones esperadas entre cinco candidatos; no mide ahorro adicional de tokens.
- Recuperación por lotes aplicada: --query repetible conserva unión exacta.
  A/B Sol/medium 108.741 -> 64.728 tokens (-40,5%), 6/6 respuestas ambos; una
  pareja, antes releyó una fuente. No predice ahorro semanal ni coste de montaje.
  Evidencia: ~/.codex/token-economy/progressive-benchmark/REPORT.md. QMD probado
  aislado: vector 5/6; query completo timeout 180s. No promovido por evidencia.
- Skill personal `~/.codex/skills/ahorro-tokens/SKILL.md`: reúne el flujo y su
  medición; AGENTS conserva reglas rutinarias para no cargar la skill cada tarea.
- Fish/Starship (2026-09-28): Starship1.26.0 instalado en ~/.local/bin;
  ~/.config/starship.toml define Isla dos líneas, firma 🎩, Git/contexto,
  errores/duración/hora y transience. Colores ahora derivados de pywal con
  contraste>=4.5 sobre su background vía ~/.config/starship/pywal.py; config
  generado en ~/.cache/starship/pywal.toml, regenerado por wal_sync_signal.
  config.fish inicializa Starship y conserva
  pywal syntax/aliases/zoxide/sudo Isla; retirado tema Tide antiguo del arranque.
  Sintaxis, fixtures Git/Python/error/duración e inicio Fish pasan; QA en Kitty.
  Respaldo en ~/.local/state/shell-backups/ (latest-starship apunta al original).
  Integrado en repo como paquete Stow starship + Fish sin Tide; instalador
  incluye starship/python y README actualizado. Commit20966d4 (2026-09-28).
- Publicación completa (2026-09-28): commit74b3a2c en main incluye controles/
  iconos, Auth y puente sudo reproducible, lockscreen/lanzador, sesión/perfil,
  docs/licencias/pruebas (81 archivos). Starship ya publicado en20966d4.
  24 checks core +3 Wayland pasan; puente del repo e instalador/XDG/backup
  revalidados. Capturas iconos/Auth/lockscreen inspeccionadas. Super+L/hypridle
  del paquete Hypr conservan hyprlock; README explica opt-in al nuevo lanzador.
  Checkout sin cambios versionables pendientes. QA prolongado/multimonitor
  continúan pendientes; no se bloquearon ni autenticaron sesiones para publicar.
- Al cerrar una fase: actualizar este estado breve y registrar evidencia/límites
  en TASK_STATE.md. No duplicar el historial aquí ni guardar secretos.
- Bloqueo de sesión inspirado en serpantinum (2026-09-30): auditoría `docs/LOCKSCREEN_SERPANTINUM_AUDIT.md` sobre SHA 9861a84d, SDDM excluido. Isla implementa reposo reloj/wallpaper → acceso → alas clima/media; animación de puntos con tamaños/tiempos/curvas de `PasswordInput.qml`, reflujo y scroll. Modelo visual sin caracteres; TextField/PAM y máscara por defecto intactos. Runtime sincronizado con `~/.config/quickshell`; preview y regresiones pasan. PAM real de esta revisión, multimonitor e IME pendientes. Ver TASK_STATE.
- Glow de Isla (2026-10-01): `InnerGlow.qml` concentra luz radial interior en pill principal y estado lateral, workspace seleccionado, Keep Awake, OSD y aviso crítico. Overview ilumina la vista elegida y la portada musical conserva halo tenue al pausar. Paneles grandes quedan sobrios. Capturas Wayland, zoom, `qmllint` y regresiones pasan; portada con música y aviso crítico reales siguen sin QA visual. Detalles en TASK_STATE.
- Batería de la barra (2026-10-01): indicador propio de nivel UPower en `BatteryIndicator.qml` reemplaza símbolo genérico en estado lateral y chip efímero. Verde al cargar, gris en espera, amarillo 21–40 %, rojo ≤20 %, neutro por encima; porcentaje/estado accesibles y visibles al hover, clic abre Ajustes rápidos. `Pill.qml` corrigió lecturas `percentage/state` y recordatorio de batería baja. QA de cinco estados y captura Wayland pasan; perfiles de energía no disponibles en este equipo, así que amarillo comunica nivel preventivo, no modo ahorro.
- Skills de QA de pill (2026-10-01): `.agents/skills/pill-frame-inspection` guía captura/extracción temporal, revisión de frames y corrección de continuidad; `.agents/skills/pill-detail-audit` define auditoría iterativa visual/funcional con parada verificable. AGENTS las enruta para peticiones específicas y enlaces en `~/.codex/skills` las hacen descubribles; complementan fluid-island-motion. Validadas con skill-creator.

- Auditoría surfaces/clipboard (2026-10-04): Loader asíncrono, Notifs virtualizadas, pulso continuo de reposo retirado, consumidor CAVA compacto limitado. Super+V clipboard integrado con miniaturas/vista previa y Limpiar todo asíncrono. 13 surfaces revisadas en Wayland; regresiones y límites en docs/SURFACE_PERFORMANCE_AUDIT.md y TASK_STATE.md.

- Microinteracciones (2026-10-04): limpieza con retirada suave/estado vacío, respuesta compartida de clic, metadatos/etiquetas discretas, confirmación de sesión y filas WiFi/BT con transiciones nativas. ContentMotion/AnimatedLabel/MotionList reutilizan Motion; interrupciones/ocultación/reduceMotion probados en Wayland. Alcance y límites en TASK_STATE.

- Movimiento revisado (2026-10-05): host asíncrono con revelado, intercambios rápidos
  hacia último destino, exposición smoothstep y stagger corto ligado a geometría.
  Cursor nativo en IslaTextField; foco/placeholder y búsqueda con reduceMotion.
  Lockscreen: alas geométricas, retirada de media inferior y foco/puntos al ocultar.
  Regresiones y QA representativa Wayland; límites/evidencia en TASK_STATE.md.

- Textboxes (2026-10-05): InputCaret/InputPlaceholder compartidos en launcher,
  clipboard, Apariencia, WiFi, Auth y lockscreen; caret inmediato con peso suave
  y parpadeo tenue en reposo, hints sin solapamiento ni reflujo. Puntos de bloqueo
  sin giro/rebote y borrado acotado. Pruebas y QA sintética Wayland pasan; IME/PAM
  reales pendientes. Detalles en TASK_STATE.md.

- Arranque corregido (2026-10-05): retirado refresh prematuro que competía con la carga nativa de Hyprland; router conserva primera petición mientras falta monitor y Pill habilita workspace al completar construcción. Fallo reproducido en arranque frío; launcher abre con primera llamada a ~50ms tras fix. Router/motion/lint pasan. Login nuevo y multimonitor pendientes; detalle en TASK_STATE.md.

- Monitores/GPU (2026-10-05): configuración Lua activa usa highrr/auto, externo desactiva panel interno y desconexión lo habilita; selección GPU por sysfs conserva todas y prioriza salida externa. Usuario reinició y confirmó gran mejora de fluidez. Log posterior confirma NVIDIA primaria, DP-1 239.964Hz, sin configerrors; prueba Lua hotplug/GPU pasa. Desconexión física pendiente. Ver TASK_STATE.md.

- Apps lateral derecho (2026-10-05): iconos sin nombres por app del workspace visible, ScriptModel/MotionList con entrada/salida/recolocación y ancho SmoothedAnimation;144px con una app/batería frente a233px, vacío101px. Duplicados por class unificados; overflow desplazable. Regresión Wayland/offscreen, lint y capturas sintéticas/reales pasan. Multimonitor y muchas apps reales pendientes; ver TASK_STATE.md.
- Nombre app única (2026-10-05): presentación1800ms al aparecer y hover animado expanden lateral; varias apps sólo iconos. Retorno de varias a una existente no repite intro. Fixture QtTest Wayland y capturas pasan; offscreen falla icono Image.Null; detalles en TASK_STATE.md.

- Modularización/opcionales (2026-10-05): contrato `modules` permite rail y
  contenedor derecho, apps/audio/red/batería y animación de cambios; pill principal
  obligatoria. TopBarModules/OptionalModule retienen salida y descargan contenido,
  liberan input y resuelven reduceMotion. Indicadores/apps reciben datos;
  ShellRuntime separa integración de servicios del bootstrap; IslandStatusAdapter
  separa OSD/Caps/batería/audio de Pill mediante señales. Config/IPC,
  regresiones y QA Wayland pasan; ajustes personales restaurados sin guardar.
  Detalles, alcance y límites en TASK_STATE.md y docs/SHELL_ARCHITECTURE.md.

- Modularización siguiente (2026-10-05): WorkspaceModel adapta Hyprland; rail
  visual recibe datos/emite navegación. PillGeometry calcula tamaños sin
  servicios; MaterialChoreography separa barrido/pulso y recibe tokens.
  DesktopStatus centraliza sondeos/tracker y distribuye eventos a adapters por
  monitor. Corregidos revelado lateral antes del ancho y disparo de material
  al propagar geometría. Regresiones/QA Wayland pasan; contrato Config intacto.
  Estado y límites en TASK_STATE.md/docs/SHELL_ARCHITECTURE.md.

- Modularización de surfaces (2026-10-05): WorkspacesSurface compone
  WorkspaceModel/WorkspacesView, mantiene diez tarjetas y destinos vacíos;
  mapa compartido incluye contador de ventanas. UtilsSurface delega
  QuickControlsAdapter/QuickControlsView: datos por propiedades, acciones por
  señales, procesos/servicios fuera de la vista. QA Wayland de ambos paneles,
  swaps y navegación Apariencia realizada sin cambiar controles del sistema.
  Contratos en docs/SHELL_ARCHITECTURE.md, validación/límites en TASK_STATE.md.
  Esta fase fue completada por la separación integral registrada a continuación.

- Separación integral completada (2026-10-05): las 14 surfaces tienen vista de
  datos/señales y composición de servicios/acciones; ninguna queda pendiente.
  PillContentAdapter separa cabecera/reloj/workspace/media/notificación.
  Config/Settings sigue siendo el contrato único. Gate estático de límites,
  regresiones de carga/entrada/datos y QA Wayland de 13 paneles pasan; Auth
  validado con backend simulado. Documentación en docs/SHELL_ARCHITECTURE.md.
  Catálogo completado en fase siguiente; interfaz de configuración pendiente. Límites: PAM real,
  reproducción/dispositivos reales y multimonitor físico no probados en esta fase.

- Preparación final de composición/app (2026-10-05): OverlayInputPolicy separa
  foco/fullscreen/regiones/backdrop sin servicios; PillHeaderView separa reposo
  y cabecera; PillMorphMotion posee morph, exposición y respiración con mismas
  duraciones/retargeting. Settings.schema/catalog reúne los 30 campos, pill
  obligatoria, seis módulos opcionales y 14 surfaces con dependencias/alcance.
  IPC settings catalog disponible; inventario declarativo, no sondeo live.
  pillBlur/showGlyphs inactive, clockSeconds partial identificados honestamente.
  Gates, regresiones y QA Wayland de teclado/cierre/reapertura pasan; ajustes
  personales limpios. Los tres puntos cerrados; siguiente desarrollo: interfaz
  de la app sobre Config, no más separaciones obligatorias de esta fase.
  Evidencia y límites en TASK_STATE.md/docs/SHELL_ARCHITECTURE.md.
- Bloqueo (2026-10-09): entrada suave desde fondo opaco después de secured;
  reproductor bajo reloj sólo al reproducir, con retirada al pausar/abrir acceso
  y Loader retenido durante desaparición. Players inyectado en composición;
  LockMedia sin polling de progreso no mostrado. Ancho/altura estrechos usan
  geometría real. Regresiones entrada/motion/typing/launcher y preview Wayland
  pasan; capturas en ~/.cache/isla-lock-audit/2026-10-09. PAM/bloqueo real y
  multimonitor no probados en esta fase. Detalles en TASK_STATE.md.
- Multimedia del bloqueo (2026-10-09): usuario rechazó tarjeta inicial; propuesta
  actual con portada cuadrada grande, título/artista legibles, controles agrupados
  y composición vertical en ala. Altura adaptable a texto grande. Regresión
  Wayland/motion pasan; capturas revisadas con/sin portada y texto largo. Diseño
  pendiente de aceptación; no se ejecutó bloqueo/PAM real. Ver TASK_STATE.md.
- Multimedia del bloqueo, segunda propuesta (2026-10-09): usuario volvió a
  rechazar diseño; panel vertical centrado, portada176u, título/artista debajo,
  controles planos y fondo oscuro translúcido sin blur/borde. Ala usa variante
  compacta100u. Regresión Wayland y capturas pasan; pendiente aceptación.
- Bloqueo según referencia del usuario (2026-10-09): reloj a izquierda/media a
  derecha sobre fondo sin tarjeta; portada, metadatos, timeline nativo y controles
  planos. Estrecho/texto grande apilados; reloj recentra animado si deja de sonar.
  Sin swipe. Seek y separación probados en fixture Wayland fullscreen; motion pasa.
  Diseño pendiente aceptación, música simulada/PAM real no probado. Ver TASK_STATE.
- Material del bloqueo (2026-10-09): LockGlass ahora usa PillMaterial real de
  Isla sobre sample seguro del wallpaper; textos/controles/slider/campos y fondo
  vinculados a Theme, acento y Flags.glassAlpha. Retirados blanco/azul y borde
  personalizados. Wayland/motion/preview pasan; PAM real sin probar. Ver TASK_STATE.
- Reloj de reposo (2026-10-09): horas/minutos descienden por separado con reel
  recortado y tiempo Motion del workspace. Ancho estable incluido AM/PM;
  interrupciones toman último destino, hidden/reducedMotion sincronizan directo.
  Wayland/status/calendario-foco pasan; shell recargado. Ver TASK_STATE.md.
- Workspaces (2026-10-09): cinco estilos en Configuración→Apariencia: números
  (default), puntos, barras, cápsulas, Pac-Man. Ambos layouts, Theme, ocupación,
  urgencia, hit targets y motor físico compartidos; símbolos más densos.
  Selector envuelve en anchos pequeños. Validación/save-reload temporal y
  Wayland/composer/lens pasan; capturas en ~/.cache/isla-workspace-styles/2026-10-09.
- Pac-Man (2026-10-09): boca abre/cierra durante viaje y orienta hacia dirección;
  usa mismo FrameAnimation del lens y se detiene en reposo/hidden/reducedMotion.
  Regresiones y capturas Wayland abierta/cerrada pasan; ver TASK_STATE.md.
- Pac-Man ajustado tras feedback (2026-10-09): mordida4–44° completa sin atenuar
  por velocidad, ciclo240ms y retorno suave18°. Regresión extrema/Wayland pasa.
- Configuración (2026-10-10): selector de estilos ya no alterna checked nativo;
  marcado/acento/accesibilidad dependen sólo de Config. Prueba usa clics QtTest
  reales sin preactualizar Config, verifica exclusividad y persistencia temporal.
  Shell recargado; no configuración personal escrita. Ver TASK_STATE.md.

## Segundo cerebro local (2026-10-11)

Bóveda Obsidian: `/home/zdito/Documents/Segundo Cerebro/Isla/Inicio.md`.
Fuentes enlazadas sin copias; recuperación con recall.py existente. Puntero global
en ~/.codex/AGENTS.md para conversaciones locales fuera del proyecto. No implica
memoria en chats remotos ni ahorro de cuota medido.

## Catálogo del segundo cerebro (2026-10-11)

Bóveda ampliada con fichas de todos los archivos inventariados, índices por carpeta
y nueve mapas temáticos. `tools/brain.py` regenera; `--search 'texto'` busca contenido
literal actual y conserva todos los resultados fuera del contexto. Archivo ignorado
o binario: ficha de ruta, sin indexar contenido. Fuentes/declaraciones son evidencia
extraída, relaciones por nombre son candidatas; comprobar código. Pruebas en
`tools/test_brain.py`. Detalles y límites en TASK_STATE.md.

## Skill de recuperación selectiva (2026-10-11)

`/home/zdito/.codex/skills/segundo-cerebro/SKILL.md` rige el uso oportuno de
mapa, historial, fichas y código vigente; activación indicada en AGENTS global/local.
Evita relecturas y búsquedas redundantes; mantiene notas y regenera fichas tras cambios.
No promete ahorro medido. Validación y límites en TASK_STATE.md.

- Recuperación integrada (2026-10-11): instalador/CI de desktop-recovery se unen
  a main con Edots y contratos actuales; checkout in situ y enlaces Wpscan
  rotos corregidos. 14 pruebas de recuperación, gate, lock y Starship pasan;
  instalación real/login limpio no probados. Detalles en TASK_STATE.md.

- Presentación pública (2026-10-11): README, arquitectura, Edots, Auth, pruebas
  y changelog simplificados. 230 informes/evidencias/archivos de memoria retirados
  del índice, conservados localmente y excluidos en .git/info/exclude. 11 fuentes
  QML/JS sólo comentarios; gate y enlaces Markdown pasan. Historial Git intacto.

- Resortes del video (2026-10-11): experimento retirado tras caídas de sesión
  durante reload de Hyprland, también al restaurar. animations.lua activa externa
  restaurada por cmp; QML propio revertido, patch/backup en
  ~/.local/state/isla-motion/2026-10-11. Fondo guardado reaplicado, awww confirma.
  No reintentar reload real sin diagnosticar en aislamiento. Causa raíz no
  identificada; portal SEGV en journal no la certifica. Ver TASK_STATE.md.
- Diagnóstico reload (2026-10-11): journal muestra global wl_output unavailable
  y muerte de clientes, sin core Hyprland. monitors.lua externo ordena disable
  eDP en cada config.reloaded (confirmado en mock); patrón coincide upstream12996
  v0.56.2. Causa probable: carrera salidas/reload, portal SEGV secundario.
  Falta log compositor previo para certeza; no nuevo reload/fix. Informe en
  ~/.local/state/isla-motion/2026-10-11/diagnostico/INFORME.md.
- Mitigación de reload preparada (2026-10-11): monitors.lua candidato en
  ~/.local/state/isla-motion/2026-10-11/correccion registra estado del panel durante
  carga, sin callback config.reloaded; pruebas Lua/sintaxis PASS. Activo intacto.
  Instalar con sesión cerrada usando APLICAR.md; no reload real. Pendiente hardware
  y compositor aislado; estado DRM no garantiza imagen. Ver TASK_STATE.md.
- Mitigación instalada en disco (2026-10-11, sustituye pendiente instalación):
  usuario autoriza reiniciar luego. misc.disable_autoreload=true sólo runtime,
  inotify cero watches comprobado antes de copiar monitors.lua corregido.
  Sin reload; siguiente inicio aplicará fix y restaurará watcher por defaults.
  Backup conservado; QA hardware pendiente. Ver TASK_STATE.md.
- Logout Win+M (2026-10-11): Session usa uwsm stop cuando gestionado, fallback
  loginctl terminate-session con XDG_SESSION_ID obligatorio. Legacy dispatch exit
  retirado; confirmación intacta. Mock command/fixture sesión/load singleton PASS,
  Isla cargó cambio; uwsm dry-run válido. No logout real, lint255 sin diagnóstico.
- Nuevo inicio confirmado (2026-10-11 11:53): mitigación monitores cargada sin
  configerrors, DP-1 activo/eDP apagado; watcher volvió al default habilitado.
  Logout/login usuario realizado. Recarga/hotplug siguen sin probar; no reload.

- Modernización Hyprland instalada en disco (2026-10-11): conserva Isla/dwindle;
  popin94/97 y tiempos menores, spring reflow620/43, smart_split, modales centrados,
  Shift+flechas mover espacios, Shift/Ctrl+F fullscreen/maximizado y gesto scratchpad.
  Parser0.56.2 PASS, revisión independiente sin bloqueos. No reload/QA visual;
  requiere nuevo login. Autoreload runtime deshabilitado. Backup/informe en
  ~/.local/state/isla-motion/2026-10-11/modernizacion; monitores intactos.

- Investigación glass (2026-10-11): acrylic wiki Latest rechazado por parser0.56.2.
  HyprGlass ofrece rama0.56/presets/selección, pendiente compilar y QA; no instalado.
  Propuesta prioriza vidrio mate/foco nativo, luego piloto kitty. Reporte en
  ~/.local/state/isla-motion/2026-10-11/diseno/INVESTIGACION.md. Sin cambios activos.

## 2026-10-11 · Vidrio aplicado

Vidrio/foco instalado en disco: nativos+Kitty82%+HyprGlass0.56 piloto Kitty, capas Isla intactas. Build/parser/mock/Kitty PASS, revisión fuente independiente. Sin reload/runtime plugin/QA; requiere logout/login. Backup ~/.local/state/isla-motion/2026-10-11/vidrio-aplicado. Motionblur off.

- Referencia glass aplicada live (2026-10-11): Kitty50%, rounding20/power2
  (máximo regla instalado), glow35/shadow28, preset vidrio menos distorsionado.
  Parser/runtimePASS/pluginactive, captura grim inspeccionada; fondo oscuro
  produce vidrio oscuro. Backup referencia-glass. No reload ni medición GPU.

## 2026-10-11 · Kitty estética y movimiento

Kitty pulido: pipeline local motionblur cursor + foco250ms/tab200ms, tipografía12.5/espaciado/pestañas indexadas. Vidrio50% intacto. Slang2026.18.2 local, GLSL/parserPASS y preview inspeccionado. F8 reduce/F9 restaura (CtrlShift). Config recargada soloKitty, noHyprland. Backup kitty-estetica; GPU/fluidez sostenida pendiente.

## 2026-10-11 · Flujo scrolling

Scrolling nativo aplicado live y disco: user prefiere flujoNiri a splits horizontales. Columnas50%, foco/anchos/centro/reordenar/agrupar. Smart_splitfalse. Parser/runtimePASS sinreload; snapshot inspeccionado. Backup/rollback ~/.local/state/isla-motion/2026-10-11/scrolling. Overview/gestos/multi-monitor pendienteQA.

- Límite QA scrolling: captura actual muestra pantalla bloqueada; no permite
  evaluar columnas. Solo runtime/config verificados; QA visual pendiente desbloqueo.

- 2026-10-11: Fastfetch renovado con logo original Edots PNG, información contextual y paleta del terminal. Config activa ~/.config/fastfetch/config.jsonc; respaldo/QA ~/.local/state/isla-motion/2026-10-11/fastfetch-isla/.
- Fastfetch: preferencia posterior del usuario reemplaza PNG por arte ASCII Edots cian-violeta (~/.config/fastfetch/edots.txt); verificado visualmente en Kitty.

- 2026-10-12: Edots añade sección Hyprland: flujo y animaciones live, guardar/revertir propios y persistencia isla/hyprland.json al iniciar Isla. Backend valida/serializa, conserva curvas y protege herencia/resortes; recuperación explícita con backup. Mock/QML/UI/UX/routing PASS y speed+restore nativo PASS sin reload. Evidencia ~/.local/state/isla-motion/2026-10-12/hyprland-settings/RESULTADO.md; login/layout reales y multimonitor pendientes.

- 2026-10-12: Expulsión/captura compartida pulida: resorte exacto independiente
  de dt, reposo con velocidades, reabrir absorción sin reset, cuello pinzado y
  borde continuo también al retornar; contención de cápsula0.08·s, contenido
  en ambos ejes y reduceMotion live. Regresiones/gate/routing Wayland PASS;
  dos ciclos threaded examinados, driver alternativo no adoptado. Lint255 sin
  diagnóstico; GPU sostenido/multimonitor físico pendientes. Evidencia:
  ~/.local/state/isla-motion/2026-10-12/shell-smooth/RESULTADO.md.

- 2026-10-12 seguimiento Settings: bloqueo síncrono de270ms identificado;
  editor retenido precarga async con guard Ready. Contracción conserva layout
  y escala uniforme; radio limitado24·s elimina inflación intermedia.
  Continuidad/async/centered/surface-switch/gate PASS; QA nativo editor real
  en shell-smooth/settings-swallow-real-*. Sin benchmark GPU sostenido.

- 2026-10-12 lag: llvmpipe comprobado; NVIDIA módulo615.71.09 vs bibliotecas615.78.08. Experimento Mesa+Intel bajó CPU pero produjo escritorio negro confirmado por usuario. REVERTIDO en autostart y ambos recovery binds; shell original restaurada PID419833 y captura muestra escritorio/barra/ventanas. No volver a adoptar Intel en esta sesión sin integración visual comprobada. Lag y discrepancia NVIDIA pendientes. Evidencia gpu-lag/RESULTADO.md.

- 2026-10-12 solución lag NVIDIA: cache615.71.09 aislado y scripts/start-isla.sh ante mismatch kernel/userspace; integrado autostart y ambos recovery binds. Main GTX1660Ti hardware, sin llvmpipe, DP-1 escritorio/editor visibles; CPU3s278→46%, contracción fixture mediana20.48→4.49ms (no FPS). Launcher guards/cache parcial/reboot simulado PASS; surface-switch13 destinos PASS; revisión independiente sin bloqueante. Reboot físico/global mismatch no reparado; tras coincidencia wrapper usa sistema. Evidencia gpu-lag/RESULTADO.md.

- 2026-10-12 scrolling: reproducido bleed de Spotify offscreen del workspace2 al salir horizontalmente hacia3 vacío. workspaces cambia a slidevert live+persistent (animations.lua), columnas horizontales; before/after100ms demuestran ausencia de Spotify y clientes2 intactos. Mitigación compositor, sin restart; evidencia scrolling-workspace/RESULTADO.md.

- 2026-10-13 transición Niri: prototipo scrolloverview compilado y pruebas nativas iniciales PASS, pero instalación/recarga persistente congeló Hyprland (usuario reinició). Plugin desactivado, sólo hyprglass cargado tras reinicio; configerrors vacío. Super+Tab conserva Isla, fallback slidevert vigente. Implementación NO terminada; no recargar plugin sin resolver bloqueo.

- 2026-10-13 cierre manual Niri/bloqueo: Super+Tab stock scrolloverview7ff22457 compatible0.56.2; Super+Shift+Tab Isla. Carga externa al inicio, sin transición automática ni plugin load dentro de parse. Host ciclos/navegación/cambio vistas PASS, default/configerrors vacío; revisión corrigió clic con Super mediante ignore_mods. Bloqueo: reloj/fecha jerárquicos, acceso central, media adaptable, velo estático y sin blur duplicado; dots vacíos no pisan placeholder. Fixtures Wayland, texto1.75/white wallpaper/launcher PASS; rendimiento driver4ms igual antes/después, no claimFPS. Sin prueba de PAM real, teclas físicas ni otros monitores. Detalles docs/WORKSPACE_TRANSITIONS.md y docs/lockscreen-redesign-2026-10-13/REPORT.md.

- 2026-10-13 energía del bloqueo: popup nace del botón (escala0.94→1 y reveal350ms), opciones escalonadas, iconos Lucide animados, descripciones y confirmación con check/acento; cierre140ms, reduceMotion inmediato. Fondo reforzado para texto1.75 y foco/confirmación limpiados al cerrar. Power fixture/core/motion Wayland PASS; acciones reales no ejecutadas. Evidencia ~/.local/state/isla-motion/2026-10-13/lockscreen-power/.

- 2026-10-13 scrolling/foco: input.follow_mouse1→2 live y persistente en hypr/modules/input.lua. Hover conserva foco/viewport; clic y atajos cambian ventana. Super+P colresize+conf y anchos0.333/0.5/0.667/1 intactos. Warps nativos por bordes con Zen PASS foco/tamaños conservados; foco/cursor originales restaurados.

- 2026-10-13 entrada de apps: windowsIn popin94%/serpantinum260ms→slide right/softFluid360ms live+persistent. Ventanas entran lateralmente con tamaño final; windowsMove spring y workspace slidevert intactos. Kitty de prueba abre/cierra y clientes/workspaces conservados, captura+video window-sheet; sintaxis/configerrors PASS. Es aproximación nativa, no motor Niri ni benchmarkFPS.

## Referencia MacShell (2026-10-16)

Revisión estática del commit18d9ceb: material/refracción, capturas, texto, música,
Dock/popups y notificaciones contrastados con Isla. Propuestas priorizadas en
`docs/macshell-review-2026-10-16/REPORT.md`: portada/ambiente coordinados, luz de
material discreta, crossfade de metadatos, menús alineados y ciclo de previews.
Sin implementación ni ejecución/QA visual de MacShell; propuestas no aprobadas.
Conservar motor físico, Theme/Motion y rechazo de contornos neón. Shader tintcard
sin consumidor QML encontrado: no atribuirlo a un efecto activo.

## Mejoras MacShell integradas (2026-10-17)

Autorizadas por usuario e implementadas conservando motor/identidad: ArtworkImage
retiene/cambia portadas con último URL pendiente; panel+ambiente comparten barrera
416·s/256 y progreso en split/compact, conservando fuente durante cierre real.
CrossfadeLabel para metadatos sin deformación; título reserva2líneas redondeadas
para evitar recorte. Luz/sombra interior fija tenue y menú alineado si cabe.
Edots: materialDepth0.25 (Apariencia), mediaTransitions y menuSelectionAnchor true
(Movimiento/Apariencia), save/discard probado en config temporal. QA Wayland,
HTTP lento/cancelación, routing2layouts/2motion, fuentes1–1.75 y settings PASS.
Revisión corrigió layout/sincronía/retención. qmllint255 sin diagnóstico; sin FPS
ni AT-SPI. docs/macshell-review-2026-10-16/implementation/REPORT.md y capturas.
Acabado pendiente valoración. No se copió shader ni cambió reproducción personal.

## Publicación 2026-10-18

Todos los cambios funcionales pendientes publicados en origin/main hasta d09ca29, en seis commits por UI, audio, portapapeles, CAVA, reproductor y documentación. Árbol limpio y HEAD igual a origin/main. Capturas, informes y memoria siguen locales conforme a la política del repositorio. Evidencia en TASK_STATE.md.
