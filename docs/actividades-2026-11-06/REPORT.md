ESTADO: **parcial** — implementación y pruebas aisladas terminadas. El sandbox impide escuchar sockets Unix (`EPERM`); quedan la comprobación nativa de Socket/IPC y la QA Wayland de Claude. Sin commit ni push. No se ejecutó `qs -d`, no se contactó la shell/socket del usuario y no se modificó ni consultó Hyprland real. Los comandos `hyprctl` del test de fish son ejecutables simulados en PATH temporal.

ARCHIVOS:

- Modelo/configuración: `bar/Singletons/Activities.qml`, `bar/Singletons/qmldir`, `bar/Singletons/Settings.js`.
- Fuentes: `bar/Singletons/Notifs.qml`, `bar/Singletons/SystemUpdates.qml` (sólo emisiones a Activities).
- Presentación/gestos: `bar/components/ActivityDropContent.qml`, `bar/components/FluidRecordingCompanion.qml`, `bar/components/ActivityView.qml`, `bar/components/PillPullGesture.qml`, `bar/windows/IslandOverlay.qml`.
- Inicialización: `bar/shell.qml`.
- Ajustes/idiomas: `bar/settings/EdotsWindow.qml`, `bar/settings/SettingsPage.qml`, `bar/settings/FishIntegration.qml`, `bar/i18n/en.js`.
- Cliente: `bar/scripts/isla-activity`, `bar/scripts/fish/isla.fish`.
- Pruebas: `bar/activities-regression.qml`, `bar/tests/activity-cli.py`, `bar/tests/activity-qml.py`, `bar/tests/activity-fish-button.py`, `bar/tests/activity-fish-button.qml`.
- Documentación: append en `bar/TESTING.md` y este `docs/actividades-2026-11-06/REPORT.md`.

No se editaron archivos fuera de la lista permitida. Se conservaron los cambios locales previos. El relevo de esta fase queda aquí: no se modificaron PROJECT_MEMORY.md ni TASK_STATE.md porque el encargo restringe las rutas.

CRITERIOS:

| Nº | Estado | Evidencia y límites |
| --- | --- | --- |
| 1 | probado / transporte bloqueado | Modelo real: start/update/end, JSON inválido, tipos, longitudes, ids especiales, progreso fuera de rango rechazado. 1000 eventos sin espera publican una vez; 1000 en 1 s publican como máximo 30/s más el vaciado final. El dibujo recibe snapshots, sin invalidaciones por cada entrada. El fixture incluye prueba del SocketServer con línea fragmentada, JSON inválido y recuperación de conexión; su bind está bloqueado aquí. No se midieron repintados físicos de Wayland. |
| 2 | probado | Python con socket simulado: start/update/end, run done/failed y código 7, duración, ausencia de campos null, pipe con ráfaga 1000/s y último porcentaje. Subproceso real sin shell conserva stdin/stdout/stderr y código 7; sólo avisa una vez. Intento AF_UNIX real: SKIP explícito por EPERM. Arranque completo start: mediana 34,60 ms, máximo 37,76 ms, 12 muestras. |
| 3 | probado / transporte bloqueado | Se invocan directamente los métodos tipados de IpcHandler activity y se verifica la misma validación/estado. El listener IPC propio de las instancias aisladas también falla en este sandbox; no se ejecutaron llamadas contra la shell real. |
| 4 | probado / visual no verificado | Prioridad fallo > progreso > indeterminada, contador/agrupación, ocho entradas y cesión. Se extiende la misma FluidRecordingCompanion izquierda; foco/grabación figuran además como filas con acceso a sus controles. Clic/gesto descendente seleccionan Procesos; auto resuelve media visible, actividad viva o utilidades. No se añadió otra gota. Composición final pendiente de QA Wayland. |
| 5 | probado / visual no verificado | Tiempo controlado verifica exactamente 6 s/10 s y un único Timer de expiración one-shot. Resultado success/error, check existente, muelle Motion.strokeSpring.lift impulsado y asentado con pasos manuales, ErrorShake y reducción de movimiento. Se conserva el motor de reabsorción existente, cubierto por las regresiones de companion. Acabado visible pendiente de Claude. |
| 6 | probado | QObject de notificación con señales reales de hints/body/closed: 12 → 42 → 100 mantiene una entrada, sin añadir popup y sin reiniciar la expiración al cambiar el cuerpo tras finalizar. SystemUpdates mapea evento real de fase 3/10 y resultado success; no se ejecutó ningún instalador. No se usó un emisor D-Bus externo. |
| 7 | probado | fish -n; hook productivo con PID de foco simulado, comando corto, foco propio, foco ajeno, éxito/fallo, enabled=false, umbral fraccionario y duración 1 m 12 s. Fallback de CLI probado cargando el hook mediante symlink. Botones productivos de Edots crean/quitan el enlace correcto en HOME temporal. No se instaló en HOME del usuario. |
| 8 | probado / fallos previos conservados | Validación de booleanos y rango 3–600; controles de actividades presentes y botón fish en español/inglés. Las 17 regresiones tienen exactamente los mismos exit codes y marcadores antes/después: 14 PASS y tres fallos previos detallados abajo. qmllint sin errores nuevos. |
| 9 | probado / documentado | Tras vaciar/desactivar: no publicación ni expiración pendientes; contenido sin arco/shake y gota sin motor activo. Revisión del código confirma ausencia de polling o reloj periódico en reposo. El reloj de duración sólo corre con la lista abierta y procesos vivos, y se prueba su parada al quitar el último. El listener permanece a la espera de eventos; desactivar Activities lo cierra. Coste de GPU/CPU real no medido. |

Decisiones de integración: el estado sin publicar vive separado de la lista que observa QML; un Timer de 34 ms agrupa también entre ids, límite más estricto que 30/s por id. Se conservan como máximo ocho entradas visibles, incluyendo recientes: primero cede una terminada y después la indeterminada más antigua; si ocho son determinadas en curso se rechaza la novena. La revisión independiente detectó aceptación de progreso inválido: se corrigió para aceptar exclusivamente -1 o 0..1 y se añadieron -7, -0.5, 1.1 y 5 al test.

PRUEBAS:

Entorno: Quickshell 0.3.2 de Arch Linux, Python 3.14.9, fish 4.9.3, Qt6 qmllint. Offscreen con plataforma de tema `basic` y controles `Basic`. Configuración inexistente, runtime y caché temporales por fixture; las pruebas nuevas aíslan también HOME, configuración y estado XDG y eliminan variables Wayland/Hyprland/D-Bus. Ningún resultado offscreen se presenta como QA visual.

| Comando | Resultado |
| --- | --- |
| `python -I bar/tests/activity-qml.py` | PASS: cuatro grupos del modelo/UI; BLOCKED explícito del SocketServer en runtime temporal. El runner detecta FAIL aunque el proceso termine con 0. |
| `python -I bar/tests/activity-cli.py` | PASS de CLI/fish; SKIP real AF_UNIX: `bind denied ([Errno 1] Operation not permitted)`. |
| `python -I bar/tests/activity-fish-button.py` | PASS: creación y retirada del symlink mediante botones reales en HOME temporal. |
| `fish -n bar/scripts/fish/isla.fish` | PASS. |
| Parseo AST de los cuatro archivos Python | PASS, sin crear cachés en el árbol. |
| `/usr/lib/qt6/bin/qmllint` sobre todos los QML tocados | exit 0. Activities, contenido, companion, ActivityView, FishIntegration y ambos fixtures nuevos sin diagnósticos. Los archivos existentes mantienen advertencias; la comparación de mensajes normalizados con la copia previa no añade clases de diagnóstico. |
| Regresiones previas y posteriores: 17 fixtures, entorno nuevo para cada uno | 14 PASS, tres fallos idénticos. Los dos summary.json son iguales. |
| `git diff --check` limitado a archivos de esta fase | PASS. |
| 12 subprocesos completos `bar/scripts/isla-activity start --id bench --title test`, socket ausente temporal | mediana 34,60 ms, máximo 37,76 ms. `--help`: mediana 34,45 ms, máximo 36,52 ms. |

Regresiones PASS antes y después: centered-companion, companion-continuity, drop-gesture, notification-attention, notification-drop, notification-priority, notification-routing, notifs-surface, pull-gesture, session-companion, settings-companion, updates-notice, water-decor, water-drop.

| Fallo previo | Antes y después |
| --- | --- |
| interaction-surfaces | exit 1, `FAIL: surface load Workspaces`. |
| settings-async | exit 255, `No PanelWindow backend loaded` en offscreen. |
| updates-service | exit 0 pero marcador `FAIL: Updates service ... compare`. |

Evidencia local de esta ejecución: `/tmp/actividades/before/summary.json`, `/tmp/actividades/after/summary.json`, sus logs por fixture, `/tmp/actividades/activities-final.log`, `/tmp/actividades/lint-final-new.log`, `/tmp/actividades/lint-before.log` y `/tmp/actividades/lint-after.log`. La copia de fuentes previa a editar está en `/tmp/actividades/source-before`. Son artefactos temporales; los comandos reproducibles y resultados estables quedan en este informe y en bar/TESTING.md.

El arranque inicial del CLI superaba el presupuesto (mediana 65,96 ms). Se sustituyó la construcción de argparse por getopt estándar y se difirieron imports exclusivos de run/pipe. Mantiene opciones con espacios, `--opción=valor`, el separador `--` y argumentos del hijo. Sin dependencias añadidas.

Reposo: Activities sólo despierta el publicador con entrada y arma el Timer de expiración para el vencimiento próximo; ambos son one-shot. Un único mkdir prepara el directorio al iniciar la shell; no hay procesos ni polling por actualización del servidor. El listener usa señales de Quickshell.Io. Sin actividad, ConfirmationIndicator tiene status vacío y no activa animación ni layer; el muelle de éxito y el motor compartido se asientan. La lista oculta no anima arcos. Con una indeterminada estable sólo anima por cuadro el arco existente. La duración visible usa un reloj de 1 s exclusivamente mientras la página Procesos está abierta y hay procesos en curso; se comprueba su activación y parada al cerrar, además del cálculo de duración. No corre en reposo ni alimenta la animación de la gota.

API y ejemplos (documentación; no se enviaron estos ejemplos a la shell del usuario):

```bash
bar/scripts/isla-activity start --id build --title 'cargo build' --icon build --progress -1
bar/scripts/isla-activity update --id build --progress 0.42 --subtitle '312/740'
bar/scripts/isla-activity end --id build --state done --subtitle '1 m 12 s'
bar/scripts/isla-activity run --title 'Compilar' --icon build -- cargo build
comando_que_imprime_porcentajes | bar/scripts/isla-activity pipe --id copia --title 'Copiando'
```

`run` hereda stdio, genera id salvo que se indique `--id`, devuelve el estado del comando y cierra done/failed con duración. Sin shell avisa una sola vez por stderr y ejecuta el comando igualmente. `pipe` crea la actividad, interpreta NN%, agrupa envíos y termina done al EOF; el EOF no permite deducir el código de salida del productor. Para representar ese resultado se usa run.

Socket: `$XDG_RUNTIME_DIR/isla/activity.sock`, flujo UTF-8 de objetos JSON separados por newline, sin respuesta. Un cliente puede mantener la conexión y enviar muchas líneas; no necesita procesos por mensaje:

```python
import json, os, socket
events = [
    {"op": "start", "id": "build", "title": "cargo build", "icon": "build", "progress": -1},
    {"op": "update", "id": "build", "progress": 0.42, "subtitle": "312/740"},
    {"op": "end", "id": "build", "state": "done", "subtitle": "1 m 12 s"},
]
with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
    client.connect(os.path.join(os.environ["XDG_RUNTIME_DIR"], "isla", "activity.sock"))
    for event in events:
        client.sendall((json.dumps(event) + "\n").encode("utf-8"))
```

Contrato: id de 1–96 caracteres ASCII `[a-zA-Z0-9_.:-]`; start requiere título no vacío. title se limita a 160 caracteres, subtitle a 320, icon/source a 96; se limpian controles. Se rechazan líneas JSON de más de 8192 unidades de string, objetos/tipos inválidos y progreso no finito o distinto de -1/0..1. Entradas inválidas no cierran la conexión. Campos desconocidos se ignoran. start del mismo id lo reinicia; update/end requieren un id en curso. end requiere state done o failed. startedAt/endedAt son milisegundos de época asignados por el modelo.

IPC: cada método recibe **un string JSON**, comparte dispatch con el socket y devuelve bool. No necesita op dentro del objeto. Sintaxis comprobada con la ayuda local del CLI, sin realizar estas llamadas:

```bash
qs ipc -p bar call activity start '{"id":"build","title":"cargo build","progress":-1}'
qs ipc -p bar call activity update '{"id":"build","progress":0.42}'
qs ipc -p bar call activity end '{"id":"build","state":"done"}'
```

Ajustes: `activities.enabled=true`, `activities.longCommandSeconds=10` (3–600), `activities.fromNotifications=true`, en Edots → Avanzado. El hook fish lee la configuración persistida (ISLA_CONFIG o el archivo XDG de Isla). Sólo consulta foco tras superar el umbral y compara el PID activo con fish y sus ancestros. Los botones son la única instalación/retirada; no reemplazan un archivo o enlace ajeno y el fallback resuelve el archivo canónico del repo incluso desde el symlink instalado. Requiere fish, python3, hyprctl y jq para esa integración.

DUDAS:

- Para Claude: ¿aprueba la composición Wayland del hover/título/subtítulo/contador, convivencia con grabación y foco, y continuidad de celebración/reabsorción con movimiento normal y reducido? Offscreen sólo acredita estados/geometría lógica.
- Para Claude: completar en un entorno con AF_UNIX permitido el tramo SocketServer del fixture y una llamada IPC a **una instancia aislada**, sin usar el socket del usuario. El bloqueo observado es `EPERM`, no un PASS del transporte.
