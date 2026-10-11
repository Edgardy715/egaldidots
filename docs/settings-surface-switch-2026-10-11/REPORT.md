# Configuración al abrir otras superficies

2026-10-11. Se corrigió un robo de foco reproducible del editor retenido:
Configuración → launcher → petición de perfil dirigida al editor oculto
dejaba `launcherSearch.activeFocus=false`. [Reproducción anterior](before.txt).

Edots sólo activa su foco cuando está visible, habilitado y listo; conserva
el campo activo cuando ya tiene foco. Un cambio de página oculto no solicita
foco. El callback de asentamiento de IslandOverlay tampoco sustituye el foco
de un hijo que ya está recibiendo teclado. El editor sigue retenido, con su
estado y borradores, durante cierre y reapertura.

## Comprobaciones

- [Regresión nueva](after.txt): Window/IslandOverlay reales en Wayland, eventos
  QtTest; Configuración↔13 destinos, split/compact, movimiento normal/reducido,
  selector de archivos y menú de fuentes, borrador conservado, petición de
  perfil oculta, texto en launcher, Ctrl+S sin guardar el borrador oculto y
  cambios rápidos de destino. Configuración, estado de notificaciones y árbol
  de prueba temporales; no se activaron acciones de sistema.
- [Escape nativo](native-escape.txt): wtype cierra las 14 rutas sin Auth y
  comprueba liberación del teclado.
- [Regresiones vecinas](neighbors.txt): controles Edots, gota retenida,
  coreografía de páginas y Auth con backend falso pasan.
- [Gate](gate.txt) y git diff --check pasan. [Qt6 lint](qmllint.txt) termina
  exit0 con advertencias de acceso dinámico/no cualificado y layout existentes.

Capturas Wayland del subárbol de contenido QML inspeccionadas:
[salida de Configuración](settings-to-launcher.png) y
[launcher con texto y cursor](launcher-focused.png). Son muestras estáticas,
no una medición de fluidez; el Popup del selector pertenece a otro subárbol.

El primer intento de fixture terminó abruptamente al gestionar un assert
dentro del bucle de QtTest; no se atribuye ese crash a navegación de producto.
La segunda versión cerró normalmente después de detectar el error. Un intento
de captura del ProxyWindowContentItem sin engine QML se sustituyó por el hijo
FocusScope. La prueba del menú de fuentes inicialmente seleccionó un control
oculto de otra fila; ahora busca el control visible y habilitado. Los tests
finales pasan. Hay advertencias Qt de cancelación de DelegateModel y, en algunas
ejecuciones, objetos aún en creación al destruir la fixture.

No se probó multimonitor físico, IME ni autenticación PAM real. Los eventos
de escritura de la regresión son QtTest; sólo Escape se inyectó con wtype.
