# pets-edots: fase 3 de Eshell Pets (personalización en Edots)
Lee AGENTS.md y PROJECT_MEMORY.md. Recupera sólo lo pertinente con
`python ~/.codex/token-economy/recall.py 'pets edots paleta vista previa'`.
Lee docs/eshell-pets-redesign-2026-10-23/PROPOSAL.md (secciones d «Formato de paquete» y
«Personalización») y docs/SHELL_ARCHITECTURE.md (Settings/Config/Flags).

En paralelo otro trabajo de Codex corrige un bug en IslandRestStatus/Pill/PetLayer/PetPerch/
PetActor y en bar/tests/pets.py y las regresiones pets-*.qml existentes: **no toques esos archivos.**

## Objetivo
La página «Eshell Pets» de Edots gana (a) una vista previa en vivo de la mascota y (b) variantes
de paleta seleccionables. Accesorios quedan fuera de esta ronda.

## Decisiones ya tomadas (no las cambies)
1. Campo nuevo `pets.palette` en bar/Singletons/Settings.js: control `choice`, default `"marea"`,
   opciones `marea`, `coral`, `lavanda`, `arena` (+ `matugen` sólo si se cumple el punto 4).
   Etiquetas en español. Una clave desconocida vuelve al default; claves heredadas se conservan.
2. Variantes como datos del paquete: `pet.json` gana `paletteVariants: { coral: {<char>: "#rrggbb"}, … }`
   que sólo sobrescribe colores por carácter de paleta (los roles siguen siendo los de `palette`).
   El contorno `o` y los ojos se mantienen oscuros; brote, mejillas y chispa pueden variar.
   Intención: coral = cuerpo coral cálido y hoja oliva; lavanda = cuerpo lila suave y hoja menta;
   arena = cuerpo arena/beige y hoja verde salvia. Mismo contraste que Marea sobre vidrio claro y
   oscuro (el validador de petpack.py ya avisa de poco contraste: ninguna variante puede avisar).
3. `bar/pets/tools/petpack.py build` genera un atlas por variante (`atlas.png` = marea,
   `atlas-<variante>.png`), con el mismo hash de `pet.json`; `validate` valida las variantes.
   `PetPack.atlas` elige el archivo según `Config.pets.palette`, con caída a `atlas.png` si falta.
   Cambiar de paleta no recarga `atlas.json` ni reinicia la mascota.
4. Matugen: sólo si puedes hacerlo con un `ShaderEffect` de mapeo de paleta usando la misma
   cadena de shaders compilados que ya usa el proyecto (mira bar/fluid/FluidNeck.qml y cómo se
   compilan sus .qsb). Si no hay cadena utilizable sin dependencias nuevas, NO lo añadas y
   repórtalo como bloqueado con el motivo.
5. Vista previa: componente nuevo `bar/settings/PetPreview.qml`, colocado en la página Eshell Pets
   de EdotsWindow.qml igual que IslandStudio en otras páginas (cabecera de la página, ~160–200 px de
   alto, respetando `richComposition`). Usa `PetSprite` con el atlas de la paleta del **borrador**
   (valores no guardados, como hace IslandStudio con el resto de ajustes) y la escala del borrador.
   Recorre idle → walk → dance → sleep en bucle con el nombre de la mascota debajo; clic = `happy`.
   No instancia PetActor ni PetLayer ni toca la mascota real. Timer sólo corriendo con la página
   visible; reduced motion = pose fija idle. Fondo: una franja de vidrio con la línea de apoyo,
   coherente con el estilo Edots existente.

## Archivos permitidos
bar/Singletons/Settings.js, bar/pets/PetPack.qml, bar/pets/PetSprite.qml (sólo si hace falta),
bar/pets/tools/petpack.py, bar/pets/packs/mimo/ (pet.json y artefactos construidos),
bar/settings/EdotsWindow.qml, bar/settings/PetPreview.qml (nuevo), un shader nuevo si se cumple el
punto 4, bar/tests/settings.cjs, bar/tests/settings-integration.py, bar/tests/pets-palette.py (nuevo)
y un fixture nuevo `bar/pets-preview-regression.qml` si lo necesitas.
No toques nada más ni reviertas cambios ajenos (el árbol tiene mucho trabajo sin commitear).

## Criterios de aceptación
1. `pets.palette` validado, persistido con Config.update/save y probado con ISLA_CONFIG temporal;
   valor inválido → `marea`.
2. `petpack.py validate` y `build` pasan para mimo con las 3 variantes, sin avisos de contraste;
   atlas reproducibles (dos builds seguidos producen los mismos bytes).
3. Cambiar la paleta con la mascota visible cambia el atlas sin recargar el paquete ni reiniciar la
   animación en curso (prueba en fixture offscreen).
4. La vista previa usa el borrador (cambiar paleta/escala sin guardar la actualiza), no corre timers
   con la página oculta y respeta reduced motion (prueba).
5. Coste cero con pets desactivado: sin atlas extra cargados.
6. Si puedes acceder a Wayland: captura de Edots en la página Eshell Pets con cada paleta en
   docs/eshell-pets-redesign-2026-10-23/qa-phase3/. Si no, márcalo no verificado.

## Validación
node bar/tests/settings.cjs; python bar/tests/settings-integration.py; python bar/tests/pets-palette.py;
python bar/pets/tools/petpack.py validate bar/pets/packs/mimo; y la regresión de controles de ajustes
(settings-controls-regression.qml) con el comando que use TESTING.md. Indica cada comando y resultado.

## Informe final (obligatorio, en este orden)
ESTADO: completo | parcial | bloqueado
ARCHIVOS: <lista>
CRITERIOS: <n> — probado/no verificado/bloqueado — <evidencia>
PRUEBAS: <comando → resultado>
DUDAS: <preguntas para Claude o "ninguna">
No hagas commit ni push. Subagentes sólo si ahorran: economy_worker o economy_researcher; nunca
economy_architect (Astra).
