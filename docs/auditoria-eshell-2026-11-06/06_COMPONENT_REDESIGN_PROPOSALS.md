# 06 · Propuestas de rediseño por componente

Leyenda de evidencia: **[V]** verificado · **[I]** inferencia · **[X]** experimental.

## Convenciones

**Alternativas.** Cada componente tiene hasta tres:

- **A · Conservadora:** misma forma, se corrige la deuda.
- **B · Moderna:** un componente nuevo dentro del lenguaje líquido.
- **C · Experimental:** solo si hay presupuesto de rendimiento.

**Recomendación** marcada con ★. Todas las soluciones son QML nativo (Qt Quick, Shapes, ShaderEffect); no hay dependencias web.

**Restricciones comunes:**

- Colores siempre por rol Matugen.
- `reduceMotion` implica fundido cruzado y nada de escala ni traslación.
- El hit target nunca se mueve con la animación (patrón actual de `CtrlBtn`).

---

## 1. Botones (5 implementaciones → 1 familia)

**Problema [V]:** CtrlBtn, MotionButton, EdotsButton, LockButton y AudioButton tienen API y estados distintos. `dim` baja la opacidad a 0.32.

| | Propuesta |
|---|---|
| **A** | Mantener `CtrlBtn` como base y convertir los otros cuatro en envoltorios finos (`IconButton`, `TextButton`, `PrimaryButton`) que solo fijan propiedades |
| **★ B** | Crear la familia `IslaButton` con `variant: icon \| text \| filled \| tonal \| ghost`, `size: s \| m \| l` (32/40/48) y una única gramática de estados: reposo, hover (tono +4 %), pulsado (compresión 0.96), foco (anillo de 2 px con desplazamiento de 2 px), deshabilitado (tono plano y glifo al 38 % **sin** opacidad global). El pulso de confirmación ya existente se conserva |
| **C** | En hover, el fondo del botón "se condensa" desde el puntero: un gradiente radial que sigue la posición del cursor con un muelle y desaparece al salir. Recuerda a los botones "spotlight" de Aceternity/Magic UI, pero en vidrio tonal y sin brillo de neón. Usar solo en botones primarios grandes (sesión, lockscreen) |

**Aceptación:**

1. Los 5 sitios usan la familia.
2. Tab, Espacio e Intro funcionan.
3. El lector anuncia rol y nombre.
4. El contraste del glifo es ≥ 3:1 en todos los estados salvo deshabilitado.

## 2. Slider (4 implementaciones → 1)

**Problema [V]:** `Slider.qml` (rico pero sin accesibilidad), `AudioFader` (6 px, Controls.Basic), el tubo de `SettingRow` y el de `LockMedia`. **Nota (doc 11):** el tubo de `SettingRow` ya es el diseño recomendado y tiene teclado; la propuesta es extraerlo, no rediseñarlo.

| | Propuesta |
|---|---|
| **A** | Dar a `Slider.qml` `Accessible.Slider`, `Keys` (±1 / ±10 con Shift, Inicio/Fin) y `WheelHandler`, y sustituir `AudioFader` por él con `thickness: 6` |
| **★ B** | Un **slider de tubo líquido** como único modelo: la pista *es* el control (12 px en listas, 36 px en el centro de control con el icono dentro), sin pulgar visible en reposo. Al agarrar aparecen el menisco y el engrosamiento actuales, y el valor se muestra con `RollingNumber`. Por encima de 100 % (volumen) la sección extra cambia a `error` con una muesca en 100. Basado en `Controls.Slider` para obtener accesibilidad y teclado nativos, con `background` y `handle` propios |
| **C** | **[X]** Slider con "tensión": al arrastrar más allá de los extremos, la pista se estira (rubber band, ya existe) y además el menisco se separa en una gota que vuelve con muelle al soltar. Comparte motor con `FluidCompanion` |

**Aceptación:**

1. Una sola implementación.
2. Teclado y rueda funcionan.
3. Se anuncia el valor.
4. El overdrag está limitado.
5. El primer fotograma del mezclador mide menos de 8 ms (doc 08).

## 3. Switch / Toggle

**Problema [V]:** proporción iOS con estado "off" M3 (pulgar gris pequeño y contorno). El "off" tiene poco contraste en la captura de conectividad.

| | Propuesta |
|---|---|
| **A** | Mismo tamaño; en "off", pista `tonalFill` sin contorno y pulgar `onSurfaceVariant` del mismo diámetro que en "on" |
| **★ B** | **Toggle gota**: pista de 44×26, pulgar de 22 px. Al cambiar, el pulgar se alarga (ya existe el estiramiento) y la pista "se llena" desde el pulgar como un líquido (gradiente que avanza con el mismo muelle) en lugar de cambiar de color de golpe. El estado on/off también se distingue por la posición y por una pequeña marca dentro del pulgar (check/raya) para quien no distingue colores |
| **C** | **[X]** Al encender, el pulgar suelta una microgota que corre por la pista. Solo en Ajustes (no en listas largas) |

## 4. Segmented / pestañas (0 componentes → 1)

**Problema [V]:** Mixer y Connectivity implementan cada uno su indicador. `LiquidSelection` pierde velocidad al redirigir [I].

| | Propuesta |
|---|---|
| **★ A/B** | `SegmentedControl` con modelo, rol `PageTabList`/`PageTab`, flechas y Inicio/Fin. Indicador con bordes de entrada y salida independientes pero sobre **`SpringValue`**, de modo que conserva velocidad. Es la mejora de tacto más barata del informe |
| **C** | **[X]** Indicador con forma de gota: al desplazarse se estrecha en el centro (cintura) como dos gotas que se unen. Reutiliza el SDF del cuello (`fluid_neck`). Se justifica solo si el cuello ya está cargado |

## 5. Riel de workspaces

**Estado [V]:** cápsula con indicador "pacman" lila y puntos; tres capas MultiEffect.

| | Propuesta |
|---|---|
| **A** | Mantener los estilos y retirar las capas MultiEffect fijas (el brillo se hace con un `Rectangle` con gradiente o con el propio color). Celdas de al menos 24 px de zona de clic |
| **★ B** | Estilo "**gota viajera**" por defecto: el activo es una cápsula que se desplaza con muelle; al cambiar de workspace se estira hacia el destino (borde de entrada rápido, borde de salida lento), igual que el `SegmentedControl` para compartir código. Los ocupados son puntos, los vacíos anillos y los urgentes laten una vez. Con rueda sobre el riel se cambia de workspace |
| **C** | **[X]** Miniaturas en hover: al pasar 400 ms sobre un punto, aparece una mini-vista del workspace (screencopy de Hyprland) en una gota que cuelga del riel. Requiere medir el coste de screencopy |

Pacman se mantiene como estilo opcional: tiene personalidad, pero no debe ser el que define la marca.

## 6. Pill central

**Estado [V]:** es el componente más logrado. La deuda está en `Pill.qml` (941 líneas), los bordes de `PillMaterial` y el formato de hora.

| | Propuesta |
|---|---|
| **★ A** | Respetar la propuesta pendiente: un solo borde en `PillMaterial`, permanencia del workspace en 1100 ms y notificación en dos líneas. Además, unificar el formato de hora con el ajuste `time12h` (o explicar el porqué en Ajustes) |
| **B** | **Estados de reposo con jerarquía**: reloj por defecto; con media, portada y título; con grabación, punto y tiempo; con temporizador de foco, un anillo. Prioridad declarativa en `IslandStatusAdapter` (ya existe) y como mucho un elemento secundario a la vez. Transición entre estados por fundido cruzado de contenido con la forma en muelle |
| **C** | **[X]** "Pill que respira con el sistema": la anchura en reposo varía ±1 px según la carga de CPU o audio. Descartable si distrae; requiere prueba de percepción |

Refactor recomendado (sin cambio visual): dividir `Pill.qml` en `PillState` (lógica), `PillRest` (reposo) y `PillNotify` (notificación), dejando `Pill.qml` como composición.

## 7. Superficies y tarjetas

**Problema [V]:** tarjeta dentro de tarjeta (mezclador), 5+ tarjetas propias y `GlassCard` casi sin uso.

| | Propuesta |
|---|---|
| **★ A** | Regla de un solo nivel: la surface es el nivel 0 y una lista o grupo es el nivel 1 (`tonalFill`). Dentro del nivel 1 no hay más rellenos: los combos y botones secundarios pasan a "ghost" (sin fondo hasta el hover). `GlassCard` se convierte en la única tarjeta |
| **B** | Filas de lista nativas (`IslaListRow`: icono, título, subtítulo, trailing) que sustituyen a la mitad de las tarjetas (dispositivos de audio, redes, portapapeles y notificaciones) |

## 8. Reproductor de media

**Estado:** excepción aprobada (Swiftify). **No se pudo ver en vivo** porque no había reproductor activo.

| | Propuesta |
|---|---|
| **★ A** | Conservar. Asegurar que la línea de tiempo (`SwiftMediaTimeline`, que ya tiene teclado y accesibilidad [V]) y los botones de transporte usan la familia de botones para el foco |
| **B** | Color de media extraído de la portada (paleta local de la carátula, no la de Matugen) **solo dentro** de la surface de media, con transición de color de 400 ms al cambiar de pista |

## 9. Notificaciones

| | Propuesta |
|---|---|
| **★ A** | Quitar `layer.enabled: true` permanente de `NotifCardView` y activar la capa solo durante el gesto de deslizar. Fila de lista (§7B) en el historial |
| **B** | Agrupar por app con contador y expandir con muelle (pila que se abre) |

## 10. Estados vacío, carga y error (0 → 3 componentes)

**★** `EmptyState` (glifo, título y acción opcional), `LoadingState` (tres puntos que respiran, *no* spinner) y `ErrorState` (`ErrorShake` más la acción "Reintentar"). El estado de Wi-Fi desactivado (captura) pasa a `EmptyState` con el botón "Activar Wi-Fi" en el centro, en lugar de depender solo del toggle de arriba.
