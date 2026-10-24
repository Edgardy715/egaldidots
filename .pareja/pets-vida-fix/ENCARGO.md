# pets-vida-fix: correcciones de la revisión de «más vida» (ronda 1 de 2)
Encargo corto y finito: lee SÓLO bar/pets/PetActor.qml, bar/pets/PetLayer.qml, bar/windows/IslandOverlay.qml
(alrededor de las líneas citadas) y bar/pets-regression.qml. No cargues PROJECT_MEMORY ni TASK_STATE.
AHORRA CONSUMO: no explores el repo, no intentes Wayland/grim (tu sandbox no puede; lo ejecuta Claude),
no regeneres el paquete, no repitas validaciones que no cambian. Corrige y prueba sólo offscreen
(`WAYLAND_DISPLAY= python bar/tests/pets.py`).

## Correcciones (revisión independiente, verificadas leyendo código)
1. **doze colgado** (PetActor.qml ~481, 446, 430-433, 323): si `mood` cambia a "music" o se activa
   reduced motion durante `doze`, `pending` queda true, `sleepTimer` parado y `musicStart` bloqueado.
   Debe limpiarse `pending` (y rearmarse el sueño si procede) al interrumpirse doze por cualquier
   `play()` ajeno, cambio de mood o reduced. La música sigue sin despertar a una mascota ya dormida.
2. **Throttle de mirada** (PetLayer.qml ~98): un cambio de lado dentro de 250 ms se descarta sin
   aplicarse luego. Debe aplicarse la última dirección pendiente al vencer la ventana
   (timer imperativo, sin `running:` ligado; coste cero si no hay pendiente).
3. **Posición vieja del puntero** (IslandOverlay.qml ~318-321): `onHoveredChanged` usa
   `pill.pointerX` antes de actualizarse. Usa la posición del propio evento/handler.
4. **`pillDirection` obsoleto** (PetLayer.qml ~98, 346): al interrumpirse la mirada, limpia
   `pillDirection` para que volver a idle con el puntero del mismo lado vuelva a mirar.

## Pruebas (pets-regression.qml)
- doze interrumpido por música y por reduced motion: pending false, vuelve a dormirse/base.
- cambio de lado dentro de 250 ms acaba mirando al último lado.
- mirada interrumpida y retomada del mismo lado vuelve a mirar.
- `transfer()` usa `jumpHeight` y respeta `minimumY` (prueba de integración, no sólo la función).
- tras `wake` se reproduce la reacción esperada (react/look_up/love según afterWake).
Mutación: revierte cada corrección 1–4 y confirma que una prueba falla; restaura.

## Archivos permitidos
bar/pets/PetActor.qml, bar/pets/PetLayer.qml, bar/windows/IslandOverlay.qml, bar/pets-regression.qml,
bar/tests/pets.py. Nada más. Invariantes: timers imperativos, umbrales 0.95, coste cero oculta/dormida.

## Informe final (breve, ≤150 palabras)
ESTADO / ARCHIVOS / PRUEBAS (comando → resultado) / DUDAS. Sin commit ni push.
