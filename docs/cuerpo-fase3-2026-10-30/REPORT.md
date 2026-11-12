# Cuerpo · Fase 3 · 2026-10-30

Estado: aplicado en la pill real y cargado en Wayland. Autorización: «Intenta aplicar la 3».

## Resultado y decisiones

- Opción A del plan: `PillBody` presenta el shader en reposo y entrega el fondo a `PillMaterial` con un fundido interrumpible de 100 ms. Surfaces internas/externas, notificaciones, cambios de layout, uniones/capturas Fluid y retorno de altura usan el material existente.
- `PillMorphMotion` conserva ancho/alto. El cuerpo toma esa geometría y añade desplazamientos expresivos acotados; no crea otro propietario del layout. Viewport con margen de 90×escala, sin ampliar la máscara de entrada ni añadir handlers de clic. `IslandOverlay.qml` conserva su hash anterior.
- Retirados visualmente ojos de header/perch mediante gate legado desactivado. Se conserva reloj y estados de actividad/grabación. El toggle existente `appearance.personality` ahora se llama Cuerpo; no cambia el formato persistente.
- Reducir movimiento detiene respiración y fundidos; reducir transparencia, desactivar superficies líquidas/Cuerpo, renderer software o fallo del shader recuperan el material existente. Oculto o sin exposición no corren relojes ni integraciones inducidas por cambios de geometría/puntero.
- Revisión independiente Sol/medium encontró refreshes estando inactivo: corregido `BodyEngine.refresh`, conservando `manualStep`. Reproducción independiente posterior: advanceCount permanece 0 al cambiar ancho/puntero oculto. Sin otros hallazgos materiales. No se ejecutó revisión Claude.
- En Wayland la sombra exterior del shader producía una segunda placa por el blur del compositor. Nuevo uniforme `outsideOpacity` por defecto 1 conserva demos; composición de producción usa 0. Shader recompilado y shell reiniciada porque reload conserva caché qsb. No se cambió la configuración del compositor.

## Evidencia

Logs en este directorio, inspeccionados por PASS y ausencia de FAIL/ERROR (QtTest puede devolver exit=0 tras un fallo):

| Comprobación | Resultado |
|---|---|
| Node body-brain / body-drop | PASS: brain.log / drop.log |
| Motor y shader fase 1 + gota fase 2, offscreen RHI OpenGL | PASS: body.log / body-drop.log |
| Composición y política de entrada | PASS: composition.log / input.log |
| Integración real Pill, offscreen RHI | PASS: integration-rhi.log |
| Integración real Pill, Wayland | PASS: integration-wayland.log |
| Fallback software | PASS: fallback.log |
| qmllint adaptador/shader/Pill/regresión | PASS: lint.log |
| verify-config.sh | PASS: config.log |

Integración cubre shader Compiled, propiedad de geometría, entrega de material, inversión del fundido, calendario abrir/cerrar, Fluid, layout, compact y escala 1.5, opacidad cero, oculto, movimiento/transparencia reducidos y desactivación. La medición espera al morph de arranque/avisos reales: el ancho del header puede cambiar por su cuenta.

QA nativa de producción: `rest.png`, `calendar.png`, `return.png` inspeccionadas. Calendario abierto por IPC y cerrado al terminar; material expandido intacto, cuerpo recuperado, sin placa exterior. Shell reiniciada con carga correcta; no errores de QML/shader en el log de producción. Avisos de portal DBus y textinput Wayland del entorno no impiden las pruebas.

## Límites y siguientes fases

- Gota mensajera/archivo siguen aislados en demo. Eventos reales (Cava, hora del día, foco, descargas/notificaciones) y limpieza/opciones específicas del antiguo grupo Iris: Fase 4. En esta fase la luz usa la hora predeterminada del motor, no el reloj real.
- Respiración sigue como excepción del plan a reposo sin loops: Timer 33 ms; se detiene con movimiento reducido. Toggle específico de respiración pendiente de Fase 4.
- QA temporal exhaustiva, vídeo de 20 s, segundo monitor y tema claro no verificados aquí: Fase 5. No se certifica continuidad de todos los cuadros con capturas estáticas.
- Árbol previamente sucio preservado; sin commit/push. `status-before.txt` y hashes anterior/final delimitan evidencia. Sin cambios de política de entrada, servicios externos ni archivos reales.
