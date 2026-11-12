# Prompt: Isla excelente — QA integral, pulido visual y movimiento fotograma a fotograma

Destino: Claude Code (Opus) abierto en `/home/zdito/.config/quickshell`, permisos amplios.
Copia todo lo que hay debajo de la línea en una conversación nueva. Antes de pegar:
`pacman -Q wf-recorder || sudo pacman -S wf-recorder` (grabación con tiempos reales por frame).

---

# Misión

Eres el responsable de calidad, diseño y movimiento de **Isla** (edotsShell / Fluid Island), una shell
Quickshell/QML sobre Hyprland. Tu trabajo tiene tres partes, en este orden:

1. **Probar** la shell en todos los aspectos posibles: funcionamiento, interacción, estados límite,
   rendimiento, accesibilidad y, sobre todo, cada animación fotograma a fotograma.
2. **Corregir** todo bug encontrado, sin pedir permiso al usuario. Cada corrección queda demostrada con la
   misma prueba que lo detectó.
3. **Elevar** el acabado visual y de movimiento hasta que Isla se sienta claramente superior a las demás
   shells de Linux: limpia y minimalista, pero con la magia y los detalles que la hacen única.

El resultado final que el usuario debe sentir: «tengo una shell distinta a todas». Cada pantalla parece
diseñada por el mismo equipo, el color se usa con intención, los layouts respiran, y nada salta,
parpadea, se corta ni llega tarde.

# Reglas que no se negocian

- El código actual es la fuente de verdad. Hay trabajo local sin commit y cambios ajenos: consérvalos.
  Nunca `git checkout`/`reset`/`stash` sobre archivos que no hayas tocado tú en esta sesión.
- Sin push. Sin commits salvo que el usuario los pida.
- Las decisiones aprobadas siguen vigentes (Cuerpo/vidrio líquido SDF, Tidemark, gotas con motor único
  FluidCompanion, sin bucles idle, `reduceMotion`, separación pet/surfaces). Puedes pulirlas a fondo; no
  cambies su dirección. Si una mejora exige romper una decisión aprobada, constrúyela como prototipo o vista
  previa en `docs/previews/`, documenta el porqué y sigue con lo demás: no bloquees la sesión esperando.
- Bugs: corrígelos sin preguntar. Cambios visuales: aplícalos si cumplen los contratos de
  `bar/fluid/MOTION_LANGUAGE.md` y este prompt; los gustos dudosos van a vista previa.
- Prueba antes de afirmar. Distingue siempre **probado**, **no verificado** y **bloqueado**.
  Offscreen no es QA visual. Un test en verde no prueba que algo se vea bien.
- Antes de editar QML, lee sólo el fragmento que vas a tocar y su dueño real (quién anima cada propiedad).
  Nunca añadas un segundo motor de animación, un fade que esconda una costura ni un bucle decorativo.

# Fase 0 · Contexto, skills y herramientas (antes de tocar código)

## 0.1 Contexto mínimo

1. Lee `PROJECT_MEMORY.md` completo (es corto) y `docs/SHELL_ARCHITECTURE.md` por encima.
2. Lee `bar/fluid/MOTION_LANGUAGE.md` y `bar/TESTING.md`.
3. Recupera sólo lo pertinente del historial con
   `python ~/.codex/token-economy/recall.py 'tema' --root /home/zdito/.config/quickshell`
   (temas útiles: `qa visual`, `cuerpo fase5`, `pulido barra`, `tidemark`, `regresiones preexistentes`).
   No cargues TASK_STATE.md entero ni la bóveda entera.
4. Lee los informes previos como punto de partida, no los repitas:
   `docs/shell-visual-qa-2026-10-30/REPORT.md` (P0/P1 pendientes) y
   `docs/plan-pulido-barra-2026-10-31.md` (fases 1–5 de la barra: nitidez de píxel, un material,
   un acento, reposo quieto, laterales con resorte).

## 0.2 Skills: reconocer, buscar e instalar

Primero carga las skills locales que ya cubren el trabajo (lee su SKILL.md, no las parafrasees de memoria):

| Necesidad | Skill |
|---|---|
| Movimiento, pill, gotas, surfaces | `.agents/skills/fluid-island-motion` |
| Transiciones frame a frame | `.agents/skills/pill-frame-inspection` |
| Auditoría integral de la pill | `.agents/skills/pill-detail-audit` |
| Jerarquía, material, tipografía Apple-like | `.agents/skills/apple-inspired-ui` |
| Diseño, color, layout, crítica, pulido | `impeccable`, `~/.codex/skills/ui-ux-pro-max`, `ui-design` |
| Muelles, curvas, gestos | `ui-animation` |
| QML y Quickshell | `qt-qml`, `quickshell`, `qt-qml-review`, `qt-qml-profiler` |
| Hyprland (reglas, animaciones, capas) | `hyprland` |
| Bugs difíciles | `diagnosing-bugs` o `superpowers:systematic-debugging` |
| Coordinación y revisión | `agency-agents`, `orquestacion-pareja` |
| Logs grandes | `headroom` |

Después usa la skill **find-skills de Vercel** para cubrir los huecos:

1. Comprueba que existe: `ls ~/.agents/skills/find-skills/SKILL.md`.
   Si no existe: `npx skills add vercel-labs/skills@find-skills -g -y` y léela.
2. Consulta primero el ranking de https://skills.sh/ y luego busca con `npx skills find <consulta>`.
   Consultas mínimas: `motion design`, `animation review`, `video frame analysis`, `color palette oklch`,
   `design system tokens`, `accessibility contrast`, `visual regression`, `qml`, `wayland`.
3. Instala sólo lo que aporte algo que las skills locales no cubren. Antes de instalar cualquier skill o
   herramienta de GitHub: lee su SKILL.md/README completo, revisa qué scripts ejecuta, prefiere autores con
   muchas instalaciones o mantenimiento activo y descarta lo que pida credenciales o red sin motivo.
   Instala en global (`-g`) y anota en el informe qué instalaste, de dónde y qué mejoró.
4. Aplica la misma lógica a herramientas: si una herramienta de GitHub o del repositorio oficial mejora el
   resultado de forma medible (p. ej. comparación perceptual de imágenes, detección de frames duplicados,
   medición de contraste), úsala. Si no mejora nada medible, no la añadas.

## 0.3 Herramientas de captura

Verifica: `command -v grim wf-recorder ffmpeg ffprobe magick qmllint qmlprofiler hyprctl`.
- Grabación con tiempos reales: `wf-recorder -o <monitor> -g "<x>,<y> <w>x<h>" -r <refresco> -f clip.mkv`.
  Recorta siempre a la región de interés (franja superior 0–60 px, la pill, el surface): menos píxeles,
  menos tokens.
- Si falta `wf-recorder` y no se puede instalar, ráfaga de `grim` con marca de tiempo y dilo en el informe
  como muestreo, no como grabación completa.
- Lectura de frames: `ffprobe -show_frames` para PTS/duración; extrae con `-fps_mode passthrough` (nunca
  interpoles). Detecta frames perdidos por huecos en PTS y frames iguales con `mpdecimate` o `magick compare`.
- Para ahorrar tokens, no mires frames sueltos: arma hojas de contacto (`magick montage`, 12–16 frames por
  imagen, con el número de frame y el PTS impresos) y amplía sólo los frames sospechosos.
- La shell real es `qs -d` (`pgrep -ax qs`). Las regresiones van con `ISLA_CONFIG` temporal
  (`{}` o copia), nunca con la configuración del usuario.

## 0.4 Plan escrito

Crea `docs/shell-excelencia-2026-11-05/PLAN.md` con:
- Inventario de superficies (ver Fase 1) y, por cada una, sus transiciones y estados.
- Criterios de aceptación medibles por requisito (ver «Estándar de calidad»).
- Qué skills/herramientas usarás en cada fase y qué delegas.
- Riesgos conocidos y fallos preexistentes que no debes confundir con regresiones nuevas
  (`top-workspace-motion-regression`: «retarget must settle at workspace 2»; `surface-materialize`
  con la config del usuario por tiempos).
Muestra al usuario un resumen de 5–8 líneas del plan y empieza sin esperar respuesta.

# Fase 1 · Inventario y línea base

Lista cada superficie con su archivo dueño (delega el barrido a `isla-explorador`):
barra superior (rail de workspaces, módulos, estado, avatar, chip), pill/isla y Cuerpo (shader
`bar/body/shaders/body.frag`, bulto, cuello, gotas izquierda/derecha), media (carátula, visualizador Cava,
companion, letras), launcher, selector de wallpaper, overview, portapapeles, calendario, conectividad,
ajustes rápidos/utils, OSD de volumen/brillo, notificaciones y toasts, temporizador de enfoque, grabación
y capturas (Satty), actualizaciones, prompt de autenticación, pantalla de bloqueo, Edots/ajustes.

Línea base antes de cambiar nada:
1. Suite estática: `qmllint` sobre lo tocado más tarde, `qt-qml-review` sobre los componentes centrales.
2. Regresiones: todas las `bar/*-regression.qml` con `QT_QPA_PLATFORM=offscreen` e `ISLA_CONFIG` temporal,
   y los tests de `bar/TESTING.md`. Guarda el resultado (PASS/FAIL por archivo) en
   `docs/shell-excelencia-2026-11-05/baseline.txt`. Lanza las largas en segundo plano.
3. Capturas en vivo de cada superficie en reposo, tema oscuro y claro, con `grim -o <monitor>`.
4. Rendimiento en reposo y en uso: GPU/CPU en reposo (objetivo ≈0 con la shell quieta), `qmlprofiler`
   sobre una transición pesada (launcher, overview), `bar/tests/qml-performance.py` y
   `bar/tests/session-soak.py`.

# Fase 2 · Recorridos de uso real, fotograma a fotograma

Graba y analiza cada recorrido completo, no transiciones aisladas. Cada uno con duración, monitor y región:

1. **Arranque**: inicio de la shell, primer pintado de barra y pill, sin parpadeo ni salto de layout.
2. **Trabajo normal**: cambiar de workspace despacio y muy rápido (5 cambios en 1 s), abrir y cerrar
   ventanas, pantalla completa y volver.
3. **Música**: empezar a reproducir, cambiar de pista, pausar, cambiar de reproductor, letras, carátula
   nueva con paleta distinta.
4. **Surfaces**: abrir/cerrar launcher, wallpaper, overview, portapapeles, calendario, conectividad y
   ajustes rápidos; cambiar de uno a otro sin cerrar; cerrar con Escape, con clic fuera y por IPC.
5. **Interrupciones**: invertir cada transición en su punto de mayor velocidad (abrir y cerrar a los
   80–150 ms), doble clic, teclado durante la animación, hover que entra y sale en la mitad.
6. **Avisos**: ráfaga de 5 notificaciones, OSD de volumen repetido, toast sobre surface abierto,
   No molestar.
7. **Sistema**: bloqueo y desbloqueo, cambio de wallpaper (matugen recolorea todo), tema claro/oscuro,
   `reduceMotion`, Reducir transparencia, hotplug o segundo monitor si existe.
8. **Captura y grabación**: captura con Satty, gota del archivo guardado, grabación de pantalla activa.
9. **Sesión larga**: 20 min de uso mixto; busca fugas, temporizadores que siguen corriendo ocultos y
   deriva de estado.

Para cada transición sigue `pill-frame-inspection`: anota origen, destino, disparador y quién anima cada
propiedad; recorre los frames revisando en orden contorno, borde, brillo, texto, carátula, clipping y
relación entre cuerpos. Marca el último frame correcto y el primero defectuoso, con PTS y coordenadas.

Defectos que buscas activamente:
- Saltos de posición o tamaño de 1 frame, retarget que pierde velocidad, rebote no pedido.
- Costuras entre pill, cuello y gotas; banda negra o destello en el relevo body↔material.
- Contenido que llega antes o después que su forma; texto que se mueve dentro de un contenedor que crece;
  recorte que corta glifos o carátulas.
- Parpadeo de opacidad, doble fade, frames en blanco, iconos que aparecen sin transición.
- Bordes de 1 px en medio píxel (borrosos), centros ópticos desalineados entre módulos.
- Frames perdidos (huecos de PTS) y picos de frame time durante la transición.
- Animación que corre oculta o sigue con `reduceMotion` activo.

# Fase 3 · Corrección

Por cada defecto: causa raíz en el dueño real, cambio mínimo, misma grabación otra vez, comparación de
hojas de contacto antes/después. Si el defecto es lógico, añade o amplía una regresión
`bar/*-regression.qml` que falle sin el arreglo. Si el mismo arreglo falla tres veces, para, nombra la
suposición que puede ser falsa y diagnostica con `diagnosing-bugs` en lugar de seguir probando valores.

Ordena por impacto: P0 (roto o visiblemente feo en uso diario) → P1 (se nota al fijarse) → P2 (detalle).
Termina todos los P0 y P1 antes de empezar la Fase 4.

# Fase 4 · Elevación visual y de movimiento

Antes de diseñar, estudia en 15–20 min (web, capturas, repos) qué hacen bien las shells de referencia
(Caelestia, end-4/illogical-impulse, Noctalia, DankMaterialShell, HyprPanel, AGS/Astal) y macOS/iOS
(Dynamic Island, Control Center). No copies: escribe en el PLAN.md tres diferenciadores concretos de Isla
y qué los hace imposibles de confundir con otra shell. Isla ya tiene identidad (vidrio líquido, gotas,
Tidemark): el objetivo es que esa identidad se ejecute mejor que nadie, no añadir una nueva.

Aplica en este orden, midiendo cada paso:

1. **Nitidez de píxel**: posiciones, tamaños y bordes a píxel entero según la escala del monitor;
   un único centro vertical para todos los módulos de la barra.
2. **Un material**: un solo vidrio con la misma receta de borde, brillo y sombra en barra, pill, gotas y
   surfaces. Elevación por tono y sombra, no por bordes extra.
3. **Color**: paleta derivada del wallpaper (matugen) organizada en roles (fondo, superficie, superficie
   elevada, texto primario/secundario/terciario, acento, estado). Un solo acento, usado con escasez para
   lo activo o lo que pide atención. Calcula los tonos en OKLCH para que la luminosidad sea uniforme entre
   wallpapers. Contraste mínimo: 4.5:1 texto normal, 3:1 iconos y bordes funcionales, en ambos temas y con
   al menos 5 wallpapers distintos (claro, oscuro, saturado, gris, con mucho ruido).
4. **Layout y tipografía**: rejilla de 4 px, márgenes y radios concéntricos (radio interior = exterior −
   margen), escala tipográfica corta (3–4 tamaños), cifras tabulares en reloj, porcentajes y tiempos,
   alineación óptica de iconos. Quita todo elemento que no aporte información o acción.
5. **Reposo quieto**: con la shell quieta no se mueve nada salvo lo que comunica algo; GPU ≈0.
6. **Movimiento**: muelles con retarget que conserva velocidad para toda geometría; el contenido llega
   con su forma (sin fase de cristal vacío); entradas y salidas simétricas en carácter, salidas más cortas;
   crossfade de contenido al cambiar de surface sin cerrar; escalonado leve (20–40 ms) en listas.
7. **Detalles que dan magia**: microinteracciones de hover/press en todo control (MaterialIcon/MotionButton),
   respuesta inmediata (<100 ms) a cada entrada, momentos finitos ligados a eventos reales (pista nueva,
   archivo guardado, tarea terminada) que terminan quietos.

Para cambios visuales grandes, prepara antes una vista previa HTML o QML (`docs/previews/`) con el estado
actual y el propuesto lado a lado; aplica si mejora y cumple las reglas; si no está claro, déjala como
propuesta en el informe.

# Estándar de calidad (criterios de aceptación)

- 0 saltos de 1 frame, costuras, parpadeos o frames en blanco en los recorridos de la Fase 2.
- Frame time estable durante transiciones al refresco del monitor; ningún hueco de PTS atribuible a Isla.
- Toda transición se puede interrumpir e invertir sin salto.
- Contraste según la Fase 4 en ambos temas y con los 5 wallpapers de prueba.
- GPU/CPU en reposo ≈0; sin temporizadores ni animaciones ocultas; sin fugas en la sesión larga.
- Regresiones: ninguna que pasaba en la línea base falla al terminar; los arreglos lógicos tienen test.
- `reduceMotion` y Reducir transparencia funcionan en todas las superficies.
- Revisión independiente final sin hallazgos P0/P1 abiertos.

# Economía de tokens (mismo resultado, menos coste)

- Delega: barridos y búsquedas → `isla-explorador`; ediciones ya decididas, tests y docs →
  `isla-implementador`; revisión del diff de riesgo al cerrar cada fase → `isla-revisor`.
  El diseño de movimiento, el color y el juicio visual se quedan en el hilo principal.
- Encargos a subagentes con contexto nuevo, archivos concretos y criterio de terminado. No repitas una
  investigación ya entregada.
- Lee fragmentos, no archivos enteros. Agrupa comandos relacionados en una sola llamada.
- Imágenes: recorta a la región, reduce escala para la vista general, hojas de contacto en vez de frames
  sueltos, amplía sólo lo sospechoso.
- Logs y salidas grandes: guárdalas en archivo y lee sólo errores (`headroom`).
- Como máximo dos rondas de revisión por cambio. No repitas un ciclo sin cambios o sin una duda concreta.

# Entregables

1. `docs/shell-excelencia-2026-11-05/REPORT.md`: por requisito, estado (probado / no verificado /
   bloqueado) con evidencia (ruta de captura, PTS, comando y salida); bugs encontrados con causa, archivo
   y arreglo; mejoras visuales con antes/después; skills y herramientas instaladas y qué aportaron;
   pendientes ordenados por impacto.
2. `evidence/` con hojas de contacto y capturas antes/después (recortadas, sin datos personales:
   oculta notificaciones, títulos de ventanas y portapapeles reales).
3. `PROJECT_MEMORY.md` actualizado con el estado breve; decisiones, pruebas y límites en `TASK_STATE.md`.
4. Mensaje final al usuario: qué cambió que se note a simple vista, cómo verlo (recorrido de 2 min),
   y qué queda sin verificar.

# Cuándo parar

Termina cuando se cumplan los criterios de aceptación y la revisión independiente final esté limpia, o
cuando lo que quede sea gusto sin defecto medible (déjalo como propuesta en el informe). Si una parte
queda bloqueada (falta hardware, permisos, segundo monitor), documéntala y sigue con lo demás.
