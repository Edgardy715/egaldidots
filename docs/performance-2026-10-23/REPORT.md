# Verificación pendiente · 2026-10-23

## Estado

El usuario pidió dejar el ensayo para uso normal, guardando logs sin mantener
al modelo trabajando dos horas. Se inició un **proceso local independiente**, sin
API de IA ni automatización que reactive este chat. El análisis posterior requiere
volver a pedirlo. No se considera verificada todavía una sesión de dos horas.

## Recolector

- Script: `bar/tests/session-soak.py`; PID objetivo 545318, colector 552155.
- Inicio UTC: 2026-10-23T04:38:50.132964+00:00; duración máxima7200s, intervalo30s.
- Datos vivos: `normal-use-01/samples.jsonl`; estado atómico `normal-use-01/status.json`.
- PSS/RSS desde smaps_rollup, CPU por diferencia utime+stime y reloj monotónico,
  VRAM por PID desde nvidia-smi pmon, playback y IdleHint orientativo.
- Sale si termina qs o cambia su starttime. No sigue otro PID automáticamente.
  Conserva logs de shell al inicio/final para revisar posibles recargas con el
  mismo PID. possible_reload es una señal orientativa por comparación de tails,
  no una certificación de ausencia de recargas si se desbordan los1000 mensajes.
- `idle_hint_advisory=no` no prueba presencia del usuario. Periodos sin uso no se
  presentarán como interacción activa ni se inferirá actividad sólo a partir de CPU.
- El muestreo es únicamente software local que duerme entre muestras. La
  [documentación de OpenAI sobre ejecución local](https://developers.openai.com/api/docs/guides/tools-local-shell)
  distingue la ejecución de comandos de las peticiones al modelo; este script no
  incluye clientes ni peticiones a un modelo. Leer/analizar después sí requiere
  una nueva intervención del asistente.

PASS self-test: parser de GPU soportada/no disponible, filtro PID, PSS real y
rechazo de starttime distinto. PASS integración de2s con3 muestras, JSONL, VRAM
real del PID y estado completed (`smoke/`). Registro largo confirmado running
con muestras reales antes de cerrar el turno. Los archivos vivos no se commitean
hasta completar/revisar; no se congela una muestra parcial como resultado final.

## Nuevo hallazgo nativo

`ldd /usr/bin/qs` muestra libjemalloc.so.2, y el binario declara «Use jemalloc: ON».
Versión instalada5.4.0. **malloc_stats/malloc_trim de glibc no miden/liberan el
asignador principal**. El intento GDB sobre copia temporal devolvió estadísticas
cero y trim0: se descarta esa vía, no se interpreta como ausencia de fuga. Se
interrumpió al identificar el asignador; se cerró la copia y se restauró la shell
normal. No queda un debugger unido al proceso normal.

Crudos del intento: `native-gdb.txt`, `native-memory.json`, `native-gpu.jsonl`.
La sonda posterior debe usar estadísticas jemalloc actualizadas (epoch y
allocated/active/resident/retained), contrastadas con smaps; la
[API oficial de jemalloc](https://jemalloc.net/jemalloc.3.html) describe esos controles.
No se añadió purga periódica ni se cambió la configuración del asignador.

## GPU y límites

NVIDIA GTX1660Ti, driver615.78.08. pmon sí informa VRAM del proceso qs; durante
la parte registrada del ensayo nativo se observaron 69–95MiB.
Los contadores SM para ese proceso aparecen como `-`: se guardan como null, nunca
como0. No hay una medición sustentada de carga GPU/energía atribuible a qs. La
utilización/potencia global incluye otras aplicaciones y no se usa como ahorro
atribuido a Isla.

La instancia existente al retomar llevaba673s, con PSS350284KiB; ese dato de
11min no se presenta como ensayo de horas (`existing-session.json`). PSS estable,
causa final de crecimiento y consumo GPU siguen pendientes del análisis adecuado.
El registro largo no abre paneles ni cambia canciones/configuración por sí mismo.
