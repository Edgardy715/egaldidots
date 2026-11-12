# Latencia al cambiar apartados de Edots · 2026-10-22

## Resultado

Corregido trabajo oculto al crear filas: SettingRow sólo instancia el editor
aplicable (Switch, choices, slider o texto), y sólo crea Personalizado/Restablecer
si hay una modificación. Font picker sigue bajo su Loader previo. Se conservan
estilos, animaciones, etiquetas accesibles, señales, borradores y persistencia.
El foco vuelve al editor al restablecer, incluso al destruir el botón enfocado.

No se añadió Rust: la medición del recorrido real mostró cero llamadas a
snapshot/validate al navegar. El cuello está en crear controles Qt en UI; mover
configuración a Rust no elimina ese trabajo y añadiría una frontera innecesaria.
Las implementaciones Rust ya integradas en otras fases se mantienen.

## Reproducción y referencias

Baseline en baseline/ con SHA256 en baseline.json, antes de editar. La primera
regresión Wayland reprodujo Apariencia38/76ms (driver de animación, no FPS físicos).
SettingRow creaba Switch/Slider/TextField aunque sus padres no se mostrasen.
Prueba roja persistente: `settings-navigation-performance.py --baseline-lazy-check`;
con la versión antigua captura LAZY_EDITOR_FAIL en slider oculto de
mediaTransitions. Son nombres de objeto de prueba, sin cambiar la apariencia.
La versión nueva exige ausencia de editores no aplicables durante toda la navegación.

Tres hipótesis: creación de filas/editores, copias/validación, fuentes/animación.
Se perfilaron las funciones por separado y se instrumentaron únicamente copias
privadas de Config durante navegación. Modelo de fuentes ya era lazy; no se
acortaron duraciones de transición ni se eliminó animación visible para medir.

## Comparación final Wayland

Dos parejas aisladas en orden antes→después / después→antes; cada proceso hace
dos ciclos de seis destinos con la misma configuración temporal. Cuatro máximos
por apartado/backend. FrameAnimation registra intervalos del driver durante cada
transición, después de calentar el editor. Configuración personal nunca guardada.

| Apartado | Mediana del máximo por transición antes / después (ms) | Máximo observado antes / después (ms) |
| --- | ---: | ---: |
| Apariencia | 62.5 / 21.0 | 70 / 23 |
| Composición | 11.0 / 13.5 | 12 / 16 |
| Movimiento | 27.5 / 11.5 | 32 / 15 |
| Tipografía | 32.5 / 16.0 | 35 / 20 |
| Perfil | 12.0 / 11.0 | 13 / 12 |
| Avanzado | 24.0 / 14.5 | 30 / 18 |

La peor pausa observada del conjunto fue70→23ms. Apariencia mejoró en las cuatro
comparaciones (60/63/70/62 frente21/15/21/23), sin solapamiento de los rangos.
Composición/Perfil ya estaban cerca del intervalo de reposo del fixture; sus
variaciones pequeñas no se presentan como mejoras. No es medición de input→pixel,
GPU, FPS físicos ni prueba de ausencia absoluta de tirones.

`comparison-final.json` y summary-final.json son las cifras finales. La primera
comparación con cuatro editores lazy está en comparison.json; se excluyó su
pareja0 porque coincidió con parte de la fixture roja. Se conserva esa evidencia,
pero no se usa para las conclusiones finales. Después se añadió el Loader de
Restablecer y se repitió toda la comparación final sin ventanas de prueba
simultáneas. El helper final de restauración de foco se añadió después; no se
invoca al navegar y se validó con la regresión de controles, sin repetir métricas
ajenas a ese recorrido.

## Por qué Rust no mejora este cambio

Luna/medium midió Settings.js en Node: núcleo merge+validate0,071–0,098ms de
mediana, catalog0,116–0,175ms según documento; config-profile.json contiene método
y comando reproducible. Node no equivale al JS de Qt, por lo que se repitió el
núcleo en Qt:10series×100operaciones por ejecución de la fixture.

En la comparación final, medianas del núcleo Qt0,530ms antes y0,515ms después.
No se modificó ese código ni se atribuye la diferencia pequeña a una mejora.
Durante las48transiciones medidas hubo **0snapshot y0validate** en cada backend;
cambiar sección usa fieldSelection/entries, no reconstruye configuración.
Config.qml/Settings.js/SettingsPage.qml/EdotsWindow.qml y las duraciones de
EdotsPageMotion permanecen byte a byte iguales al baseline. No se duplicaron
reglas de validación, no se añadió FFI, proceso ni servicio.

## Funcionalidad, foco y QA

- Navegación fría/caliente, modelo sin secciones intermedias, ausencia de editores
  ocultos, búsqueda, composición ancha/estrecha, cambios rápidos, reduced y
  borradores retenidos/commit: PASS en comparación final.
- UX Wayland antes/después y última versión:1000×700/640×560, fuentes1/1,75,
  scroll, errores/borradores, foco de campo inválido y picker: PASS. Capturas16por
  variante en qa-before/, qa-after/ (cuatro loaders), qa-final/ (cinco loaders).
  Avatar sintético/config privada. Las capturas estáticas no certifican movimiento.
- Controles nativos: combo pointer/teclado/custom, texto, switch/slider, restaurar
  módulos: PASS. Test adicional activó Restablecer con teclado y detectó pérdida
  de foco de Shift+Tab tras destruir el botón; restoreDefault() desde la fila
  estable devuelve foco al editor. La regresión final comprueba reset, descarga
  del botón, Tab y Shift+Tab con destino visible y nombre accesible: PASS.
  `controls-final.txt`; fallo previo en validation/controls-reset-red.txt.
- settings-motion-regression (retarget, último destino, reduced/hidden) y
  settings-async-regression: PASS. Gate settings/boundaries/calculadora, sintaxis
  Python y diffcheck PASS. Implementador ejecutó integración Config temporal PASS
  en la fase inicial; backend no se alteró después.
- Revisión independiente UI Sol/medium comparó código/foco y capturas, sin
  defectos sustentados. Su incertidumbre sobre reset se convirtió en prueba roja
  y corrección; review.txt delimita alcance y versiones. Qmllint Qt6 exit0 según
  implementador, conserva avisos dinámicos/de scope, no se declara lint sin avisos.

Validaciones Wayland serializadas para evitar conflicto de foco/medición. Avisos
conocidos de textinput aparecen también en baseline; no se interpretan como pase
físico. La prueba final exige marcador PASS y ausencia de FAIL: qs puede retornar
cero aun cuando un TestCase haya fallado.

## Reproducción

```sh
python bar/tests/settings-navigation-performance.py --rounds 2 --output /tmp/settings-comparison.json
python bar/tests/settings-navigation-performance.py --rounds 1 --baseline-lazy-check --output /tmp/settings-red.json
python bar/tests/settings-ux.py
# Para controles/motion/async, ejecutar qs -p con ISLA_CONFIG temporal y Wayland.
sh bar/tests/verify-config.sh
```

El benchmark crea copias privadas del bar, superpone el baseline para la variante
antigua e instrumenta sólo sus copias Config; no modifica producción ni settings
personales. Final de producción: SettingRow.qml; nueva regresión en
settings-controls-regression.qml y harness de rendimiento. Hashes y archivo en
sources.json/source-final.tar.gz; resto de componentes requiere checkout existente.

## Límites

No medidos: batería, CPU/PSS globales, arranque, primer pixel, AT-SPI ni uso
prolongado. La validación se centra en seis apartados; Hyprland y bibliotecas de
fuentes extraordinariamente grandes conservan sus caminos previos. Las pausas
observadas bajan, pero23ms todavía puede exceder un frame en pantallas rápidas.
No se alteró la configuración personal, no se forzó reinicio de shell ni se hizo
commit/merge/publicación. La interfaz actualizada se carga por el mecanismo normal
de recarga de QML. Otro cambio Rust requiere un coste que realmente se ejecute en
el recorrido lento.
