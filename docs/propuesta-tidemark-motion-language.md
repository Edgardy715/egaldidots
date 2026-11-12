# Propuesta de texto · Tidemark (para MOTION_LANGUAGE.md y fluid-island-motion)

> Pendiente de OK del usuario: no está escrito en MOTION_LANGUAGE.md ni en la skill.

## Tidemark: lenguaje de trazo (2026-10-30)

- **Idea:** un símbolo cambia de estado como un trazo que se dibuja, se parte o se endereza, no como un cambio de glifo. Cabeza gruesa que lidera, cola fina; acento del wallpaper en reposo; verde/rojo (`Theme.signalSuccess/Error`) sólo al resolver.
- **Motor:** `SpringValue` (omega/zeta de `Motion.strokeSpring.*`). Cada cambio parte de la posición y la velocidad actuales; sin timers, el `FrameAnimation` sólo corre mientras integra. reduceMotion resuelve al estado final; oculto no anima.
- **Piezas:** `LevelStroke`/`LevelDial` (trazo = medida, `trim.end`), `VolumeGlyph` (la onda central se endereza hasta ser la barra de mute), `PlayPauseGlyph` (el triángulo se parte como una gota), `LockGlyph`, `TimeRing`, `PlusCheckGlyph` (barra → check), `RadioGlyph` (ondas en orden desde el punto; barra de apagado), rayo de batería (trazo y luego relleno).
- **Presentación pura:** el estado llega por propiedades; ningún glifo conecta servicios.
- **No animar:** scroll de volumen/brillo/wallpaper/letras, muestras del medidor del mezclador (ya suavizado lineal de 32 ms), hover repetido, avance de canción, iconos fijos.
- **Pruebas:** `bar/stroke-language-regression.qml` (estado final, interrupción, reduceMotion, oculto). Offscreen no es QA visual.
