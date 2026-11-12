# Línea base W0/W1 · 2026-10-31 (Wayland real, GPU NVIDIA)

Método: `qs -c bar --no-duplicate` reiniciado con `appearance.waterBody` false y luego true
en `~/.config/isla/shell.json` (respaldo previo: `shell.json.pre-water.bak`). Lectura de GPU
con `nvidia-smi` (10 muestras de 1 s) y PSS desde `/proc/<pid>/smaps_rollup`.

| Medida | waterBody=false | waterBody=true |
|---|---|---|
| GPU total, reposo (media 10 s) | ~27 % | ~26 % |
| PSS, reposo (tras 10 s) | 343 MB | 345 MB |

Limitaciones (no verificado):
- La GPU total incluye el escritorio y la app de Claude (ruido de ±8 puntos entre muestras).
- `nvidia-smi pmon` no da uso por proceso en este driver (columnas vacías), así que no hay
  GPU atribuida a `qs`.
- Lanzador abierto, morph y tiempo de fotogramas: no medidos en esta pasada.
- PSS de 403 MB en la primera muestra con water on era calentamiento; a los 10 s coincide con off.

Capturas: `off-rest-pill.png` y `on-rest-pill.png` (zona 120×44 px del reposo): idénticas a
ojo; `on-rest-full.png` muestra la pantalla con water on.
