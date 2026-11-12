# Cuerpo · Fase 5 · 2026-10-30

Aplicada por petición «Sí, Fase 5». QA temporal en vivo, interrupciones, tema claro,
ánimos/horas, multimonitor/bloqueo y rendimiento en reposo. Sin commit/push.

## Resultado

- Vídeos continuos de la shell real (`qs -d`, DP-1 1920×1080, grim ~27 fps + ffmpeg con
  duraciones por fotograma): `fase5-live-1.mp4` (23 s, sin hover) y `fase5-live-2.mp4`
  (con hover sobre pill y gota). Guion en `events.log`: oferta → hover pill → hover gota →
  entrega → calendario a mitad de entrega → cierre → sin segunda entrega.
- Recogida continua: salida, viaje, regreso, fusión y brote acoplado en ~2 s (`sheet-pickup.png`).
  Entrega completa desde la gota acoplada (`sheet-deliver.png`).
- Interrupción nativa: abrir calendario a mitad de entrega retira la gota en un fotograma
  ~80 ms antes de que el panel cubra ese punto; el archivo vuelve a la gota acoplada sin nueva
  recogida (`sheet-interrupt-fine.png`). Límite menor aceptado, no corregido.
- Reload de la shell durante la recogida: misma PID, sin errores, archivo descartado y sin gota
  residual (`after-reload.png`).

## Defectos encontrados y corregidos

1. **Bulto despegado con archivo guardado.** El modo `stored` ensanchaba el núcleo del motor a
   132·k; en la pill el bulto de atención quedaba ~60 px fuera del cuerpo visible
   (`zoom-hover-pill.png`). `BodyEngine.storedWidens` (demo true, PillBody false) y
   `BodyDropBrain.prepare` respeta `widen:false`.
2. **Atención que viajaba desde x=0.** Al primer hover el bulto cruzaba la pill desde la izquierda.
   `BodyBrain`: la atención nace en el puntero cuando parte de cero.
3. **Volteo del bulto con el puntero dentro del cuerpo.** La dirección normalizada saltaba (y +35 px
   en un fotograma). La dirección se escala por `max(dist, hh)`: dentro del cuerpo no se
   normaliza y el brote vuelve al núcleo sin voltearse. Tras 1–3: `zoom-hover-fixed.png`, estable.
4. **Tema claro ilegible.** El vidrio del cuerpo era casi negro fijo y el contenido usa
   `Theme.foreground`: en claro, reloj oscuro sobre negro. Nuevo uniform `colBase` en
   `body.frag`/`BodyShader` (default el negro anterior); PillBody usa `Theme.cardBot` sólo con
   tema claro y la refracción se mezcla en vez de sumarse sobre bases claras. Oscuro idéntico.
   `light-dark-after.png` (offscreen RHI, evidencia de color, no QA visual). La captura previa
   no se conservó; mostraba «6:34 PM» casi invisible sobre la pill negra.

## Ánimos, horas y música

`demo-moods-hours.png` (body-demo Wayland, `ISLA_BODY_TEST=1`, paleta clara temporal):
curiosa, curiosa con atención, contenta, tímida, dormida, auto, 06 h, 18 h, 02 h y música.
Las formas responden como en Fase 1. La demo conserva el vidrio oscuro de la página de
referencia; el tema claro de producción se verifica con PillBody (punto 4).

## Multimonitor y bloqueo

- Sólo DP-1 conectado: multimonitor **no verificable** en vivo. Revisión de código: un Pill/
  PillBody/BodyMessenger por pantalla (Variants), consumidor Cava por `screenName`, archivo
  ofrecido e IPC `bodyOpen` dirigidos al monitor enfocado. Límite: con el archivo en DP-1 y el
  foco en otro monitor, `bodyOpen` no lo abre (el clic sobre la gota sí).
- Bloqueo **no probado en vivo** (bloquear interrumpiría al usuario). La shell no recibe estado de
  bloqueo (lockscreen es otro proceso). Con respiración apagada (default) el reposo no tiene
  temporizadores periódicos; con `bodyBreath=true` el Timer de 33 ms seguiría durante el bloqueo.
  Fullscreen sí detiene el motor (opacidad de la pill → `running=false`).

## Rendimiento en reposo (§8)

`bar/tests/gpu-recording.py` prueba el grabador, no carga GPU; se midió con `nvidia-smi pmon`
(GPU NVIDIA que sirve DP-1) y ticks de `/proc` durante 20 s:

| Caso | CPU proceso | GPU proceso (pmon) | GPU global |
|---|---|---|---|
| Shell real, reposo, respiración off | 3,35 % (toda la shell) | sin muestras (≈0) | 31,7 % (Hyprland y otro proceso) |
| Probe pill, respiración off | 0,65 % | sin muestras | 30,1 % |
| Probe pill, respiración on | 6,6 % | 17 % en 2/20 muestras (≈1,7 % medio) | 29,9 % |

Presupuesto < 2 % GPU: cumplido con respiración off; con respiración on el promedio estimado
queda en el límite y la medida por proceso de pmon es gruesa. El coste de composición de
Hyprland para la capa no se puede aislar con estas herramientas.

## Pruebas

- PASS Node: `body-brain` (nueva: atención sin viaje y brote estable con puntero dentro;
  falla con el código anterior), `body-drop`.
- PASS RHI offscreen: `body`, `body-drop`, `body-messenger` (nuevo: sin ensanche en host pill;
  reduceMotion a mitad de recogida y de entrega), `body-pill` en paleta oscura y clara
  (nuevo: `colBase` sigue al tema). Logs `test-*.log`. qmllint sólo con la advertencia
  previa `state` en BodyEngine.

## Límites

- La shell real usa la caché qsb anterior hasta reiniciar `qs`; en tema oscuro el resultado es
  idéntico. Tema claro en vivo no verificado.
- La entrega real abrió el PNG de prueba en Brave (xdg-open); la ventana
  «isla-fase5-fixture.png - Brave» quedó abierta en el workspace 1.
- Sin revisión independiente de estos cambios. Cambios ajenos conservados; sin commit/push.
