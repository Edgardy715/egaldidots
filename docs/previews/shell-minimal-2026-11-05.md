# Shell más limpia: auditoría de todas las surfaces (2026-11-05)

Revisión en vivo de las 18 surfaces (captura de cada una en el escritorio 9, sin datos personales en el repo).
Sustituye a la nota anterior sobre la pill sola (`pill-minimal-2026-11-05.md`), que queda integrada en «Pill».

## Regla común

La carga no viene del vidrio ni de la gota. Viene de **decir lo mismo dos o tres veces** y de **texto de ayuda fijo**.
Tres reglas para toda la shell:

1. **Cada dato se dice una vez.** Si el estado ya se ve en un control (interruptor, botón marcado, contador), no se repite en un subtítulo, una etiqueta ni un pie.
2. **El pie sólo habla cuando hay algo nuevo:** error, progreso o advertencia. «Los cambios se aplican al instante» o «Todos los cambios están guardados» no aportan nada en reposo.
3. **Los atajos de teclado no se quedan en pantalla.** Siguen funcionando y siguen en `Accessible.description`; quien usa el teclado ya los conoce.

## Aplicado en esta fase (texto y visibilidad, sin cambiar geometría ni movimiento)

| Surface | Antes | Ahora |
|---|---|---|
| Overview | Fila «← → elegir ↵ abrir esc cerrar»; «Vacío» en cada escritorio libre | Sin fila de atajos; el escritorio libre no lleva etiqueta |
| Sesión | «← → Elegir · Esc Cerrar» junto a «Bloquear» | Sólo «Bloquear» |
| Portapapeles | Pie «Clic o Enter · copiar» | Sólo el contador de elementos (y «Esc · volver» en detalle) |
| Sonido | Pie «Los cambios se aplican al instante.» | Pie vacío salvo progreso, perfil o aviso de >100 % |
| Enfoque | «Sesión temporal · se descarta al reiniciar Isla» siempre | Sólo el aviso de minutos fuera de rango |
| Fondos | Pie «Ya es tu fondo · ← → para explorar otros» y «← → navegar · Intro o doble clic para aplicar» | Pie sólo con progreso, éxito o error; el botón «Aplicado/Aplicar» ya dice el estado |
| Conectividad | Wi-Fi apagado dicho tres veces (pestaña, fila, estado vacío con instrucción) | El estado vacío conserva el icono y el título, sin la instrucción |

## Propuestas pendientes (gusto o estructura; ordenadas por impacto)

1. **Ajustes (Edots): barra inferior sólo cuando hay cambios.** Hoy muestra siempre «Todos los cambios están guardados» y dos botones desactivados. Propuesta: la barra entra con el `LiquidFill` existente cuando hay vista previa y sale al guardar. Libera ~56 px y quita los dos controles muertos. Archivo: `bar/settings/EdotsWindow.qml` ~430–470.
2. **Ajustes: descripciones bajo demanda.** Cada fila lleva título y descripción de una o dos líneas. Propuesta: descripción sólo en filas no evidentes (las que hoy pasan de 60 caracteres), el resto en `ToolTip`. También quitar el subtítulo «Tu Isla, a tu manera» y el icono repetido junto al título de la página (ya está en la barra lateral). Archivos: `SettingRow.qml`, `EdotsWindow.qml:152`.
3. **Fondos: una sola marca de «actual».** Hoy coinciden la etiqueta «Fondo actual» sobre la vista previa, la marca ✓ en la miniatura y el botón «Aplicado». Propuesta: dejar la ✓ y el botón; quitar la etiqueta. Quitar también el subtítulo «35 fondos disponibles», porque el contador «8 / 35» dice lo mismo. Archivo: `WallpaperView.qml:164, :426`.
4. **Sonido: menos cabecera.** Subtítulo «3 salidas · 2 entradas» más encabezado «Dónde quieres escuchar» más las pestañas: tres niveles antes del primer control. Propuesta: quitar el encabezado de sección (las pestañas ya nombran la página). Archivo: `MixerView.qml:93, :195`.
5. **Bordes anidados.** Notificaciones (triple borde: panel, tarjeta, icono), Enfoque (dos niveles), Ajustes rápidos (tarjetas dentro de tarjeta) y Ajustes (tarjeta de sección dentro del panel). Propuesta: un único nivel con borde; lo de dentro se separa por espacio y tono de fondo. Archivos: `NotifsView.qml:55, :97, :197`, `FocusTimerView.qml:53, :142`, `QuickControlsView.qml:67, :158, :414`.
6. **Calendario y clima: menos etiquetas pequeñas.** Hoy hay «Ahora mismo», «Actualizado 16:18», «Sensación 33°», «Humedad» y «Viento» en 11 px. Propuesta: agrupar en una línea («Lluvia · sensación 33° · 64 % · 18 km/h») y mostrar «Actualizado» sólo si los datos son viejos. Archivo: `CalendarView.qml:533–600`.
7. **Pill.**
   - El aviso de workspace ya es sólo un número que rueda; está hecho.
   - **Pendiente:** bajar la espera de 1600 a 1100 ms.
   - **Pendiente:** tarjeta de notificación en dos líneas, sin el aro del icono.
   - **Pendiente:** un solo borde en `PillMaterial.qml`; hoy hay tres (:94, :135, :216).
8. **Escritorios (rejilla 1–10).** El rótulo «Espacio 9» repite la celda resaltada. Propuesta: quitarlo.

Orden recomendado: 1 → 3 → 5 → 2 → 4 → 6 → 7 → 8. El 1 y el 5 son los que más se notan.
