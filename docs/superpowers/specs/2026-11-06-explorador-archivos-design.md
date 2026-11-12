# Explorador de archivos de Azog (nombre de trabajo: «Files»)

Fecha: 2026-11-06. Estado: spec pendiente de revisión del usuario.

## Objetivo

Sustituir Thunar como gestor de archivos del sistema por uno propio, con la identidad
Quicksilver/Azog: rápido, fluido, animado y ligero. Éxito = abrir una carpeta de 20 000
archivos sin tirones visibles, navegar con animación continua, y poder usarlo a diario
(copiar, mover, papelera, arrastrar a otras apps) sin volver a Thunar salvo casos raros.

## Decisiones tomadas

- **Superficie:** ventana flotante propia (`FloatingWindow` de Quickshell), no surface de la pill.
  Motivos: drag & drop con otras apps, foco compartido con terminal/navegador, varias instancias.
  Se pierde el morph desde la pill; se compensa con apertura animada interna. Acceso rápido
  desde la pill (Lugares/Recientes) queda para una fase posterior.
- **Lenguaje:** QML para UI; listado con `Qt.labs.folderlistmodel` (C++ nativo, inotify,
  hilo propio); helper Python por pipe para operaciones largas y miniaturas de vídeo (mismo
  patrón que `bar/services/clipboard_library.py`). Sin plugin C++ propio (se rompe con cada
  actualización de Qt en Arch). Rust sólo si `qmlprofiler` demuestra un cuello de botella
  real; hoy no hay toolchain instalado.
- **Thunar** permanece instalado como respaldo.

## Arquitectura

| Unidad | Rol | Depende de |
| --- | --- | --- |
| `windows/FilesWindow.qml` | Ventana flotante; `Loader` desde composición; se destruye al cerrar | Theme, Motion |
| `components/files/FilesView.qml` | Composición: barra lateral, ruta, vista, estado | las demás |
| `components/files/FilesModel.qml` | Envuelve `FolderListModel` (orden, ocultos, filtro de búsqueda) | folderlistmodel |
| `components/files/FileGrid.qml` / `FileList.qml` | Vistas virtualizadas con `reuseItems`; delegados ligeros | FilesModel |
| `components/files/SelectionModel.qml` | Selección (clic, ctrl, mayús, caja, teclado) y resaltado único deslizante | — |
| `components/files/PathBar.qml` | Breadcrumb animado; Ctrl+L lo vuelve editable | — |
| `components/files/Sidebar.qml` | Lugares (XDG) y unidades (`lsblk`/udisks2) | helper |
| `components/files/QuickLook.qml` | Vista previa con espacio; crece desde el elemento | — |
| `Singletons/FileOps.qml` | Cola de operaciones: copiar, mover, papelera, renombrar, deshacer; progreso | helper |
| `services/files_helper.py` | Operaciones con progreso/cancelación y miniaturas de vídeo (`ffmpegthumbnailer`, caché `~/.cache/thumbnails`) | stdlib |

Los componentes hoja reciben datos por propiedades y piden acciones por señales; la
composición conecta servicios (regla de `docs/SHELL_ARCHITECTURE.md`).

### Integración

- IPC: `qs ipc call files open <ruta>` (y `toggle`).
- `files.desktop` como gestor por defecto de `inode/directory`; interfaz DBus
  `org.freedesktop.FileManager1` (ShowFolders/ShowItems) en una fase posterior si es viable.
- Ajustes en `Settings.js` (sección `files`: vista, ocultos, tamaño de icono, orden); cambios
  vía `Config.update/save`; textos con `I18n.tr` y `i18n/en.js`.

## Animaciones (muelles de `Motion`)

Apertura: el cristal se despliega con `Motion.surfaceSpring`. Navegar: deslizamiento
direccional (entrar/subir) sólo del contenido visible. Selección: un único resaltado que
se desliza entre elementos. Caja de selección elástica. Miniaturas con fundido. QuickLook:
crece desde el rect del elemento y regresa a él. Segmentos de ruta se reacomodan. Con
`reduceMotion` se sustituye por fundido corto. Sin partículas ni rebotes gratuitos.

## Reglas de rendimiento

Sin shaders ni `MultiEffect` por elemento; delegados mínimos; `Image` asíncrono con
`sourceSize`; nada anima fuera de pantalla ni con la ventana oculta; `Loader` con
precalentamiento en reposo (objetivo de apertura ≲150 ms, a medir, no asumido); el helper
no corre si no hay operaciones. Operaciones largas nunca en el hilo de la UI.

## Alcance v1

Entra: navegar, cuadrícula/lista, miniaturas (imagen y vídeo), selección ratón/teclado,
abrir (`xdg-open`), copiar/cortar/pegar con progreso y cancelación, renombrar, papelera
(`gio trash`), carpeta nueva, deshacer papelera/renombrar, arrastrar y soltar dentro y fuera,
QuickLook, buscar al teclear, menú contextual, ocultos, orden.

Fuera (fases posteriores): pestañas, MTP/red, propiedades/permisos, acceso desde la pill,
DBus FileManager1.

## Manejo de errores

Permisos o rutas inexistentes: la ruta vuelve al último directorio válido con aviso breve.
Operación fallida: se reporta por elemento sin abortar el resto; el helper nunca borra
definitivamente (sólo papelera) y confirma antes de sobrescribir. Carpeta eliminada mientras
se ve: sube al padre existente. Si el helper muere, la cola informa y se reinicia.

## Pruebas

- Regresiones QML siguiendo `bar/TESTING.md` (selección, navegación, cola de operaciones con
  `ISLA_CONFIG` temporal y directorio fixture).
- Tests Python del helper (copiar/mover/cancelar/colisiones) como `test-hypr-binds.py`.
- Rendimiento: fixture de 20 000 archivos, `qmlprofiler` sobre abrir/scroll/navegar.
- QA visual en Wayland aparte; offscreen no cuenta como QA visual. Se distinguirá probado,
  no verificado y bloqueado en `TASK_STATE.md`.

## Riesgos abiertos

- Transparencia/blur de la ventana depende de reglas de Hyprland (rama `hyprland-glass-keybinds`);
  verificar en vivo.
- `FloatingWindow` no puede posicionarse desde el cliente en Wayland: tamaño/centrado por
  `windowrule`.
- DnD saliente desde Qt en Wayland: probar con navegador y terminal antes de prometerlo.
- `FolderListModel` carece de mime y de ocultos por patrón; si limita, la alternativa es un
  modelo propio alimentado por el helper (decidir con medición).
