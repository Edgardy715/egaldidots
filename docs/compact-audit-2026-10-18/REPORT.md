# Auditoría del modo compacto · 2026-10-18

Auditoría de código, geometría, interacción y movimiento de la composición compacta
actual. Se conserva el motor Fluid, Theme/Matugen, la composición central y el
reproductor aprobado. Configuración temporal en todas las pruebas; no se cambió
la configuración personal, reproducción, red ni acciones de sesión.

## Hallazgos y correcciones

| Prioridad | Defecto | Causa y resultado |
|---|---|---|
| P2 | Un rail oculto robaba ancho a música | Se reservaba por lifetime aunque no cupiera. Presupuesto mínimo independiente de `fits`; la música recupera su ancho cuando el rail se retira. Reproducción independiente: 20 espacios/400px; regresión: 30/500px. |
| P2 | Títulos cortos desaparecían | El ancho natural dejaba menos de64px a metadatos, que entonces se ocultaban. Reserva mínima legible; «Sol / Ana» permanece visible. |
| P2 | Hueco vacío con poco ancho | El mínimo76px no permitía mostrar texto. Ahora reserva36px para portada sola por debajo de112px. |
| P2 | Escala de texto ignorada en música | Tamaños13/11 constantes tanto en medición como dibujo. Ambos usan tokens de Theme, comprobados a1.5. |
| P2 | Música sin foco visible y con dos paradas equivalentes | Un único target para portada/texto/espectro, contorno de foco y activación por Enter o puntero en toda la fila. |
| P2 | Selección de espacio invadía vecinos | Círculo28px en celdas comprimidas de19px. Selección integrada limitada a la celda; estilos y motor originales conservados. |
| P3 | Separadores cortaban antes que módulos | Su visibilidad dependía inmediatamente de `presented`. Su opacidad sigue ahora exposición de los grupos adyacentes. |
| QA | Fixture podía salir0 después de un FAIL propio | Las aserciones personalizadas ahora salen1; asentamiento comprueba ancho y alto. Capturas de reposo esperan también opacidad del reloj. |

Archivos: `bar/components/{TopBarModules,CompactMediaStatus,TopWorkspaceRail}.qml`,
`bar/compact-island-regression.qml` y documentación de pruebas.

## Movimiento y evidencia

Dueños: PillMorphMotion para dimensiones/radio; OptionalModule para retirada y
revelado; TopWorkspaceRail para selección; BarLayoutTransition para cambio de
host. No se añadió otro motor ni se modificaron tiempos físicos aprobados.

Se muestrearon72 imágenes de escena renderizada en Wayland: dos aperturas y dos
cierres de calendario,18 muestras por recorrido. Aperturas examinadas entre
68–1295ms y78–1279ms; cierres entre73–1238ms y74–1226ms. La captura introduce
intervalos irregulares (aproximadamente65–89ms), por lo que no representa todos
los fotogramas ni permite medir FPS. `frame-samples.log` conserva tiempos y
geometría; `motion-contact.png` resume24 muestras. Originales temporales en
`/tmp/isla-compact-audit/frames/`.

En los recorridos muestreados no se observa inversión accidental de dimensiones,
contenido de panel fuera de su recipiente ni estado invadiendo el reloj al volver.
En el segundo cierre, la forma llega a1065.21×56 a492ms y la exposición del estado
pasa0.410→0.835→0.933→0.978→0.996→1 entre492–825ms. La aserción de separación
con el reloj se verifica en cada muestra interactiva. Retarget a60/160/330ms y
activar movimiento reducido en vuelo pasan con configuración temporal.

Esto acredita geometría y las imágenes examinadas, no continuidad de cada frame
presentado. Las capturas de escena no incluyen el blur final del compositor.
Se inspeccionó además captura nativa del escritorio; la sesión personal está en
split, por lo que la QA compacta se realizó con fixtures Wayland aisladas.

## Validación

| Comprobación | Resultado |
|---|---|
| compact-island ampliada, offscreen y Wayland | PASS: límites1100/620px, muchas apps, texto largo/corto, fuente1.5, rail sobredimensionado, teclado/puntero, música/ausencia/pausa, paneles, inversiones y reducido |
| layout-motion, Wayland | PASS: ambas composiciones,11 surfaces no destructivas, transferencia de media y reduced motion |
| layout-interruptions, Wayland | PASS: notificación durante panel/cambio de diseño, desaparición/reaparición de música, inversión rápida y OSD |
| top-workspace-motion, offscreen | PASS: seguimiento, retarget, reposo, reducido y ocultación |
| optional-modules, offscreen | PASS: lifetime, retirada, inversión, entrada, ocultación temporal y reducido |
| verify-config.sh | PASS: configuración, límites de componentes y calculadora |
| qmllint Qt6 | exit0; advertencia preexistente del tipo genérico Loader.item.playing en fixture |
| Revisión independiente Sol/medium | Detectó reserva de rail; corrección revisada sin nuevos hallazgos sustentados |

Hubo una primera aserción intermitente de altura al volver, sin reproducción
estable en producto; la fixture esperaba ancho pero no alto. Se reforzó la espera
en ambos ejes y se repitió en Wayland/offscreen. No se atribuye un bug al motor
sin evidencia adicional. El qmllint antiguo de `/usr/bin` falla sin diagnóstico;
se usó `/usr/lib/qt6/bin/qmllint`. Avisos de `.face` ausente, registro de servidor
notificaciones ocupado por la shell real y Qt Wayland textinput quedan en logs;
no impidieron los PASS y no se presentan como defectos corregidos.

La primera captura de texto grande coincidió con el giro del minuto del reloj.
Diagnóstico aislado posterior: mostrado37/entrante37/travel0/alto56/sin animación;
`large-text-settled.png` conserva la apariencia asentada. No se modificó el reloj
por una captura transitoria.

## Mejoras de uso y diseño propuestas

1. **Priorizar lectura frente a aplicaciones secundarias.** Cuando la música
   pierda el título, reducir primero el grupo de apps a unas pocas y overflow,
   conservando audio/red/batería. Hoy cada lateral recibe la mitad del presupuesto;
   repartir sobrante entre lados aprovecharía mejor monitores estrechos. Requiere
   revisar prioridades de uso antes de sustituir la composición existente.
2. **Conservar el acceso a espacios al saturar el rail.** Un modo de sólo botón
   de overview cuando no caben todas las posiciones evitaría retirar el grupo
   completo. No inventar posiciones ni sustituir WorkspaceModel sin probar IDs
   dispersos y navegación del compositor.
3. **Hacer explícita la portada sola.** Tooltip con título/artista y estado de
   reproducción para el caso comprimido, manteniendo un solo control y el
   nombre accesible ya presente. Evitar añadir transporte permanente: la
   composición actual reserva esas acciones al panel.

Son propuestas de evolución, no requisitos incumplidos ni cambios ya aplicados.
La prioridad inmediata fue corregir pérdida de información, foco y solapes.

## Límites

Sin medición de FPS/GPU/CPU, grabación completa con PTS, AT-SPI/lector de pantalla,
varios monitores físicos, escalado fraccional ni acciones reales de red/energía.
Música de fixture determinista; no se alteró la reproducción personal. Escala
visual1 y fuente1.5 probadas; no se certifica cualquier combinación de fuentes,
tema y resolución. No se declara ausencia absoluta de bugs. Se preservó el
archivo ajeno no rastreado `docs/PROJECT_MEMORY_ARCHIVE-2026-10-18.md`.

Ahorro aplicado: memoria selectiva, un revisor independiente reutilizado para su
mismo alcance, logs recuperables y pruebas agrupadas por riesgo. No se midió ni
se afirma ahorro porcentual de cuota.
