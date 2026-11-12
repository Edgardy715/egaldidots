# Explorador de archivos (Files) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Un gestor de archivos propio de Azog, en ventana flotante, rápido y animado, que sustituya a Thunar en el uso diario.

**Architecture:** QML para la UI; el listado lo hace `Qt.labs.folderlistmodel` (C++ nativo con inotify); un helper Python por stdin/stdout NDJSON ejecuta operaciones largas con progreso y cancelación y genera miniaturas de vídeo. Los componentes hoja reciben datos por propiedades; la composición (`FilesView`) conecta `FileOps` y modelos.

**Tech Stack:** Quickshell 0.3.2 (`FloatingWindow`, `Process`, `IpcHandler`), Qt 6 Quick, `Qt.labs.folderlistmodel`, Python 3 stdlib, `ffmpegthumbnailer`, `lsblk`.

**Spec:** `docs/superpowers/specs/2026-11-06-explorador-archivos-design.md`

## Global Constraints

- Rutas de este plan relativas a la raíz del repo (`/home/zdito/.config/quickshell`); el código QML vive en `bar/`.
- Textos visibles con `I18n.tr("…")` y entrada en `bar/i18n/en.js`; colores sólo de `Theme`/`IslaPalette`; tiempos sólo de `Motion` (`Motion.surfaceSpring`, `Motion.standard`, `Motion.fast`); `Motion.mult` ya aplica `reduceMotion`.
- Ajustes: defaults y validación en `bar/Singletons/Settings.js`; cambios con `Config.update/discard/save`; `Flags` es de sólo lectura. Pruebas con `ISLA_CONFIG` temporal.
- Sin shaders ni `MultiEffect` por elemento; nada anima fuera de pantalla ni con la ventana oculta.
- El helper nunca borra definitivamente: sólo papelera. Nunca sobrescribe sin política explícita `overwrite` elegida por el usuario.
- Pruebas QML: `ISLA_CONFIG=/tmp/isla-files-test.json QT_QPA_PLATFORM=offscreen qs -p bar/<nombre>-regression.qml`; deben imprimir `PASS: …` (QtTest no imprime fallos bajo `qs -p`). Offscreen no es QA visual.
- Commits sólo si el usuario lo pide; `git add` únicamente los archivos de la tarea (el árbol tiene trabajo ajeno sin commit); sin líneas de atribución a Claude.

## Review Focus

- Nombres con `#`, `%`, `?`, espacios, saltos de línea, Unicode o `-` inicial: rutas y URLs `file://` correctas en miniaturas, abrir y arrastrar (Task 2, 4).
- Copiar/mover una carpeta dentro de sí misma o de un descendiente: error limpio, nada copiado (Task 1).
- Pegar en la misma carpeta de origen: «mantener ambos» (`a (2).txt`), nunca sobrescribir el original (Task 1).
- Carpeta eliminada, desmontada o sin permiso de lectura mientras se ve: sube al padre existente con aviso, sin colgar la UI (Task 2, 6).
- Enlaces simbólicos rotos o en bucle; directorio vacío; 20 000 archivos (Task 2, 4, 8).

---

### Task 1: Helper de operaciones (`files_helper.py`)

**Files:**
- Create: `bar/services/files_helper.py`
- Test: `bar/tests/files-helper.py`

**Interfaces:**
- Produces (CLI): `python3 files_helper.py <op>`; lee una línea JSON de stdin y emite NDJSON a stdout. `op ∈ {conflicts, copy, move, trash, restore, rename, mkdir, thumb}`.
  - Petición: `{"sources":[abs…], "dest":abs, "conflict":"skip|keepboth|overwrite"}` (`copy`/`move`); `{"paths":[abs…]}` (`trash`); `{"entries":[{"trashed":abs,"original":abs}…]}` (`restore`); `{"path":abs,"name":str}` (`rename`); `{"parent":abs,"name":str}` (`mkdir`); `{"path":abs,"size":int}` (`thumb`).
  - Eventos: `{"event":"progress","done":int,"total":int,"current":str}`, `{"event":"item_error","path":str,"error":str}`, `{"event":"done","ok":bool,"cancelled":bool,"undo":{...}|null,"result":...}`. `conflicts` devuelve `result: [nombres existentes en dest]`; `thumb` devuelve `result: ruta png|null`.
- Produces (módulo, para tests): `plan_conflicts(sources: list[str], dest: str) -> list[str]`, `unique_name(dest_dir: Path, name: str) -> str`, `run_copy(req: dict, emit: Callable) -> dict`, `run_move`, `run_trash(req, emit)`, `run_restore`, `thumb_video(path: str, size: int) -> str | None`.

- [ ] **Step 1: Write failing tests** in `bar/tests/files-helper.py` (unittest, `tempfile.TemporaryDirectory`, `HOME`/`XDG_DATA_HOME` redirigidos al temporal; importa el helper con `importlib` como `test-hypr-binds.py`):
  `test_copy_tree_preserves_symlinks`, `test_keepboth_names_a_2_txt`, `test_paste_in_same_folder_never_overwrites`, `test_skip_leaves_destination_untouched`, `test_overwrite_requires_explicit_policy`, `test_copy_into_itself_rejected` (carpeta → su descendiente: `ok=False`, ningún archivo creado), `test_move_across_same_fs_is_rename`, `test_trash_writes_trashinfo_and_restore_roundtrips`, `test_trash_never_unlinks_when_trash_fails`, `test_cancel_via_sigterm_emits_cancelled_done` (proceso real, árbol grande), `test_unreadable_item_reported_rest_continues`, `test_odd_names` (`"a#b%20 c?.txt"`, `"-rf"`, `"x\ny"`, `"ñ😀.txt"`, symlink roto), `test_progress_monotonic`.
- [ ] **Step 2: Run** `python3 bar/tests/files-helper.py -v` — Expected: FAIL (módulo no existe).
- [ ] **Step 3: Implement** `bar/services/files_helper.py` con las funciones de Interfaces. Copia con `os.scandir` + `shutil.copy2`/`os.symlink` (no sigue enlaces), troceada de 1 MiB para emitir progreso (máx. 20 eventos/s); mover = `os.rename` y, si cruza FS, copia + borrado del origen sólo tras copiar con éxito; papelera según la spec FreeDesktop (`~/.local/share/Trash/{files,info}`, `.trashinfo` con ruta percent-encoded, nombre único); otro FS → `gio trash` sin `undo`. SIGTERM → bandera de cancelación comprobada entre trozos. Miniaturas: URI `file://` percent-encoded → md5 → `~/.cache/thumbnails/{normal,large}/<md5>.png` vía `ffmpegthumbnailer -i … -o … -s <size>`. Rechaza rutas no absolutas y `name` con `/` o `..`.
- [ ] **Step 4: Run** `python3 bar/tests/files-helper.py -v` — Expected: PASS, 0 fallos.
- [ ] **Step 5: Commit** (si el usuario lo pide): `git add bar/services/files_helper.py bar/tests/files-helper.py`.

### Task 2: Ajustes y modelo de carpeta (`FilesModel`)

**Files:**
- Modify: `bar/Singletons/Settings.js` (sección `files`, junto a `regional`, línea ~54 y metadatos ~139), `bar/i18n/en.js`
- Create: `bar/components/files/FilesModel.qml`, `bar/components/files/PathUtil.js`
- Test: `bar/tests/files-settings.py` (patrón `settings-integration.py`), `bar/files-model-regression.qml`, fixture generada en el temporal (script en el propio test).

**Interfaces:**
- Produces (`Settings.js`): `files: { view: "grid"|"list" = "grid", showHidden: bool = false, iconSize: int 48..160 = 96, sortField: "name"|"modified"|"size"|"type" = "name", sortReversed: bool = false, dirsFirst: bool = true }`.
- Produces (`PathUtil.js`): `toUrl(path: string) -> string` (codifica `#`, `%`, `?`, espacios, saltos de línea; resultado `file:///…`), `fromUrl(url) -> string`, `parent(path) -> string`, `segments(path) -> [{name, path}]`, `nearestExisting(path, existsFn) -> string`.
- Produces (`FilesModel`): `property string path`; `property alias count`; `property string filter` (búsqueda al teclear, insensible a mayúsculas/acentos); `readonly property bool loading`; `signal pathLost(string fallback)`; funciones `get(i) -> {name, path, url, isDir, size, modified}`, `indexOfName(name) -> int`, `navigate(path)`.

- [ ] **Step 1: Write failing tests**: settings (defaults, rechazo de `iconSize: 5` y de `view: "x"`, round-trip temporal vía `Config.update/save`); regresión QML `PathUtil` (`toUrl("/t/a#b%20c?.txt")` re-decodifica a la misma ruta; `segments("/home/u/x")` da 4 migas con `"/"` raíz) y `FilesModel` sobre fixture (carpeta vacía, 20 000 archivos cuenta correcta, symlink roto listado sin colgar, `pathLost` al borrar la carpeta mostrada, filtro «cafe» encuentra «Café»).
- [ ] **Step 2: Run** `python bar/tests/files-settings.py` y `ISLA_CONFIG=/tmp/isla-files-test.json QT_QPA_PLATFORM=offscreen qs -p bar/files-model-regression.qml` — Expected: FAIL.
- [ ] **Step 3: Implement** la sección `files` y `PathUtil.js`; `FilesModel` envuelve `FolderListModel` (`showHidden`, `sortField`, `sortReversed`, `showDirsFirst` desde `Flags`/`Config`), filtra con un `QSortFilterProxy`-equivalente en JS sólo si `filter` no está vacío (si no, usa el modelo directo para no copiar 20 000 filas). Detecta carpeta perdida cuando `status` pasa a error/`count` 0 y la ruta ya no existe (comprobación con `Process test -d`) y emite `pathLost(PathUtil.nearestExisting(...))`.
- [ ] **Step 4: Run** los dos comandos — Expected: `PASS` en ambos.
- [ ] **Step 5: Commit** (si lo pide): archivos de la tarea.

### Task 3: Cola de operaciones (`FileOps`)

**Files:**
- Create: `bar/Singletons/FileOps.qml`
- Modify: `bar/Singletons/qmldir` (`singleton FileOps FileOps.qml`), `bar/i18n/en.js`
- Test: `bar/file-ops-regression.qml`

**Interfaces:**
- Consumes: protocolo del helper (Task 1), `PathUtil`.
- Produces (`FileOps`): `readonly property bool busy`, `readonly property real progress` (0..1), `readonly property string current`, `readonly property bool canUndo`; `function conflicts(sources: var, dest: string, cb: function)`; `function copy(sources, dest, policy: string)`, `move(sources, dest, policy)`, `trash(paths)`, `rename(path, name)`, `mkdir(parent, name)`, `undo()`, `cancel()`, `function thumb(path, size, cb)`; `signal finished(string op, bool ok, string message)`; `signal itemFailed(string path, string error)`. Una cola FIFO; un `Process` por trabajo con `stdinEnabled: true`, petición escrita como una línea JSON; se destruye al terminar; pila de deshacer acotada a 20 (`trash`→`restore`, `rename`→`rename`, `move`→`move` inverso).

- [ ] **Step 1: Write failing test** `file-ops-regression.qml` (directorio temporal por `Quickshell.env("ISLA_FILES_TEST_DIR")`): copy+progress hasta 1.0, `finished("copy", true, …)`, trash→`undo()` restaura, `cancel()` durante una copia grande da `ok=false`, dos trabajos encolados terminan en orden, helper ausente (`ISLA_FILES_HELPER=/no/existe`) → `finished(…, false, …)` sin colgar, nombres raros de Review Focus.
- [ ] **Step 2: Run** `ISLA_FILES_TEST_DIR=$(mktemp -d) ISLA_CONFIG=/tmp/isla-files-test.json QT_QPA_PLATFORM=offscreen qs -p bar/file-ops-regression.qml` — Expected: FAIL.
- [ ] **Step 3: Implement** `FileOps.qml` (ruta del helper por `Qt.resolvedUrl("../services/files_helper.py")`, anulable con `ISLA_FILES_HELPER` para tests).
- [ ] **Step 4: Run** el mismo comando — Expected: `PASS: file operations queue …`.
- [ ] **Step 5: Commit** (si lo pide).

### Task 4: Selección y vistas (`SelectionModel`, `FileGrid`, `FileList`)

**Files:**
- Create: `bar/components/files/SelectionModel.qml`, `bar/components/files/FileGrid.qml`, `bar/components/files/FileList.qml`, `bar/components/files/FileDelegate.qml`
- Test: `bar/files-views-regression.qml`

**Interfaces:**
- Consumes: `FilesModel` (Task 2).
- Produces (`SelectionModel`): `property var selected` (conjunto de rutas), `readonly property int count`, `property int currentIndex`; `select(i)`, `toggle(i)`, `extendTo(i)` (mayús), `selectRect(rect, itemRectFn)`, `selectAll()`, `clear()`, `move(delta: int, extend: bool)`, `paths() -> [string]`.
- Produces (`FileGrid`/`FileList`): propiedades `model`, `selection`, `iconSize`; señales `activated(int index)`, `contextRequested(int index, point pos)`, `dragStarted(var paths)`; `function positionAt(index) -> rect` (para QuickLook y resaltado); `function ensureVisible(index)`.
- Producto del delegado: icono por tipo (mime aproximado por extensión en JS; sin llamadas por elemento), miniatura de imagen con `Image { asynchronous: true; sourceSize: Qt.size(iconSize*2, iconSize*2); cache: true }` sólo si la extensión es de imagen y el delegado es visible; miniaturas de vídeo vía `FileOps.thumb`. `reuseItems: true`, `cacheBuffer` acotado.

- [ ] **Step 1: Write failing test** `files-views-regression.qml`: clic, ctrl-clic, mayús-clic, flechas con mayús, caja que cruza 3 elementos, `selectAll`, selección sobrevive al reordenar, 20 000 elementos: `FileGrid` instancia menos de 200 delegados (contador `Component.onCompleted`), scroll al final sin delegados fantasma, tecla Home/End, miniatura de `a#b%20c.png` carga (`Image.Ready`).
- [ ] **Step 2: Run** `ISLA_CONFIG=/tmp/isla-files-test.json QT_QPA_PLATFORM=offscreen qs -p bar/files-views-regression.qml` — Expected: FAIL.
- [ ] **Step 3: Implement** los cuatro componentes; resaltado de selección = un solo `Rectangle` por selección contigua visible que desliza (la animación llega en Task 7; aquí sólo geometría correcta).
- [ ] **Step 4: Run** — Expected: `PASS: files views …`.
- [ ] **Step 5: Commit** (si lo pide).

### Task 5: Ruta y barra lateral (`PathBar`, `Sidebar`)

**Files:**
- Create: `bar/components/files/PathBar.qml`, `bar/components/files/Sidebar.qml`, `bar/components/files/PlacesData.qml`
- Test: `bar/files-nav-regression.qml`

**Interfaces:**
- Produces (`PathBar`): `property string path`, `signal navigateTo(string path)`, `signal editingChanged`, `function startEditing()`; con `PathUtil.segments`; editable con Ctrl+L, Enter navega, Esc cancela; ruta inválida deja el campo con error y no navega.
- Produces (`PlacesData`): `readonly property var places` (`[{name, path, icon}]` Home, Escritorio, Documentos, Descargas, Música, Imágenes, Vídeos desde `xdg-user-dirs`, sólo los que existen) y `readonly property var drives` (`[{name, path, mounted, size}]` de `lsblk -J -o NAME,LABEL,MOUNTPOINT,SIZE,RM,TYPE`, refresco al abrir y cada 30 s sólo si la ventana está visible); `signal navigateTo(string path)` en `Sidebar`.

- [ ] **Step 1: Write failing test**: migas correctas para `/`, `/home/u`, ruta con espacios; Enter con ruta inexistente no emite `navigateTo`; `PlacesData` ignora carpetas XDG inexistentes y entradas de `lsblk` sin mountpoint como «no montada»; JSON de `lsblk` malformado no rompe.
- [ ] **Step 2: Run** `ISLA_CONFIG=/tmp/isla-files-test.json QT_QPA_PLATFORM=offscreen qs -p bar/files-nav-regression.qml` — Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** — Expected: `PASS: files navigation …`.
- [ ] **Step 5: Commit** (si lo pide).

### Task 6: Composición, ventana, IPC y gestor por defecto

**Files:**
- Create: `bar/components/files/FilesView.qml`, `bar/components/files/ContextMenu.qml`, `bar/windows/FilesWindow.qml`, `bar/components/files/FilesHost.qml` (`Loader` + ciclo de vida), `bar/scripts/isla-files` (lanzador: `qs -c bar ipc call files open "$1"`), `bar/assets/azog-files.desktop`
- Modify: `bar/shell.qml` (añadir `FilesHost {}` y `IpcHandler { target: "files" }`), `bar/TESTING.md`
- Test: `bar/files-integration-regression.qml`, `bar/tests/files-ipc.py` (patrón de `settings-integration.py`)

**Interfaces:**
- Consumes: Tasks 2–5.
- Produces (IPC `files`): `open(path: string): bool` (ruta inexistente o relativa → `false`; archivo → abre su carpeta con ese archivo seleccionado), `toggle(): bool`, `close(): bool`.
- Produces (`FilesHost`): `function open(path: string)`, `function close()`; la ventana se crea al abrir y se destruye al cerrar; si ya existe, la lleva al frente y navega. `FilesView` conecta: navegación (historial atrás/adelante, `Alt+←/→`, `Backspace` sube), abrir (`xdg-open` por `Process` con ruta como argumento, nunca por shell), menú contextual (Abrir, Abrir con…, Copiar, Cortar, Pegar, Renombrar, Papelera, Carpeta nueva, Copiar ruta), portapapeles interno de rutas, barra de progreso de `FileOps`, conflictos (diálogo propio: Omitir / Mantener ambos / Reemplazar), `pathLost` → navega al fallback con aviso.

- [ ] **Step 1: Write failing tests**: `files-ipc.py` abre con ruta válida (`true`), rutas relativas e inexistentes (`false`), `toggle` dos veces deja cero ventanas; regresión QML: navegar a subcarpeta/atrás/arriba, copiar→pegar con conflicto muestra el diálogo, papelera+`Ctrl+Z`, abrir un archivo con espacios y `#` llama a `xdg-open` con el argumento íntegro (stub vía `ISLA_FILES_OPENER`), carpeta borrada bajo la vista → fallback.
- [ ] **Step 2: Run** ambos — Expected: FAIL.
- [ ] **Step 3: Implement.** `FilesWindow` usa `FloatingWindow` con `color: "transparent"`; el cristal lo dibuja la UI con los tokens de `Theme`; título «Azog · Archivos». `.desktop` con `MimeType=inode/directory;` y `Exec=<repo>/bar/scripts/isla-files %f`.
- [ ] **Step 4: Run** ambos — Expected: PASS.
- [ ] **Step 5: Install check (manual, Wayland):** copiar el `.desktop` a `~/.local/share/applications/` y `xdg-mime default azog-files.desktop inode/directory` **sólo con el visto bueno del usuario** (cambia configuración del sistema); verificar `xdg-open ~/Documents` abre la ventana.
- [ ] **Step 6: Commit** (si lo pide).

### Task 7: Interacción avanzada (arrastre, QuickLook, búsqueda)

**Files:**
- Create: `bar/components/files/QuickLook.qml`, `bar/components/files/RubberBand.qml`
- Modify: `bar/components/files/FilesView.qml`, `FileGrid.qml`, `FileList.qml`
- Test: `bar/files-interaction-regression.qml`

**Interfaces:**
- Produces (`QuickLook`): `property string path`, `property rect originRect`, `property bool open`, `signal closed`; imagen o texto (primeros 64 KiB) o icono grande; Espacio abre/cierra, flechas cambian de archivo.
- DnD: `Drag.mimeData = {"text/uri-list": urls}` con `PathUtil.toUrl`; soltar sobre carpeta o miga de la ruta llama `FileOps.move` (Ctrl = `copy`); soltar sobre la ventana desde fuera copia.
- Búsqueda al teclear: letras imprimibles rellenan `FilesModel.filter`, Esc la limpia.

- [ ] **Step 1: Write failing test:** Espacio abre QuickLook con `originRect` = `positionAt(i)`; Esc lo cierra; teclear «car» filtra y selecciona la primera coincidencia; arrastre interno a carpeta mueve el archivo; archivo con `#` sale en `text/uri-list` codificado.
- [ ] **Step 2: Run** `ISLA_CONFIG=/tmp/isla-files-test.json QT_QPA_PLATFORM=offscreen qs -p bar/files-interaction-regression.qml` — Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** — Expected: PASS.
- [ ] **Step 5: Manual (Wayland):** arrastrar un archivo a Firefox/kitty; anotar resultado real en `TASK_STATE.md` (probado / no verificado).
- [ ] **Step 6: Commit** (si lo pide).

### Task 8: Animaciones y rendimiento

**Files:**
- Create: `bar/components/files/NavTransition.qml`
- Modify: `FilesView.qml`, `FileGrid.qml`, `FileList.qml`, `PathBar.qml`, `QuickLook.qml`, `FilesWindow.qml`
- Read first: `bar/fluid/MOTION_LANGUAGE.md`, `.agents/skills/fluid-island-motion/SKILL.md`
- Test: `bar/files-motion-regression.qml`, `bar/tests/files-performance.py`

**Interfaces:**
- Consumes: `Motion.surfaceSpring`, `Motion.standard`, `Motion.fast`, `Motion.mult`.
- Produces (`NavTransition`): `property int direction` (+1 entrar, −1 subir), `function run(fromSnapshot)`: el contenido nuevo entra desplazado ≤24 px con fundido; interrumpible (una navegación nueva reorienta desde el estado actual, sin saltos). Resto: apertura de ventana con muelle de surface y rebase ≈3 %, resaltado de selección único que desliza, caja elástica, fundido de miniaturas, QuickLook crece desde `originRect` y vuelve, migas que se reacomodan.

- [ ] **Step 1: Write failing test:** con `reduceMotion` activo todas las transiciones duran ≤ `Motion.fast`; navegar dos veces seguidas no deja `opacity`/`x` intermedios (estado final exacto); ventana oculta → ningún `Animation.running`; 20 muestras de apertura monótonas sin salto > 1 px/frame en el resaltado.
- [ ] **Step 2: Run** `ISLA_CONFIG=/tmp/isla-files-test.json QT_QPA_PLATFORM=offscreen qs -p bar/files-motion-regression.qml` — Expected: FAIL.
- [ ] **Step 3: Implement** las animaciones sobre los componentes existentes; sin segundo fondo ni doble animación sobre un mismo valor.
- [ ] **Step 4: Run** el test — Expected: PASS.
- [ ] **Step 5: Perf:** `python bar/tests/files-performance.py` genera 20 000 archivos, abre, hace scroll y navega ×20 con `qmlprofiler` (patrón de `settings-navigation-performance.py`), guarda JSON en `/tmp`. Reportar apertura en frío/caliente, p95 de intervalo de fotogramas y RSS tras cerrar. **Los números se informan tal cual; no se afirma ≲150 ms ni 60 FPS sin ellos.** Si algún cuello de botella apunta a `FolderListModel`, parar y volver al usuario (decisión de modelo propio, ver Riesgos de la spec).
- [ ] **Step 6: QA visual en Wayland:** capturas de grid, lista, QuickLook, selección y diálogo de conflicto; verificar blur/transparencia con las reglas de Hyprland (añadir `windowrule` al `hypr/` del usuario sólo con su visto bueno).
- [ ] **Step 7: Commit** (si lo pide).

### Task 9: Cierre y documentación

**Files:**
- Modify: `PROJECT_MEMORY.md` (estado breve), `TASK_STATE.md` (decisiones, pruebas, límites), `bar/TESTING.md` (nuevos comandos), `docs/SHELL_ARCHITECTURE.md` (fila para `FilesHost`/`FileOps`)

- [ ] **Step 1:** Ejecutar todo: `python3 bar/tests/files-helper.py`, `python bar/tests/files-settings.py`, `python bar/tests/files-ipc.py`, las cinco regresiones QML `files-*`/`file-ops-*`, y `sh bar/tests/verify-config.sh` — Expected: todo PASS (si algo falla, se informa con la salida).
- [ ] **Step 2:** Revisión independiente (`isla-revisor`) sobre el diff: estado compartido, rendimiento, seguridad de rutas. Corregir hallazgos y repetir sólo lo afectado.
- [ ] **Step 3:** Registrar en `TASK_STATE.md` lo probado, lo no verificado (p. ej. DnD saliente, multimonitor) y lo bloqueado.
- [ ] **Step 4: Commit** (si lo pide).

---

## Self-review

- **Spec coverage:** ventana flotante (T6), listado nativo (T2), helper con operaciones/miniaturas/deshacer (T1, T3), selección y vistas (T4), ruta/lugares/unidades (T5), IPC y `.desktop` (T6), ajustes `files` (T2), DnD y QuickLook y búsqueda al teclear (T7), animaciones y rendimiento (T8), pruebas y documentación (T9). Fuera de v1 según spec: pestañas, MTP, propiedades, acceso desde la pill, DBus `FileManager1`.
- **Consistencia de tipos:** `PathUtil.toUrl/fromUrl/segments/nearestExisting`, `FilesModel.get/indexOfName/pathLost`, `FileOps.copy/move/trash/rename/mkdir/undo/cancel/thumb`, `SelectionModel.paths()` usados con los mismos nombres en T2–T8.
- **Riesgo explícito:** T6 Step 5 y T8 Step 6 cambian configuración del sistema/Hyprland sólo con permiso del usuario.
