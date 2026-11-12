# Isla frente a escritorios maduros: diseño y movimiento

Fecha: 2026-10-26. Revisión de trabajo basada en HEAD `1b0ead1` y archivos locales sin commit; los hashes de las fuentes examinadas están en `source.sha256`. No se modificó código de producto ni configuración personal.

## Dictamen

Isla ya tiene identidad y una base de movimiento avanzada. El siguiente salto consiste en convertir esa calidad en una experiencia predecible en todas las tareas y condiciones: respuesta útil temprana, continuidad temporal bajo carga, legibilidad, accesibilidad y coherencia entre superficies. Añadir efectos por sí solo no resolvería esas brechas.

No hay fundamento para asignarle un porcentaje de madurez frente a macOS. Tampoco se midieron ambos escritorios en hardware equivalente. La comparación utiliza principios de diseño e interacción y evidencia local, no una clasificación de rendimiento.

## Qué está conseguido y conviene conservar

- `Motion.qml` y `MOTION_LANGUAGE.md` definen una gramática explícita: duración por intención, geometría compartida, continuidad, interrupciones y movimiento reducido.
- `PillMorphMotion.qml` conserva posición y velocidad al cambiar de destino. `PillSurfaceHost.qml` separa geometría, carga y exposición del contenido. Hay pruebas específicas para cierres durante cambios y contenido persistente al redimensionar.
- La barra actual tiene una silueta reconocible y contenida. En la captura nativa de Sonido, título, pestañas, salida predeterminada y controles tienen jerarquía comprensible. No se observa una ausencia general de diseño.
- Existen tokens semánticos, temas claro/oscuro, escala tipográfica, nombres accesibles y componentes con soporte de teclado. Las capturas históricas de Edots incluyen tema claro y texto ampliado. No procede recomendar construir todo esto desde cero.
- Iris y las gotas aportan una identidad propia. Su personalidad puede convivir con rapidez y sobriedad; no hay evidencia que justifique eliminarlas.

## 1. Dar prioridad a la disponibilidad del contenido

**Evidencia histórica y código actual.** El registro de materialización del 25 de octubre documenta t90 de aproximadamente 250–360 ms, asentamiento al 1 % de 480–630 ms y hasta 700–740 ms para el mixer con criterio de 0,5 px. La propia fase registra objetivos excedidos. Las hojas de captura muestran un tramo inicial de superficie casi vacía antes de que el contenido sea legible. El host actual combina exposición por geometría con revelado de carga y retirada entre superficies.

**Juicio de diseño.** Esa coreografía puede sentirse agradable en una demostración y demasiado ceremoniosa en una acción repetida. Buscar una aplicación o cambiar una salida de audio necesita transmitir disponibilidad antes de que termine toda la cola del muelle. El problema no es que cualquier animación de 600 ms sea incorrecta: importa cuánto espera el usuario para leer, escribir y actuar.

**Siguiente paso.** Medir por separado entrada→respuesta visible, entrada→campo enfocado, entrada→control utilizable y asentamiento. Probar la escritura inmediata y cambios rápidos entre paneles. Ajustar coordinación y revelado antes de recortar todas las duraciones. Un objetivo inicial propuesto sería feedback en el siguiente cuadro disponible y contenido principal utilizable durante los primeros 200–250 ms cuando ya esté cargado; no es un estándar universal ni una medición actual.

## 2. Conservar el tiempo real cuando llegan cuadros tarde

**Hallazgo reproducido con el componente actual.** `PillMorphMotion.step(dt)` limita cada avance a 1/30 s antes de subdividirlo. Eso evita pasos numéricos grandes, pero descarta el tiempo transcurrido que exceda ese límite. La prueba `frame-step.qml` llama al componente real con frecuencias sintéticas constantes, sin renderizar una escena:

| Actualizaciones simuladas/s | t90 del ancho | Fin de integración |
| --- | ---: | ---: |
| 144 | 264 ms | 694 ms |
| 60 | 267 ms | 700 ms |
| 30 | 267 ms | 700 ms |
| 20 | 400 ms | 1050 ms |
| 10 | 800 ms | 2100 ms |

**Implicación.** Si la entrega de cuadros cae, el movimiento además se alarga en tiempo de reloj. Esto es un límite demostrado del integrador, no una afirmación de que el escritorio esté funcionando actualmente a 20 FPS. La prueba tampoco mide latencia del compositor o presentación física.

**Siguiente paso.** Definir una política explícita para cuadros tardíos: recuperar tiempo con subpasos acotados o resolver el tramo mediante un método adecuado al muelle asimétrico existente. Hay que conservar estabilidad y velocidad al interrumpir. No sustituir ciegamente el motor por otro muelle de parámetros constantes. Validar cuadros aislados de 50–100 ms además de frecuencias constantes.

## 3. Convertir los tokens en reglas de composición

**Observación visual y recomendación.** Sonido y calendario comparten material y color, pero resuelven la tarea con densidades distintas: Sonido presenta una lista operativa y controles; el calendario da gran protagonismo a la fecha y reserva un bloque amplio para clima. En la captura actual, ese bloque está consultando datos. No es un fallo de red demostrado ni una razón para eliminar el clima.

El paso de madurez es definir qué elementos comparten contrato: cabecera, acción primaria, navegación, selección, estados secundarios y pie. Compartir radios y colores no determina por sí solo qué debe llamar primero la atención. Tampoco obliga a que todas las superficies tengan la misma plantilla.

**Siguiente paso.** Comparar tareas y estados, no componentes aislados: salida de audio, búsqueda, selección de fecha, conectividad, guardado. Para cada uno, comprobar que se identifiquen tarea y acción principal sin explorar el panel, y que los datos secundarios no desplacen el control principal al llegar. Conservar las diferencias deliberadas del reproductor aprobado, sin extenderlas automáticamente al resto.

## 4. Material y accesibilidad como comportamiento completo

**Evidencia estática.** El esquema expone opacidad del vidrio, profundidad, intensidad de estado, escala de texto y reducción de movimiento. No declara en esos ajustes un perfil semántico específico de alto contraste o reducción de transparencia. Eso no prueba la ausencia de cualquier adaptación externa. Los botones de navegación del calendario definen objetivos de 28×28 multiplicados por la escala y usan `MotionArea`; tienen nombre accesible y soporte de entrada compartido.

**Brecha.** Falta acreditar que el material siga siendo legible sobre fondos claros, detallados o de alto contraste y que las tareas completas funcionen con teclado y asistencia. No se midieron ratios de contraste en esta auditoría ni se probó un lector de pantalla. Tener `Accessible.name` no acredita por sí solo una experiencia accesible completa.

**Siguiente paso.** Probar fondos adversos y temas claro/oscuro con estados normal, foco, seleccionado y deshabilitado; revisar objetivos de entrada sin agrandar necesariamente el dibujo del control. Definir una variante de material legible y predecible para quien necesite menos transparencia. Validar aumento de texto y escala de interfaz de forma independiente.

## 5. Cerrar detalles editoriales visibles

**Observado hoy en Wayland.** El calendario muestra `MONDAY`, `October 2026` y abreviaturas inglesas junto a `Clima`, `Humedad` y `Consultando clima…`. El código usa `Qt.locale()` para fechas y cadenas españolas para otros textos. Puede ser el resultado del locale de esta sesión, pero la mezcla es real en la experiencia capturada.

**Siguiente paso.** Adoptar una política de idioma coherente entre fechas, textos, formatos, atajos y estados de carga/error. Estos detalles tienen poco espectáculo y mucho efecto sobre la sensación de producto terminado. No fijar español en todo el código para resolver sólo esta captura.

## 6. Coordinar el escritorio más allá de la pill

**Límite de alcance.** Isla es una shell de Quickshell. El compositor gobierna ventanas y espacios de trabajo, y las aplicaciones conservan sus propios controles y toolkits. `SHELL_ARCHITECTURE.md` documenta esa separación y la integración con Hyprland. Esta auditoría no demuestra incoherencias concretas en todos esos límites.

**Requisito para competir como experiencia completa.** Hay que evaluar secuencias de extremo a extremo: abrir desde launcher, cambiar de workspace, pasar a fullscreen, recibir una notificación, volver al panel y bloquear/desbloquear. Origen espacial, foco, cancelación, escala, cursor y ritmo deben seguir siendo comprensibles al cruzar esas fronteras. La shell puede mejorar su integración, pero no puede imponer por sí sola la composición interna de cada aplicación.

**Siguiente paso.** Establecer una matriz pequeña de recorridos reales con GTK, Qt y una aplicación Electron. Documentar qué gobierna Isla, qué gobierna el compositor y qué depende de cada aplicación. La integración visual necesita contratos y pruebas; no requiere escribir un sistema operativo nuevo.

## 7. Validar la percepción además de las invariantes

**Evidencia.** Las regresiones actuales de materialización, cambio/cierre y contenido retenido pasan con marcador PASS explícito. Las capturas de cuadros del 25 de octubre son irregulares y no prueban FPS. El soak de rendimiento del 23 de octubre sí terminó: 241 muestras durante dos horas, con `possible_reload: true`; no debe describirse como una ejecución todavía pendiente. Su existencia tampoco acredita frame pacing o estabilidad de todas las animaciones actuales.

**Siguiente paso.** Obtener una línea base de intervalos de presentación y respuesta de entrada en el hardware real, con carga, distintos refrescos y uso prolongado. Registrar percentiles y cuadros tardíos; separar CPU, memoria y GPU del tiempo que tarda una tarea en responder. Validar con interacción física después de las regresiones. Una captura bonita y un PASS numérico responden preguntas distintas.

## Orden recomendado

1. **Respuesta y tiempo:** medir disponibilidad útil; resolver la pérdida de tiempo del integrador y comprobar interrupciones.
2. **Acabado común:** idioma, objetivos de entrada, jerarquía y estados de carga/error en las tareas frecuentes.
3. **Legibilidad e integración:** matriz de material, accesibilidad y recorridos entre shell/compositor/aplicaciones.
4. **Personalidad:** afinar intensidad y frecuencia de efectos con las tareas ya rápidas y legibles. Conservar lo aprobado; añadir efectos sólo cuando ayuden a comprender o disfrutar una interacción concreta.

## Evidencia, reproducción y límites

- Fuentes: Motion, Theme, Settings, PillMorphMotion, PillSurfaceHost, CalendarView, MotionArea/MotionButton; revisión independiente acotada de launcher, Quick Controls y muestras de Settings. `source.sha256` identifica el subconjunto principal. El árbol contiene muchos cambios ajenos sin commit; no se alteraron.
- PASS actuales en `regressions.log`: `surface-materialize-regression`, `surface-swap-close-regression`, `content-hold-regression`, usando configuración temporal y plataforma offscreen. No son QA visual.
- Reproducción del cuadro tardío: `ISLA_CONFIG=/tmp/isla-frame-audit.json QT_QPA_PLATFORM=offscreen timeout 10s qs -p docs/design-competition-2026-10-26/frame-step.qml`; exigir `FRAME_STEP` y `PASS`, no sólo exit 0. El harness tiene una importación absoluta propia de este workspace; ajustarla al trasladarlo. `frame-step.log` conserva salida y advertencias de objetos sin escena, esperadas en esta prueba numérica.
- QA nativo actual: barra de la sesión y fixture `bar/surface-materialize-capture.qml` en Wayland, configuración/Iris temporales, capturas de calendario y Sonido asentado. El fixture se detuvo. No se comprobó la interacción física ni la ubicación del overlay productivo abriendo cada panel. Las capturas completas contienen otras ventanas personales y quedaron en `/tmp/isla-design-audit-20261026/`, fuera de este informe.
- Evidencia histórica: `docs/surface-materialize-2026-10-25/`, `docs/settings-latency-2026-10-22/`, `docs/claude-audit-2026-10-22/REPORT.md`, `docs/performance-2026-10-23/`. Los fallos históricos ya corregidos no se presentan como activos.
- No hubo revisión exhaustiva de cada superficie, lector de pantalla, contraste medido, captura de todos los cuadros, benchmark macOS/GNOME o prueba multimonitor. Las recomendaciones de composición están identificadas como juicio de diseño, no como fallos automatizados.
- Se utilizó el contexto de Impeccable para una revisión nativa general; no se ejecutó su detector web ni se emitió una puntuación heurística formal: no acredita QML/Wayland. Su contexto avisa que interpreta la plataforma nativa del proyecto como web; no se alteraron los metadatos por esa limitación.

## Referencias externas

- [Apple: Animate with springs](https://developer.apple.com/videos/play/wwdc2023/10158/): continuidad de posición/velocidad, interrupciones y uso de muelles con o sin rebote. Isla ya incorpora parte de esos principios.
- [GNOME HIG: Accessibility](https://developer.gnome.org/hig/guidelines/accessibility.html): nombres accesibles y validación con contraste alto, texto grande, teclado y lector de pantalla.

No se extraen reglas de milisegundos universales de estas referencias ni se confunden sus recomendaciones con una medición comparativa del producto.
