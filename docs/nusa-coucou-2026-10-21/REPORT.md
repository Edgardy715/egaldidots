# Nusa × Coucou → oportunidades para Isla

Fecha: 2026-10-21. Investigación de referencias y propuesta; no implementación ni auditoría completa de accesibilidad. Las recomendaciones no sustituyen diseños aprobados.

## Conclusión

Isla ya posee un lenguaje físico propio. Su oportunidad es convertirlo en comportamiento reconocible: anticipar la acción, recibirla, confirmar su resultado y volver al reposo. Añadir rebotes a todos los controles o una mascota permanente produciría actividad, pero no necesariamente personalidad.

Dirección propuesta: **Isla es una materia tranquila que recibe, acompaña y devuelve lo que necesitas.** El usuario reconoce esa identidad por las respuestas del sistema, incluso sin logotipo.

## Alcance y evidencia

- Nusa: navegación de la demo oficial; estados Music, Shelf, Lyrics, Focus timer y Headphones, además del reposo inicial. Capturas vistas en navegador; inspección de HTML/CSS/JS. El repositorio público consultado contiene la web, no el código de la aplicación Windows. No se probaron archivos reales, reproductores ni recordatorios nativos.
- Fuente Nusa: https://rama2555.github.io/nusa/ y https://github.com/rama2555/nusa/blob/3fa95bf30bf469f74b4db4cdfbf49aaf2cc6750f/index.html. Fuente descargada en /tmp/nusa-index.html; SHA256 6bd4ad6eb69ff9fa75a366f44ec616a47aff10a315e75c06b739c84f4eda1f96. El SHA del repositorio se consultó durante la investigación; no se comparó byte a byte la descarga main con ese commit.
- Coucou: investigación independiente de código y documentación; detalles y revisión fijada en COUCOU-EVIDENCE.md. No ejecución de la aplicación nativa.
- Isla: código actual de Motion, InteractionMotion, MotionArea, SurfaceRouter, NotificationChoreography, VolumeChip, BatteryChip, IslandStatusAdapter, OsdOverlay y contratos de arquitectura/movimiento. Captura histórica music-playing.png de docs/compact-audit-2026-10-18 vista como referencia de composición, no como prueba del runtime actual.
- Se preservan las modificaciones preexistentes. No pruebas de FPS/CPU, hardware, DnD nativo ni lector de pantalla.

## Nusa: qué observé

La demo conserva una misma silueta anclada al borde, con tamaños por tarea y revelado de contenido retrasado. El morph usa 620 ms y una Bézier con sobrepaso; no demuestra un resorte físico. Shelf representa recepción mediante luz localizada, deformación y aparición de la tarjeta. El temporizador privilegia la cifra y una acción principal; auriculares usa una confirmación menor. Música y letras comparten un cuerpo que se ensancha. El sitio anuncia ojos en reposo, recordatorios, tareas y archivos; Windows sigue presentado como próximo lanzamiento. La demo simula archivos, barras y letras. Su promesa de CPU nula en reposo no está verificada. En el JS, Shelf sigue solicitando frames mientras ese estado está seleccionado; desactivar CSS mediante prefers-reduced-motion no acredita detener ese Canvas.

### Lo que esto sugiere para Isla

**Jerarquía de tamaños.** Una conexión breve, una tarea sostenida y un panel de exploración no merecen la misma amplitud. Propondría tres niveles: señal compacta, vistazo accionable y surface completa. El tamaño tendría relación con la decisión que el usuario necesita tomar.

**Recepción física de archivos.** La característica atractiva no es una bandeja rectangular: es la sensación de que el destino acepta el objeto. En Isla encaja con el contrato de captura de las gotas. La luz debe representar que un archivo es admisible; la confirmación debe seguir al éxito real, nunca adelantarse a un fallo de lectura o guardado.

**Despliegue por necesidad.** Música básica y letras extensas pueden ocupar espacios diferentes sin convertirse en aplicaciones distintas. Nuestro reproductor ya tiene letras, portada, ambiente y visualizador; conviene conservar el diseño Swiftify aprobado. La oportunidad sería un vistazo breve opcional cuando la música está cerrada, sujeto a comprobar que aporte algo frente al compacto actual.

**Foco como actividad persistente.** Un temporizador tiene sentido porque atraviesa el trabajo sin exigir mantener su panel abierto. Su progreso puede vivir en una gota o indicador compacto; el final puede ser un único gesto reconocible. No hace falta un gestor de productividad completo.

**Reposo con intención.** Propondría calma y menor densidad antes que ojos. El reloj y los estados importantes deben seguir disponibles. Un reposo expresivo no debería esconder información esencial ni introducir un bucle constante.

## Coucou: qué aporta a la dirección

Su mayor contribución es la correspondencia entre estado funcional y actitud. La implementación inspeccionada distingue trabajo, pensamiento, solicitud, error y finalización; el carácter cambia para ayudar a interpretar esos estados. Además, protege las solicitudes que necesitan respuesta de los comportamientos ambientales.

Hay cuatro mecanismos especialmente trasladables:

1. **Origen de apertura explícito:** hover permite mirar; clic expresa compromiso. El cierre tiene tolerancia para que cruzar hacia un control no cierre el panel. En Isla se podría ensayar un vistazo antes de tocar la apertura persistente.
2. **Continuidad de identidad:** el objeto animado permanece vivo durante cambios de presentación. Confirma la decisión existente de Isla de conservar geometría y velocidades al retargetear.
3. **Arrastre con histéresis:** distintos umbrales de entrada y salida evitan que el destino oscile cuando el cursor roza el borde. La velocidad también interviene en la captura.
4. **Atención con memoria:** una actualización de una solicitud ya visible no vuelve a tratarse como una urgencia nueva. La restauración de foco forma parte de completar la interacción.

No todo conviene trasladarlo. Un repertorio de bromas responde bien a un compañero explícito, pero puede estorbar en una shell de uso frecuente. Los tiempos de SwiftUI son referencia de intención, no calibración QML. El reloj físico y la política de movimiento reducido requieren revisión propia; el detalle técnico, inferencias y permalinks están en [COUCOU-EVIDENCE.md](COUCOU-EVIDENCE.md).

## Comparación con el estado real de Isla

| Área | Evidencia actual | Oportunidad |
| --- | --- | --- |
| Física y continuidad | Motion, motor Fluid, retarget y captura documentados | Conservar; dar significado distinto a anticipación, recepción y cierre |
| Controles | MotionArea/InteractionMotion ya implementan hover, foco, presión y reconocimiento de click | Separar reconocimiento de click de éxito real de la operación |
| Música y letras | Swiftify aprobado, CAVA, paleta, metadatos y letras | No rehacer; estudiar mirada breve sólo si resuelve una necesidad |
| Volumen/brillo/mic | VolumeChip integrado, agrupación de eventos en IslandStatusAdapter; OsdOverlay como fallback | Extender coherentemente señales existentes, no añadir otro OSD |
| Carga/batería | BatteryChip ya muestra feedback temporal | Tomarlo como punto de partida; no venderlo como función ausente |
| Notificaciones | NotificationChoreography suspende/revela surfaces y ejecuta un ciclo de morph | Evaluar tratamiento menos intrusivo para eventos de baja prioridad |
| Archivos temporales | Sin DropArea/Drag ni ruta Shelf en las áreas/catálogo inspeccionados | Prototipo acotado de bandeja; aún falta verificar DnD entre clientes Wayland |
| Temporizador de trabajo | Sin panel/servicio correspondiente en catálogo y fuentes inspeccionados | Función nueva pequeña con progreso persistente |
| Sesiones de agentes IA | Sin integración equivalente en las áreas inspeccionadas | Módulo posterior si forma parte del uso habitual |

Estas ausencias se acotan a las áreas inspeccionadas: no son una afirmación sobre todo archivo externo o script personal.

## Propuestas concretas

### 1. Una gramática de respuesta compartida

Cada gesto debe responder a una causa:

- **Disponibilidad:** hover o foco revela que se puede actuar; hit target fijo.
- **Compromiso:** la pulsación comprime sólo la parte visual.
- **Trabajo:** estado pendiente explícito, sin fingir éxito.
- **Recepción:** un cambio breve confirma que Isla recibió el resultado.
- **Cierre:** la superficie devuelve el foco y recupera su forma desde el estado actual.

Ejemplo: guardar un elemento del portapapeles no acaba en el brillo del click. Cuando el servicio confirma el guardado, el resumen puede asentarse y el destino quedar identificado. Si falla, se conserva la selección y aparece recuperación. El movimiento responde al dato.

Reutilizar MotionArea, InteractionMotion y ContentMotion. Añadir sólo feedback de resultados concretos que hoy lo necesiten; no construir primero un framework universal.

### 2. Bandeja temporal de archivos

Flujo mínimo propuesto: arrastrar al destino → destino admisible visible → soltar → confirmar recepción → conservar referencias visibles → sacar el archivo o retirarlo de la bandeja.

Personalidad: leve tensión en el borde de recepción, luz interior acotada al punto de entrada y asentamiento al completarse. El texto no se estira. No reproducir literalmente el efecto ni recursos de otra marca.

Contrato funcional: añadir a la bandeja no mueve ni borra el original; retirar un elemento elimina la referencia. Nombres, número de archivos y errores legibles. Escape cancela. Alternativa de teclado para añadir y retirar. Definir referencias frente a copias antes de implementar persistencia. Primer prototipo sin archivo personal real.

Riesgo principal: una demo convincente no demuestra drag-and-drop entrante y saliente entre Quickshell y aplicaciones Wayland. Probar primero dos clientes representativos y múltiples archivos; diseñar el acabado después de acreditar transporte y semántica.

### 3. Un vistazo que no interrumpe

Propuesta para conexión de auriculares o resultado de una acción: icono, nombre y estado en una franja breve; acceso al detalle sólo si el usuario lo solicita. Un evento informativo no debería desmontar lo que estás usando.

Antes de cambiar arquitectura, probar una ruta informativa existente. Notificación crítica y autenticación conservan prioridad. La interacción activa manda sobre decoración y mensajes de baja prioridad. No convertir un hover accidental en apertura de un panel completo; cualquier vistazo debe tener acceso equivalente por teclado.

### 4. Temporizador compacto

Una duración, iniciar/pausar/cancelar, progreso y final. Contar a partir de una fecha de término, no descontando ticks como fuente de verdad. Definir suspensión del equipo y recuperación tras reinicio antes de prometer persistencia.

Durante la sesión: señal pequeña. Al finalizar: un asentamiento o apertura única y aviso silenciable. Movimiento reducido conserva resultado legible. Evitar añadir tareas, estadísticas, hidratación y hábitos en la primera versión.

### 5. Personalidad sin mascota obligatoria

Explorar un pequeño repertorio propio: recibir, asentir, esperar y descansar. La materia de Isla ya permite expresarlo mediante tensión, luz interior y postura de la silueta. Una misma familia debe servir tanto a clipboard como a conectividad.

Si más adelante se elige personaje, tendría que ser original, opcional y subordinado al contenido. No desplazar reloj/media ni responder a todo movimiento del cursor. Primero comprobar si los gestos sin personaje ya aportan la calidez buscada.

### 6. Actividad de agentes, como módulo posterior

Un indicador de trabajando / requiere atención / terminado, con origen, proyecto y salto al contexto. Empezaría sólo con lectura de estado de una integración autorizada y un formato pequeño de eventos.

Aprobar comandos es una segunda función con consecuencias propias: requiere sesión inequívoca, comando completo, vigencia y respuesta al origen correcto. No inferir autorización del color o de una mascota. No adoptar chat, voz, finanzas y sincronización móvil como parte necesaria de la shell.

## Qué conservar y qué evitar

Conservar Theme/Matugen, vidrio, tipografía y sistema Fluid. La personalidad no requiere una paleta azul-violeta fija ni reemplazar nuestros iconos. El reproductor ya tiene una expresión propia; la cohesión se lograría compartiendo reglas de respuesta, no uniformando todos sus dibujos.

Evitar: ojos permanentemente activos, pulso global infinito, sonido para cada hover, carruseles que escondan funciones principales, hacer a la pill seguir el cursor y escala del texto durante la deformación. También evitar sumar servicios sólo porque la referencia los enumera.

El sonido, si se explora, debe ser original y acotado a resultados que merezcan atención, con silencio y control de volumen. No es requisito de una primera fase.

## Orden recomendado y aceptación

| Orden | Entregable | Señal de aceptación |
| --- | --- | --- |
| 1 | Prototipo de respuesta semántica en una acción existente | Se entiende qué ocurrió; error conserva contexto; teclado/reduced equivalentes |
| 2 | Prueba técnica de bandeja temporal | Entrar/sacar archivos funciona entre clientes Wayland sin mover originales |
| 3 | Acabado de recepción y vistazo breve | No interrumpe panel/input; cancelación y eventos consecutivos no producen saltos |
| 4 | Temporizador | Exactitud tras ocultar/suspender según contrato; final único y accesible |
| 5 | Módulo de agentes opcional | Sesión correcta, atención identificable y actualización finita; sin permisos implícitos |

Para cada cambio visual: normal/reduced, ocultación, retarget/reapertura, teclado, escalas y ambos layouts. Medir consumo con el módulo visible/oculto antes de afirmar mejoras. No hace falta ejecutar estas pruebas para este informe: no se ha cambiado código funcional.

## Límites y licencias

Coucou distingue código MIT de assets reservados; ver investigación independiente. Usar principios y mecanismos generales con identidad y recursos originales. Para Nusa no se estableció una licencia que permita reutilizar código o arte: tratarlo como referencia, sin copiar recursos.

No se midió rendimiento de ninguna app nativa ni se instaló software. No se ha hecho QA actual del shell ni una auditoría completa de cada servicio. Esta investigación sustenta una dirección y prototipos verificables, no una promesa de que toda función de las referencias se pueda trasladar sin trabajo específico.
