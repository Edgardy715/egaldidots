# Edots · Configuración de Isla

Edots forma parte de la shell: una gota nace de Isla, se despliega en el centro
y vuelve a ella al cerrar. **Win + I** abre y cierra los ajustes. También se
puede usar `bar/settings/open.sh` o el lanzador instalado con
`bar/settings/install.sh`. No inicia otro proceso escritor de preferencias.

La integración usa SurfaceRouter, IslandOverlay y el motor FluidCompanion.
SettingsSurface contiene EdotsWindow (ahora un FocusScope, aunque conserva el
nombre por compatibilidad). Su contenido permanece montado después de la
primera apertura para conservar navegación, búsqueda y borradores al cerrar.
El recipiente reutiliza PillMaterial; Edots no dibuja otro fondo exterior.

## Uso

- Apariencia: material, geometría y reloj.
- Composición: activar u ocultar módulos; Isla principal permanece obligatoria.
- Movimiento: ajustes y laboratorio sintético, ritmos Ágil/Natural/Pausado.
- Tipografía: fuentes instaladas, nombres manuales y muestra de lectura.
- Tu perfil: nombre y ruta de avatar.
- Avanzado: rutas y opciones limitadas del contrato.
- Buscar (`Ctrl+F`) encuentra ajustes en todas las secciones, sin distinguir
  acentos y admitiendo varios términos.
- Guardar (`Ctrl+S`) confirma la escritura asíncrona; Descartar recupera lo
  persistido. Restablecer afecta solo al campo elegido.

Los cambios válidos actualizan la sesión inmediatamente. Cerrar conserva la
edición; reiniciar la shell carga lo persistido. Las preferencias son globales.
Las opciones sin consumidor o parcialmente implementadas se identifican y su
edición permanece desactivada.

Composición mantiene disponibles los botones de cada módulo al ocultarlo.
El avatar de la esquina superior derecha sigue la imagen de «Tu perfil» y abre
el panel de sesión; si la imagen no existe, muestra la inicial del usuario.
Composición → Avatar permite ocultarlo o restaurarlo. El mismo avatar aparece
arriba a la izquierda del editor y abre «Tu perfil».

La barra permanece visible mientras Configuración está abierta para ver los
cambios en directo.

Ocultar Estado conserva las preferencias de sus hijos. Los botones muestran su
activación efectiva; seleccionar un hijo oculto reactiva Estado y ese componente
sin cambiar las preferencias de sus hermanos.
El diagrama se omite en espacios bajos; los interruptores siguen disponibles.

## Controles y movimiento

El diseño aprobado usa la paleta viva y las fuentes de Isla, navegación
horizontal y grupos ligeros. El logo suministrado se conserva sin editar.
EdotsIcon completa la cobertura de símbolos animados con gestos finitos de
entrada, selección, foco, hover y presión. No hay ciclos ornamentales continuos.

EdotsTextField mantiene la edición nativa, selección, cursor y composición de
texto. Anima foco, borde, material y placeholder. EdotsButton conserva activación
nativa y anima presión, recuperación, estado y foco. Interruptores y sliders
ofrecen respuesta física breve; el arrastre sigue inmediatamente al puntero.

EdotsComboBox mantiene el modelo de fuentes y la selección nativa de Qt.
Su lista opaca se abre encima o debajo del campo según el espacio de la surface,
con un máximo de 280 px, scroll y una muestra de cada fuente. El campo conserva
la entrada manual. Alt + ↓ abre la lista; flechas navegan, Enter confirma,
Escape cancela la opción resaltada y Tab confirma el texto escrito. Abrir la
lista no confirma el valor anterior. Ocultar/deshabilitar el control la cierra.

EdotsPageMotion conserva salida, entrada y último destino de navegación;
interrupciones de la gota reutilizan la física de FluidCompanion. Movimiento
reducido evita desplazamiento/compresión y conserva señales suaves de estado.
El laboratorio es sintético: no cambia reproducción, notificaciones ni espacios
reales. Config.update/discard/save siguen siendo las únicas operaciones de edición.

## Atajo

La configuración activa de Hyprland añade Win + I para ejecutar
`quickshell -p ~/.config/quickshell/bar ipc call island settings`.
IslandOverlay maneja Meta+I cuando su capa tiene foco exclusivo, para cerrar
los ajustes desde dentro. En otra instalación debe añadirse el bind equivalente
en la configuración de Hyprland de esa sesión.

## Comprobación

Usar siempre `ISLA_CONFIG` temporal para las fixtures de edición:

```sh
bash bar/tests/verify-config.sh
python bar/tests/settings-integration.py
ISLA_CONFIG=/tmp/edots-check.json QT_QPA_PLATFORM=offscreen quickshell -p bar/settings-regression.qml
ISLA_CONFIG=/tmp/edots-motion.json QT_QPA_PLATFORM=offscreen quickshell -p bar/settings-motion-regression.qml
ISLA_CONFIG=/tmp/edots-drop.json QT_QPA_PLATFORM=offscreen quickshell -p bar/settings-companion-regression.qml
ISLA_CONFIG=/tmp/edots-modules.json QT_QPA_PLATFORM=offscreen quickshell -p bar/module-composer-regression.qml
ISLA_CONFIG=/tmp/edots-controls.json quickshell -p bar/settings-controls-regression.qml
ISLA_CONFIG=/tmp/edots-preview.json quickshell -p bar/settings-preview.qml
```

Exigir el marcador PASS y ausencia de FAIL: QtTest embebido puede terminar con
exit 0 tras una aserción fallida. La regresión de controles envía eventos de Qt
en Wayland: clics, teclado, fuentes manuales, Enter/Tab/Escape, límites del popup,
interruptor, slider y restauración de módulos. No sustituye una prueba física.
La preview tiene IPC edotsTest para página, escena, búsqueda y lista de fuentes.

QA visual realizada a 1000×700 y 760×560, con capturas de desplegables y controles.
Apertura desde Isla, búsqueda con teclado y retorno revisados en la shell.
No se midieron FPS ni se probó multimonitor físico en esta fase.

Investigación de referencias: [SETTINGS_APP_RESEARCH.md](SETTINGS_APP_RESEARCH.md).

### Selección de rutas

Todos los campos de rutas incluyen «Elegir…» y conservan edición manual. Avatar
filtra imágenes, colores filtra JSON y el script permite archivos. Wallpapers
y caché usan selector de carpetas. Aceptar actualiza la sesión; Guardar persiste.
Cancelar conserva el valor. El selector integrado de Edots usa una galería con miniaturas y vista previa
grande. Un clic selecciona; doble clic o Enter abre carpetas; «Usar archivo»
confirma. Incluye ubicación editable, accesos rápidos, carpeta superior y
archivos ocultos. Se abre dentro de la misma capa con foco modal y Escape
lo cancela, sin ventanas externas. La imagen se aplica solo al confirmar.

Prueba: `ISLA_CONFIG=/tmp/isla-picker.json quickshell -p bar/settings-path-picker-regression.qml`.


### Diseño de barra

En Composición, Separada mantiene las pills laterales y la gota musical;
Compacta reúne espacios, música, reloj, estado y perfil en una unidad centrada.
La música compacta muestra portada, metadatos y pausa/reproducción, con
visualizador al reproducir si hay espacio. Pulsar portada/título abre la tarjeta
en el cuerpo principal. Elige el diseño en directo, luego Guardar o Descartar.
También aparece en la búsqueda «compacta» y en ventanas pequeñas de Edots.
El ajuste es appearance.barLayout y acepta split/compact; sin preferencia
guardada, se conserva la versión separada.
