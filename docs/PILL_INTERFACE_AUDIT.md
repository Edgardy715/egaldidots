# Auditoría y rediseño de la pill · 2026-10-08

## Resultado y dirección

Isla mantiene la pill compacta translúcida, las gotas y el motor Fluid existentes.
Las superficies de lectura usan un material más estable, menos contornos/glow,
cabeceras con jerarquía y texto secundario legible. No se añaden funciones,
dependencias ni motores. Se preservan datos y cambios ajenos presentes al inicio.
La petición actual permite revisar preferencias históricas: el aumento de opacidad
expandida se justifica por el texto del escritorio que competía con los controles.
glassAlpha sigue gobernando reposo y una preferencia de opacidad 1 se respeta.

## Fuentes y disponibilidad

Se consultaron AGENTS.md, PROJECT_MEMORY.md, secciones pertinentes de TASK_STATE,
MOTION_LANGUAGE.md y SHELL_ARCHITECTURE.md; skills fluid-island-motion,
pill-detail-audit, apple-inspired-ui, impeccable, ui-design, ui-ux-pro-max,
qt-qml, quickshell, animate, ui-animation, pill-frame-inspection, ponytail y
agency-agents. MCP disponibles: archivos/terminal, imágenes, navegador y
Context7/documentación. Navegador usado para HIG; captura nativa con grim,
teclado con wtype e IPC del proyecto. CUA no habilita control nativo.

Impeccable tenía su script sin permiso de ejecución; se corrigió con chmod u+x
en ~/.codex/skills/impeccable/scripts/impeccable. context funciona. Se aplicaron
sus criterios de composición, contraste, jerarquía, estados y craft-floor.
Su detección no identifica QML: detect --json devuelve []; no es evidencia de
conformidad. PRODUCT.md/DESIGN.md registran el contexto existente; Linux/Wayland
queda fuera de la enumeración de plataformas web/móvil del detector. Se usó el
brief explícito del usuario, sin inventar una plataforma web ni repetir una
entrevista que contradijera la autorización de continuar. No se instalaron MCP
ni dependencias opcionales. wf-recorder no disponible; grim ofrece muestreo
irregular con tiempos reales, sin certificar FPS.

Referencias consultadas: [Apple Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
para material que protege contenido denso;
[Qt Item](https://doc.qt.io/qt-6.8/qml-qtquick-item.html) para foco/Tab y
[SmoothedAnimation](https://doc.qt.io/qt-6/qml-qtquick-smoothedanimation.html)
para continuidad al retarget. Los contratos locales siguen siendo autoridad.

## Hallazgos y disposición

La evidencia está en `/home/zdito/.local/state/isla-audits/20261008`.
Capturas privadas del escritorio; no se incorporan al repositorio ni se publican.
Originales completos conservados. comparison.png compara la misma región para
utils/overview/wallpaper. El fondo del escritorio cambia durante la sesión, por
lo que la comparación es de geometría y legibilidad, no una medición fotométrica.

| Tipo / impacto | Evidencia y reproducción | Archivos | Corrección / estado |
| --- | --- | --- | --- |
| Demostrado: búsqueda sin feedback | Abrir launcher y escribir una consulta inexistente; before/launcher-empty.png | LauncherController, LauncherView, LauncherSurface, Pill, PillGeometry | Estado sin coincidencias después del debounce; no durante cálculo/cierre; altura compartida y fixture |
| Demostrado: Tab captura navegación | Abrir overview y Tab: movía selección en lugar de alcanzar botones. Código y teclado nativo | IslandOverlay, OverviewView, WallpaperView | Tab/Backtab recorren controles; flechas exploran contenido. after/overview-controls.png y overview-group.png; wallpaper-tab.png y wallpaper-key-closed.png |
| Demostrado por código: etiquetas idénticas | Todas las miniaturas anunciaban el mismo nombre | WallpaperView | Nombres únicos con índice/nombre de archivo. No validado con lector de pantalla |
| Demostrado: exposición de cabecera incorrecta | Timer local sobrescribía entered incluso false; reproducido por fixture | SurfaceHeader | entered vuelve a ser entrada; no Timer local. Altura real y elipsis evitan choque con trailing |
| Oportunidad visual: fondo y doble contorno compiten | before/{utils,overview,wallpaper}.png muestran escritorio visible detrás del contenido y borde concéntrico | PillMaterial, Pill | Expansión eleva alpha, atenúa halo/sheen y elimina segundo contorno; sombra común. after/*-final.png |
| Demostrado para paleta actual: texto pequeño tenue | Theme.dim vs fondo: 3.07:1; secondary compuesto sobre fondo: 5.72:1. Son tokens, no garantía de toda composición | SurfaceHeader, WorkspacesView, ClipboardView, HintKbd, AppItem, SessionView, IslandRestStatus, WallpaperView | Reutiliza iconSecondary; badge seleccionado oscuro sobre fondo claro; sin doble reducción de opacidad |
| Oportunidad: media vacío sin siguiente paso | Abrir Media sin reproductor, before/media.png | MediaView | Título jerárquico y ayuda breve; after/media-final.png |
| Defecto de copia: carpeta fija falsa con configuración personalizada | Vacío decía ~/Wallpapers aunque path es configurable | WallpaperView | Instrucción neutral a la carpeta de fondos; no cambia indexación |
| Hipótesis descartada: sexta fila cortada | launcher-results.png deja fila parcial al límite; navegación a sexta en launcher-scroll-final.png la expone completa | LauncherView/PillGeometry existentes | Lista desplazable funciona; sin cambio de geometría innecesario |
| Incidencia observada pendiente: hot reload SIGSEGV | Crash g51gqmlmt, report 13:37:41; Qt QPainterPath/QQuickShape/derefWindow; log con recargas e incubation | Runtime Qt/Quickshell; origen exacto sin determinar | No se declara corregido ni causado por navegación. Repetición sin reload conserva instancia sin crash nuevo |

No se atribuyen a esta tarea las modificaciones previas de Settings, módulos,
avatar, rutas o servicios. Se guardó el diff inicial fuera del repositorio para
comparar autoría; no se restauraron archivos globalmente. PillMaterial elimina
lectura directa de Players: artUrl llega por propiedad desde composición.

## Cobertura nativa

Monitor DP-1 1920×1080, escala del compositor 1, 239.964Hz; preferencias iniciales
uiScale=1, fontScale=1.2, glassAlpha=.34. Capturas de reposo, calendario,
utilidades, conectividad, volumen, notificaciones, launcher, fondos, overview,
media, clipboard, workspaces, sesión, apariencia y Settings. Capturas iniciales
con región 420,0 1080×820; finales completas para evitar recortar companions.

- Estados asentados comparables: after/utils-final.png, overview-final.png,
  wallpaper-final.png y comparison.png. launcher-empty.png muestra feedback.
- Launcher: consulta, debounce, vacío, calculadora/errores por regresión; teclado,
  Escape/reapertura y sexta fila completa en shell. No se lanzó aplicación real.
- Overview: grupos, foco, selección y controles por teclado; overview-group.png
  acredita grupo 5–8 sin cambiar el workspace real.
- Fondos: preview real, miniaturas, navegación, Tab a cerrar y Return cierra sin
  aplicar. after/wallpaper-with-media.png, wallpaper-tab.png. Biblioteca actual
  tiene 35 imágenes; vacío/error/loading se cubren parcialmente por fixtures y
  fuente, no por biblioteca real vaciada. No se aplicó fondo ni paleta.
- Media: reproductor MPRIS sintético por D-Bus, reproducción/pausa, título largo,
  carátula fallback y carátula QA, gota compacta y absorción; after/media-*.png.
  No audio real. fixture detenida; media-final.png acredita ausencia de player.
- Notificación sintética propia sobre calendario y restauración posterior:
  notification-calendar.png/notification-restored.png. No se eliminó historial.
- Settings: editor asentado y composición revisados; settings-with-media.png y
  settings-final.png. Persistencia, errores y discard/save probados sólo con
  archivos temporales. No se guardaron preferencias personales.
- Escala uiScale1.25/fontScale1.4 y reduceMotion=true en sesión: overview,
  launcher y wallpaper *-large-reduced.png; retarget rápido rapid-reduced.png.
  Config.update y discard restauraron documento/effective iniciales y dirty=false.
  restoration.json acredita limpieza; no cambios en datos del usuario.
- Interacción hover/pulsación/cancelación y hitboxes: QtTest pertinente y regiones
  nativas existentes. No clic físico end-to-end exhaustivo en todas las acciones.
  Sesión sólo apertura/cierre; no shutdown/logout/lock real ni polkit auténtico.

## Movimiento y revisión independiente

El muestreo original motion/ conserva un diálogo de crash de la instancia previa;
no usarlo como gate limpio. Informe mtime13:37:41 precede los finales de las
capturas originales. La instancia se reinició antes de concluir esa evidencia.
La coincidencia del diálogo no demuestra que un swap produjera SIGSEGV.

motion-clean/timing-{0,1}.json conserva tiempos monotónicos reales: 67 y 62
muestras durante ~4.77s. Secuencia media→hide→overview→wallpaper→launcher→hide→
media→hide con cambios antes de asentarse, más seis repeticiones rápidas.
stability.json: misma instancia g51tmnlmt PID1492, sin nuevos informes de crash.
Se inspeccionaron contactos y estados. No cortes materiales visibles en las
muestras observadas; no se garantiza cada fotograma ni una tasa continua.
No se cambió el motor ni su easing por razones estéticas sin defecto demostrado.

Revisión independiente agency_ui_reviewer: aceptó evidencia de Settings, media
vacío, launcher desplazable, fondo/foco/cierre, escala y movimiento reducido.
Detectó el diálogo de crash y pidió revalidar; tras muestras limpias retiró
atribución a navegación. No encontró otro defecto nuevo confirmado en acabado
o interacción final. economy_researcher aportó análisis acotado de input antes
de implementar. No reemplaza aceptación estética por el usuario.

## Pruebas

Todas con ISLA_CONFIG temporal cuando modifican ajustes. Logs iniciales en
`tests/` de la carpeta de evidencia; salidas completas adicionales en
~/.cache/codex-economy, sin confundir warnings offscreen con QA visual.

PASS: pill-geometry (incluye altura de vacío), motion, surface-choreography,
interaction, surface-data-contract, overview, wallpaper, media-session,
media-motion (primera corrida playing:false), absorption (fixture determinista
30/60/144/240Hz), session-companion, settings-companion, notification,
launcher-controller e interaction-surfaces (14 surfaces). PASS adicional:
quick-controls; node settings.cjs y surface-boundaries.cjs; settings-integration.py
con IPC/persistencia temporal. PASS en Wayland: surface-data-contract y nueva
pill-interface-regression; ésta también offscreen y reejecutada tras cierre de
cambios. Comprueba alpha escalada/preferencia opaca, entered/límites de header y
vacío/search/calculadora/cierre. No obliga a servicios musicales reales.

qmllint de /usr/lib/qt6/bin y git diff --check PASS. Advertencias heredadas de
unqualified access permanecen; /usr/bin/qmllint antiguo no sirve en este entorno.
Gate global verify-config.sh NO PASS: ruta absoluta preexistente
`/home/zdito/Edots app icon.png` en bar/optional-modules-regression.qml:47.
No se toca esa fixture ajena; sus subchecks pertinentes se ejecutaron por separado.
Logs de recarga registraron conflictos temporales de Polkit/notificaciones e
incubation durante reemplazo; se conservan sin declararlos defectos corregidos.

## Límites pendientes

SIGSEGV durante hot reload: causa no aislada, no corregido; no hubo caída en la
repetición limpia. Gate global bloqueado por ruta heredada. Sin FPS continuo,
prueba prolongada, multimonitor, lector de pantalla/AT real, autenticación real,
player/audio real, ni validación exhaustiva de todos los estados error/loading
con servicios fallando. Sin aprobación estética del usuario. El rediseño no
certifica esos requisitos; los estados y pruebas comprobados quedan arriba.
