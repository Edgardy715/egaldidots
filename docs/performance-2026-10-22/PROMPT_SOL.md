# Encargo: fluidez, CPU y memoria de Isla (edotsShell)

Eres el ingeniero responsable de rendimiento de Isla, una shell Quickshell/QML para
Hyprland con un núcleo híbrido en Rust que está en desarrollo. Tu trabajo es
**reducir CPU, memoria y redibujados innecesarios sin perder fluidez ni cambiar el
diseño aprobado**. Cada mejora se mide antes y después en la sesión real. Lo que no
se mide no cuenta como mejora.

Trabajas en `/home/zdito/.config/quickshell`. Responde y documenta en español.

---

## 0. Antes de tocar nada (obligatorio, en este orden)

1. Lee `AGENTS.md` y `PROJECT_MEMORY.md` completos (son cortos).
2. Lee `.agents/skills/fluid-island-motion/SKILL.md` y `bar/fluid/MOTION_LANGUAGE.md`.
   Toda mejora de rendimiento que afecte al movimiento tiene que respetarlos.
3. Lee `docs/SHELL_ARCHITECTURE.md` (Settings.js, Flags, Config.update/discard/save).
4. Lee la sección del 2026-10-22 «CPU en reposo: InnerGlow a 240 Hz» con
   `rg -n "InnerGlow a 240 Hz" -A 20 TASK_STATE.md`. **No leas TASK_STATE.md completo**:
   pesa cientos de KB. Para lo anterior usa
   `python ~/.codex/token-economy/recall.py 'tema' --root /home/zdito/.config/quickshell`.
5. Lee `docs/performance-2026-10-21/REPORT.md` y `docs/rust-cava-2026-10-21/REPORT.md`
   para no repetir lo que ya se midió.
6. Ejecuta `git status`. Hay mucho trabajo local sin commitear que **no es tuyo**
   (pets, MediaView, WallpaperView, settings…). No lo reviertas, no lo formatees y no
   lo incluyas en tus commits.

---

## 1. Hechos ya establecidos (no los vuelvas a investigar)

- El monitor DP-1 va a **240 Hz**. Cualquier `FrameAnimation`, animación infinita o
  binding que cambie en cada fotograma obliga a Qt Quick a renderizar esa ventana
  240 veces por segundo. Es el multiplicador de coste número uno de esta shell.
- Qt Quick sólo renderiza cuando la escena cambia. Por eso la regla general es: **si
  algo no cambia visiblemente, no debe tocar ninguna propiedad**.
- Corrección ya hecha: `bar/components/InnerGlow.qml` pasó de `FrameAnimation` a un
  `Timer` a 12 Hz con dt real. Medido en A/B con arranque limpio y sin música, la CPU
  de `qs` en reposo bajó del 20–25 % al 3,7–4 %, con RSS igual (~450 MB). Ese es el
  patrón de referencia para la deriva decorativa lenta.
- La shell **no recarga en caliente**. Para probar en la sesión real hay que reiniciarla:
  ```sh
  qs kill -c bar; sleep 1; (cd ~; setsid -f qs -c bar --no-duplicate >/dev/null 2>&1 </dev/null)
  ```
  Hyprland usa configuración Lua, así que `hyprctl dispatch exec …` con la sintaxis
  antigua falla. Usa `setsid` como arriba.
- Los helpers de Rust viven en `rust/{cava-stream,audio-peak,clipboard-list}`. Son
  **opcionales** y siempre tienen fallback en Python mediante un `.sh` que hace `exec`
  del binario instalado en `~/.local/share/isla/bin/` si existe. La medición anterior
  dio ~10 MiB de PSS ahorrados en CAVA y ningún ahorro global de CPU demostrado.

---

## 2. Problemas a resolver, por prioridad

### P1. Animaciones ambientales a 240 Hz mientras suena música

Candidatos que corren cada fotograma:

| Archivo | Qué hace en cada fotograma |
|---|---|
| `bar/Singletons/Cava.qml:97` | `Spectrum.advance()` en JS y asigna un **array nuevo** a `values`, lo que reevalúa todos los bindings de las barras |
| `bar/components/MediaTimeline.qml:117` | avanza `waveOffset` de la onda de progreso |
| `bar/components/SwiftMediaTimeline.qml:88` | avanza `phaseOffset` |
| `bar/components/MediaTransportButton.qml:54` | giro de `angle` del botón principal |

Objetivo: que el contenido **decorativo continuo** (espectro, ondas, giros) se
actualice a una frecuencia acotada, mientras que el **movimiento interactivo** (morph
de la pill, muelles de gotas, lente del rail, respuesta al puntero) sigue a la tasa del
monitor.

Cómo lo haría:

1. **Mide primero** el escenario con música (`playerctl play`, media visible y con la
   pill en reposo): CPU por hilo con `top -H -b -n 4 -d 3 -p $(pgrep -x qs)`. El hilo
   `QSGRend…` es el coste de render y el hilo principal `qs` el de JS y bindings.
2. Diseña un **reloj ambiental compartido** (por ejemplo, un singleton `AmbientClock`
   en `bar/Singletons/`). Debe tener una propiedad `elapsed`/`tick` que avance con un
   `Timer` a una frecuencia configurable (por defecto 60 Hz), basada en tiempo real
   (`Date.now()` con dt acotado como en InnerGlow) y que se detenga cuando no tenga
   suscriptores visibles. Así sustituyes N relojes por 1 y todas las ondas avanzan en
   el mismo fotograma.
   - Añade el ajuste en `bar/Singletons/Settings.js` con default, validación y rango
     (por ejemplo, 30–240). Exponlo por la fachada `Flags` siguiendo el patrón
     existente y añádelo a `bar/shell.json.example`. No inventes otro mecanismo de
     configuración.
3. **CAVA: evalúa dos opciones y elige con datos.**
   - **A (QML):** el suavizado de la envolvente avanza con el reloj ambiental en lugar
     de `FrameAnimation`, y se deja de crear un array nuevo por paso si el modelo de las
     barras lo permite.
   - **B (Rust):** `rust/cava-stream` hace el parseo, el mapeo perceptual (dB → 0..1),
     el suavizado espacial y la envolvente de ataque 65 ms / release 210 ms, y emite
     cuadros ya suavizados a frecuencia fija. QML sólo asigna. El cálculo tiene que ser
     **idéntico** al de `bar/Singletons/Spectrum.js` (`parse` y `advance`): escribe
     tests en Rust que comparen con vectores generados desde la versión JS. El fallback
     Python tiene que producir la misma salida, o bien QML conserva `Spectrum.js` para
     el fallback: decide qué es más simple y documéntalo.
   - Elige B sólo si mide menos CPU total (`qs` + helper) que A. Si empatan, gana A
     porque es más simple.
4. Comprueba visualmente las ondas y el espectro en la sesión real, mirándolos, no sólo
   con logs. A 60 Hz en un monitor de 240 Hz las ondas no deben verse a saltos. Si se
   ven, sube a 120 Hz y vuelve a medir. La fluidez percibida manda sobre el ahorro.

### P2. Memoria creciente

La RSS de `qs` subió de 450 a 588 MB en 28 minutos de uso real. No sabemos si es una
fuga, una caché que crece o el heap de JS sin recoger.

Cómo lo haría:

1. Escribe un script en `bar/tests/` que muestree cada 30 s el PSS (Proportional Set
   Size) de `qs` desde `/proc/<pid>/smaps_rollup` y lo guarde en
   `docs/performance-2026-10-22/`.
2. Repite cada escenario 20 veces y mide después de cada tanda:
   - abrir y cerrar media;
   - abrir y cerrar el wallpaper picker;
   - abrir y cerrar el launcher;
   - cambiar de canción (portada nueva);
   - recibir notificaciones;
   - abrir y cerrar Edots.
3. Distingue la causa:
   - si llamar a `gc()` desde un IPC o test baja la memoria, es heap de JS;
   - si crece con imágenes, es la caché de texturas o de pixmaps (revisa `sourceSize`,
     `cache`, `asynchronous` y que las imágenes ocultas liberen `source`);
   - si crece con instancias, es un `Loader` o un `Repeater` que no destruye.
   La skill `qt-qml-profiler` sirve para el resumen de memoria y de la caché de pixmaps.
4. Corrige sólo lo que el muestreo señale. Una fuga demostrada se cierra con una
   regresión que repite el escenario y comprueba que el PSS se estabiliza.

### P3. CPU residual en reposo (~4 %)

Con la pill en reposo y sin música todavía hay redibujados. Encuentra qué propiedad
cambia: instrumenta temporalmente con `QSG_RENDER_TIMING=1` en una instancia de prueba,
o desactiva candidatos uno a uno (A/B). Busca relojes o animaciones que corran con su
componente oculto o con opacidad 0, y bindings a `Date`/tiempo.

El objetivo es **0 fotogramas por segundo cuando nada cambia visiblemente**, salvo los
12 Hz de la deriva de InnerGlow, que son aceptados.

### P4. Bucle de binding en `Players.active`

El log repite «Binding loop detected for property "active"» en
`bar/Singletons/Players.qml:32`. Encuentra el ciclo (seguramente `manual`/`recent` o
algún consumidor que escribe de vuelta) y rómpelo sin cambiar la prioridad documentada:
el manual vivo primero, luego el que reproduce y luego el reciente. Añade un test.

---

## 3. Cuándo y cómo usar Rust

Rust es la herramienta para **trabajo continuo fuera del hilo de QML**: parseo de
flujos, DSP, polling de sistema y procesamiento de listas grandes. **No es un objetivo
en sí mismo.**

Úsalo cuando:
- el coste está en JS del hilo principal (parseo, bucles por cuadro, arrays grandes), o
- sustituye un proceso Python persistente (ahorro de PSS), o
- evita lanzar procesos de forma periódica (`Process` cada N segundos).

No lo uses cuando:
- el coste está en el render (redibujados), porque eso se arregla dejando de cambiar
  propiedades, no con Rust;
- el ahorro esperado no se puede medir, o es menor que la complejidad añadida.

Reglas de código Rust en este repo:
1. Un crate por helper en `rust/<nombre>/`, edición 2021, `publish = false`, y el mismo
   `[profile.release]` que `rust/cava-stream/Cargo.toml` (`opt-level="s"`, `lto`,
   `codegen-units=1`, `strip`, `panic="abort"`).
2. Dependencias mínimas. Nada de tokio ni async runtimes para un bucle de E/S simple:
   `nix::poll` basta. Cada crate nuevo necesita una justificación en el REPORT.
3. Sin `unsafe` salvo FFI imprescindible, con comentario `// SAFETY:`.
4. Protocolo hacia QML: líneas de texto por stdout, una por cuadro o evento, con formato
   estable y documentado en el README del crate. Los errores van por stderr y nunca
   rompen el formato de stdout. Haz flush por cuadro.
5. Ciclo de vida: acepta `--parent PID`, arma la señal de muerte del padre (como hace
   `cava-stream`), termina limpio con SIGTERM y no deja huérfanos. Verifícalo matando
   `qs` y comprobando con `pgrep` que el helper desaparece.
6. Siempre con fallback: el `.sh` hace `exec` del binario si existe y si no, de la
   implementación Python o QML existente. Borrar el binario devuelve al
   comportamiento anterior sin otro cambio. No borres los fallbacks.
7. Antes de dar un crate por terminado tienen que pasar:
   ```sh
   cargo test --locked
   cargo clippy --locked --all-targets -- -D warnings
   cargo build --release --locked
   ```
   Instálalo con el script de `scripts/` correspondiente (crea uno siguiendo
   `scripts/build-cava-helper.sh` si es un helper nuevo).
8. Para cada helper mide el PSS y la CPU de Rust frente a la alternativa anterior, en el
   mismo escenario y con la misma duración, y pon la tabla en el REPORT.

---

## 4. Cómo programar en QML aquí

- Sigue el estilo del archivo que tocas: nombres, densidad de comentarios (pocos, en
  español, que expliquen el *porqué*) e idioms.
- Los componentes hoja reciben datos por propiedades. Players y Cava se conectan desde
  la composición, nunca desde una hoja.
- Toda animación o reloj se condiciona a `visible`, a la opacidad > 0 y a
  `!Flags.reduceMotion`, y se reanuda sin salto (dt acotado).
- Tiempos y curvas salen de `Motion`; no metas literales nuevos de duración.
- Prefiere bindings declarativos y `readonly property` a asignaciones imperativas. No
  crees arrays u objetos nuevos en código que corre por fotograma si puedes mutar o
  evitarlo.
- Ajustes nuevos: default y validación en `Settings.js`, lectura por `Flags`, y pruebas
  con `ISLA_CONFIG` apuntando a un JSON temporal en tu directorio de trabajo. **Nunca**
  toques la configuración real del usuario para probar.

---

## 5. Método de trabajo para cada problema

1. **Hipótesis**: escribe en una línea qué crees que cuesta y por qué.
2. **Medición base** en la sesión real, con arranque limpio y el escenario fijo
   (reposo / música / interacción), con al menos 4 muestras de 3 s:
   ```sh
   P=$(pgrep -x qs); top -b -n 4 -d 3 -p $P | awk -v p=$P '$1==p {print $9"% cpu, rss "$6}'
   ```
   Añade `top -H` si necesitas separar el hilo de render del hilo principal.
3. **Cambio mínimo** que ataca la causa.
4. **A/B**: guarda tu versión, restaura la anterior con `git show HEAD:<ruta> > <ruta>`
   (sólo en ese archivo), reinicia y mide; luego vuelve a tu versión, reinicia y mide.
   Si `HEAD` no es la base correcta porque el archivo tenía cambios locales, guarda una
   copia previa tú mismo antes de editar.
5. **Regresiones**: ejecuta las que afectan al área (`bar/*-regression.qml` con
   `quickshell -p bar/<test>.qml` y `ISLA_CONFIG` temporal; las que crean ventanas
   necesitan Wayland, no `offscreen`) y los tests de `bar/tests/` pertinentes. Si un
   test falla, comprueba si ya fallaba antes de tu cambio y dilo.
6. **QA visual** en la pantalla real para todo lo que se mueve. Offscreen no es QA
   visual. Si no puedes mirarlo, márcalo como «no verificado visualmente» y pide al
   usuario que lo confirme.
7. Si una hipótesis no se confirma con la medición, descártala, anótala y pasa a la
   siguiente. No insistas sin datos nuevos.

Si tras dos intentos un problema no mejora de forma medible, detente en ese problema,
documenta lo aprendido y sigue con el siguiente.

---

## 6. Lo que NO debes hacer

- No bajes la tasa del movimiento interactivo (morph de la pill, gotas, brote/recogida,
  lente del rail, respuesta al hover). Sólo lo decorativo y continuo se acota.
- No cambies diseños aprobados: respiración de la notificación, cuello de gotas en GPU,
  yema redonda, pulso de personalidad, paleta. Rendimiento significa el mismo aspecto
  con menos coste.
- No desactives efectos, ni actives `reduceMotion`, ni bajes la calidad como «solución».
- No introduzcas Rust sin medir, ni borres los fallbacks Python, ni dejes procesos
  persistentes en reposo.
- No reviertas, formatees ni commitees cambios ajenos. Haz `git add` sólo de rutas
  concretas, nunca `git add -A`.
- No toques la configuración real del usuario (`shell.json`, Hyprland) para probar.
- No cargues TASK_STATE.md completo ni la bóveda entera.
- No declares una mejora sin la tabla A/B. No digas «más fluido» sin haberlo mirado.
- No hagas push salvo que el usuario lo pida en la conversación. Si lo pide, lo ejecutas tú.
- No amplíes el encargo a una auditoría de toda la shell sin evidencia que lo justifique.

---

## 7. Entregables

1. Código con commits pequeños, uno por problema, con mensajes en el estilo del repo
   (`perf(media): …`, `fix(players): …`) que incluyan sólo tus archivos.
2. `docs/performance-2026-10-22/REPORT.md` con:
   - por problema: hipótesis, causa confirmada, cambio, tabla A/B (CPU por escenario,
     PSS/RSS), pruebas ejecutadas con resultado y estado de QA visual;
   - para cada helper Rust: el protocolo, la equivalencia con JS demostrada por tests y
     la tabla de PSS/CPU frente al fallback;
   - una sección «Probado / No verificado / Bloqueado», sin mezclar categorías.
3. Las mediciones en crudo (JSON o TXT) en la misma carpeta.
4. Actualiza `PROJECT_MEMORY.md` (1–2 líneas en «Estado activo», sin superar los 4 KB) y
   añade al final de `TASK_STATE.md` las decisiones, pruebas y límites, con `cat >>` o
   un editor, sin leerlo entero.
5. Un resumen final para el usuario de 10 líneas como máximo: qué mejoró y cuánto
   (cifras), qué falta mirar con sus ojos y qué decisiones quedan pendientes.

## 8. Criterio de éxito

- Reposo sin música: igual o por debajo del 4 % actual, idealmente sólo los 12 Hz de la
  deriva.
- Con música: reducción medible de la CPU de `qs` sin pérdida visible de fluidez en
  ondas ni espectro.
- PSS estable (sin crecimiento sostenido) tras 20 repeticiones de cada escenario de P2.
- Sin bucles de binding en el log tras un arranque y 5 minutos de uso.
- Todas las regresiones del área en verde, o con su fallo previo documentado.
