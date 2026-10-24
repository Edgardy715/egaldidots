# Eshell Pets · entrega de fase 2

Implementados A → E, con pruebas por bloque antes de avanzar. Sin cambio de
rama ni commits; se conservan los cambios ajenos. Esta entrega queda preparada
para la revisión posterior de Claude/isla-revisor y su QA propia.

## Comportamiento y decisiones

- Un solo actor: host de vuelo durante el traslado, reparentado a la percha al
  tocar. Parábola, retarget conservando posición/velocidad, entrada, salida y
  cancelación al ocultar. Se mantienen candidate → settleTimer → activePerch.
- Estilo Mascota en split y compact: percha rail p1, sin input propio; puntos,
  brincos, hover fijo y fallback al nicho. La lens no anima por Mimo. La percha
  queda sobre el cristal del rail para conservar el color del sprite.
- Terminal/editor por eventos nativos de ToplevelManager (comprobados con dos
  ventanas Wayland en Hyprland), pulsos de Players desde composición; code se
  asienta tras cuatro vueltas, baile de casa de ocho segundos, noche y saludo.
- Travesuras ponderadas por el cerebro existente. Cinco ajustes nuevos con
  defaults, validación y persistencia: catorce campos Pets en el editor actual.
- Hop de tres poses y atlas de cuarenta frames; fuentes/hojas/GIF regenerados,
  ambas pet.json idénticas. Hojas clara y oscura inspeccionadas.

Desviaciones justificadas del brief:

1. **Ápice visible, autorizado por el usuario.** La fórmula literal cortaba el
   brote en DP-1. La altura se limita al espacio visible; el retarget frena el
   ascenso conservando la velocidad actual. El cambio de px puede retrasarse
   desde el ápice hasta que la escala de destino quepa por completo.
2. **Retorno al hogar, autorizado por el usuario.** El cierre normal del launcher
   tarda más de 400 ms en presentar el nicho. Se retiene el origen hasta que
   vuelva la percha y entonces se vuela; se cancela al reabrir/ir a otra
   superficie. Tope de seguridad 2500 ms si se desactivan las perchas mientras
   espera. Los demás relevos mantienen 400 ms. Los umbrales 0.95 y el
   acoplamiento del nicho no cambian.
3. **Driver limitado en pantallas rápidas.** Una FrameAnimation continua a
   240 Hz costaba 3.2% CPU aunque se limitaran sus escrituras. Un Timer
   imperativo de 24 ms suspende el driver entre avances y se detiene al llegar
   u ocultar. La puerta inicial de 17 ms aún dio 2.11% con el contador preciso;
   24 ms redujo los despertares (piloto: 1.91%, 26 fps medios con un vuelo/s).
   Se conserva el tiempo real integrado, la duración y la continuidad del vuelo.
   No hay driver permanente en reposo.
4. El fixture overlay usaba cierre reducido y ocultaba el fallo real de retorno.
   Ahora usa Flags.reduceMotion y comprueba el cierre normal, reapertura y
   visibilidad real del actor durante el relevo.

## Validación

Todos los fixtures usan ISLA_CONFIG temporal. Evidencia en
[validation-phase2](validation-phase2/).

| Comprobación | Resultado |
| --- | --- |
| pets.py: paquete/clasificador, runtime, rail e IslandOverlay real | PASS |
| settings.cjs y settings-integration.py (14 campos) | PASS |
| Wayland: layout-routing, media-dock-surfaces, pill-composition, bar-layout-transition | PASS |
| Offscreen: pill-interface, status, clock-reel, island-status-adapter, workspace-styles, pacman-motion, neon, optional-modules, module-composer, compact-island | PASS |
| overlay-native-input.py: Escape/foco de 14 superficies | PASS |
| Revisión independiente Sol: vuelo, geometría, retarget y retención | Sin hallazgos pendientes tras corregir el límite superior |

El lint QML devuelve 255 sin diagnóstico en este entorno. No se registra como
PASS; las cargas reales de los componentes en los fixtures sí pasan.

## QA nativa en DP-1

[Hojas de contacto y muestras](qa-phase2/) de 29 escenas y 327 capturas con grim,
1920×1080 a 239.964 Hz. IslandOverlay de producción desplazado 96 px hacia abajo
para no cubrir la barra personal; configuración temporal. Revisados todos los
fotogramas capturados de vuelos/brincos y ambas repeticiones.

- Barra ↔ launcher, repetido dos veces: espera visible de retorno y vuelo hasta
  el nicho; aterrizaje sobre la superficie aún en morph seguido sin corte.
- Rail 1→2 y 1→5, dos veces en cada layout; 1→5→2 rápido, hover, punto activo
  sustituido. Sin brote cortado tras la corrección: margen mínimo muestreado
  durante vuelo 2.03 px. Los clics/hover nativos están cubiertos por QtTest.
- Rail ↔ launcher: compact vuela en ambos sentidos. En split, el regreso desde
  launcher al rail supera 900·s y usa fade + entrada conforme al brief.
- Media → launcher: la disponibilidad real produce media → casa → launcher;
  ambos tramos observados. No se fuerza una percha antes de estar presentada.
- Kitty enfocada activa code. MPRIS falso sin audio: dance durante ocho segundos
  y retorno a idle. Frequent produce wave con reloj adelantado en el fixture.
- Reduced motion: traslado y cambio de workspace sin vuelo.

Las capturas son muestras irregulares (intervalo mediano ~127 ms en las ráfagas
cortas), no todos los frames del compositor ni una medida de FPS. Los detalles se centran en el cuerpo detectado en la captura; la pose y fase
rotuladas proceden de una consulta IPC posterior, con ese pequeño desfase.
La hoja de contexto conserva el recorrido. Continuidad matemática y retarget se comprueban además en runtime.
No se afirma inspección de los intervalos no capturados.

## Rendimiento

Dos rondas en orden inverso, ventanas de 5 s, proceso Wayland de 200×100.
Idle/rail-idle fijan RNG=0.99: conservan cerebro y animación idle, excluyen
paseos/bostezos espontáneos que pertenecen a otros escenarios. Una muestra
previa inició un paseo y dio 2.6 fps; se conserva el fallo en perf/.
CPU en porcentaje de un núcleo; FPS son frameSwapped de esa ventana. No quedan
quickshell offscreen concurrentes. Se limpiaron seis fixtures abandonados,
identificados antes de terminar sólo esos procesos; evidencia en
validation-phase2/offscreen-cleanup.json. La shell personal sigue ejecutándose.

El coste de los marcadores PET_READY/PET_RESULT producía ocasionalmente un tick
de CPU incluso en disabled de fase 1. La cifra estable excluye los primeros y
últimos 250 ms; CPU completa y muestras permanecen en results.json. Además, un tick de Linux
de 10 ms podía aparecer en hidden sin frames nuevos. Una sonda por hilo
registró ~0.3 ms/4.5 s tanto en hidden como disabled (Qt/Wayland). Se usa por eso
schedstat en nanosegundos sobre todos los hilos, exigiendo un árbol estable; el
contador por ticks se conserva. El criterio de cero es 0.0% a una décima
(<0.05%), no cero tiempo físico. El revisor independiente comprobó este cambio. El conteo
de frames conserva las dos presentaciones de los marcadores (~0.4 fps).

La PSS histórica de after-isolated también cambió en disabled al repetirla en
este entorno. Por eso se conserva y compara, pero el límite de +2 MiB se
comprueba además contra una referencia emparejada: core previo a A recuperado
del respaldo de sesión, actor reconstruido mediante reversión comprobada de las
ediciones A, Settings original de nueve campos y paquete original de 37 frames.
Se usa el mismo harness actual salvo el binding coding inexistente en fase 1;
la copia temporal del actor antiguo expone sus Math.random mediante la misma
propiedad random para aplicar el control idéntico de idle, sin cambiar decisiones.
Fuentes congeladas, hashes, método y resultados en perf/phase1-matched/.
Esta comparación no equivale a afirmar que la diferencia histórica sea cero.

| Escenario | FPS fase 1 histórico | FPS fase 2 | CPU fase 2 (%) | PSS fase 2 (MiB) |
| --- | ---: | ---: | ---: | ---: |
| disabled | 0.6 | 0.4 | 0.0 | 104.56 |
| idle | 1.3 | 1.0 | 0.09 | 114.15 |
| walking | 6.3 | 6.6 | 0.50 | 111.85 |
| reacting | 5.1 | 5.6 | 0.44 | 113.10 |
| dancing | 4.3 | 4.4 | 0.30 | 113.94 |
| hidden | 0.6 | 0.4 | 0.0 | 111.28 |
| sleeping | 0.6 | 0.4 | 0.0 | 112.99 |
| flying | — | 32.0 | 1.97 | 112.81 |
| coding | — | 0.0 | 0.01 | 114.30 |
| rail-idle | — | 1.0 | 0.09 | 135.22 |

Todos los criterios pasan. CPU de flying: 1.97%
media (rondas 1.85/2.08%), con cinco vuelos iniciados en cinco segundos. Los
estados quietos dan 0.0% a una décima (valores sin redondear en JSON).

PSS idle: referencia de fase 1 emparejada **112.59 MiB** →
fase 2 **114.15 MiB**, **+1.56 MiB**, dentro de +2 MiB.
La histórica after-isolated era **105.22 MiB**:
el delta bruto es **+8.93 MiB** y no cumple el límite si se toma esa
cifra aislada. La repetición de fase 1 también sube ~7.4 MiB frente al histórico;
por eso la conclusión de memoria se basa en la comparación emparejada descrita,
no se atribuye toda esa deriva a Mimo ni se oculta el dato antiguo.

[Resultado final y checks](perf/phase2/final-results.json): combina las dos
rondas completas con una repetición exclusiva de flying después de corregir
el primer inicio a t=0 y exigir cinco inicios/5 s. Los otros nueve escenarios
conservan su evidencia de esas rondas completas. Se guardan fuentes/hash por
medición; el código de producto es idéntico, sólo cambian el fixture y su assert
de conteo. Los registros originales y todos los intentos fallidos se conservan.


## Límites y siguiente revisión

No hay bloqueo funcional conocido en el alcance probado. No se midió el coste
de toda la shell: el benchmark aísla la mascota y, en rail-idle, el rail real.
No se verificaron otras escalas/monitores mediante captura nativa. No se cambió
la configuración personal ni se reinició la barra del usuario.

Quedan la revisión posterior de Claude con isla-revisor y su QA visual propia
antes de dar la fase por cerrada, tal como exige PHASE2.md.
