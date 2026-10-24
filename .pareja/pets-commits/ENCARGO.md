# pets-commits: commits LOCALES de Eshell Pets (sin push)
Ahorra consumo: no ejecutes pruebas Wayland/qs/grim (ya pasan; tu sandbox no puede), no releas
PROJECT_MEMORY/TASK_STATE. Usa sólo git (status, diff --stat, add, commit, log).

## Reglas duras
- NO `git push`, NO cambiar de rama (main), NO amend/rebase/reset/stash/checkout de archivos.
- El árbol tiene ~180 cambios; la mayoría NO son de pets (otro trabajo local). No los incluyas.
  Añade por ruta explícita; nunca `git add -A` ni `git add .`.
- Archivos tracked compartidos (Pill.qml, PillSurface.qml, Config.qml, Settings.js, IslandOverlay.qml,
  EdotsWindow.qml, PillSurfaceHost.qml, FluidMediaCompanion.qml, MediaView.qml, MediaAmbient.qml,
  MediaSession.qml, MediaTimeline.qml, MediaTransportButton.qml, MediaSurface.qml, LockMedia.qml):
  mira `git diff <archivo>`. Si el diff mezcla pets con otro trabajo, usa `git add -p` y mete sólo
  los hunks de pets (petContext, petPresented, pets.*, PetPerch, pillLook, palette, mediaSurface perch,
  media-drop/gather). Si un hunk es ambiguo, déjalo fuera y anótalo en el informe.
- Mensajes en inglés, estilo del repo (`feat(pets): ...`, `fix(pets): ...`, `test(pets): ...`,
  `docs(pets): ...`). Termina cada mensaje con la línea:
  Co-Authored-By: Codex <noreply@openai.com>

## Commits sugeridos (en este orden; fusiona si un grupo queda vacío)
1. feat(pets): runtime — bar/pets/ (código, packs, tools), PetPreview.qml, pets-qa.qml, hunks de pets en
   Config/Settings/Pill/PillSurface/PillSurfaceHost/IslandOverlay/EdotsWindow, shader pet_palette (+ .qsb si existe y está trackeable).
2. fix(pets): media drop and perch — hunks de FluidMediaCompanion, FluidCompanion, MediaView (perch + timeline.visible),
   y los hunks de pets en el resto de Media*.
3. test(pets): regressions — bar/pets-*regression.qml, pets-performance.qml, bar/tests/pet*.{py,cjs}, pets-palette.py.
4. docs(pets): docs/ESHELL_PETS_PLAN.md, docs/eshell-pets-2026-10-22/, docs/eshell-pets-redesign-2026-10-23/
   (excluye frames crudos temporales muy pesados si los hay >5 MB; anótalos), .pareja/pets-*.
Los docs/ARCHIVE y wallpaper-media NO son de pets: fuera.
PROJECT_MEMORY.md / TASK_STATE.md: sólo si su diff es exclusivamente de pets; si no, fuera.

## Verificación antes de cerrar
`git status --short` debe seguir mostrando el resto del trabajo ajeno intacto; `git log --oneline -6`;
`git show --stat HEAD~N` por commit para confirmar que no entró nada ajeno.

## Informe (≤120 palabras)
Commits (hash + asunto), archivos/hunks dejados fuera por ambigüedad, confirmación de que no hubo push.
