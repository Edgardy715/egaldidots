# Audio peak híbrido QML/Qt + Python/Rust · 2026-10-21

## Decisión

Integrado e instalado el reducer Rust sin dependencias. Sustituye únicamente el
recorrido de muestras finitas dentro de `PeakMeter.feed`, mediante ctypes en el
mismo proceso. QML/Qt, controlador Python, captura parec, rutas de audio,
fragmentos PCM, envelope y publicación JSON conservan sus responsabilidades.
No añade daemon, thread ni proceso. Se conserva el fallback Python.

Se promueve por una reducción clara de CPU del puente activo, aceptando un
pequeño coste PSS. No demuestra ahorro de memoria ni mejora de latencia.
La corrección adicional de lifetime elimina un huérfano real detectado durante
la integración; usa el guard Linux ya existente en el proyecto.

## Referencia y método

`baseline/bar/services/` conserva las fuentes anteriores al prototipo, incluidos
peak y bridge. `reference.json` fija hashes y entorno; `prototype/` conserva el
estado recibido antes de editar. Se verificó que audio_bridge coincidía con su
baseline. `comparison-pre-lifetime.json` guarda la primera comparación completa.
Después de corregir ownership se repitió toda la comparación: `comparison.json`
es la evidencia final, con complete/defaults_preserved=true.

El benchmark final crea dos copias iguales de servicios **con el guard final**;
sólo sustituye audio_meter.py por el baseline en una. Así se aísla el reducer
Rust. Comprueba `/proc/PID/maps` para evitar medir fallback como si fuese Rust.
Cuatro rondas por backend activo, 12 s cada ejecución, alternando Python→Rust y
Rust→Python; 1 s de calentamiento después del ataque. Dos rondas sin medidores,
3 s por ejecución tras calentamiento. Medianas entre ejecuciones; PSS usa primero
la mediana de muestras cada 250 ms. CPU es porcentaje de **un núcleo** Linux.

Carga: tono estéreo en contrafase a 1 kHz, 48 kHz float32LE, amplitud 0,2,
productor en bloques de 10 ms; captura simultánea del stream privado y su monitor.
Un null sink exclusivo evita reproducción audible. No se mueve audio personal,
ni se pide micrófono/monitor personal ni se cambian defaults o volúmenes.
El bridge consulta el inventario existente, pero no se conserva metadata personal
en los resultados. Elimina su productor/módulo y comprueba defaults originales.
CPU/PSS incluye bridge, suscripción y ambos parec; excluye servidor compartido,
productor sintético y harness, comunes a las variantes.

## Resultados finales

| Dos medidores activos | Python | Rust |
| --- | ---: | ---: |
| CPU mediana (% de un núcleo) | 3.366 | 1.249 |
| CPU rango observado (%) | 3.079–3.496 | 1.248–1.331 |
| PSS mediana del árbol (KiB) | 13257.0 | 13354.5 |
| Procesos | 4 | 4 |
| Ataque mediano / máximo (ms) | 59.9 / 65.1 | 62.1 / 63.9 |
| Release mediano / máximo (ms) | 522.1 / 538.7 | 541.7 / 547.9 |
| Publicaciones por segundo | 29.31 | 29.26 |
| P95 intervalo publicaciones (ms) | 35.02 | 35.04 |

La caída CPU es 2.12 puntos de un núcleo (~63% del
árbol en este escenario), con reducción en las cuatro parejas. Los rangos no se
solapan. No se extrapola ese porcentaje a la shell completa ni a batería.
PSS aumenta unos 97.5 KiB: se acepta por el ahorro CPU, sin afirmar ahorro RAM.
Sin medidores hay dos procesos en ambos casos, CPU por debajo de resolución del
contador durante 3 s y PSS 11656,5→11730,0 KiB, con variación entre ejecuciones.
Eso no prueba coste CPU nulo ni reducción en reposo global.

Ataque y release pasan los límites anteriores de 200/900 ms, señal sostenida sin
falsos ceros. Las diferencias pequeñas de latencia/publicación no establecen una
mejora; la mediana de release fue algo mayor con Rust. El algoritmo de envelope
es exactamente el mismo por paridad de fixtures. Esto no mide FPS de pantalla.

Microbenchmark separado: feed completo, incluidos conversión/copia de array,
fragmentos y FFI; 4 rondas alternadas, 2000 llamadas por variante/tamaño.

| Muestras por llamada | Python (µs) | Rust (µs) |
| --- | ---: | ---: |
| 0 | 0.649 | 0.931 |
| 16 | 2.014 | 1.030 |
| 960 | 71.897 | 3.037 |
| 1920 | 143.578 | 4.929 |
| 8192 | 638.825 | 23.867 |

La llamada vacía empeora ligeramente por FFI; no es carga de audio y EOF no llama
feed. Se conserva el código mínimo en lugar de añadir otra rama sin utilidad
medida. Estos tiempos no son latencia acústica ni de interfaz. Los primeros
ensayos preliminares variaron con carga/frecuencia CPU; se usan los datos finales
alternados, no el mejor tiempo seleccionado.

## FFI, comportamiento y fallback

ABI `isla_peak_f32_v1(*const f32, usize) -> f32`. El loader declara tamaños/tipos;
array('f') propio, convertido desde float32LE, permanece vivo durante la llamada
síncrona. Liberar el GIL no permite que otro hilo acceda al array local. Los
fragmentos incompletos siguen en Python y el byteswap previo se conserva.

Rust ignora NaN e infinitos, conserva máximos finitos y subnormales y devuelve
cero si no hay muestras finitas. Antes de formar el slice rechaza nulo,
desalineación y longitud excesiva. Estas guardas **no validan cualquier dirección
arbitraria**: el contrato unsafe exige una única asignación legible de `length`
floats inicializados e inmutables; el único caller de producto suministra su
array propio. Sin callbacks, referencias retenidas ni ownership transferido.

Biblioteca ausente, corrupta/incompatible con dlopen o sin símbolo v1 usa Python.
No promete recuperar una corrupción de memoria ni una biblioteca que mienta
sobre su ABI. Se instala sólo el release validado; no hay rutas arbitrarias de
plugins ni nueva opción de configuración.

## Corrección de procesos descubierta durante integración

La prueba QML cerraba/reabría AudioController y después salía. Antes del arreglo,
pactl subscribe persistía tras morir el bridge, incluso con fallback Python y
tras 3 s de espera: `lifecycle-before.json`, `validation/qml-lifetime-red.txt`.
Se identificaron/limpiaron sólo los huérfanos de las fixtures por su XDG temporal.
El test fake contra el bridge original también falla al matar al dueño:
`validation/lifetime-baseline-red.txt`.

Se extrajo sin cambiar el algoritmo `die_with_parent` de cava_stream.py a
process_lifetime.py, conservando el import público desde CAVA y usándolo también
en Nmcli. No importa el módulo CAVA completo para armar un guard de procesos.
Los tres lanzamientos del bridge capturan su PID antes del fork y arman
PR_SET_PDEATHSIG/SIGKILL antes de exec, seguido de comprobación del padre para
cerrar la carrera. Los launchers son de un solo hilo; no usar este patrón sin
revisar el diseño si se introducen hilos. EOF/TERM mantienen cleanup y reap.
No cambia argv, protocolo, rutas, controles ni persistencia.

Después: QML real native/fallback pasa snapshot, medidor privado, cierre y
reapertura, `/proc/maps` y ausencia de hijos vivos al finalizar. Es integración
offscreen, no QA visual ni captura personal. Se permite hasta 3 s de cleanup;
SIGKILL puede dejar zombies a cargo del init, pero no procesos ejecutándose.

## Build, instalación y rollback

`scripts/build-audio-peak.sh` usa cargo disponible o el toolchain local existente,
release --locked y cache fuera del repo. No descarga toolchains ni añade paquetes.
El instalador intenta ambos helpers Rust si hay cargo; el fallo no elimina un
release previo. El script copia con modo 0644 a un temporal del directorio de
destino y publica por rename atómico. Build/copia fallidos conservan la biblioteca
anterior; señales retiran el temporal. Cargo no es dependencia de runtime.

Destino: `${XDG_DATA_HOME:-$HOME/.local/share}/isla/lib/libisla_audio_peak.so`.
El binario instalado coincide byte a byte con el medido, incluso tras recompilar
el fuente formateado. Hash/tamaño en measured-library.json y activation.json.
No se reinició la shell personal: los bridges nuevos cargan el release, los ya
abiertos conservan su backend hasta cerrar/reabrir. No había bridges activos al
comprobar la activación final; el controlador sí se ejercitó en la fixture QML.

Rollback reversible: mover la biblioteca a otro nombre y cerrar/reabrir el panel
de audio; el siguiente bridge usa Python. El guard de procesos sigue siendo útil
con cualquiera de los backends. No retirar process_lifetime.py mientras sus
callers lo importen. No se ejecutó el instalador completo sobre la sesión personal.

## Aceptación y reproducción

| Requisito | Evidencia | Estado |
| --- | --- | --- |
| Núcleo Rust y guardas FFI | 2 unit tests, clippy all-targets -Dwarnings, fmt | PASS |
| Paridad + fragments/NaN/Inf/fallback | audio-peak.py, 3 tests, baseline/native/fallback | PASS |
| Beneficio real y equivalente | comparison.json, 4 parejas activas + 2 sin medidores | PASS CPU; coste PSS explícito |
| Build locked y publicación atómica | audio-peak-install.py; fallos de build/copia y XDG con espacios | PASS |
| Ownership y cancelación | audio-lifetime.py, 5 modos, contraste rojo con original | PASS |
| Integración instalada | hash idéntico, loader por defecto y QML con .so instalada en XDG privado | PASS |
| Callers compartidos | audio-backend 8, CAVA Python 7, Nmcli quit/TERM/reload/race | PASS |
| Instalador | scripts/test-install.py, 15; sintaxis y diff check | PASS |
| Revisión independiente | Sol/medium FFI, build, método y lifetime; review.txt | Sin defectos sustentados |

```sh
sh scripts/build-audio-peak.sh
# cargo test --locked; cargo clippy --locked --all-targets -- -D warnings
# Los comandos cargo anteriores se ejecutan en rust/audio-peak.
python bar/tests/audio-peak.py --library "$HOME/.local/share/isla/lib/libisla_audio_peak.so"
python bar/tests/audio-peak-install.py
python bar/tests/audio-peak-qml.py --library "$HOME/.local/share/isla/lib/libisla_audio_peak.so"
python bar/tests/audio-lifetime.py
python bar/tests/audio-backend.py
python bar/tests/cava-stream.py
python bar/tests/nmcli-lifetime.py
python bar/tests/audio-peak-performance.py --library "$HOME/.local/share/isla/lib/libisla_audio_peak.so" --seconds 12 --rounds 4 --output /tmp/audio-peak.json
python scripts/test-install.py
```

Entorno: Python3.14.8, Rust1.99.1, Linux7.2.9/CachyOS x86_64,
i7-10750H; detalles en reference.json y rust-toolchain.txt. Fuentes finales y
hashes en sources.json; source-final.tar.gz conserva los archivos necesarios
para la comparación y fixtures, además del baseline del reducer. Logs en validation/.
La revisión independiente no repitió el benchmark real ni certifica toda la shell.

## Límites y pendientes

No se ha medido batería, GPU, FPS físicos, arranque global, hardware/multimonitor
ni varias horas de uso. No hay mejora RAM demostrada; la biblioteca añade un coste
pequeño. Latencia no mejora de forma concluyente. La reducción CPU corresponde a
dos medidores activos y a este entorno; falta cuantificar su peso en el uso diario.

SIGKILL de un bridge termina sus hijos; matar QS mientras el bridge está ocupado
en una consulta sigue dependiendo del cierre de stdin/terminación gestionada por
QS y del timeout existente de 8 s. No se añade supervisión general de procesos.
Las pruebas cubren cancelación del bridge y salida normal del controlador; no
certifican todos los puntos posibles de SIGKILL de QS.

Siguiente trabajo requiere otro perfil que demuestre un cuello de botella.
No se ha elegido otra migración Rust ni se ha alterado diseño/configuración para
fabricar una mejora. Conservados los cambios ajenos, sin commits ni publicaciones.
