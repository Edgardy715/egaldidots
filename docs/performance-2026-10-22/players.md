# P4 · Players.active

2026-10-22. Corrección síncrona; no se reinició la shell ni se modificó reproducción real.

## Causa y cambio

`onActiveChanged` consultaba `root.playing`, un binding derivado de `active` que
todavía puede contener el estado del reproductor anterior durante esa señal.
Si el anterior reproducía y el nuevo está pausado, el handler lo guardaba como
`recent` de forma incorrecta. Al retirar el activo y quedar un player pausado,
`active` ya había leído `recent` para elegir el fallback: escribirlo durante su
evaluación provocaba el loop `active → onActiveChanged → recent → active`.

El handler ahora comprueba `root.active && root.active.isPlaying` directamente.
No difiere trabajo ni cambia el algoritmo de selección. Sólo escribe `recent`
si el nuevo activo reproduce, una rama que no depende de `recent`. Se conserva
manual vivo > reproduciendo > reciente > primero, y el handler de `playing`
conserva la recencia cuando el mismo player pasa de pausa a reproducción.
La búsqueda de consumidores no encontró escritores externos de manual/recent;
MediaSurface invoca `cycleManual`, el resto consume Players.

## Evidencia reproducible

Base: `fad458135e8ebd0ae31de5ec9ea051bfcc238ad1:bar/Singletons/Players.qml`, sin cambios
locales previos; SHA256 `3eb93a69342f2d8ca14ce886f76a5549f3a070a7b23d2963cd1d9a794d99472e`.
Copia de trabajo y logs: `/tmp/isla-players-p4-before/{Players.qml,baseline.log,fixed.log,session.log}`.

`bar/tests/players.py` carga el archivo Players real en Quickshell 0.3.2, con
MPRIS sintético, sin conexión al MPRIS real y con plataforma offscreen. Incluye
bindings consumidores y lectura reentrante al recibir `activeChanged`.

```sh
git show fad458135e8ebd0ae31de5ec9ea051bfcc238ad1:bar/Singletons/Players.qml > /tmp/Players-p4-before.qml
python bar/tests/players.py --source /tmp/Players-p4-before.qml
python bar/tests/players.py
git diff --check -- bar/Singletons/Players.qml bar/tests/players.py
```

La base termina con código 1: falla la recencia al seleccionar manualmente un
player pausado y al reemplazar un activo reproduciendo por uno pausado. Este
último escenario emite dos veces el síntoma exacto:

```text
Binding loop detected for property "active":
qs:@/qs/Singletons/Players.qml:32:5
```

La versión corregida termina con código 0 y `PASS: Players priority, recency,
filtering, cycling and removal`, sin binding loops. Cubre también lista vacía,
proxy playerctld, pausado manual frente a otro reproduciendo, cambio de recencia,
ciclo positivo/negativo, retirada manual, estado Stopped y retirada de todos.
`git diff --check` pasa.

## Límites

El test deja un aviso de conversión undefined→bool en `has` durante el teardown
de objetos sintéticos; también ocurre en la base. No se modificó ese contrato.
La lectura de los últimos 500 mensajes de la instancia real no mostró el loop;
la reproducción demostrada procede del test aislado. El coordinador valida la
integración en la sesión real y mide CPU; aquí no se atribuye ahorro medido.
