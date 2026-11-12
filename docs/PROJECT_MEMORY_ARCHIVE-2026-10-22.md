# Archivo de PROJECT_MEMORY.md (mapa detallado al 2026-10-22)

Copia íntegra y sin cambios del mapa antes de reducirlo a índice el 2026-10-22.
No editar; el estado vigente está en PROJECT_MEMORY.md. Buscar con rg o
`recall.py --file docs/PROJECT_MEMORY_ARCHIVE-2026-10-22.md` y leer por rangos.
<!-- fin-cabecera-archivo -->

# Isla: mapa de memoria

Actualizado: 2026-10-22. Mapa de rutas y estado activo; código y petición actual
prevalecen. Leer sólo lo pertinente; este mapa no certifica runtime actual.

## Recuperar evidencia

- Historial: `python ~/.codex/token-economy/recall.py 'tema' --root /home/zdito/.config/quickshell`.
  Agrupa consultas con `--query`. TASK_STATE.md conserva decisiones y pruebas;
  no leerlo completo. Si conoces archivo/rango, acceder directamente.
- Mapa anterior íntegro: `docs/PROJECT_MEMORY_ARCHIVE-2026-10-18.md`.
  Buscar términos con rg y leer rangos; no cargarlo completo al retomar.
  Si recall no encuentra una decisión anterior, usar `--file` con ese archivo
  y seleccionar rangos antes de leer secciones extensas.
- Bóveda e inventario: skill segundo-cerebro; no regenerar ni explorar todo
  por rutina. Mantener este mapa breve; nuevos detalles van a TASK_STATE.md.

## Contratos y rutas

- Grabación directa GPU (2026-10-21): sustituye OBS por gpu-screen-recorder,
  portal, H.264 hardware30/VFR sin fallbackCPU. Audio sistema/mic independientes;
  cuenta atrás/morph y pill REC/pausa/guardado. Sin auxiliar al cerrar en reposo.
  Binario6.1.4 disponible localmente sin instalar paquetes de sistema.
  Evidencia y límites docs/recording-2026-10-21/DIRECT.md; captura portal/audio real
  pendiente de medición propia; usuario confirma funcionamiento. Encoder NVENC
  sintético y QML Wayland PASS. Afinado visual posterior: barra grabar/morph, audio
  agrupado y tiempo/estado integrado; refinement/REPORT.md, valoración pendiente.
  Estado separado en gota izquierda (música derecha), compartiendo Fluid y reloj;
  click abre controles, fallback por espacio/sesión/settings. Split/compact,
  interrupciones/input/reduced y revisión PASS. Evidencia drop/REPORT.md.

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

## Estado activo

- Eshell Pets (2026-10-22): fase4 funcional; bar/pets runtime/host/ghost en
  botón existente de workspaces, sin alterar input/layout. Config/Edots pets,
  disabled default, sólo monitor activo; descarga hidden/sin espacio, reduced
  y fallback a ojos previos. Settings/persistencia/editor, Wayland/input/overlay,
  gate/lintQt6 y revisión PASS. docs/eshell-pets-2026-10-22/REPORT.md y plan
  docs/ESHELL_PETS_PLAN.md. Sueño one-shot45s local, dos respiraciones y quietud;
  workspace/hover/foco despiertan, reduced/minimal estático. Wayland/sueño/input/
  gate/lint/revisión PASS. phase2/REPORT.md: baseline2rondas, CPUquiet0observada,
  reacción8,425/sueñoactivo9,275%núcleo, PSS+7,73/9,55/12,92MiB: target8pendiente.
  SVG cacheado descartado por peor consumo, Shape conservado. Compositor sin
  bloom blanco; clip muestreado sleep-wake.mp4. Fase3: media cabecera y wallpaper
  placa/miniaturas, eventos reproducción/pista/selección/éxito confirmado; una
  instancia entre rutas/monitor mediante petContext y petPresented/petEligible.
  Wayland composición real+servicios simulados, input/sueño/cierre/suspensión/
  retarget/late-result, gate/lintQt6 y revisión PASS. phase3/REPORT.md. No nuevo
  coste global medido ni comandos personales. Fase4: BuiltinPet ghost/blob/octopus,
  ajustes por superficie/sueño/mirada/reacciones y botón accesible de alimentar
  en música; comida1,6s finita, reduced/minimal estático, hidden cancela. Wayland,
  persistencia/editor14campos, gate/lint y revisión PASS;9capturas compositor,
  phase4/REPORT.md. Próxima fase5 paquetes/plantilla/validador/skill; sin nueva
  medición de recursos ni multimonitor físico.

- Edots navegación (2026-10-22): SettingRow crea sólo editor aplicable y bloque
  Restablecer si modified; foco vuelve al editor despuésreset. Qtconfig0snapshot/
  validate al navegar, núcleo~0,52ms: no Rust para este cuello de creaciónUI.
  DosparesWaylandABBA: Apariencia mediana máximo62,5→21ms; peor global70→23ms,
  driver noFPSfísicos. Teclado/reset/Tab/ShiftTab, UX/font1,75/compacto/borradores,
  retarget/reduced/async/gate PASS; revisiónUI sin defectos. Baseline, métricas y
  capturas docs/settings-latency-2026-10-22/REPORT.md. Config/persistencia/motion
  intactos;23ms aún puede exceder un frame rápido, sin pruebaCPU/RAMglobal.

- Biblioteca clipboard Rust (2026-10-21): lector opcional instalado, sólo list;
  QML/modelos y escrituras/previews/copia Python intactos, sin daemon. En fixture
  QML privada0/100/1000entradas, datos disponibles39→3 /55,5→6 /65,5→14ms;
  CLI20muestras alternadas y permisos/flock/validación conservados. FormatosJSON
  no representables hacen exec fallback tras liberarlock; ausencia vuelvePython.
  Unit8/paridadCLI7/biblioteca9/launcher-atómico/QMLnative-fallback/instalador15
  y gate PASS; revisión independiente sin defectos. Evidencia y límites en
  docs/rust-clipboard-list-2026-10-21/REPORT.md; no medirlo como latencia global,
  primer pixel o ahorro residente. Sin tocar historial personal/reiniciar shell.

- Audio peak híbrido (2026-10-21): cdylib Rust sin dependencias integrada e
  instalada; sólo reduce muestras finitas vía ctypes. Python conserva captura,
  fragmentos/envelope/routing y fallback; QML intacto. Cuatro parejas privadas
  de12s con2medidores: CPU árbol3,366→1,249% de un núcleo; PSS+97,5KiB, sin
  mejora de latencia demostrada. Guard Linux compartido process_lifetime elimina
  pactl subscribe huérfano al cerrar controlador; EOF/TERM/KILL/query/servidor,
  QML native/fallback y callersCAVA/Nmcli PASS. Build locked/atómico y rollback;
  docs/rust-audio-peak-2026-10-21/REPORT.md. Sin reiniciar shell; backend en nuevos
  bridges. Sin mejora global/RAM/batería/FPS/arranque ni prueba de horas.

- CAVA híbrido Rust (2026-10-21): helper nativo instalado; QML/Qt y CAVA/parec
  conservados. Launcher exec elige Rust y pasa propietario QS; fallback Python
  si binario ausente. Comparación privada ABBA60Hz: árbol activo28,60→17,32MiB
  PSS (~11,28MiB); CPU2,47→1,98% observada, sin generalizar dos muestras.
  Unit/clippy/paridad/lifecycle/QML/backend/envelope/revisión PASS. Build opcional
  locked/atómico: scripts/build-cava-helper.sh; evidencia y rollback en
  docs/rust-cava-2026-10-21/REPORT.md. Sin ahorro global/FPS/energía demostrado.

- Rendimiento (2026-10-21): sesión QObject estable en media, espectro/brillo/CAVA
  ocultos suspendidos, envelope en silencio sin frames y rebind PipeWire por
  señales. Descubrimiento CAVA por eventos/reconciliación; escaneo Wpscan async,
  uno activo + último pendiente. Módulo compilado e instalado; Nmcli monitor
  hace exec con parent-death, sin huérfanos tras SIGTERM/reload. Regresiones y
  revisión independiente PASS; datos y reproducción en
  docs/performance-2026-10-21/REPORT.md. Sin mejora global de RAM/arranque ni FPS
  demostrados; baseline antes del reinicio recuperado con 402 hashes.

- Personalidad (2026-10-21, afinado): pulso discreto sin aro, concentrado abajo;
  hover sin tooltip, luz local/expresión/presión y foco visible. Reemplaza acabado
  intenso rechazado. Refinement Wayland/input/reduced PASS. Pulso por resultados de
  clipboard/Wi-Fi/Config/enfoque, carga compacta, compañero original con mirada
  y expresiones (appearance.personality) y timer temporal1..180min. Sin Shelf
  por aclaración del usuario. Informativas preservan surfaces; crítico/auth
  priorizados y avance consume identidad mostrada incluso destruida. Wayland
  personalidad/focus/compacta y gates/regresiones PASS; sin hardware/FPS.
  docs/personality-2026-10-21/REPORT.md y reception-preview.gif.

- Referencias Nusa/Coucou (2026-10-21): investigación, sin cambios funcionales.
  Propuesta de respuesta semántica, bandeja temporal, vistazo contextual y timer;
  conserva Fluid/Swiftify. Evidencia y límites nativo/demo/licencias en
  docs/nusa-coucou-2026-10-21/REPORT.md y COUCOU-EVIDENCE.md.

- Rail workspaces (2026-10-18): ancho retargeteable Motion.morph como panel apps,
  nuevas posiciones se revelan al ganar espacio; selección acotada al ancho
  actual. Respeta animateChanges/reduced/hidden. Fixture5→6/inversión y lente
  Wayland PASS; compacta integración offscreen PASS. Evidencia/límites en
  docs/workspace-width-2026-10-18/REPORT.md; sin cambiar workspace real/FPS.

- Wallpaper música (2026-10-18): corregido guard width>1000 imposible con cuerpo
  1000 menos márgenes. Header adapta metadatos al ancho y conserva cover estrecho.
  Fixture cabecera Wayland escalas1/0.8 y fuente1/1.5 PASS; docking real del motor
  con gota simulada wallpaper/overview/launcher normal/reduced PASS. Evidencia
  docs/wallpaper-media-2026-10-18/REPORT.md; sin modificar reproducción/fondo.

- Conectividad rediseño (2026-10-18): dos vistas confirmadas por usuario,
  cuerpo460×520, selector con estado, conexión destacada y acciones BT debajo
  del nombre. Cambio retira antes de sustituir; hidden/reduced resuelven.
  Credenciales con escala legible/colores semánticos; Tab/ShiftTab revelan foco
  en lista desplazable. Fixtures mock y host Wayland, input y lintQt6 PASS.
  Evidencia/límites en docs/connectivity-2026-10-18/REPORT.md; diseño aprobado por
  usuario, sin conexiones reales ni FPS.

- Auditoría general (2026-10-18): Nmcli libera procesos y serializa refrescos;
  brillo agrupa destinos/teclas y rechaza lecturas obsoletas; launcher no activa
  resultados pendientes; clipboard conserva texto y libera jobs; calendario sin
  loops ocultos, cierre reduced inmediato, urgent y URLs wallpaper corregidos.
  Servicios/datos/Wayland11surfaces/gate PASS; revisión independiente atendida.
  SinFPS ni hardware/PAM real. docs/shell-audit-2026-10-18/REPORT.md.

- Fluidez Edots (2026-10-18): selección atómica evita secciones transitorias al
  pasar Composición; sin filas ocultas y selector de fuentes sólo bajo demanda.
  Navegación/UX/controles/async/motion/gate PASS; driver máximo176/181→62/58ms,
  Composición11/14ms. SinFPS; Apariencia aún~60ms. Evidencia
  docs/settings-fluency-2026-10-18/REPORT.md.

- Tipografía bloqueo (2026-10-18): LockSurface/LockMedia usan Theme.fontMedia
  (Inter actual); hora Medium, tnum, CurveRendering, tracking−2 y sombra suave.
  Preview Wayland reposo/acceso y guards PASS; evidencia en
  docs/lockscreen-type-2026-10-18/. Sin bloqueo/PAM real.

- Cambio de pista reposo (2026-10-18): compacto/split opt-in de portada con
  compresión sutil desde valor actual; misma portada también reacciona. Imagen
  retenida/fundido y entrada4px; metadatos funden/trasladan4px. Panel conserva
  defaults. Hidden/reduced/disabled cancelan. FixtureWayland e HTTP art PASS;
  revisión puntual sin hallazgos. docs/rest-track-transition-2026-10-18/REPORT.md.

- Seguimiento media compacto (2026-10-18): aro reactivado desde MediaSession;
  CAVA pequeño comparte neón/acento/energía en compacto y split, sin nuevo reloj.
  Pausa/silencio/reduced/oculto desactivan efecto. Compact offscreen/Wayland,
  CAVA nativo eje1/1.25, lintQt6 y gate PASS. Evidencia en
  docs/compact-audit-2026-10-18/media-followup/REPORT.md.

- Auditoría compacta (2026-10-18): corregidos reserva de rail oculto, metadatos
  cortos/inexistentes, portada sola36px en estrecho, fontScale, foco único visible,
  selección de workspace acotada y separadores ligados a exposición. Compact
  Wayland/offscreen, layouts11surfaces, interrupciones/notificaciones, módulos,
  rail, lintQt6 y gate PASS;72muestras temporales en2ciclos. Revisión independiente
  sin nuevos hallazgos. SinFPS/AT-SPI/multimonitor físico; propuestas de prioridad
  apps/ancho y fallback de rail en docs/compact-audit-2026-10-18/REPORT.md.

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

## Otras áreas: consultar según la tarea

- Wallpapers/Matugen: docs/matugen-migration-2026-10-14/REPORT.md;
  historial de wallpapers/launcher/sonido en TASK_STATE.md y mapa archivado.
- MacShell: docs/macshell-review-2026-10-16/implementation/REPORT.md.
- Bloqueo: docs/lockscreen-redesign-2026-10-13/REPORT.md.
- Workspaces/Niri: docs/WORKSPACE_TRANSITIONS.md. No reintroducir el prototipo
  de plugin que congeló Hyprland sin resolver su bloqueo; consultar historia.
- GPU/arranque, vidrio, Kitty y scrolling: mapa archivado y TASK_STATE.md.
  No adoptar experimentos de GPU previamente revertidos sin QA real.
- Publicación 2026-10-22: código, pruebas y documentación publicados en main hasta e66a860;
  informes/capturas/memoria locales. Consultar git para estado vigente.
- Cuotas/orquestación 2026-10-18: reglas globales ~/.codex/AGENTS.md y roles
  ~/.codex/agents; trabajo directo por defecto, encargos finitos/contexto nuevo.
  Evidencia y reversión en ~/.codex/token-economy/audit/2026-10-18/.
  No hay ahorro de cuota demostrado todavía ni cambio de modelos/razonamiento.

- Claude local (2026-10-22): CLAUDE.md importa AGENTS.md y orienta a mapa/bóveda/skills.
  .claude/settings.local.json añade contexto externo; Desktop tiene MCP edotsShell.
  Detalles y comprobaciones en TASK_STATE.md, sección Claude local.
