# Opción B experimental: envolvente CAVA en Rust

Prototipo aislado; no instalado y sin cambios en `rust/` ni `bar/`. El coordinador
elige entre A y B sólo con CPU total `qs` + helper en el mismo escenario.
Este directorio no demuestra ahorro ni fluidez visual.

## Reproducir

Desde la raíz:

```sh
docs/performance-2026-10-22/rust-experiment/reproduce.sh
python docs/performance-2026-10-22/rust-experiment/check-runtime.py
```

El script copia el crate existente a `/tmp/isla-cava-b`, aplica `main.patch`,
copia `spectrum.rs`, genera vectores con Node y ejecuta test/clippy/build locked.
No añade dependencias ni instala binarios. `sources.json` identifica las fuentes
originales; `Spectrum.js` es la referencia exacta usada para generar los vectores.
`vectors.json` contiene 82 casos parse y 600 pasos attack/release/silencio/resume,
con comparación absoluta <=2e-14 (diferencias de libm JS/Rust).

Binario: `/tmp/isla-cava-b/target/release/isla-cava-stream`.
Añadir `--smooth` activa B; sin esa opción conserva salida ASCII entera original.
Todas las opciones de identidad/desktop/bus/parent y protección por muerte del
padre se mantienen. Ejemplo de argv desde un Process QML experimental:

```js
["/tmp/isla-cava-b/target/release/isla-cava-stream", "--smooth",
 "--parent", Quickshell.processId.toString(),
 "--identity", root.playerIdentity, "--desktop", root.playerDesktop,
 "--bus", root.playerBus]
```

## Contrato hacia QML y fallback

B emite líneas ASCII con 24 doubles finitos en [0,1], separados por espacios y
terminadas con `\n`. Ya incluyen mapeo dB, filtro espacial y envolvente.
QML valida cantidad/rango y asigna `root.values = frame`; NO ejecuta
`Spectrum.parse` ni `Spectrum.advance` sobre esa línea. Mantener los gates de
wanted/available/sourceRestart y movimiento reducido. `hasFrame` se activa al
primer cuadro; reset al iniciar/salir conserva la lógica actual.

El fallback continúa siendo QML + Spectrum.js y el wrapper original (Python o
Rust raw). Elegir explícitamente la rama antes de lanzar el proceso: si B no está
disponible, arrancar el wrapper existente y su parse/advance A. Nunca interpretar
salida raw como normalized ni mantener el parser B después de volver a A.
El modo es deliberadamente experimental: no se modifica el wrapper de producción.

## Semántica temporal

Tick nominal 60 Hz (16.666667ms), reloj monotónico y dt real máximo 50ms como A.
El deadline avanza por periodo; si se pierde un periodo se salta, sin ráfagas de
recuperación. Un input válido refresca el target; a >=250ms sin input se libera
contra cero. Ataque 65ms, release 210ms, corte estricto `<0.0001` y silencio cero.
No emite cuadros idénticos ni mantiene reloj de envolvente tras asentarse en cero.
Sigue vivo el descubrimiento/captura original mientras haya consumidor QML.

Sólo la envolvente final se serializa; stdout conserva las escrituras no bloqueantes
y cola acotada original (frame parcial y último completo), stderr queda separado.
El backpressure puede descartar cuadros completos, nunca mezclar dos líneas.

## Límites

Comparar a igual frecuencia y con los mismos consumidores visibles. El cambio de
frontera JS/Rust no evita el render de Qt ni el array nuevo de asignación QML.
La equivalencia es matemática para los vectores y un mismo dt, no fase exacta entre
Timer Qt e Instant Rust. La captura real y la evaluación visual corresponden al
coordinador. No se cambió reproducción, configuración personal ni sesión shell.

## Comprobaciones de esta entrega

- `cargo test --locked`: 10/10 PASS; clippy all-targets `-D warnings` y release locked PASS.
- Protocolo sintético: 89 cuadros activos, 60.033 Hz observados durante 1.60s,
  valores finitos normalizados y ataque monotónico. No es medida de presentación.
- Lifecycle modo smooth: 5/5 PASS, incluyendo parent mismatch/death, TERM/KILL,
  query bloqueada, pipe lleno/BrokenPipe y ausencia de hijos vivos tras terminar.
- La prueba heredada de backpressure usa margen 600 bytes por los doubles
  (antes 150 para enteros); todas las aserciones de limpieza permanecen.
- Reconstrucción por patch produce exactamente el main.rs probado. Sintaxis sh PASS.

Resultados recuperables en `cargo-checks.log`, `runtime-checks.log` y
`validation.json`; SHA256 del binario allí. Sin fallos pendientes en estas pruebas.
