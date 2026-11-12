# Prompt · Lenguaje de trazo vivo para toda la pill

> Pégalo como primer mensaje de un chat nuevo con Opus 5.5, abierto en
> `/home/zdito/.config/quickshell`. Escrito el 2026-10-30.

---

Quiero que planifiquemos juntos cómo llevar a **toda la pill de Isla** el estilo de
animación y diseño que nació con `bar/components/ConfirmationIndicator.qml`. No hablo
sólo de estados de carga: quiero el **lenguaje** de ese indicador aplicado a
microinteracciones, iconos, transiciones de contenido y feedback en cada surface de la
pill (reposo, media, notificaciones, launcher, ajustes rápidos, calendario,
conectividad, mezclador, portapapeles, OSD, temporizador, wallpapers, etc.).

**El objetivo es que Isla tenga un estilo de diseño y animación propio.** No
queremos parecernos a Apple, a Pixel/Material ni a ninguna otra interfaz. La
investigación sobre otros sistemas sirve sólo para entender *por qué* ciertas
decisiones funcionan; el resultado tiene que ser reconocible como Isla y como nada
más. Si una idea se puede confundir con la de otro sistema, descártala o
transfórmala hasta que sea nuestra.

**Esta sesión es de plan e ideas, no de implementación.** Entrega el plan y espera mi
aprobación antes de tocar código. Responde en español, en formato TDAH: acción primero,
pasos numerados, sin preámbulo.

## 1. Contexto obligatorio (léelo antes de proponer nada)

1. `PROJECT_MEMORY.md`; de `TASK_STATE.md` sólo lo pertinente con
   `python ~/.codex/token-economy/recall.py 'ConfirmationIndicator trazo AnimatedSymbol' --root .`
2. Skills del proyecto: `.agents/skills/fluid-island-motion/SKILL.md` (y sus
   `references/`). `.agents/skills/apple-inspired-ui/SKILL.md` sólo como criterio
   de calidad (jerarquía, legibilidad, controles), nunca como estética. Si llegas a
   inspeccionar transiciones, `.agents/skills/pill-frame-inspection/SKILL.md`.
3. `bar/fluid/MOTION_LANGUAGE.md`, sobre todo "Principio rector", "Reglas de
   coreografía", "Controles y microinteracciones" e "Iconos por trazos".
4. `docs/INTERACTION_SYSTEM.md` y `docs/SHELL_ARCHITECTURE.md`.
5. Código base del lenguaje:
   - `bar/components/ConfirmationIndicator.qml`: arco que respira (fase senoidal
     1100 ms), anillo determinado, cierre del anillo desde donde estaba el arco y
     símbolo dibujado con `ShapePath.trim.end` (check, cruz, barra de cancelado), color
     de señal y brillo `MultiEffect` sólo mientras es visible.
   - `bar/components/AnimatedSymbol.qml` y `MaterialIcon.qml`: iconos Lucide por
     trazos, ya animables pieza a pieza.
   - `bar/Singletons/Motion.qml`: tokens (`fast`, `standard`, `emphasized`, `heat`,
     `hover`, `press`, `iconGesture`, `iconSwap`, `easeStandard`, `easeBreathe`,
     `surfaceSpring`, curvas M3…). Todo se multiplica por `mult` (reduceMotion).

Usa el código como fuente de verdad: si algo de este prompt no coincide, gana el código
y me lo dices.

## 2. Qué es este estilo (resultado de la investigación previa)

Nombre de trabajo: **lenguaje de trazo vivo** (provisional; propón el nombre propio
de Isla). Cinco principios, extraídos de lo que ya hace nuestro indicador:

1. **Se dibuja, no se intercambia.** Lo que aparece se traza a lo largo de su camino;
   lo que se va se des-traza. Cada trazo tiene una dirección con significado (una
   flecha viaja con su punta).
2. **Un objeto, muchos estados.** El mismo trazo se transforma (arco → anillo →
   check) en lugar de ocultar uno y mostrar otro: se conserva lo común y sólo se
   redibuja lo que cambia.
3. **El trazo como medida.** Un trazo parcial sobre su versión tenue comunica
   progreso o nivel: volumen, brillo, batería, tiempo restante, posición de la
   canción.
4. **La espera respira; el resultado se celebra poco.** Movimiento lento y senoidal
   mientras algo tarda; al resolverse, color de señal y un brillo breve, y calma.
5. **Interrumpible y con memoria.** Cada cambio arranca desde el estado actual
   (el cierre del anillo parte de donde estaba el arco). Coincide con la regla 8 de
   `MOTION_LANGUAGE.md`.

**Cómo usar la investigación externa.** Otros sistemas resolvieron problemas
parecidos y sirven para entender el porqué, no para imitar el resultado:
- Apple (SF Symbols 7, WWDC25): sus efectos *Draw On/Off*, *Magic Replace* y
  *Variable Draw* confirman que trazar, conservar lo común y medir con el trazo se
  entienden bien. También distinguen tres ritmos de trazado: escalonado por partes,
  todo a la vez (inmediato) o secuencial (para llamar la atención). Toma la idea de
  "elegir el ritmo según la intención", no sus curvas, nombres ni aspecto.
- Material 3 Expressive: morfología de formas y muelles en dos familias (espaciales y
  de efectos) por tres velocidades. Sirve como contraste para organizar nuestros
  propios tokens, no como estética.

Para cada principio, di qué lo hace **distinto** en Isla: por ejemplo, cómo encaja con
la superficie líquida, las gotas, el acento dinámico del wallpaper o la respiración de
la pill, que ningún otro sistema tiene.

Marco de microinteracción (Dan Saffer): **disparador → reglas → feedback → bucles y
modos**. Úsalo para describir cada propuesta.

Límites de usabilidad que salieron de la investigación y son buena práctica general:
el movimiento debe tener propósito; feedback breve y preciso antes que llamativo;
**no animar interacciones muy frecuentes**; toda animación necesita alternativa con
reduceMotion.

Implementación en Qt 6.12 (instalado): `ShapePath.trim.start/end/offset` (desde Qt
6.10) es el equivalente nativo de `stroke-dashoffset`; ya lo usan ConfirmationIndicator
y AnimatedSymbol. `Shape.CurveRenderer` da curvas nítidas en GPU.

Fuentes:
- Apple, WWDC25 "What's new in SF Symbols 7": https://developer.apple.com/videos/play/wwdc2025/337/
- Apple HIG, Motion: https://developer.apple.com/design/human-interface-guidelines/motion
- Qt 6.12, ShapePath.trim: https://doc.qt.io/qt-6/qml-qtquick-shapes-shapepath.html
- Dan Saffer, *Microinteractions* (estructura): https://cieden.com/book/sub-atomic/microinteractions/structure-of-microinteractions
- Técnica de trazo propio (stroke-dashoffset): https://svgator.com/tutorials/stroke-path-animation-explained

Amplía esta investigación si te hace falta. Marca qué es práctica establecida y qué
es opinión tuya. Investiga principios, nunca para buscar algo que copiar.

## 3. Qué quiero que entregues

0. **Identidad propia**: en pocas líneas, qué rasgos hacen reconocible el estilo de
   Isla (forma del trazo, grosor, puntas, ritmo, relación con el líquido y el color)
   y en qué se diferencia de Apple y de Material. Propón un nombre propio.
1. **Inventario de la pill**: cada surface y cada microinteracción actual
   (disparador, qué cambia, cómo se anima hoy, archivo:línea). Para el barrido usa
   subagentes baratos (isla-explorador) y quédate con las conclusiones.
2. **Propuesta por interacción**: qué principio de los cinco aplica, cómo se vería
   (dirección del trazo, ritmo, color, duración con tokens existentes) y por qué mejora
   la experiencia. Marca las que **no** deben animarse (frecuentes o sin propósito).
3. **Piezas reutilizables**: qué componentes o tokens nuevos harían falta (p. ej. un
   componente que transforme un símbolo en otro conservando los trazos comunes
   sobre AnimatedSymbol, un anillo de nivel
   reutilizable para OSD/batería/temporizador, tokens de grosor y brillo de trazo) y
   cómo encajan con Motion, Theme y la escala `s`.
4. **Plan por fases** con piloto primero (2–3 interacciones de alto impacto y bajo
   riesgo que yo pueda ver en vivo), criterios de aceptación por fase, pruebas
   (regresiones `*-regression.qml` existentes y nuevas) y tiempo estimado concreto.
5. **Riesgos y presupuesto de rendimiento**: coste de `layer`/`MultiEffect`, número de
   `Shape` vivos, animaciones que deben pararse al ocultarse, impacto en la pill en
   reposo (debe ser cero).
6. **Preguntas para mí** sólo donde la decisión sea de gusto o producto.

## 4. Reglas no negociables

- Estilo propio: nada de copiar a Apple, Pixel/Material ni otra interfaz, ni en
  aspecto, ni en nombres, ni en curvas concretas. Las referencias externas sólo
  explican principios. Si una skill o documento del proyecto dice "Apple-like", esta
  regla prevalece: busca el equivalente propio de Isla. Al cerrar cada propuesta,
  comprueba que no parezca sacada de otro sistema.
- **No tocar los motores aprobados**: muelle de `PillMorphMotion`
  (`Motion.surfaceSpring`), física de las gotas y respiración de la pill. El lenguaje
  de trazo complementa su contenido; no reemplaza la geometría.
- Duraciones y curvas siempre desde `Motion`; nada de literales nuevos.
- reduceMotion resuelve el estado final directamente; oculto = sin animación.
- Sin bucles ornamentales, partículas ni rebotes por todas partes. Contención: la
  firma vale por aparecer en los momentos que importan.
- Conserva cambios ajenos sin commit (hay muchos). Sin commit ni push salvo que lo
  pida.
- Calidad de interfaz: jerarquía clara, legibilidad, objetivos táctiles fijos,
  accesibilidad (contraste, foco de teclado, `Accessible`).
- Para QML aplica las skills `qt-qml` (buenas prácticas) y, si revisas código,
  `qt-qml-review`; para rendimiento, `qt-qml-profiler`. Para motion general,
  `ui-animation`; para acabado de interfaz, `impeccable`.

## 5. Skills externas

Si para alguna parte de la implementación te falta una skill (por ejemplo, morfología
de trazos, diseño de iconos por trazo, animación con muelles o auditoría de
accesibilidad), usa **find-skills de Vercel** para buscarla:

```bash
npx skills find "<capacidad + contexto>"
```

Consultas concretas funcionan mejor (`"svg stroke animation"`, `"qml animation"`) que
genéricas (`"design"`). Si find-skills no está instalada, pide mi permiso antes de
instalarla (`npx skills add vercel-labs/skills --skill find-skills`) y antes de
instalar cualquier skill que encuentres; dime de qué repositorio viene y léela antes
de seguirla. Una skill externa nunca prevalece sobre las reglas de este proyecto.

## 6. Cierre

Registra el plan aprobado en `TASK_STATE.md` y un estado breve en `PROJECT_MEMORY.md`.
Si el plan cambia una regla del lenguaje, propón el texto para `MOTION_LANGUAGE.md`
y la skill `fluid-island-motion`, pero no lo escribas sin mi visto bueno.
