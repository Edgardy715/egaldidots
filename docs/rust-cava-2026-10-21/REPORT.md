# CAVA híbrido: QML/Qt + Rust · 2026-10-21

## Decisión

Promovido un helper Rust acotado para orquestar descubrimiento y captura del
visualizador. La interfaz, bindings, geometría, animaciones y envelope siguen en
QML/Qt; CAVA sigue calculando FFT y parec sigue capturando audio. Python permanece
como fallback y proporciona parent-death al monitor NetworkManager. No se propone
reescribir toda la shell ni añadir un daemon general.

La comparación anterior de descubrimiento no demostraba que Rust fuese inútil.
Este experimento compara una implementación Rust con el Python ya optimizado,
incluyendo reproducción real en una fuente privada, antes de promoverla.

## Método y resultados

`bar/tests/cava-hybrid-performance.py` crea un null sink privado e inaudible y un
stream de tono440Hz identificado por nombre único. Usa pactl, parec y CAVA reales;
verifica que parec recibe el ID exacto y monitor privado. No modifica defaults,
volumen ni streams personales. Elimina su stream y módulo en finally y comprueba
que los defaults originales siguen iguales. `complete=true` y
`defaults_preserved=true` en comparison.json.

Dos rondas de12s por backend/escenario, calentamiento1s; orden Python→Rust y
Rust→Python. CPU y PSS corresponden al helper y todos sus descendientes, incluyendo
CAVA/parec/pactl, excluyendo el servidor de audio compartido y el productor del
tono. CPU es porcentaje de un núcleo Linux, no de toda la máquina. Memoria: mediana
de muestras PSS por ejecución y luego mediana entre las dos ejecuciones.

| Escenario | Python PSS | Rust PSS | Ahorro | CPU Python / Rust |
|---|---:|---:|---:|---:|
| Identidad sin resolver | 11,73 MiB | 1,63 MiB | 10,10 MiB (86%) | 0,082 / 0,000% |
| Audio privado activo | 28,60 MiB | 17,32 MiB | 11,28 MiB (39%) | 2,468 / 1,983% |

El ahorro estable del proceso principal es aproximadamente10,1MiB; la variación
adicional de librerías compartidas hace que el ahorro del árbol activo varíe
9,94–12,62MiB. La mejora de memoria justifica la integración. CPU bajó en ambas
parejas (2,377→1,750 y2,558→2,216%), pero sólo dos muestras cortas no establecen un
porcentaje general ni ahorro energético. 0% significa debajo de la resolución del
contador durante ese intervalo, no ausencia de trabajo.

Ambos producen24 bandas válidas en0..65535 y60frames/s con audio. Pico del tono en
la misma banda9, media alrededor5845–5846, sin cambio del algoritmo. P95 de intervalos
activos: Python16,75/16,79ms; Rust16,79/16,78ms. Máximo observado: Python18,90/47,99ms;
Rust17,19/18,13ms. No se afirma mejora de FPS de pantalla. Primer dato con señal:
Python669/706ms, Rust595/604ms; es latencia del helper con stream ya existente,
no arranque global de la shell.

Sin selección, ambos publican sólo ceros; Python aproximadamente1Hz y Rust hasta2Hz.
La envolvente QML permanece dormida en cero. Sin consumidor, no hay helper de
ningún backend: no se atribuye ahorro de memoria al reposo sin visualizador.

Datos: `python-baseline.json` (primera medición Python previa), `comparison.json`
(ocho ejecuciones completas), `baseline.json` y `baseline/` (siete fuentes con
SHA256 congeladas antes de implementar Rust), `sources.json` (fuentes finales).

## Integración y reproducción

`bar/services/cava-stream.sh` hace exec del binario instalado si es ejecutable y
le pasa Quickshell.processId como propietario explícito. Si está ausente, hace
exec de Python. No queda un shell supervisor. El contrato QML de24 bandas no cambia.
CAVA se pide por consumidores visibles como antes.

`sh scripts/build-cava-helper.sh` compila release con Cargo.lock y hace instalación
atómica en `${XDG_DATA_HOME:-$HOME/.local/share}/isla/bin/isla-cava-stream`.
El instalador lo intenta cuando existe cargo; sin toolchain usa Python. No añade
Rust a paquetes obligatorios ni descarga toolchains por sí mismo. Fallos de build
preservan un binario anterior; sin binario, Python sigue disponible.

Se usó rustc1.99.1 aislado en ~/.local/share/isla/{cargo,rustup}, sin cambiar perfiles
ni paquetes del sistema. Binario x86_64:449776bytes; SHA256
`fc1449e66e05622dbba50f4e5f9b0e473da3660df662af8a4397bb4f1a63bda4`.
El release recompilado por el script coincide exactamente con el medido.
Cargo es necesario para construir, no para ejecutar. Dependencias Rust fijadas en
Cargo.lock: serde_json, nix, signal-hook y tempfile y sus transitivas.

```sh
sh scripts/build-cava-helper.sh
ISLA_CAVA_TEST_BINARY="$HOME/.local/share/isla/bin/isla-cava-stream" python bar/tests/cava-stream.py
ISLA_CAVA_RUST_BINARY="$HOME/.local/share/isla/bin/isla-cava-stream" python bar/tests/cava-rust-lifecycle.py
python bar/tests/cava-backend.py
python bar/tests/cava-hybrid-performance.py --rust "$HOME/.local/share/isla/bin/isla-cava-stream" --seconds 12 --rounds 2 --output /tmp/cava-hybrid.json
```

Rollback: retirar ese binario y cerrar/reabrir el consumidor del visualizador.
El fallback cubre ausencia del binario; un fallo de ejecución de un binario instalado
se diagnostica como error, sin sustituir silenciosamente una implementación rota.

## Validación

- Rust:7unit tests, clippy all-targets con-Dwarnings, release locked PASS.
- La misma regresión cava-stream.py:7tests PASS sobre Rust, incluyendo eventos,
  ausencia/ambigüedad/corked, identidad de cliente, reroute, burst/splitlines,
  descubrimiento fallido, desconexión/reconexión y limpieza. Los tests unit de
  selección en ese script siguen probando Python; Rust tiene sus propios unit.
- cava-rust-lifecycle.py:5tests PASS contra el binario instalado. Propietario
  incorrecto no crea hijos; SIGTERM/SIGKILL durante captura, query bloqueada,
  stdout lleno/BrokenPipe y muerte del propietario eliminan procesos vivos.
  Un zombie terminado tras SIGKILL depende del reap de init, no del helper muerto.
- cava-backend.py PASS: argv con espacios/metacaracteres, exec/propietario directo,
  backend presente/ausente, instalación atómica/fallo y frames por el Process QML
  real con productores fake. También prueba binario Rust instalado mediante QML
  con identidad imposible (silencio, sin captura personal).
- cava-envelope.py PASS: cero publicaciones en silencio, ataque/release/resume/reset.
- Gate verify-config y sintaxis shell/install PASS. Revisión independiente sin
  defectos sustentados en selección, límites, discovery async y lifecycle;
  ensayos adicionales de cancelación1–3ms con productores sintéticos PASS.
- Benchmark real privado PASS: protocolo,60Hz, stream/monitor exactos,
  limpieza sin hijos vivos y defaults preservados.

## Límites

No se ha medido batería, GPU, FPS de pantalla, arranque global, multimonitor físico
ni horas de uso. No se ha capturado audio personal para esta prueba. Clientes que
mezclan varias pestañas dentro de un único stream comparten el límite previo de
identificación; la ambigüedad entre streams distintos sigue dando silencio.

La implementación mata/recolecta hijos read-only con SIGKILL al cerrar, frente a
TERM con gracia de Python; no tienen estado persistente que guardar. Las líneas
superiores a4096bytes se descartan y la salida saturada conserva un frame parcial
y el último completo. Snapshots JSON tienen límite8MiB y timeout2s por consulta.
Se mantiene la complejidad adicional de un pequeño binario y sus dependencias
porque el ahorro de memoria activo está demostrado; no se amplía Rust sin medir
otro cuello de botella concreto.
