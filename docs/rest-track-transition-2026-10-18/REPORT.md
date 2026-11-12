# Transición de pista en reposo · 2026-10-18

Petición: transición fluida y premium en compacto y normal sin abrir el player.
Se conserva la identidad de Isla y el reproductor aprobado.

- Portada: compresión leve (límite7%, recorrido real menor en el impulso corto),
  respuesta SmoothedAnimation Motion.standardSmall y retorno tras Motion.press.
  Identidad título/artista evita reactivar por una URL tardía; mismo álbum
  también responde. El próximo gesto parte de la compresión actual.
- Nueva imagen entra4px desde abajo con el fundido Motion.standard existente;
  imagen anterior retenida hasta decode. No hay hueco transparente de salida.
- Metadatos funden en200ms de Motion.standardSmall con traslado4px. Colas de
  imagen/texto existentes conservan el último destino ante cambios rápidos.
- Progreso, hit targets, tamaño de decodificación y señal CAVA intactos.
- Movimiento reducido, transiciones deshabilitadas, ocultación y panel expandido
  cancelan la compresión y el timer. Reabrir no reproduce pistas anteriores.

Opt-in en IslandMediaSummary desde CompactMediaStatus y en cover/metadata del
FluidMediaCompanion. ArtworkImage y CrossfadeLabel conservan swapTravel0 por
defecto; no se impone esta coreografía a player, calendario, overview o fondos.

Validación: rest-media-transition-regression Wayland PASS: dos composiciones,
interrupción rápida, imagen final, misma portada, geometría estable, reducido
en vuelo, disabled, hidden/reopen y opt-out expandido. Capturas01–04 conservan
estado inicial, transición, retarget y llegada. Son muestras de escena Wayland
con captura irregular, no una grabación completa ni FPS.

Integración compact-island completa en Wayland PASS tras los cambios.

media-presentation.py con HTTP local PASS: retención con carga lenta, última URL,
respuesta obsoleta, ambiente compartido, metadata, error, hidden y reduced;
prueba opt-in del reposo se ejecutó aparte. qmllintQt6 y verify-config exit0,
diff-check PASS; avisos heredados de acceso no cualificado permanecen. Revisor
independiente sin nuevos hallazgos en defaults/cancelación.

Se corrigieron durante validación dos intentos fallidos: control imperativo de
animación hija de Behavior y cambio de destino con start mientras ya corría.
La versión final usa animación independiente, restart desde valor actual y
stop explícito al cancelar. No se certifica continuidad física de velocidad.

SinFPS/GPU/AT-SPI ni cambio de reproducción personal. Valoración perceptual final
pendiente del usuario; las imágenes intermedias muestran superposición de glifos
propia del fundido, no se presentan como estados finales.
