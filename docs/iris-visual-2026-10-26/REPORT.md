# Iris: primer refinamiento visual · 2026-10-26

Se amplían ligeramente los ojos en reposo y el trazo de la sonrisa, se mejora el contraste de la pupila y el gesto curioso abre los ojos con el resorte existente. Se conserva el color adaptado al tema, la lógica de movimiento reducido y la ausencia de un bucle de reposo. El cambio es deliberadamente pequeño: no representa un rediseño integral ni una evaluación completa del movimiento.

`before.png` y `after.png` muestran la misma vista previa nativa Wayland ampliada; `real-size.png` muestra la escala real. Son capturas de un fixture, no de la sesión completa. Las pruebas offscreen personality (incluida la apertura de curiosidad) e iris-delight pasaron para colores lógicos claro/oscuro, visitantes, mirada, interrupciones y suspensión. La prueba personality nativa falló por tiempo al esperar el retorno de firefly tanto con el componente anterior como con el nuevo; al ampliar temporalmente ese margen llegó más lejos pero falló al esperar el fin de pat. Se restauró el tiempo original: no se ha identificado la causa ni se declara validación nativa completa.

Pendiente: comprobar interacción y continuidad de cuadros en una sesión real, más composición y legibilidad con temas y escalas adicionales.
