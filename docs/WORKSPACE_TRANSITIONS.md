# Overview manual de workspaces

Esta es una integración opcional de la sesión local con Hyprland Lua. El
instalador del repositorio no descarga el plugin ni instala los módulos Lua
externos descritos abajo; la configuración base conserva el overview de Isla.

El diseño vigente usa ScrollOverview **stock** sólo al pedirlo: `Super+Tab`
abre/cierra el overview del plugin; `Super+Shift+Tab` abre/cierra el overview de
Isla. `Super+rueda` y los binds numéricos conservan los dispatchers nativos de
Hyprland. No hay transición automática al cambiar workspace.

## Archivos y arranque

- `~/.local/share/isla/scrolloverview/source-stock` contiene el árbol limpio
  de upstream `yayuuu/hyprland-scroll-overview`, commit
  `7ff22457dc016239eff1b19c3ea57de93404b5c9`.
- `~/.local/share/isla/scrolloverview/scrolloverview.so` es el build stock
  contra Hyprland 0.56.2 (`efb50993780079460b0cbed1363e2166a2de1d9f`).
  SHA-256: `27038217c977f3e3951bde95ade667bd85af4915ae49f7d1224df8f0fba527c2`.
- `~/.config/hypr/modules/workspace_motion.lua` registra el evento de inicio,
  aplica `scale=0.48`, `layout=vertical`, `blur=false` cuando el plugin existe y
  reúne las llamadas a la API stock para navegación y selección.
- `scripts/scrolloverview-load.sh` ejecuta `hyprctl plugin load` en un proceso
  hijo después del arranque. Comprueba la instancia, el archivo y si ya está
  cargado; usa un lock por instancia y un timeout. La configuración Lua nunca
  llama `hl.plugin.load` para ScrollOverview durante su evaluación.
- `scripts/scrolloverview-toggle.sh` cierra cualquier surface de Isla antes
  de abrir Niri; si falta el plugin, alterna el overview de Isla.
  `scripts/scrolloverview-isla.sh` cierra Niri antes de alternar Isla.
  Ambos binds funcionan dentro del submap `scrolloverview`. Ese submap añade
  Escape, Return, flechas y clic izquierdo; sólo está activo con Niri abierto.

Para reconstruir tras actualizar Hyprland o sus headers:

```sh
cmake -S ~/.local/share/isla/scrolloverview/source-stock -B /tmp/isla-scrolloverview-manual-build -DCMAKE_BUILD_TYPE=Release
cmake --build /tmp/isla-scrolloverview-manual-build -j2
install -m 755 /tmp/isla-scrolloverview-manual-build/libscrolloverview.so ~/.local/share/isla/scrolloverview/scrolloverview.so.new
mv -f ~/.local/share/isla/scrolloverview/scrolloverview.so.new ~/.local/share/isla/scrolloverview/scrolloverview.so
```

Reemplazar el archivo con `mv` es atómico; nunca escribir directamente sobre
un `.so` cargado. Verificar la compatibilidad ABI con la nueva versión de
Hyprland antes de cargar el build actualizado en una sesión principal; la
copia nueva se usará en el siguiente arranque.

El experimento anterior de transición automática se conserva sólo como archivo local y no se carga.

## Incidente anterior y alcance de la prueba

La instalación anterior congeló la sesión al cargar una variante modificada
del plugin después de descargarla. El módulo de entonces intentaba cargar el
plugin al evaluar la configuración; el código upstream llama
`HyprlandAPI::reloadConfig()` tanto al registrar su configuración como al
descargarse. La reentrada de configuración es una causa plausible, pero no se
obtuvo traza del compositor congelado que la demuestre. El build stock y la
carga externa eliminan esa ruta concreta y también retiran todo el código de
transición automática.

Se probó en un Hyprland 0.56.2 anidado con hyprglass 0.10.0 desactivado:
carga al inicio, overview con dos Kitty, overview en workspace vacío, cierre,
`hyprctl reload`, descarga y recarga mediante el script. Cada IPC respondió;
`hyprctl configerrors` quedó vacío y `plugin:scrolloverview:scale` devolvió
`0.480000`. Capturas: `~/.local/state/isla-motion/2026-10-13/scrolloverview-manual/`.
Se verificó el registro de los binds y la activación automática del submap;
Escape y Return enviados al anidado con `wtype` cerraron Niri y restauraron
el submap por defecto. `wtype` no activó la combinación virtual Super+Tab;
los scripts de ambas rutas se probaron en el anidado con un `qs` falso para no
afectar la sesión principal. También pasaron `luac -p`, el test Lua, el test
aislado del loader y `bash -n`. Nada de esta prueba carga el plugin en la
sesión principal.

## Recuperación

Si el plugin no carga, `Super+Tab` abre el overview de Isla. Para desactivar la
carga en un arranque siguiente, renombrar `scrolloverview.so` a
`scrolloverview.disabled.so`; el loader no encontrará el archivo y el bind
mantendrá el fallback a Isla. Esto no descarga un plugin ya activo. No
descargar un plugin abierto ni repetir cargas
si una solicitud IPC agota el tiempo: primero comprobar que el compositor
responde y revisar su log.

## Validación posterior en la sesión principal

El build stock se cargó una sola vez mediante el loader externo. Niri→Isla→Niri, seis ciclos de apertura/cierre, ocho toggles rápidos, navegación y Escape/Return pasaron sin congelamiento; ventanas y workspaces conservaron su asignación. Configerrors vacío, submap final default y ambos plugins responden. Evidencia: ~/.local/state/isla-motion/2026-10-13/scrolloverview-manual/host/.

La revisión independiente detectó que seleccionar manteniendo Super requería ignorar modificadores: el bind mouse:272 ahora usa ignore_mods=true, opción documentada y aceptada por la recarga sin errores. El código stock respeta ignoreMods. La salida JSON de binds no expone ese campo. El registro confirma Super+Tab (64), Super+Shift+Tab (65) y submap_universal; la inyección virtual de Super+Tab no activó el atajo, por lo que no certifica la pulsación física ni el clic físico con Super sostenida.

Los tests Lua y del loader/rutas pasaron tras integrar: output-a8w871u_.log y output-r7zsyyoq.log. Ante fallo IPC del plugin no se abre otra vista; sólo su ausencia permite fallback a Isla. No se descargó ni recargó el plugin activo.
