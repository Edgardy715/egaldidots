# pets-vida: más vida en reposo para Mimo
Lee AGENTS.md, PROJECT_MEMORY.md y `.agents/skills/fluid-island-motion/SKILL.md`.
Recupera sólo lo pertinente con `python ~/.codex/token-economy/recall.py 'pets cerebro sueño salto mirada'`.
Lee docs/eshell-pets-redesign-2026-10-23/PHASE2.md (invariantes) y las secciones «fase 2» y
«correcciones de revisión fase 2» de TASK_STATE.md. Este encargo parte del árbol con dos entregas
recientes ya integradas (bug de la gota de media y fase 3 de paletas); respétalas.

## Objetivo
Que Mimo se sienta más vivo en reposo sin coste extra cuando está oculto o dormido y sin cambiar
el diseño aprobado (nicho, perchas, saltos, umbrales).

## Diseño decidido (Claude)
1. **Dormirse y despertar con transición.** Animaciones nuevas `doze` (3 fotogramas: cabeceo,
   ojos entrecerrados, cabeza baja; ~600/600/700 ms, sin bucle) antes de `sleep`, y `wake`
   (3–4 fotogramas: ojos que se abren, estiramiento con brote erguido, sacudida; ~120/260/220/180 ms)
   al despertar por clic, caricia, hover sobre su cuerpo, saludo o código (la música NO despierta a
   una mascota dormida; se conserva PetActor.qml:304). Reduced motion: sin transición
   (pose final directa), como hoy. El sueño sigue quieto (settle) y sin timers.
2. **Mirar al puntero en la barra.** Con Mimo en la percha `bar` despierto, cuando el puntero
   entra/se mueve sobre la pill en reposo, mira hacia el lado del puntero (`look_left`/`look_right`,
   `look_up` si está encima de él) y vuelve a la animación base 1.2 s después de salir. Usa los
   eventos de hover que ya existen (la pill ya calcula `lookX/lookY` para el compañero de ojos;
   reutiliza esa fuente desde la composición, no añadas MouseArea ni máscaras de input nuevas)
   y `PetLayer.lookAt()`. Limita a un cambio de pose cada 250 ms. Dormido: no despierta por hover
   lejano, sólo por hover sobre su cuerpo (como hoy).
3. **Caricia con respuesta.** Al completar una caricia (`strokes` → `happy`) aparece un corazón
   pixel art que sube 4–6 px y se desvanece en ~700 ms. Dibújalo dentro del lienzo 20×20 del
   paquete como fotogramas de una animación `love` (3–4 fotogramas) para no ampliar bounds,
   `reachRows`, el ancho del nicho ni la máscara. Si no cabe sin ampliar bounds, repórtalo.
4. **Variedad de reposo.** Animación `stretch` (4 fotogramas) que el cerebro elige con peso bajo
   en reposo largo (>90 s despierto sin interacción), y `idle` alterna una respiración ligeramente
   distinta cada pocos ciclos sin timers nuevos (dentro del mismo frameTimer).
5. **Saltos a escala grande.** El límite conocido «saltos planos a escala grande (7)»: la altura
   del arco del salto debe escalar con px (y con la distancia), con techo para no salirse de la
   pantalla/ventana del overlay. Mantén 380–520 ms y el retarget en el aire.

Arte: dibuja en `docs/eshell-pets-redesign-2026-10-23/design/src/anims.py` con el estilo y paleta
existentes (contorno oscuro de 1 px, sin antialias, silueta continua entre fotogramas consecutivos);
`build.py` regenera hojas/GIF/frames.json; actualiza `bar/pets/packs/mimo/pet.json` a mano desde
`frames.json` (incluye `events`: `doze`, `wake`, `pet`→`love`+`happy`) y reconstruye con
`bar/pets/tools/petpack.py build` (todas las variantes de paleta). Guarda GIFs de las animaciones
nuevas en docs/eshell-pets-redesign-2026-10-23/design/ para revisión visual de Claude.

## Archivos permitidos
bar/pets/PetActor.qml, bar/pets/PetLayer.qml, bar/pets/PetPerch.qml, bar/pets/packs/mimo/,
docs/eshell-pets-redesign-2026-10-23/design/, el punto de composición que conecte la mirada de la
pill a la capa (bar/components/PillHeaderView.qml, bar/components/IslandRestStatus.qml,
bar/Pill.qml o bar/windows/IslandOverlay.qml, el mínimo necesario), bar/pets-regression.qml,
bar/pets-overlay-regression.qml, bar/pets-qa.qml, bar/tests/pets.py, bar/tests/pets-performance.py.
No toques nada más ni reviertas cambios ajenos.

## Invariantes (de fase 1–2, no negociables)
Timers armados de forma imperativa (no `restart()` sobre bindings `running:`); umbrales 0.95 y
`petNicheAnimating` intactos; `settleTimer` y flag `closing`; sin máscaras de input nuevas;
coste cero oculta, dormida o desactivada; px nunca agranda percha, máscara ni input.

## Criterios de aceptación
1. `petpack.py validate` pasa sin avisos; bounds del paquete no crecen (o se informa el motivo).
2. Pruebas offscreen nuevas en pets-regression: doze precede a sleep; wake se reproduce y termina
   en la base; reduced motion salta ambas; hover sobre la pill en la barra produce look en el lado
   correcto y vuelve a base; hover lejano no despierta; caricia → love + happy; stretch sólo tras
   reposo largo; arco del salto crece con px y respeta el techo.
3. Mutación: revertir cada punto (1–5) hace fallar al menos una prueba.
4. Rendimiento con `bar/tests/pets-performance.py` contra `perf/phase2-fixes`: sleeping/hidden/
   disabled siguen ≤0.006 % CPU; idle no sube más de 0.03 puntos; guarda en `perf/vida/`.
5. Todas las pruebas de pets y de pill existentes siguen pasando.
6. Si puedes acceder a Wayland: capturas en DP-1 de doze→sleep, wake, mirada y corazón en
   docs/eshell-pets-redesign-2026-10-23/qa-vida/. Si no, márcalo no verificado.

## Validación
python bar/tests/pets.py; python bar/tests/pets-performance.py (según su ayuda);
python bar/pets/tools/petpack.py validate bar/pets/packs/mimo; node bar/tests/settings.cjs;
regresiones de pill (pill-interface, pill-composition, bar-layout-transition, layout-routing,
media-dock-surfaces) con los comandos de TESTING.md. Indica cada comando y resultado.

## Informe final (obligatorio, en este orden)
ESTADO: completo | parcial | bloqueado
ARCHIVOS: <lista>
CRITERIOS: <n> — probado/no verificado/bloqueado — <evidencia>
PRUEBAS: <comando → resultado>
DUDAS: <preguntas para Claude o "ninguna">
No hagas commit ni push. Subagentes sólo si ahorran: economy_worker o economy_researcher; nunca
economy_architect (Astra).
