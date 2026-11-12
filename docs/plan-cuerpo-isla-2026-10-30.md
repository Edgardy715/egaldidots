# Plan: «Cuerpo» (isla sin cara) · 2026-10-30

Sustituye a Iris (ojos) como idea de personalidad. Referencia visual aprobada por
el usuario: `docs/previews/isla-cuerpo.html` (artifact «Isla sin cara»). Lo que se
ve ahí es el objetivo; este plan dice cómo llevarlo a Quickshell/Qt.

## 1. Idea en una frase

La isla no tiene cara, tiene cuerpo: un único shader SDF dibuja pill + bulto +
gotas como una sola materia líquida de vidrio, y un cerebro de muelles le da
intención (respira, nota el cursor, se encoge, duerme, se alegra). Tres capas, en
este orden: **Cuerpo → Luz → Gota**.

## 2. Qué se traslada tal cual y qué cambia

| Página (WebGL1) | Quickshell/Qt 6 |
|---|---|
| Fragment shader GLSL ES 1.0 en un `<canvas>` | `ShaderEffect` + `body.frag` GLSL 440 compilado a `.qsb` (como `bar/fluid/shaders/fluid_neck.frag`) |
| `class Spring` + `stepAll` (subpasos 1/240 s) | `bar/body/BodySprings.js` (`.pragma library`), mismo cálculo; mismo patrón que `SpringValue.qml` |
| `requestAnimationFrame` | `FrameAnimation` sólo mientras algo se mueve; `Timer` a 33 ms para la respiración en reposo |
| `pointermove` en el canvas | `HoverHandler` / `TapHandler` / `DragHandler` + `Region` de máscara de entrada |
| Paleta `PAL` fija | `Theme.accent / accentAlt / accentSoft / background` (matugen) |
| `wall()` procedural que se refracta | Textura del fondo real (awww) con fallback procedural desde Theme |
| Hora del día del slider | `new Date()` + `Timer` de 60 s |

## 3. Límites reales (no negociables, decidir con ellos)

1. **Refracción**: una ventana layer-shell no ve otras ventanas. Sólo se puede
   refractar la imagen del fondo (textura) o el degradado de Theme. Sobre ventanas
   abiertas no habrá refracción real. Aceptado.
2. **Cursor fuera de la pill**: en Wayland la ventana sólo recibe hover donde su
   máscara de entrada lo permite. Atención al cursor = sólo cuando está sobre la
   pill o su zona ampliada visible. El «se inclina antes de que llegue» de la página
   en el escritorio real queda limitado a esa zona (ver §7, decisión D1).
3. **Aura y sombra fuera del cuerpo** exigen que el `ShaderEffect` sea mayor que la
   pill (margen ≥ 80·S px) con la máscara de entrada limitada al cuerpo.
4. **Gota que viaja por la pantalla** (Fase 3) necesita una capa a pantalla completa
   con `Region` sólo sobre la gota; se crea al salir y se destruye al volver.
5. **Regla vigente «sin bucles idle infinitos»** (`docs/PROMPT-companion-polish.md`,
   `MOTION_LANGUAGE.md`): la respiración continua la contradice. Se resuelve como
   **excepción documentada y apagable**: amplitud ≤ 1,1 px, 30 fps, sólo con la isla
   visible, apagada con `reduceMotion`, fullscreen, pantalla bloqueada y con el
   ajuste `appearance.bodyBreath=false`. Decisión D2 del usuario; hasta que la
   confirme, el ajuste nace en `false` en la integración.
6. `.qsb` cacheado: un reload no lo recarga; hay que reiniciar quickshell tras
   recompilar.

## 4. Arquitectura de archivos (todo nuevo, nada existente se rompe)

```
bar/body/
  BodySprings.js      Spring puro: create(x,w,z), step(s,dt), stepAll(list,dt), settled(list)
  BodyBrain.js        .pragma library. Estado de ánimo y salidas por frame (sin QML)
  BodyLight.js        .pragma library. light(hour) → {L:[x,y], warm, night, spec, day}
  BodyEngine.qml      Item no visual: integra Brain, entrega uniforms, gestiona FrameAnimation/Timer
  BodyShader.qml      ShaderEffect envoltorio de shaders/body.frag.qsb
  shaders/body.frag   GLSL 440
  shaders/body.frag.qsb
  README.md           contrato corto
bar/body-demo.qml          ShellRoot standalone (como fluid-demo.qml), nunca importado por shell.qml
bar/body-regression.qml    QtTest offscreen
bar/tests/body-brain.cjs   node: muelles, ánimos, luz (como calculator.cjs)
```

Reglas de la casa: los componentes hoja reciben datos por **propiedades**; la
composición conecta Players/Cava/hora. Defaults y validación nuevos viven en
`bar/Singletons/Settings.js` (Flags sólo lectura; Config.update/discard/save).

## 5. Fases

| Fase | Contenido | Dónde | Estado |
|---|---|---|---|
| 1 | Cuerpo + Luz en demo aislada (shader, muelles, ánimos, hora, música simulada) | `bar/body/`, `bar/body-demo.qml` | **ENCARGO listo**: `.pareja/cuerpo-fase1/ENCARGO.md` |
| 2 | Gota mensajera en la demo (satélite, lágrima, vagar, archivo falso, residuo) | mismos archivos + `BodyDrop*` | ENCARGO listo: `.pareja/cuerpo-fase2/ENCARGO.md` |
| 3 | Integración en la pill real: decidir con el usuario cómo (ver §6) | `PillSurface`, `IslandOverlay`, Settings | Lo decide Claude tras revisar 1–2 |
| 4 | Conexión a eventos reales (Cava→música, hora, foco, notificaciones, descargas) y ajustes en Edots | composición | pendiente |
| 5 | QA visual en vivo, vídeo de 20 s, cierre en TASK_STATE.md | — | Claude |

Fases 1 y 2 son independientes del pill real: la demo corre con
`quickshell -p bar/body-demo.qml`. Así se prueba la sensación antes de tocar nada
de producción.

## 6. Integración (Fase 3, opciones)

- **A. Sustituir el fondo de la pill** por `BodyShader` (el cuerpo dibuja el vidrio).
  Máximo parecido a la página; riesgo alto: toca `PillSurface`, contenido y máscara.
- **B. Capa propia detrás** de la pill actual (underlay) y la pill actual se vuelve
  transparente en reposo. Menos riesgo, posible doble borde.
- **C. Sólo bulto y gotas** como `FluidNeck` actual y el vidrio se queda. Menos
  impacto visual.
Recomendación: probar A en reposo (cuando la pill es la cápsula base) y ceder a la
pill actual en cuanto se expande un surface (launcher, media…). Se decide con las
capturas de la Fase 1.

## 7. Decisiones abiertas del usuario

- D1: ¿zona de atención al cursor = sólo la pill, o una zona ampliada (p. ej. 520×200)
  que captura clics? Por defecto: sólo la pill + 24 px de margen.
- D2: ¿aceptas la respiración como excepción apagable a «sin loops idle»? Defecto: sí, apagable.
- D3: ¿Qué hace de archivo la gota en producto (capturas, descargas, portapapeles)? Fase 4.

## 8. Rendimiento (presupuesto)

- Reposo con respiración: 30 fps, shader a la mitad de resolución del área si hace
  falta (`layer.smooth`/escala 0,5 con el aura), < 2 % GPU en la GPU del usuario. Medir con
  `bar/tests/gpu-recording.py` / `qml-performance.py` (TESTING.md).
- Nada corre con `visible=false`, fullscreen, lock ni `reduceMotion`.
- Textura de fondo ≤ 960×540 para refracción (el efecto es borroso por naturaleza).

## 9. Criterios globales de «terminado»

1. Parecido con la página en las 5 escenas (reposo, curiosa, tímida, dormida,
   contenta; luz a 06 h, 12 h, 18 h, 02 h; música).
2. Todo interrumpible conservando velocidad (regla 8 de MOTION_LANGUAGE).
3. `reduceMotion` resuelve a destino sin animar.
4. Tests node y QML offscreen pasan; QA visual Wayland con capturas (offscreen ≠ QA).
5. Sin cambios en archivos existentes salvo los listados en cada ENCARGO.
