# Correcciones de los hallazgos de Isla

2026-10-10–11. Continuación autorizada de la auditoría; los informes originales
describen el estado anterior. Se conservaron los cambios existentes del árbol.
Todos los IDs de la auditoría tienen corrección y evidencia de regresión.

## Interacción, cálculo y gate

| ID | Corrección | Evidencia |
|---|---|---|
| UI-01 | Parser de expresiones matemáticas sin `eval`, acceso a objetos ni llamadas QML/JavaScript. Límite de 512 caracteres. | `bar/tests/calculator.cjs`, [entrada real QtTest en Wayland](launcher-input.txt) |
| UI-02 | Nombres de funciones completos; asin/acos/atan, precedencia y funciones anidadas funcionan. | Mismos tests y [controller](neighbor-tests-initial.txt) |
| UI-03 | MotionArea, CtrlBtn y Toggle ejecutan acciones Accessible y respetan disabled/visible. Toggle emite su señal al propietario del estado. | [Interacción](interaction.txt), [Auth](neighbor-tests-initial.txt), [lock typing](neighbor-tests.txt) |
| UI-05 | Foco exclusivo mientras una superficie modal solicita teclado; cierre y fullscreen retiran la solicitud. | [Política](input-policy.txt), [wtype/Escape en las 14 rutas no Auth](native-input.txt) |
| QA-01 | Fixture usa un asset del repositorio o ISLA_TEST_AVATAR, sin ruta personal hardcoded. Gate incluye el parser. | [Gate](verify-config.txt), [fixture Wayland](neighbor-tests.txt) |

La entrada de launcher se escribió carácter a carácter con QtTest en su campo
real; `Qt.quit()` queda como texto y la búsqueda posterior funciona. Las acciones
Accessible se invocaron mediante QtTest; esto no certifica lector de pantalla
AT-SPI. Escape sí se entregó desde el compositor con wtype y se comprobó estado
de router y liberación de teclado tras cada cierre.

## Configuración

CFG-01 limita uiScale a 0.25–3, topGap/appGap a 0–4. CFG-02 conserva el borrador y
su base, detecta cambios externos del mismo campo y bloquea Enter/Guardar hasta
editar, restablecer o descartar. El test sustituyó el archivo temporal de forma
atómica, recibió la recarga FileView y probó resolución, save, discard y claves
desconocidas. [Resultados completos](config-fixes.md), [Wayland](config-wayland.txt)
y [aviso inspeccionado](config-draft-conflict-wayland.png).

Un documento con valores superiores a los nuevos máximos se rechaza completo;
los valores personales actuales validan. La captura corresponde a SettingsPage
en ventana Wayland de prueba con fondo opaco, no al Edots completo.

## Servicios y brillo

| ID | Corrección | Evidencia |
|---|---|---|
| SVC-01 | `nmcli device wifi connect` reemplaza la secuencia destructiva delete/add. Isla ya no elimina el perfil antes de intentar conectar. | [Fallo, éxito, argumentos exactos y callback único](services-regression.txt) |
| SVC-02 | Session.lock ejecuta el wrapper bajo XDG_DATA_HOME, con fallback HOME, mediante argv. | [Ambas rutas con wrapper temporal](services-regression.txt) |
| SVC-03 | Restauración conserva notificaciones vivas y combina el historial; escritura pendiente espera creación del directorio. | [Antes](services-notifs-before.txt), [merge y persistencia](services-notifs-after.txt), [mkdir retrasado](services-notifs-mkdir-check.txt) |
| SVC-04 | Wipe exitoso cancela previews, borra fuentes/errores y retira el directorio PNG; un fallo conserva entradas y previews. | [Éxito/fallo/decode lento, superficie aún viva](services-regression.txt), [regresión de portapapeles](clipboard.txt) |
| SVC-05 | Selección refleja lectura confirmada; set fallido muestra error y mantiene estado real. Refresco mientras abierto recoge cambios externos y recuperación de lectura. | [QtTest Wayland con servicio falso](services-power-wayland.txt), [captura de fallo](services-power-failed.png) |
| UI-04 | Slider de brillo participa en Tab, recibe flechas y acciones Accessible con semántica Slider y guardas enabled/visible. | [Tab/Shift-Tab, flechas, acciones y ausencia de escritura duplicada](services-brightness-check.txt) |

SVC-03 pasó de sospecha a reproducción controlada: una recarga FileView forzada
tras añadir una notificación viva perdía esa entrada antes del cambio. El test
posterior conserva y persiste `fresh,old`; no mide la frecuencia de la carrera
de arranque en D-Bus real. Otro test retrasa mkdir y comprueba que la notificación
se guarda una vez existe el directorio. Los procesos y el estado de todos estos
servicios fueron temporales; no se probaron credenciales ni hardware real.

La captura de perfil muestra Balanceado seleccionado y el error tras rechazar
Rendimiento. Es contenido grabado en ventana Wayland de prueba, no toda la pill.
La eliminación de previews significa retirada de archivos temporales, no borrado
forense del soporte ni limpieza del portapapeles de otras aplicaciones.

## Integración y límites

[Split/compact, interrupciones y 14 superficies](integration-neighbors.txt)
pasan en Wayland. [Launcher del bloqueo](lock-launcher.txt) pasa con ejecutables
falsos y comprueba instalación XDG, backup, guard de preview y fallback.
La revisión independiente de fuente y registros terminó sin hallazgos
accionables confirmados. `git diff --check` y el gate final pasan. La shell
personal cargó el árbol final y el IPC de configuración indica loaded sin error.
El 10 se compararon document/effective/dirty con la captura previa y coincidían;
el reinicio de sesión del 11 eliminó ese archivo de /tmp, por lo que no se repitió
esa comparación. Las pruebas de guardado siguen usando ISLA_CONFIG temporal.
El [linter Qt 6](qmllint-qt6.txt) termina con exit 0 y advertencias de metadata
Quickshell, acceso dinámico/no cualificado y animación existente; no es una
ejecución sin diagnósticos. El `qmllint` de /usr/bin pertenece a la sintaxis Qt 5
y devuelve 255 sin mensaje ante algunos de estos archivos Qt 6; se utilizó
/usr/lib/qt6/bin/qmllint para la validación final.

El primer grupo de comprobaciones terminó con error porque el coordinador
escribió un nombre de fixture inexistente: las tres fixtures anteriores pasaron;
se ejecutó después `lockscreen-typing-regression.qml` y pasó. La primera entrada
QtTest del launcher usó un carácter acentuado no admitido por keyClick; la
fixture ASCII pasó. Los logs iniciales se conservan y no se presentan como
defectos de producto ni como pruebas finales fallidas.

No se activaron acciones reales de red, energía, portapapeles personal, PAM ni
WlSessionLock. No se certifican multimonitor físico, AT-SPI/IME, arranque de sesión,
soak ni FPS/CPU/GPU continuo. Los tests aislados pueden advertir avatar .face
ausente o nombre D-Bus ocupado por la shell personal; no se observaron errores
de carga de estas regresiones.
No se comprobó la ausencia de los ejecutables de servicio. Notifs conserva la
protección existente: errores de lectura distintos de FileNotFound suspenden
persistencia durante esa sesión para no sobrescribir un archivo ilegible.
