# Integración de escritorio · 2026-10-26

Alcance autorizado: launcher/aplicación, workspaces, fullscreen, paneles/teclado y
apariencia entre toolkits. Sin commit ni push; se conservaron cambios anteriores.

## Resultado

- Launcher ejecuta desde el singleton después de liberar la captura de teclado.
  La llamada diferida referencia un método persistente, con la entrada como
  argumento; evita depender de una lambda temporal durante la descarga.
  Enter lee el modelo aunque la fila visual aún no exista. Se conserva el cierre
  animado y la protección frente a búsquedas pendientes.
- Workspaces confirma y cierra el panel; acciones de workspace/overview se
  programan con función nativa y argumentos evaluados para sobrevivir a la descarga
  inmediata del componente. Dirección/muelle existentes conservados.
- Fullscreen descarta rutas y docking pendientes por monitor, cancela auth y
  retira foco/máscara inmediatamente. Pill y gotas conservan la retirada conjunta.
- Escape respeta la búsqueda local de ajustes antes de cerrar; popup de rutas y
  mezclador mantienen su prioridad. Las 14 superficies devuelven escritura a la app.
- Matugen sigue preferencias explícitas de apariencia; `default`/ausencia conserva
  el modo publicado. GTK3/4 sincronizan su preferencia oscura sin reemplazar otras
  claves; Qt usa el puente GTK instalado. Cursor explícito y escala automática en
  configuración portable, sin multiplicador global Qt.

La primera implementación interpretaba `default` como claro y cambió la pill a
gris clara. El usuario lo señaló; se corrigió esa interpretación y se restauró la
paleta oscura con el mismo wallpaper. GSettings sigue `default`. Captura nativa:
`restored-dark.png`. Copia de seguridad de archivos activos:
`~/.local/state/isla/desktop-theme-backup-20261026-170239`.

Durante la validación se corrigió también un ciclo de tamaño del lector de
portapapeles, manteniendo explícita la altura desplazable y comprobando texto largo.

## Evidencia y revisión

- Seis regresiones QML: política de entrada, router, launcher pendiente, modelo y
  surface de workspaces y movimiento del rail: PASS. Logs en esta carpeta.
- Wayland real: Escape y escritura posterior en 14 paneles, búsqueda anidada de
  ajustes, confirmación de workspace, fullscreen real y apertura mediante
  DesktopEntry con movimiento normal/reducido: dos ejecuciones finales consecutivas PASS
  (`native-journeys.log`, `native-journeys-final.log`). Fixture y datos temporales,
  aplicación desechable, socket askpass aislado, sin autenticar.
- Fullscreen hide, ajustes UX y configuración: PASS. Portapapeles diseño y
  recorrido con texto largo, rueda y persistencia aislada: PASS.
  La altura implícita del ScrollView se desacopla del viewport y contentHeight
  referencia explícitamente la altura calculada del contenido.
- Tema: Matugen 20/20, instalador aislado GNU Stow 15/15; sondas Qt Wayland claro
  y oscuro, puente GTK disponible, monitor DP-1 conserva escala 1. Sin instalar paquetes.
- Revisión independiente Sol medium: rutas, vida útil, entrada, reentrancia y
  fullscreen. Detectó fixture que sólo cambiaba router, y pérdida de scroll al
  sustituir implicitHeight; ambos corregidos. Sin nuevos defectos en launcher.
  Claude local no autenticado; se usó revisión independiente disponible.

## Límites

Los tests offscreen no son QA visual. Evidencia nativa de un monitor a escala 1;
no certifica todos los monitores, escalas, aplicaciones ni FPS de presentación.
No se ejercitaron credenciales reales ni bloqueo de sesión. Electron/libadwaita
pueden elegir apariencia propia cuando el portal no expresa preferencia; no se
fuerzan ajustes personales. Cambiar apariencia externa requiere generar de nuevo
(`generate.py --refresh`); no se añadió un observador permanente. Algunas apps
necesitan reabrirse; retirar variables heredadas requiere nueva sesión.
