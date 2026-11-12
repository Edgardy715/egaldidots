# Fluidez de configuración · 2026-10-18

Se elimina la reconstrucción transitoria de secciones completas al entrar/salir
Composición: SettingsPage recibe selección activa/sección/claves en un solo
binding. Composición amplia no crea filas ocultas. SettingRow carga el selector
de fuentes sólo en campos tipográficos; su lista existe sólo con popup abierto.
No se cambian duraciones ni diseño de navegación. Borradores permanecen en el
controlador del formulario.

## Evidencia

- Wayland, configuración temporal, misma secuencia seis destinos, dos ciclos:
  driver FrameAnimation máximo global 176/181 ms antes y 62/58 ms después.
  Final por página frío/caliente: Composición11/14, Movimiento31/28,
  Tipografía40/40, Perfil13/12, Avanzado26/21, Apariencia62/58 ms.
  Son intervalos del driver, no FPS ni tiempos de presentación GPU.
- Nueva settings-navigation-regression: PASS selección sin modelos intermedios,
  ausencia de fontPicker en filas comunes, composición amplia/estrecha, búsqueda,
  borradores, interrupciones y movimiento reducido. Su última ejecución de
  cobertura coincidió con otras pruebas; usar after-isolated.log para métricas.
- settings-ux.py, settings-controls-regression (Wayland aislado),
  settings-async-regression (Wayland), settings-motion-regression y verify-config
  PASS. Controls concurrente con otras ventanas falló por foco; aislado PASS.
- QA Wayland de Composición/Movimiento: distribución y controles conservados;
  capturas adjuntas. Las capturas estáticas no prueban continuidad temporal.
- qmllint Qt6 conserva advertencias de scope/tipos y geometría previas; nuevo
  Loader.item se infiere QObject, su acceso contentItem está cubierto en runtime.
  No se declara lint limpio. git diff --check PASS.

## Límites

Apariencia aún reconstruye filas (~60 ms en esta medición). No se mide GPU/FPS,
AT-SPI ni multimonitor físico. No se escribe configuración personal ni se cambia
wallpaper/reproducción. Los avisos .face ausente y textinput son del entorno.
