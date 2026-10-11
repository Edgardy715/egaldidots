# Edots: mejora integral de UI y UX

Solicitud: aplicar UI/UX Pro Max a Configuración. Contexto: utilidad de escritorio QML/Quickshell, identidad Theme/Fluid Island y seis páginas existentes. Se aplicaron los criterios pertinentes a esta plataforma; la búsqueda inicial de sistema visual mezcló landing/SPA wellness, por lo que no se persistieron esas recomendaciones. El resultado Productivity Tool y las reglas generales de jerarquía, formularios y accesibilidad sí encajan. No se cambiaron fuentes/paleta personales ni se añadieron dependencias.

## Criterios y resultado

| Criterio | Cambio o evidencia |
| --- | --- |
| Accesibilidad | Campos con nombre/descripción, error asociado, iconos decorativos ignorados, foco visible en campos inválidos y combos, tabs con selección semántica. Guardar enfoca el primer error y desplaza campo y motivo dentro del viewport. AT-SPI real pendiente. |
| Interacción | Botones principales, reset, switches, slider y navegación con área mínima44px; hover/press y teclado nativo conservados. Guardar queda deshabilitado sin cambios; progreso/feedback no se ocultan tras mensajes obsoletos. |
| Rendimiento | Se conservan controles/componentes y tokens; no dependencias ni nuevos timers de producto. Previews ceden espacio cuando no caben; listas pequeñas sin virtualización adicional. Sin profiling de CPU/GPU. |
| Estilo | Vidrio/acento dinámico y familia de iconos existentes. Jerarquía coherente y una acción primaria Guardar. Composición amplia evita duplicar los mismos módulos en el formulario. |
| Adaptación | Navegación 6 columnas o 3×2; márgenes y ritmo se compactan en altura baja. Preview de movimiento/perfil/tipografía no compite con campos en tamaños reducidos. Todos los ajustes siguen accesibles en formulario/búsqueda; 640×560 y 1000×700 probados. |
| Tipografía/color | Theme incorpora error semántico para fondos claros/oscuros; controles y ayudas escalan con fontScale, letras grandes no salen de Guardar. Contraste calculado ≥4.5:1 para texto principal/secundario/error en dos paletas de prueba. No certifica cada wallpaper/paleta arbitraria. |
| Movimiento | Motor/continuidad existente preservado; reducedMotion y salida/retarget/estado oculto verificados. Capturas asentadas; sin auditoría fotograma a fotograma. |
| Formularios | Errores de ruta en español, resumen claro y enlace Revisar ajuste. Validación del servicio sigue vigente. Foco revela errores incluso desde otra página; conserva borradores. Búsqueda vacía ofrece Limpiar búsqueda. |
| Navegación | Seis destinos existentes, perfil directo, Ctrl+F/Ctrl+S/Escape y borrado de búsqueda. Foco y shortcuts ocultos siguen cubiertos por settings-surface-switch. |
| Charts/datos | No aplicable: no gráficos analíticos en esta app. |

El selector de archivos también adapta texto, sidebar, preview y acciones a espacio/letra grande. Las dimensiones móviles, safe areas iOS/Android y requisitos web no se trasladaron mecánicamente a una shell de escritorio.

## Pruebas

- `ux.log`: fixture nueva con todas las páginas, dos dimensiones, escala1/1.75, ancho real del texto Guardar, estado/feedback, errores ocultos, campo y error dentro de scroll, estado vacío, selector compacto y contraste dark/light.
- `controls.log`: selección de fuentes por puntero/teclado, entrada custom, popup limitado, edición, switch/slider y restauración de módulos.
- `picker.log`: miniaturas/preview, confirmación archivo/carpeta, URLs y Escape a escala1 y1.75.
- `integration.log`: IPC, escritura atómica, watcher, inválidos retenidos, descarte y conflicto real con cambios externos; usa configuración temporal.
- `surface-switch.log`: 13 destinos, borradores/popups, Ctrl+S oculto, escritura/foco y retarget en split/compact y normal/reduced.
- `native-input.log`: Escape Wayland por wtype y liberación de teclado en 14 superficies sin Auth.
- `neighbors.log`: settings-motion y settings-regression PASS. config-draft aislada sin escritor externo sólo llegó DRAFT_READY; el PASS real está en integration.log.
- `gate.log`: verify-config PASS. `qmllint.log`: Qt6 exit0 con advertencias dinámicas/unqualified existentes. diffcheck PASS.
- Capturas `page-0..5`, tamaños/font, validación normal/compacta, vacío, paletas y selector inspeccionadas en Wayland. Picker captura sólo contenido sobre transparencia, por lo que esa imagen sirve para geometría y no para medir el contraste del popup compuesto.
- Revisión independiente cerró texto Guardar fuera del fondo, error técnico en inglés y motivo oculto en compacto; capturas oscuras recapturadas tras asentar movimiento.

Una tanda lanzó settings-layer-picker como si fuera autoejecutable y alcanzó timeout: es host IPC manual (`controls-picker-initial.log`), no evidencia de fallo del producto. Cobertura de popup real en surface-switch y path-picker. No certificación de accesibilidad con lector real, multimonitor, hardware táctil ni rendimiento medido. Configuración personal recargó sin errores y nunca se guardó desde fixtures.
