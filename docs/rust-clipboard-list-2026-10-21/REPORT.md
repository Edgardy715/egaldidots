# Lectura Rust de biblioteca del portapapeles · 2026-10-21

## Decisión y alcance

Integrado e instalado `isla-clipboard-list` sólo para listar guardados. QML/Qt
conserva el modelo y la presentación; Python conserva save/remove/create/rename/
delete/move/copy/preview/wipe y toda la persistencia. No se accedió al historial
ni biblioteca personales en las pruebas, ni se añadió watcher/daemon/proceso
residente. El launcher hace exec: no queda un shell supervisor.

La referencia Python tarda decenas de ms incluso con biblioteca vacía; se midió
antes de implementar. El helper reduce startup, parsing y validación del lector,
sin cambiar el formato ni quitar comprobaciones. La ganancia llega a la
publicación de datos QML. No demuestra menor latencia de toda la shell.

## Método y resultados válidos

`baseline/` y baseline.json se congelaron antes de cambiar código; Python10
muestras iniciales0/100/1000entradas:62,06/65,39/85,77ms. El original de
clipboard_library.py sigue byte a byte igual. Se compara con el binario release
final e idéntico al instalado, sobre bibliotecas sintéticas privadas.

CLI:20 ejecuciones por backend/tamaño, orden Python→Rust / Rust→Python alternado,
una ejecución de calentamiento por variante/tamaño. Tiempo incluye lanzamiento,
lectura/validación completa, serialización, consumo/parse de stdout por el
harness. CPU por request de wait4 (user+system), sin proceso adicional de servicio.
El stdout CLI usa un archivo temporal regular para evitar bloquear wait4 por
backpressure. QML usa el Process real y su pipe, por separado.

QML:2 sesiones por backend/tamaño, orden ABBA,10lecturas por sesión; ClipboardController
real usa baseline o launcher nativo, con biblioteca temporal y sección guardados.
Reloj desde loadLibrary hasta Qt.callLater tras finalizar el callback, comprobando
savedEntries completo y sin error. Excluye arranque de Quickshell; no mide primer
pixel ni animación/presentación física. Es integración offscreen, sin cambios
visuales de producto. Date.now se almacena en double y se validan rangos.

| Entradas | CLI Python / Rust (ms) | CPU Python / Rust por request (ms) | Datos QML Python / Rust (ms) |
| --- | ---: | ---: | ---: |
| 0 | 61.17 / 0.94 | 59.87 / 0.76 | 39.0 / 3.0 |
| 100 | 41.24 / 1.26 | 40.23 / 0.95 | 55.5 / 6.0 |
| 1000 | 95.01 / 10.94 | 90.05 / 7.56 | 65.5 / 14.0 |

Son medianas. En1000entradas el rango QML fue62–73ms Python y13–15ms Rust:
mejora clara de disponibilidad de datos en esa fixture. CLI y QML son series
distintas y varían con carga/frecuencia/cachés; no se usa la mejor muestra ni se
atribuye todo el tiempo del panel al helper. Son20lecturas/tamaño/backend en cada
método. Los arrays, texto completo y filtrado JS siguen en QML.

Memoria se muestrea en ejecuciones separadas (4por backend/tamaño), cada~0,5ms,
filtrando imagen anterior al exec mediante stack/exe en /proc. Con1000entradas,
mediana del máximo **observado** PSS11216→2654KiB; VmHWM observado21652→4696KiB.
Son procesos efímeros: el muestreo puede perder el pico real y perturba duración.
Las bibliotecas pequeñas Rust sólo dieron1–2muestras; no se cuantifica ahorro
PSS para ellas. Tampoco se afirma reducción de memoria residente de la shell:
el QML sigue reteniendo los mismos datos y el helper desaparece al terminar.

La primera corrida tenía overflow por reloj QML int32 y ru_maxrss heredaba la
imagen grande del harness Python. Se marcó explícitamente como evidencia inválida
(`comparison-instrumentation-invalid.json`, valid_evidence=false), se corrigió el
instrumento y se repitió toda la comparación. Un intento intermedio de usar
/usr/bin/time falló porque no estaba instalado; no se añadieron paquetes.
Sólo `comparison.json` valid_evidence/complete=true y summary.json sustentan esta
decisión. Medidas previas no se reutilizan como mejora concluida.

## Contratos, privacidad y compatibilidad

Rust mantiene rutas absolutas, override ISLA_CLIPBOARD_LIBRARY y defaults XDG/HOME;
directorio0700, metadata/lock0600, rechazo de symlinks, IDs/digest validados,
duplicados/referencias de colecciones rechazados y todos los campos obligatorios.
Cada snapshot debe existir y ser fichero regular, no enlace: no lee su payload.
Conserva arrays/orden y campos desconocidos. El archivo metadata y snapshots no
se reescriben; sólo se reparan permisos como en Python. Flock exclusivo es el
mismo de fcntl.flock Python; no se lee en medio de save/remove/rename.

No interpreta por su cuenta JSON que serde no pueda preservar. NaN/Infinity,
profundidad o parse incompatible, claves escapadas y la clave reservada interna
de serde arbitrary_precision ejecutan Python tras liberar lock/descriptores.
Los enteros grandes estándar se conservan mediante arbitrary_precision; valores
Unicode escapados normales siguen nativos. Es una compatibilidad conservadora:
los formatos raros pueden seguir pagando el coste Python. Errores de IO o
validación no activan otro intento. No se imprime stdout parcial antes de exec.
La ruta fallback la pasa el launcher de fuente, no los metadatos.

TERM durante flock termina sin hijos. BrokenPipe devuelve fallo sin panic/core
ni stderr con datos. El helper no crea procesos, excepto reemplazarse por Python
con exec en compatibilidad; ese reader list tampoco crea subprocesos. El renderer
sigue recibiendo el mismo protocolo {ok,data}/{ok:false,error}; el texto exacto
de errores de sistema no es idéntico, y el controlador muestra su error genérico
anterior. Las escrituras y fsync/transacciones Python se conservaron.

## Build, instalación y rollback

Crate con serde_json y nix(fs), ya presentes/cacheados por CAVA; no nuevos
paquetes del sistema ni daemon. Cargo.lock, release optimizado, cache fuera del
repo y cargo opcional. `scripts/build-clipboard-list.sh` copia a temporal en el
mismo directorio y publica por rename atómico con modo0755; fallo build/copia
conserva el ejecutable previo. install.sh lo intenta junto a helpers opcionales.

Destino XDG_DATA_HOME/isla/bin/isla-clipboard-list, aquí
~/.local/share/isla/bin/isla-clipboard-list;412376bytes, SHA256
abf7420a81e0e9c78b372f2d10897b425166142747aabe1857e81f51eb2b79fb.
Coincide con el release medido. No se reinició la shell personal: el controlador
actualizado lo toma al recargarse; cualquier petición posterior del launcher ya
elige el binario instalado. Se verificó producto fuente mediante fixture QML.
Rollback reversible: mover ese ejecutable a otro nombre; el siguiente list usa
Python. El dato personal no requiere migración ni restauración.

## Validación y reproducción

- Rust8unit, clippy all-targets -Dwarnings, release offline/locked PASS según
  implementador; no conservó logs persistentes. Comandos/version en
  validation/rust-checks.txt; coordinador ejecutó fmt--check y verificó hash.
- CLI7tests: válidos/vacíos/Unicode/números grandes/unknown, rechazos, snapshots,
  permisos/symlinks, interop bloqueo Python, TERM sin hijos, compatibilidad exec
  y mismoPID, argumentos y BrokenPipe PASS contra binario instalado.
- Launcher: exec mismoPID/argv, rutas espacios/metacaracteres, backend ausente,
  build/copy fallidos y reemplazo atómico PASS con fakes.
- Regresión QML completa con fallback y después con nativo instalado: save,
  colecciones, filtros, wipe, reapertura, preview y copia exacta de texto/imagen
  PASS, usando cliphist/wl-copy fake y biblioteca temporal. Python library9 PASS.
- Gate configuración/boundaries/calculadora, instalador15, sintaxis/diffcheck PASS.
- Revisión independiente Sol/medium sin defectos sustentados; comprobó además
  claves raras, archivo intacto y stdout cerrado. No repitió benchmarks/QML.

```sh
sh scripts/build-clipboard-list.sh
# En rust/clipboard-list: cargo test --offline --locked
# cargo clippy --offline --locked --all-targets -- -D warnings
python bar/tests/clipboard-list.py --binary "$HOME/.local/share/isla/bin/isla-clipboard-list"
python bar/tests/clipboard-list-backend.py
python bar/tests/clipboard-library.py
bash bar/tests/clipboard-library-regression.sh
python bar/tests/clipboard-list-performance.py --binary "$HOME/.local/share/isla/bin/isla-clipboard-list" --output /tmp/clipboard-comparison.json
sh bar/tests/verify-config.sh
python scripts/test-install.py
```

Fuentes finales+hashes en sources.json/source-final.tar.gz; referencia en
baseline/ y entorno en environment.json. source-final contiene lo modificado y
las fixtures; para QML requiere el resto del checkout y sus componentes Qt.
No se ejecutó el instalador completo sobre el equipo real ni commits/publicación.

## Límites y siguientes candidatos

No medidos: batería, FPS físicos, arranque global, horas de uso, primer pixel ni
latencia completa del panel con animación. Fixtures0/100/1000 de texto corto no
cubren todas las bibliotecas personales o documentos muy grandes; la conversión
y retención QML aún cuestan lo mismo. Fallback mantiene los formatos raros sin
una promesa de acelerarlos. No se elimina la serialización del lock con writes.

La investigación acotada de paleta/fuzzy encontró decodificación/HTTP fuera de UI
y búsqueda opcional sin evidencia de bloqueo; no se migraron por lenguaje.
Otro cambio Rust exige perfil de ese recorrido, conservando Qt y servicios donde
ya funcionan. Esta fase cierra una mejora de latencia del portapapeles, no una
reescritura general ni una afirmación de latencia global.
