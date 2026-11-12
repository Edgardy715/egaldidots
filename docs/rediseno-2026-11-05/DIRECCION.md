# Isla · rediseño integral (2026-11-05)

Petición: rediseñar toda la shell para que se vea y se sienta mucho mejor sin perder la
identidad (pill de vidrio líquido que se transforma). Cada cambio lleva su fundamento.
Evidencia «antes»: 14 capturas de superficies en el scratchpad de la sesión (contienen el chat
de fondo y datos personales: no se copian al repo).

## Diagnóstico (medido)

| Problema | Evidencia | Por qué empeora la sensación |
|---|---|---|
| Cada superficie tiene su propia cabecera | Sólo 5 de ~18 vistas usan `SurfaceHeader`; los títulos van de 18 a 24 px (Mixer 24, Conectividad 22, Fondos 18) | Gestalt de semejanza: si lo mismo no se ve igual, el ojo lo lee como cosas distintas y la shell parece un collage |
| 17 tamaños de letra, muchos a 1 px | `Theme.fontSize*`: 9,10,11,12,13,15,16,17,18,20,22,24,28,30,34,40,52 | Escalones de 1 px no crean jerarquía, crean ruido; 9–10 px está bajo el mínimo legible (HIG macOS: 11 pt para texto secundario) |
| Radios casi iguales y no concéntricos | 8, 9, 10, 12 px dentro de superficies de 18–40 px | Apple (WWDC25, *Meet Liquid Glass*): las esquinas internas son concéntricas a las externas; si no, la forma «baila» |
| Tarjeta dentro de tarjeta, borde dentro de borde | `GlassCard` lleva borde + sombra propia dentro de un vidrio que ya tiene borde y sombra; halo exterior a 7 px en `PillMaterial` | Vidrio sobre vidrio es el anti-patrón explícito de Liquid Glass; Material 3 separa por tono, no por trazo |
| Brillos en cada control activo | `layer.enabled` + `MultiEffect` en Toggle, Slider, IconTile, Batería, MaterialIcon, Avatar, GlassCard | Cada brillo es una textura fuera de pantalla más un desenfoque; visualmente compite con el único acento que debería mandar |
| Dos superficies para lo mismo | «Espacios» (rejilla 1–10) y «Tus escritorios» (overview) | Ley de Hick: más rutas para la misma tarea = más decisión, nada más |
| Superficies vacías a pantalla grande | Media sin reproductor abre 560 px para decir «Ningún medio disponible» | Una superficie que no tiene tarea no debe abrirse; basta con la respuesta de la pill |
| Memoria | 515 MB RSS al arrancar (Quickshell vacío en esta GPU: ~250); 722 MB tras 2 h | Objetivo 4 GB de RAM: cada FBO y cada componente cargado sin uso cuenta |

## Principios de la nueva Isla

1. **Una gota, una voz.** Todo nace de la pill y vuelve a ella. Una sola gramática de superficie:
   título a la izquierda (20 px, semibold), como mucho una acción a la derecha, contenido debajo.
   Sin «X»: Esc, clic fuera y la propia pill cierran (la X en la esquina es el objetivo más lejano
   del cursor, ley de Fitts, y repite lo que ya hace el gesto).
2. **Escala tipográfica de 6 pasos** (≈ razón 1,2): 11 · 13 · 15 · 20 · 28 · 40 (+ números
   grandes 34 y portada 52). Mínimo 11 px.
3. **Esquinas concéntricas.** `Theme.concentric(radioExterior, margen)` = radio interno; los
   controles pequeños son cápsulas (alto / 2).
4. **Profundidad por tono, no por trazo.** Un solo borde por superficie (el del vidrio). Lo de
   dentro se separa por espacio y por un relleno tonal suave, sin borde ni sombra propios.
5. **Un acento por superficie.** El acento marca la selección o la acción principal; el resto
   es neutro. Sin brillos en controles: el estado lo dicen el relleno y la posición.
6. **Movimiento que responde.** Se conserva el muelle de geometría aprobado el 25-10
   (rebase ≈ 3 %, 90 % a ≈ 260 ms, cierre más rápido y sin rebote): medido, ya cumple
   Kowalski (< 300 ms) y Apple (`.snappy`). Lo que sobra es el movimiento *secundario*:
   pulsos de halo, escalas de brillo y bucles que no comunican estado. Contenido: entra con
   la forma (12–40 % del crecimiento), nunca espera al final del morph.
7. **Ligera.** Componentes que sólo existen mientras se ven; sin texturas fuera de pantalla para
   adornos.

## Fuentes

- Apple HIG: Typography, Materials, Layout; WWDC25 «Meet Liquid Glass» (concentricidad, sin vidrio
  sobre vidrio); WWDC23 «Animate with springs» (response/dampingFraction).
- Emil Kowalski, *review-animations* (skill instalada): frecuencia, < 300 ms, asimetría,
  interrupción.
- Material 3: elevación tonal.
- Qt: `Item.layer` crea una textura fuera de pantalla por elemento (memoria + pasada extra).
