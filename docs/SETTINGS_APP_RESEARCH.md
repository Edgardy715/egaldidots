# Investigación y propuesta para la app de Isla

Fecha: 2026-10-05. Alcance: seis shells, configuración gráfica y oportunidades
para la pill. Este documento propone una dirección; no es una aprobación de
rediseño ni afirma que las funciones propuestas estén implementadas.

## Resultado

Construir una app centrada en **componer Isla y ensayar su comportamiento**.
La pill principal permanece obligatoria. Los laterales son opcionales. La
personalización debe conservar una superficie continua, legibilidad, prioridad
de autenticación y movimiento interrumpible del contrato actual.

Las mejores referencias aportan búsqueda, edición contextual, composición de
módulos y controles visuales comprensibles. Nuestra oportunidad es que una
persona pueda entender qué hará su pill cuando compiten música, avisos,
navegación y acciones, antes de guardar una configuración.

## Método y límites

Se revisaron documentación oficial, notas de versiones y código fuente público.
No se instalaron ni ejecutaron otras shells; no hubo inspección interactiva de
sus interfaces. Los hallazgos de GUI se apoyan en documentación/código, no en
haber usado las apps. Se distinguen hechos observados, adaptación propuesta y
extensiones que requiere Isla. No se copió código ni recursos externos.

Instantáneas de repositorios consultadas: Caelestia
`c807586850859482cf48e17f34450befca7a6ab6`, HyprPanel
`1961ba86ad5ab880beb639e5454054b2b5037e0d`, illogical-impulse
`33f31a08caddd41422a2d97670adeeb52b4f1e7c`. Serpantinum se consultó en
master; al cerrar la investigación apuntaba a
`f11dab189c4e40df3f28d76187e4d63a7a982fee`.

## Seis referencias y qué tomar de cada una

| Referencia | Evidencia observada | Adaptación para Isla |
| --- | --- | --- |
| Noctalia | Documentación actual v5+, configuración por capas y exportación; acceso desde un widget a sus ajustes. La documentación Quickshell v4 se publica como legacy. | Abrir el control exacto desde el componente; distinguir valor por defecto, heredado y personalizado. |
| DankMaterialShell | Búsqueda de ajustes y acceso desde launcher. DMS 1.6 incorpora Dank Island: centro, satélites, estados dinámicos y editor del contenido en reposo. | Búsqueda por intención y editor de composición; estudiar especialmente conflictos entre estados. |
| HyprPanel | App de ajustes con controles detallados de barra y restablecimiento global. Su repositorio está archivado desde abril de 2026. | Controles concretos y recuperación de defaults; usar como referencia histórica, no como dependencia. |
| illogical-impulse | App con categorías y página Quick; elecciones visuales de posición/estilo, transparencia y wallpaper. Documentación distingue ajustes comunes gráficos y avanzados en JSON. | Primera página de cambios frecuentes con ejemplos visuales; detalles avanzados progresivos. |
| Caelestia | Nexus contiene búsqueda, registro de páginas y panel de configuración de taskbar. README documenta overrides por monitor con excepciones. | Navegación clara, búsqueda y procedencia de valores por pantalla cuando se implemente ese alcance. |
| Serpantinum | Guide indexa título, descripción, sección y palabras clave; editor arrastra módulos entre izquierda/centro/derecha y restablece composición. | Editor con pill central bloqueada y laterales editables, con alternativa accesible al arrastre. |

Fuentes primarias:

- Noctalia: [configuración v5+](https://docs.noctalia.dev/noctalia/configuration/),
  [widgets de barra](https://docs.noctalia.dev/noctalia/bar/widgets/),
  [configuración legacy](https://docs.noctalia.dev/noctalia-shell-legacy/configuration/configure-noctalia/).
- DMS: [búsqueda y configuración en 1.2](https://danklinux.com/blog/v1-2-release),
  [Dank Island y cambios de configuración en 1.6](https://danklinux.com/blog/v1-6-release),
  [contratos de plugins](https://danklinux.com/docs/dankmaterialshell/plugins-overview).
- HyprPanel: [estado del repositorio](https://github.com/Jas-SinghFSU/HyprPanel),
  [controles de barra](https://github.com/Jas-SinghFSU/HyprPanel/blob/1961ba86ad5ab880beb639e5454054b2b5037e0d/src/components/settings/pages/config/bar/index.tsx),
  [restablecimiento global](https://github.com/Jas-SinghFSU/HyprPanel/blob/1961ba86ad5ab880beb639e5454054b2b5037e0d/src/components/settings/Header.tsx).
- illogical-impulse: [guía de configuración](https://ii.clsty.link/en/ii-qs/03config/),
  [ventana de ajustes](https://github.com/end-4/dots-hyprland/blob/33f31a08caddd41422a2d97670adeeb52b4f1e7c/dots/.config/quickshell/ii/settings.qml),
  [Quick](https://github.com/end-4/dots-hyprland/blob/33f31a08caddd41422a2d97670adeeb52b4f1e7c/dots/.config/quickshell/ii/modules/settings/QuickConfig.qml).
- Caelestia: [Nexus y búsqueda](https://github.com/caelestia-dots/shell/blob/c807586850859482cf48e17f34450befca7a6ab6/modules/nexus/NavPane.qml),
  [registro de páginas](https://github.com/caelestia-dots/shell/blob/c807586850859482cf48e17f34450befca7a6ab6/modules/nexus/PageRegistry.qml),
  [taskbar](https://github.com/caelestia-dots/shell/blob/c807586850859482cf48e17f34450befca7a6ab6/modules/nexus/pages/panels/TaskbarPanel.qml),
  [configuración y monitores](https://github.com/caelestia-dots/shell/blob/c807586850859482cf48e17f34450befca7a6ab6/README.md).
- Serpantinum: [Guide y búsqueda](https://github.com/ilyamiro/serpantinum/blob/master/src/quickshell/guide/GuidePopup.qml),
  [editor de barra](https://github.com/ilyamiro/serpantinum/blob/master/src/quickshell/guide/bar/BarGeneralTab.qml),
  [presets de widgets de escritorio](https://github.com/ilyamiro/serpantinum/blob/master/src/quickshell/guide/display/DisplayWidgetsTab.qml).

No se confirmó una función general de previsualización aislada/reversión en
todas estas apps. Los presets de widgets de Serpantinum no prueban perfiles de
pill; los perfiles de pantalla de otra shell no equivalen a perfiles visuales.
Noctalia actual y legacy deben mantenerse separados al comparar arquitectura.

## Dirección de producto

La app puede ser una ventana independiente, con navegación estable y controles
sobrios. El movimiento expresivo se observa en la pill que se configura; la
ventana facilita editar sin distraer. No introducir cambios estéticos a la
shell existente como consecuencia automática de construir la app.

Propuesta de organización, sin obligar a que cada apartado sea una página:

| Área | Pregunta que resuelve | Contenido |
| --- | --- | --- |
| Inicio | ¿Cómo quiero usar Isla? | Configuración actual, cambios frecuentes, acceso al laboratorio. |
| Pill | ¿Qué muestra y cómo responde? | Contenido en reposo, escenas, material y comportamiento de avisos/media. |
| Módulos | ¿Qué quiero a cada lado? | Encendido/apagado, dependencias, composición y opciones de cada módulo. |
| Apariencia y movimiento | ¿Cómo se siente y se lee? | Fuentes, escalas, opacidad, movimiento reducido y presets acotados. |
| Pantallas | ¿Dónde y con qué alcance? | En V1, explicación del alcance global; overrides cuando exista contrato. |
| Avanzado | ¿Cómo recupero o diagnostico? | Rutas, estado de configuración, defaults, importación/exportación futura. |

Buscar debe llevar hasta el control y resaltarlo brevemente. Indexar etiqueta,
descripción y términos cotidianos: «sin animaciones», «quitar batería», «más
grande», «reloj». Mostrar alcance y efecto; un resultado no debe prometer una
función sin consumidor real.

El editor de módulos muestra centro obligatorio y laterales opcionales. Primero
usar interruptores y vista de composición. El arrastre llega cuando exista
orden configurable; ofrecer Mover a la izquierda/derecha y Subir/Bajar por
teclado. Explicar por qué apps/audio/red/batería no aparecen al apagar su
contenedor, y qué hace habilitarlo. No presentar el padre como otro indicador.

## Qué podemos personalizar de la pill

| Grupo | Opciones con sentido para la persona | Situación de Isla / trabajo necesario |
| --- | --- | --- |
| Lectura | Fuente, tamaño de texto, escala general, separación superior. | Hay contrato global. Se afecta también a otras superficies; no venderlo como ajuste exclusivo de pill. |
| Tamaño | Presets compacta/equilibrada/amplia; altura y espacio interior con límites. | Altura de reposo y geometría son valores compartidos; faltan campos, validación y consumidores. Probar máscara/input y pantallas estrechas. |
| Material | Opacidad; acento automático/personalizado; intensidad de luz y borde. | glassAlpha existe. Acento/luz/borde individuales requieren contrato. pillBlur está inactivo; no ofrecer blur operativo hasta implementarlo y comprobar compositor. |
| Reloj | 12/24 horas, segundos, presentación de fecha. | time12h afecta calendario/lockscreen; pill compacta sigue 12h. clockSeconds es parcial: no muestra segundos en pill. Completar consumidores antes de exponer esas promesas. |
| Contenido de reposo | Reloj/avatar y resumen seleccionado de media/estado; orden acotado. | Cabecera separada facilita hacerlo. Configurar contenido/orden necesita modelo y pruebas; mantener pill principal visible. |
| Multimedia | Portada, progreso, visualizador, cuándo aparece el resumen y cuándo se retira. | Componentes y MediaSession existen; preferencias nuevas y arbitraje de visibilidad pendientes. Evitar CAVA activo si no se ve. |
| Avisos | Vista completa/resumida/privada, tipos de feedback y tiempo de lectura. | Nuevos ajustes y consumidores de notificación/OSD; texto largo y avisos críticos requieren límites semánticos. |
| Movimiento | Movimiento reducido, ritmo general, animación al activar/desactivar módulos. | Ya existen reduceMotion, motionScale y modules.animateChanges. Presets pueden usar ese contrato; no exponer resortes/curvas arbitrarias. |
| Interacción | Acciones predefinidas por clic/rueda, apertura contextual de ajustes. | Requiere contrato de acciones. Mantener teclado, foco y hitboxes estables; comandos shell personalizados fuera del primer alcance. |
| Pantallas | Alcance global o por monitor; posición y margen dentro del área segura. | Hoy no hay overrides de ajustes por monitor. Añadir herencia explícita y recuperación de monitor desconectado antes de ofrecerlos. |

radiusScale ajusta radios del sistema de controles; no equivale a personalizar
libremente el radio exterior de la pill. showGlyphs también está inactivo. El
catálogo declara estas limitaciones y la app debe respetarlas.

Ninguna opción puede deformar texto con el recipiente, dejar controles
invisibles capturando entrada, reiniciar una transición al interrumpirla o
ocultar autenticación con un modo de concentración. Esto conserva
`bar/fluid/MOTION_LANGUAGE.md` como contrato.

## Propuestas propias para la identidad de Isla

Son ideas originales para este proyecto; no una afirmación de exclusividad
mundial. La isla central y los satélites ya aparecen en DMS 1.6.

### 1. Laboratorio de escenas — primera prioridad

En vez de configurar mirando únicamente una pill vacía, elegir escenas:
reposo, canción larga, aviso extenso, volumen, launcher y movimiento reducido.
Un botón «Probar interrupción» encadena abrir → cerrar → reabrir. Una escena de
concurrencia muestra música + aviso + apertura de panel y explica qué ocupa el
centro. La persona puede verificar lectura y prioridad, no sólo color.

Reutilizar vistas/contratos con datos sintéticos. No duplicar el motor físico.
Empezar por tres escenas representativas y una interrupción; ampliar cuando
los nuevos controles lo requieran. El preview no envía avisos reales, ejecuta
acciones de sesión ni modifica volumen. La simulación de Auth nunca autentica.

### 2. Presupuesto de atención

Un ajuste comprensible para decidir cuánto protagonismo toma Isla: «Discreta»,
«Equilibrada», «Expresiva». Podría combinar duración de feedback, expansión
multimedia y énfasis de luz. Enseñar los cambios concretos que hace el preset;
permitir volver al ajuste anterior. Empezar con opciones manuales, sin analizar
aplicaciones ni automatizar cambios inesperados.

No reducirlo a velocidad de animación. Una pill discreta puede conservar su
trayectoria y presentar menos contenido rutinario. Requiere políticas de
presentación nuevas; autenticación y eventos críticos mantienen prioridad.

### 3. Configurar donde se mira

Una acción contextual «Personalizar este componente» abre la app directamente
en Media, Reloj, Módulos o Material. La pill sigue siendo interfaz cotidiana;
los controles detallados viven en la app. Reutiliza la idea observada en
Noctalia y la especializa a estados de una superficie cambiante.

Necesita destinos estables de ajustes. No añadir un nuevo gesto oculto que
desplace una acción ya usada; entrada por menú explícito y alternativa de
teclado.

### 4. Misma identidad, distinta densidad

Perfiles «Lectura», «Multimedia» y «Compacta» cambian contenido y densidad,
manteniendo el material y la continuidad. Cada tarjeta muestra una escena
representativa y enumera qué cambia. Evitar una colección de skins sin relación
con el comportamiento de Isla.

Comenzar como presets parciales del contrato disponible, sin motor de perfiles.
No llamarlos perfiles persistentes intercambiables hasta definir almacenamiento,
herencia y qué valores quedan fuera, especialmente rutas personales.

### 5. Continuidad explicable

En el laboratorio, mostrar una leyenda opcional de «qué está ocupando la pill»
y «qué espera». Ejemplo: un aviso se presenta y después regresa el resumen de
la canción sin perder el estado del reproductor. Sirve para comprender ajustes
de media/avisos y diagnosticar conflictos.

No convertir esta leyenda en otra barra permanente. Reutilizar estado del router
y coordinadores; ampliar sólo el arbitraje que una nueva preferencia necesite.

### 6. Recuperación visible

Resumen «Cambiaste fuente, opacidad y dos módulos», con restaurar por campo o
sección y comparación con defaults. Si una combinación deja poco espacio,
mostrar el efecto concreto y ofrecer el último valor válido. Para futuras
opciones de posición/tamaño, una prueba temporal con restauración evita perder
acceso a la pill.

Config ya cubre discard y guardado atómico; deshacer por campo y prueba con
temporizador necesitan historial de edición en la app. No prometer recuperación
ante caída del proceso hasta implementar y probarla fuera de ese proceso.

## Flujo de edición y arquitectura

Base disponible: Settings.schema/catalog, Config.get/update/discard/save,
30 campos, seis módulos opcionales, 14 surfaces y pill obligatoria. El catálogo
es declarativo: availabilityIsLive=false no prueba disponibilidad de servicios.
Un diagnóstico live futuro debe quedar separado del inventario.

La app debe usar Settings para reglas y Config como escritor único. No otro
JSON paralelo ni duplicación de validación. Puede generar controles simples
desde metadatos; composición y laboratorio necesitan vistas específicas.

Flujo mínimo sobre contrato actual:

1. Leer estado y mostrar defaults/efectivos/cambios pendientes. Si ya hay edición
   de sesión, reconocerla; no borrarla silenciosamente al abrir.
2. Un cambio validado usa update y es una **vista previa de sesión**: afecta la
   shell en ejecución. Mostrar «Vista previa sin guardar» mientras dirty=true.
3. Cancelar usa discard y vuelve al disco; no equivale a restaurar cualquier
   edición previa de otro consumidor. Mantener una única sesión de edición.
4. Guardar espera saving=false, dirty=false y error vacío. Que save acepte la
   petición no significa que la escritura haya terminado.
5. Al cerrar con cambios, ofrecer Guardar, Descartar o Seguir editando. Un archivo
   cambiado externamente exige recargar; informar antes de perder un borrador.

Una previsualización aislada en ventana es otra función: usar valores/datos por
propiedades donde ya sea posible. Theme/Flags aún son dependencias globales;
no basta duplicar una pill para aislar todas sus preferencias. Definir el
alcance real del preview, y ampliar inyección de tokens sólo para los controles
que lo necesiten. El lockscreen independiente lee valores persistidos.

Importación/exportación, si se incorpora: validar documento completo, enseñar
diferencias antes de aplicar, preservar claves desconocidas y avisar de rutas
ligadas a otra máquina. No exportar historiales, credenciales ni estados de
servicios como si fueran preferencias.

## Orden de desarrollo recomendado

| Fase | Entrega | Aceptación |
| --- | --- | --- |
| A. App útil | Ventana, búsqueda, campos activos, seis módulos, preview de sesión, guardar/cancelar/restablecer y errores. | ISLA_CONFIG temporal; actualización reactiva, rechazo de valores, error de guardado, archivo externo y teclado. No controles falsos de campos inactivos. |
| B. Identidad de pill | Laboratorio inicial, completar reloj, presets acotados de densidad/material/contenido. | Cada campo tiene consumidor y validación; escenas largas/vacías, cierres/interrupciones, reduceMotion y QA Wayland real. |
| C. Composición ampliada | Orden/zonas y, si se necesita, overrides por monitor. | Teclado equivalente al arrastre, herencia visible, desconexión/reconexión y geometría/máscara en pantallas estrechas. |
| D. Portabilidad | Presets guardados e importación/exportación. | Migración/versiones, diferencias legibles, defaults y rutas portables. |

No hace falta un marketplace, editor de cada curva, configuración completa del
compositor ni chatbot para desarrollar una buena primera app. Añadir servicios
externos sólo por un caso de uso comprobable. Separación actual suficiente para
empezar A; las preferencias nuevas se agregan al contrato cuando se implementan.

## Próxima decisión de diseño

Recomiendo empezar con **app + módulos opcionales + laboratorio de tres escenas**.
Es una base utilizable y muestra la identidad de Isla. Este documento deja las
demás ideas priorizadas para decidirlas sin comprometer el funcionamiento actual.
