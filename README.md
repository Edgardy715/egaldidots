# egaldidots

Configuración personal de escritorio para **Hyprland + Quickshell**. La barra
tipo isla centraliza lanzador, espacios de trabajo, multimedia, red,
notificaciones, calendario, portapapeles, sesión y selector de fondos.

## Uso

Clona el repositorio en la ruta que Quickshell usa como configuración y ejecuta
la shell desde el directorio `bar`:

```bash
git clone https://github.com/Edgardy715/egaldidots.git ~/.config/quickshell
quickshell -p ~/.config/quickshell/bar
```

Necesitas una sesión Wayland con Hyprland, Quickshell y los servicios que usan
las superficies (por ejemplo PipeWire, NetworkManager, playerctl, Cava y
brightnessctl). Los iconos y fuentes configurados también deben estar
instalados.

## Estructura

```text
bar/       Shell y componentes QML
wpscan/    Plugin Qt/C++ para explorar fondos de pantalla
docs/      Notas de mantenimiento
```

`wpscan/Wpscan/` y `wpscan/build/` se incluyen porque la shell carga esos
artefactos del plugin en tiempo de ejecución. `graphify-out/` es generado y no
se versiona.

## Desarrollo

Para reconstruir el plugin cuando cambie su código:

```bash
cmake -S wpscan -B wpscan/build
cmake --build wpscan/build
```

La configuración está hecha para mi equipo; revisa rutas, comandos, monitores,
fuentes y dependencias antes de usarla como base de tu escritorio.
