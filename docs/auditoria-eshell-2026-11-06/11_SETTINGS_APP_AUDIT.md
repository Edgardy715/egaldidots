# 11 · Auditoría de la app de configuración (Edots)

Fecha: 2026-11-06. Añadido tras detectar que las surfaces y el código de `bar/settings/` no estaban cubiertos en la primera entrega.

Leyenda: **[V]** verificado (captura o código leído) · **[I]** inferencia · **[X]** experimental.
**No se modificó ningún archivo funcional.**

## 0. Método y límites

- **Qué se hizo:** se abrió `settings-preview.qml` (ventana flotante de pruebas) con `ISLA_CONFIG` temporal, de modo que no se tocó la configuración real. Se capturó solo la región de esa ventana con `grim`. También se vio la ventana real de la shell en la página "Cuerpo".
- **Capturas [V]:** Apariencia, Composición, Movimiento, Tipografía, Tu perfil, Avanzado (parte superior), Cuerpo, y la búsqueda con 4 consultas (`idioma`, `hyprland`, `actualiz`, sin resultados).
- **No capturado:** Hyprland, Actualizaciones, Idioma y región como páginas completas; el selector de rutas; el desplegable del combo; estados de validación; el modo compacto; la barra de guardado con cambios pendientes; la parte baja de las páginas largas. El gancho de pruebas `edotsTest.page` limita el índice a 0–5 (`settings-preview.qml:12`) [V] y el teclado sintético no llegó a la ventana [V], así que no se pudo navegar a las páginas 6–9.
- **Ya existe material anterior** que no se reexaminó: `docs/settings-ux-2026-10-11/` (capturas de validación, tamaños y temas) y `docs/SETTINGS_APP_RESEARCH.md` (6 referencias). Esta auditoría lo complementa y no lo sustituye.
- **Datos personales:** las capturas están solo en el directorio temporal de la sesión.

## 1. Mapa

16 archivos y 3 373 líneas en `bar/settings/` [V]. Diez páginas en la barra lateral: Apariencia, Composición, Movimiento, Tipografía, Tu perfil, Avanzado, Hyprland, Cuerpo, Actualizaciones, Idioma y región [V `EdotsWindow.qml:97`].

| Pieza | Líneas | Papel |
|---|---|---|
| `SettingRow.qml` | 601 | Fila universal: toggle, slider, segmentado, texto, ruta |
| `EdotsWindow.qml` | 487 | Marco: cabecera, búsqueda, rail, guardado |
| `SettingsPage.qml` | 359 | Genera filas desde el esquema de `Settings.js` |
| `HyprlandPage.qml` | 301 | Página propia, fuera del esquema |
| `EdotsPathPicker.qml` | 251 | Selector de rutas |
| `UpdatesPage.qml` + `UpdateSourceCard.qml` | 453 | Actualizaciones |

El modelo es bueno: **las filas se generan desde el esquema** (`label`, `description`, `control`, `minimum`, `maximum`), con validación y borradores, y la vista previa es en vivo [V código].

## 2. Lo que está bien y debe conservarse

1. **Es la surface más accesible de la shell.** `Accessible.PageTab` y `selected` en el rail, `AlertMessage` al guardar, nombre y descripción en cada toggle y slider, atajos Ctrl+F, Ctrl+S y Escape [V código]. Es el patrón que el resto debe copiar (doc 08).
2. **Respeta `reduceMotion`** en 11 de sus 16 archivos [V]. Es la mejor cobertura del proyecto.
3. **Los controles ya son el lenguaje líquido que proponíamos.** El slider es un tubo de 26 px con relleno degradado, menisco de 1 px y pulgar que flota dentro del extremo; el switch estira el pulgar y lleva una marca de check [V `SettingRow.qml:196-262, 388-460`]. **Corrección a los docs 06 y 07:** el "slider de tubo" y el "toggle con marca" no son ideas nuevas, ya existen aquí. La propuesta pasa a ser *extraerlos* a `bar/kit/` y que el resto de la shell los use.
4. **Vistas previas con significado:** la tarjeta "Un escritorio que habla tu idioma" en Tipografía y la maqueta de barra en Composición [V captura]. Muestran el efecto antes de guardar.
5. **Búsqueda transversal** con títulos de grupo, recuento y "Limpiar búsqueda" [V captura].
6. **Filas deshabilitadas que explican por qué** ("Disponible parcialmente · edición desactivada") [V captura].
7. **Descripciones útiles y en tono propio** ("Nunca los mueve ni los borra") [V captura].

## 3. Hallazgos

### 3.1 Fallos verificados

| # | Hallazgo | Evidencia | Gravedad |
|---|---|---|---|
| S1 | **Controles numéricos sin entero ni unidad.** Solo 1 de 13 campos `control: "number"` declara `integer: true` [V `Settings.js:60`]. "Frecuencia ambiental" (30–240 fps) muestra "60.00" y "Comandos largos (segundos)" muestra "10.00" [V captura] | `SettingRow.qml:402` fija `stepSize: 0.01` si no es entero |  Alta |
| S2 | **Teclado inutilizable en esos sliders.** Con paso 0.01, recorrer 30–240 fps con las flechas exige unas 21 000 pulsaciones; 3–600 s, unas 59 700 [I, cálculo propio desde el rango y el paso] | `SettingRow.qml:402` | Alta |
| S3 | **"1 resultados"** [V captura] | `EdotsWindow.qml:286`, texto fijo `"%1 resultados"` sin plural | Baja |
| S4 | **Mensaje contradictorio en la búsqueda.** Con la consulta "hyprland" aparece un resultado (la tarjeta "Hyprland · Flujo y animaciones") y debajo "No hay ajustes que coincidan con la búsqueda" [V captura] | La ruta de páginas especiales no cuenta como ajuste | Media |
| S5 | **El rail sigue resaltando la página anterior durante la búsqueda.** "Avanzado" permanece en lila mientras se ven resultados de otras páginas [V captura] | `nav.current` depende de `root.page`, no de `searchShown` | Media |
| S6 | **Tres nombres de producto en la misma ventana:** título "Edots", salida "Volver a Isla" y el proyecto se llama Eshell [V] | `EdotsWindow.qml:190`, captura | Media (identidad) |

### 3.2 Inconsistencias con el resto de la shell

| # | Hallazgo | Evidencia |
|---|---|---|
| S7 | **Una cuarta y quinta implementación de controles.** Toggle propio frente a `components/Toggle.qml`; segmentado propio (radio) frente a las pestañas del mezclador y de conectividad. Eso hace **3 segmentados** y **2 toggles** [V] | `SettingRow.qml:196, 340-360` |
| S8 | **Hover con escala en lo más usado.** Pista del switch ×1.04 al pasar el puntero; pulgar del slider ×1.12/1.22 fuera del modo líquido [V código]. Va contra la regla "no escalar en hover" (doc 05 §3) | `SettingRow.qml:215, 441` |
| S9 | **Muelle de control con ζ bajo.** `controlSpring = min(5, 4/motionScale)` y `controlDamping 0.35`; el pulgar usa `damping: 0.5` [V]. Rebota más que el ~3 % aprobado para la pill [I] | `Motion.qml:84-85`, `SettingRow.qml:240` |
| S10 | **Literales:** `EdotsWindow` tiene 7 `pixelSize` y 3 `radius` literales; `IslandStudio` 10 `pixelSize`; `EdotsPathPicker` 4 `radius`; `SettingRow` usa `Qt.alpha("#ffffff", 0.3)` y `EdotsButton` otro hex [V recuento con `rg`] | `bar/settings/*.qml` |
| S11 | **Rail con relleno lila pleno** como indicador activo. Es la forma del indicador de la navegación lateral de Material 3 [V captura, I sobre la influencia] | Captura, `EdotsWindow.qml:234-245` |
| S12 | **Tres controles de botón** coexisten: `EdotsButton`, `EdotsComboBox` y `EdotsTextField` propios, sin relación con `CtrlBtn` ni `IslaTextField` [V] | Inventario, doc 02 |

### 3.3 Composición y arquitectura de información

| # | Hallazgo | Evidencia |
|---|---|---|
| S13 | **"Avanzado" reúne temas dispares** (archivos, rendimiento, actividades, dispositivos), aunque ya los separa en cuatro grupos con cabecera [V `EdotsWindow.qml:83-86`]. **Corrección:** no es un cajón de sastre sin estructura; el problema es solo la longitud de la página | Código |
| S14 | **Páginas con vacío o con densidad distinta:** Composición y Tu perfil ocupan un tercio de la altura y dejan casi la mitad vacía, mientras Avanzado y Apariencia exceden la ventana [V captura] | Capturas |
| S15 | **Dos páginas fuera del esquema** (Hyprland y Actualizaciones) con su propia maquetación, y 4 páginas con campos generados por `Object.keys` (Cuerpo y Actualizaciones) cuyas etiquetas no se pudieron revisar [V código, no observado] | `EdotsWindow.qml:107-110` |
| S16 | **"Cuerpo" tiene dos vocabularios:** "Cuerpo líquido", "agua", "gota", "respiración" en una lista plana de interruptores [V captura]. Los términos cuadran con la identidad, pero la jerarquía es solo la lista | Captura |
| S17 | **Compatibilidad estrecha:** el modo compacto se activa con menos de 760 px o con `fontScale > 1.35` [V `EdotsWindow.qml:60-62`]; el comportamiento real no se vio hoy (existen capturas de octubre) | Código |

## 4. Propuestas

Todas son QML nativo y respetan Matugen. Las alternativas siguen el formato de los docs anteriores: **A** conservadora, **B** moderna, **C** experimental, ★ recomendada.

### 4.1 Fila numérica (S1, S2)

| | Propuesta |
|---|---|
| **★ A** | Añadir al esquema `integer`, `step`, `unit` y `decimals` por campo y usarlos en el valor, el paso del teclado y el texto accesible. Ejemplos: `ambientFps` entero con paso 5 y unidad "fps"; `longCommandSeconds` entero con paso 1 y unidad "s"; escalas con paso 0.05 y dos decimales. Pulsar PageUp/PageDown cambia ×10 pasos. La prueba de esquema falla si un `number` no declara paso |
| B | Valor editable: al hacer clic en la cápsula del valor, se escribe el número (validado). El slider sigue para ajuste grueso |
| C | **[X]** Sliders con marcas en valores notables (30, 60, 120, 240 fps) con imán suave |

### 4.2 Navegación (S5, S11)

| | Propuesta |
|---|---|
| **★ A** | Durante la búsqueda, el rail atenúa la página activa (relleno al 40 %) y el título muestra "Resultados". Plural correcto (S3) |
| **B** | Indicador "gota viajera" compartido con `SegmentedControl` y el riel de workspaces: cápsula tonal que se desplaza con muelle, sin relleno lila pleno |
| C | **[X]** En búsqueda, el rail señala con puntos qué páginas contienen resultados |

### 4.3 Arquitectura de información (S13, S14, S16)

| | Propuesta |
|---|---|
| A | **Ya implementada:** "Avanzado" tiene cuatro grupos con cabecera |
| **★ B** | Reagrupar en siete páginas: **Apariencia** (Material, tamaño), **Barra** (Composición y gestos), **Movimiento**, **Texto** (Tipografía e Idioma y región), **Cuerpo**, **Sistema** (Rendimiento, Actividades, Dispositivos, Actualizaciones, Hyprland) y **Archivos y perfil**. Los campos no cambian; solo el mapa `pageFields` |
| C | **[X]** Una sola página larga con anclas y una vista previa de la pill siempre visible a la derecha |

### 4.4 Controles (S7, S8, S9, S10, S12)

★ Extraer el slider de tubo, el switch con marca, el segmentado y el campo de ruta de `SettingRow` a `bar/kit/` (doc 07) **sin cambiar su aspecto**, y que Ajustes los consuma. Quitar el hover con escala del switch y del pulgar, y pasar el muelle a `spring.firm` con ζ ≈ 0.7. Los literales de `EdotsWindow` e `IslandStudio` pasan a `type.*` y `shape.*`.

### 4.5 Identidad y estados (S4, S6)

- Unificar el nombre visible: "Ajustes de Eshell" en el título, o dejar "Edots" como submarca y usarlo también en la barra. Esa decisión es de producto y no está tomada [V].
- La tarjeta de página especial (Hyprland, Actualizaciones) cuenta como resultado y el mensaje de vacío solo aparece si el total es 0.

### 4.6 Nuevas interacciones

| Idea | Valor | Coste |
|---|---|---|
| Hover o foco sobre un ajuste de la pill resalta esa pieza en la pill real | Alto: cierra el círculo "ajuste → efecto" | Medio; requiere un canal de resaltado en la pill [X] |
| "Restablecer" por grupo con un solo gesto | Medio | Bajo |
| Vista previa del slider *mientras se arrastra* (ya existe para tipografía) | Medio | Bajo |

## 5. Matriz para estos hallazgos

La escala es la del doc 09. Se añaden como filas 21–26 a esa matriz (versión resumida aquí).

| # | Componente | Problema | Solución | Compl. | Riesgo | Rend. | Prior. | Confianza |
|---|---|---|---|---|---|---|---|---|
| 21 | Fila numérica | Sin entero ni paso: "60.00 fps", 21 000 pulsaciones [V] | Esquema con `integer`, `step`, `unit` (§4.1 A) | S | Bajo | Neutro | **P0** | Alta |
| 22 | Búsqueda y rail | "1 resultados", mensaje contradictorio y rail obsoleto [V] | §4.2 A y §4.5 | S | Bajo | Neutro | **P1** | Alta |
| 23 | Controles de Ajustes | Fuente de verdad sin extraer; hover con escala; ζ bajo [V] | Extraer al kit (§4.4) | M | Medio | Neutro | **P1** | Alta |
| 24 | Arquitectura de información | "Avanzado" cajón de sastre [V] | §4.3 B | M | Bajo | Neutro | **P2** | Media |
| 25 | Rail | Relleno lila tipo M3 [V, I] | §4.2 B | M | Bajo | Neutro | **P2** | Media |
| 26 | Nombre del producto | Edots, Isla y Eshell [V] | Decisión de producto | S | Bajo | Neutro | **P2** | Alta |

## 6. Efecto sobre los documentos anteriores

- **Doc 06 §2 y §3, y doc 07 §3:** el slider de tubo y el switch con marca deben presentarse como *extracción* de `SettingRow`, no como diseño nuevo.
- **Doc 09 #1:** el `IslaSlider` ya tiene su base en `SettingRow.qml:393`; la complejidad baja de L a M [I].
- **Doc 10 y 01:** Ajustes deja de figurar como "no capturado"; quedan sin capturar las páginas 6–9 y los estados de validación.
- **Doc 08:** Ajustes es la referencia de accesibilidad.

## 7. Estado de implementación (2026-11-06)

Hecho y subido (`feat(settings)`): S1/S2 (entero, paso y unidad), S3/S4/S5 (plural, vacío, rail en búsqueda), S11 (indicador tonal; verificado también en tema claro con una paleta hecha a mano), S8 (sin escala en hover del switch ni del pulgar).
S9 aplicado: muelle del pulgar del switch con `damping: 0.7` (antes 0.5), menos rebote; valor elegido por criterio, **sin medir** ni comparar en vídeo.
Fila 23 (parcial): `IslaSwitch`, `IslaSlider`, `IslaSegmented` e `IslaComboBox` (antes `EdotsComboBox`) viven en `bar/kit/`; `SettingRow` los usa. Verificado por capturas (Movimiento, Tipografía) y por `settings-controls-regression.qml` (PASS).
S10 (parcial): 26 alfas de primer plano pasaron a `Theme.alpha*`.
Pendiente: S10 (resto) (literales; el menisco `#ffffff` es un brillo especular intencionado y el tema no tiene token blanco), S6 (nombre, decisión de producto), fila 23 (extraer al kit), fila 24 (parcial, ver abajo).

Fila 24 (parcial): "Tipografía" e "Idioma y región" se fusionaron en "Texto" (10 → 9 páginas; la fusión toca la última página, así que no desplaza índices). Se probó con captura y con settings-navigation, updates, controls y companion (PASS). **No se hizo** el resto de las 7 páginas: Hyprland (índice 6) y Actualizaciones (8) son vistas propias con guardado y búsqueda específicos, y diez regresiones fijan índices; fusionarlas exige rediseñar esas vistas como secciones. `settings-ux-regression` (lastIndexOf de null) y `hyprland-settings-regression` (revert) fallan igual sin este cambio.

Fila 24 (segunda parte): "Tu perfil" se fusionó con "Avanzado" como "Perfil y sistema" (9 → 8 páginas; nombre visible y avatar van como sección "Perfil" al inicio). Índices nuevos: 0 Apariencia, 1 Composición, 2 Movimiento, 3 Texto, 4 Perfil y sistema, 5 Hyprland, 6 Cuerpo, 7 Actualizaciones. Se actualizaron las regresiones activities, hyprland-settings, updates y settings-navigation. Capturada la página 4. PASS: navigation, updates, controls, companion, module-composer. Fallan igual sin el cambio: settings-ux, hyprland-settings, activities (compare en TestCase:987) y settings-surface-switch.

Fila 24 (completa): 7 páginas. Hyprland y Actualizaciones pasan a ser pestañas de una página **Sistema** (General · Hyprland · Actualizaciones) con `IslaSegmented`; las vistas propias se conservan intactas, así que su guardado y su búsqueda no cambian. General recoge Rendimiento, Actividades y Dispositivos; la página 4 queda como Perfil y archivos. Índices: 0 Apariencia, 1 Composición, 2 Movimiento, 3 Texto, 4 Perfil y archivos, 5 Sistema (`systemTab`), 6 Amalgam. Se corrigió además una condición obsoleta (`page !== 6 && page !== 8`) del formulario. Capturadas las tres pestañas. PASS: navigation, updates, controls, companion, module-composer, settings. Fallan igual que antes: hyprland-settings (revert), activities (compare) y settings-ux (lastIndexOf).

## 8. Contraste con las referencias (añadido tras revisión)

- **Corrección al doc 05:** motion-primitives.com y uiverse.io **sí cargan en el navegador integrado** (la herramienta de lectura plana dio 403). Se comprobó: la home de motion-primitives y el catálogo de switches de Uiverse (460 componentes).
- **Animate UI, Switch (Radix):** pista de 32×18 px, pulgar de 16 px, estados por `data-checked` [V navegador y código]. La inspección por JavaScript no capturó el estiramiento del pulgar bajo `pointerdown`, así que **no se confirma** esa animación [no verificado].
- **Uiverse:** el catálogo es variado y mayoritariamente skeuomórfico o decorativo (interruptor de balancín, sol/luna, botón rojo); sirve de inventario de ideas, no de patrón de producto [V captura].
- **Sigue sin hacerse:** interacción real con sliders, tabs y segmentados de Animate UI, React Bits, Aceternity y Magic UI. Las propuestas de controles de Ajustes siguen apoyadas en el código propio y en `SETTINGS_APP_RESEARCH.md`, no en esa comparación.

### 8.1 Intento de comparación interactiva (2026-11-06)

- **Animate UI, Slider (Radix):** pista de 4 px, pulgar de 12 px, transición solo de color y sombra (0.15 s) [V medido en el navegador]. Es la geometría genérica de shadcn; el tubo de 26 px de Ajustes es más distintivo y no pierde frente a él [I].
- **Animate UI, Tabs:** existe un elemento `tabs-highlight` que se mueve entre pestañas (indicador compartido, el mismo patrón que `LiquidSelection`) [V DOM]. **No se pudo medir su curva**: el muestreo con `requestAnimationFrame` se detuvo porque el panel del navegador estaba en segundo plano (6 muestras en 6 s) [no verificado].
- **Magic UI, Aceternity, React Bits (solo catálogo, 2026-11-06) [V navegador]:** se listaron sus componentes de control; no se probó ninguno en marcha.
  - Magic UI: 158 entradas, sin switch, slider ni tabs; solo botones (Shimmer, Ripple, Pulsating, Interactive Hover), Dock y Theme Toggler. Poco útil para Ajustes.
  - Aceternity: 248 entradas; relevantes Animated Tabs, Notch, Sidebar, Stateful Button, Floating Dock. Sin switch ni slider.
  - React Bits: 469 entradas; relevantes Squish Switch, Rubber Segment, Wake Slider, Morph Slider, Elastic Slider, Pill Nav, Glide Select. Son los únicos con equivalentes directos de switch, segmentado y slider; candidatos a revisar si se rediseñan esos controles.
- **Sigue sin medirse** la curva del indicador de tabs de Animate UI ni el comportamiento de los componentes de React Bits. Las propuestas de controles de Ajustes siguen apoyadas en el código propio y en `SETTINGS_APP_RESEARCH.md`.
