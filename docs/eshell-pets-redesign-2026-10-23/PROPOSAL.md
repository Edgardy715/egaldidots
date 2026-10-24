# Eshell Pets — rediseño (propuesta para aprobar)

Fecha: 2026-10-23. Estado: **diseño pendiente de aprobación; no hay código nuevo**.
Sustituye la dirección de `docs/ESHELL_PETS_PLAN.md` (fases 1–4 de Codex).
Imágenes en `design/`; fuentes del dibujo en `design/src/` (regenerables con
`python design/src/build.py` y `mock.py`). Las maquetas son composiciones sobre
capturas antiguas, no QA: la QA real llegará con `grim -o DP-1` en cada fase.

## a) Primera mascota: Mimo, brote isleño

Piedrecita de espuma marina con un brote de dos hojas. Contorno de 1 px, 7
colores indexados, lienzo 20×20 con línea de apoyo en la fila 18. Se dibuja a
escala entera (×2 por defecto: unos 24×30 px visibles a 1080p). La identidad
está en la silueta y en el brote. Las hojas se yerguen con la sorpresa, caen al
dormir, giran como una hélice en una travesura y se le escapan al estornudar.
Expresa con postura (estirarse, encogerse, saltar, inclinarse, brazos, piernas
colgando), no sólo con los ojos.

- `design/poses-dark.png`, `design/poses-light.png`: 16 animaciones y 37 fotogramas
  sobre vidrio oscuro y claro.
- `design/anim-*.gif`: cada animación con su ritmo propuesto.
- `design/palettes.png`: Marea (fija, por defecto), Coral, Noche y Matugen
  (derivada de `~/.cache/matugen/palette.json`: cuerpo=primary, hojas=tertiary…).
- `design/accessories.png`: flor, bufanda y gafas como capas sobre el cuerpo.
- `design/mock-*.png`: lanzador, nicho de la pill, línea de tiempo de música y
  buscador de Edots.

No copia al personaje de Anthropic. Toma de él sólo el estilo: pocos colores,
silueta reconocible y poca resolución.

## b) Mapa de perchas

Una percha es un segmento horizontal que una superficie publica, con
`{id, item, x0..x1, y, tipo: edge|line|niche, zonas a evitar, poses}`. La
mascota sólo se posa si su caja completa cabe dentro de la superficie visible y
no cruza ninguna zona a evitar (texto, controles, cursor de texto). Si la
geometría cambia y deja de caber, camina al tramo libre, salta a otra percha o
se esconde. Nunca se queda encima del contenido.

| Superficie | Percha preferida | Alternativa | Pose |
| --- | --- | --- | --- |
| Barra en reposo | Nicho al final de la pill, tras el reloj (+~30 px sólo con la mascota en casa) | Sin percha: sólo aparece con superficies abiertas | idle, programa, duerme |
| Lanzador | Borde superior del buscador, lado derecho | Borde de la lista | sentado, mira lo que escribes |
| Ajustes rápidos | Pista de un slider (se aparta del pulgar) | Borde de una tarjeta sin control encima | camina, sentado |
| Música | Línea de tiempo (se aparta del cabezal) | Borde superior de la carátula | baila |
| Notificaciones | Borde superior de la tarjeta más reciente, lado opuesto a las acciones | — | sentado, mira |
| Calendario / portapapeles | Cabecera / borde del buscador | Borde de tarjeta | sentado |
| Wallpapers | Borde superior de la miniatura seleccionada | Cabecera | mira, celebra al aplicar |
| Overview | Borde superior de la miniatura del workspace enfocado | Etiqueta | sentado |
| Edots | Borde superior del buscador de la cabecera | Borde de la barra de pestañas | sentado, programa |
| Auth/polkit, sesión, grabación, OSD, toasts | Ninguna: no aparece | — | — |
| Pantalla completa / otro monitor | Oculta, sin recursos | — | — |

**Saltos:** cuando otra superficie termina de revelarse (`petPresented`), la
mascota se agacha 80 ms, salta en parábola por la capa overlay durante 380–520 ms
según la distancia y amortigua la caída. Si el destino cambia en el aire,
retoma desde la posición y velocidad actuales. Si su percha desaparece, vuelve
al nicho; sin nicho, se desvanece en 160 ms. Con movimiento reducido no salta:
aparece o desaparece sin desplazarse.

Todas las superficies viven en la misma ventana `IslandOverlay` por monitor.
Por eso basta un único actor por monitor, que puede moverse entre ellas sin
salir de la shell.

## c) Comportamientos e interacciones

Prioridad de estados: oculta > salto > reacción a ti > evento > mirada > idle o
paseo > sueño.

| Comportamiento | Disparador | Ritmo/coste |
| --- | --- | --- |
| Respira | idle | 2 fotogramas, 0,9 s cada uno; parpadeo aleatorio cada 3–7 s |
| Mira el cursor | hover dentro de la superficie (sólo donde la máscara ya recibe el ratón) | por evento |
| Mira la acción | tecleo en el lanzador, cambio de pista, selección de wallpaper, notificación nueva | por evento |
| Pasea por su percha | cada 20–60 s, a un tramo libre | 6–7 fps mientras camina; avanza 1 px por paso |
| Duerme | sin actividad en la shell (por defecto 2 min) | bosteza, se sienta, respira 2 ciclos y queda **inmóvil**: 0 fps |
| Bosteza de noche | 23:00–06:00: bosteza más y se duerme antes | reloj existente, resolución de minutos |
| Programa | ventana activa de terminal/editor (evento `activewindow` de Hyprland, sin sondeo) | portátil, 2 fotogramas |
| Baila | música sonando: en la vista de música, mientras esté abierta; en la barra, 8 s al empezar la pista | 4 fotogramas a ~4 fps; sin CAVA propio |
| Travesura al azar | frecuencia configurable: nunca, rara (~15 min), normal (~6 min), frecuente (~2 min); sólo en idle, nunca mientras tecleas ni durante transiciones | hélice, estornudo de hoja, saludo, asomarse tras el borde, desperezo, patear un píxel |
| Hover | te mira (look_up) | — |
| Clic | salto con «!» | 0,6 s |
| Clic repetido (3 en 1,5 s) o caricia (hover de ida y vuelta) | contento: ojos ^^, corazón | 1 s, con pausa de rearme |

No tiene necesidades, hambre, castigos ni avisos. El botón de comer de Codex
desaparece de la cabecera de música.

**Reglas absolutas:** la mascota no cambia ni amplía la máscara de input. Su
zona de clic es su cuerpo y sólo existe donde la máscara ya cubre, y una percha
válida nunca queda encima de un control, así que no roba clics. Es
`Accessible.ignored`. Se oculta en pantalla completa y en monitores sin foco.
Con movimiento reducido mantiene una pose estática por estado, sin paseo,
saltos ni travesuras.

**Consumo:** con la mascota desactivada no se crea ningún objeto. Oculta o
dormida no corre ningún timer. En idle hace como mucho 1–2 actualizaciones por
segundo. Cada cambio repinta el overlay, y por eso el estilo de pocos fps
encaja. Un solo reloj de fotogramas por mascota funciona sólo mientras la
animación tiene más de un fotograma, y el salto es la única animación a 60 fps
(≤0,5 s). Antes y después se mide con `bar/pets-performance.qml` y
`bar/tests/pets-performance.py` en cinco escenarios: desactivada, idle,
dormida, bailando y oculta.

## d) Formato de paquete

Un directorio `<id>/` con un único `pet.json`, que sólo contiene datos. Es fácil
de generar por una IA y de revisar a ojo. Ejemplo completo: `design/mimo.pet.json`.

```json
{
 "format": 1, "id": "mimo", "name": "Mimo", "author": "…", "license": "CC0-1.0",
 "canvas": {"width": 20, "height": 20, "baseline": 18, "originX": 10},
 "palette": {"o": {"role": "outline", "color": "#1c2a2d", "matugen": "on_primary_fixed"},
             "b": {"role": "body", "color": "#86d6c4", "matugen": "primary"}},
 "frames": {"idle_0": ["....................", "..."]},
 "animations": {"idle": {"frames": ["idle_0","idle_1"], "ms": [900,900], "loop": true},
                "sit": {"frames": ["sit_0"], "ms": [1400], "contact": "edge"}},
 "events": {"hover": "look_up", "click": "react", "pet": "happy", "music": "dance", "coding": "code"},
 "mischief": [{"animation": "twirl", "weight": 3}],
 "accessories": {"flor": {"layer": ["..."], "anchor": "head"}}
}
```

- Cada fotograma es una lista de cadenas. `.` es transparente y cualquier otra
  letra es un índice de la paleta. Admite hasta 12 colores, lienzos de hasta
  32×32 y 96 fotogramas.
- Animaciones obligatorias: idle, blink, look_left, look_right, look_up, walk,
  sit, sleep, react y happy. Las opcionales (yawn, code, dance, wave y
  travesuras) recurren a una obligatoria si faltan.
- **Validador** `petpack.py validate|build|preview <dir>`. Comprueba el esquema,
  los límites, el tamaño de cada fotograma, los caracteres de la paleta, las
  referencias y el contacto con la línea de apoyo. Avisa de saltos bruscos de
  silueta entre fotogramas consecutivos y de poco contraste sobre vidrio claro y
  oscuro. Rechaza rutas, URL, código y archivos de más de 256 KB.
- **Compilación**: genera `build/atlas.png` (índices de paleta), `atlas.json`,
  una hoja de vista previa y GIFs. Se usa sólo si el hash coincide con `pet.json`.
- **Render**: un `Image` con `smooth: false`, escala entera y `sourceClipRect`
  por fotograma, más un shader de paleta de una pasada (índice → color, en la
  misma vía `.qsb` que FluidNeck). Así se recolorea en vivo con Matugen sin
  procesos. Sin shader, la alternativa sería hornear un PNG por paleta.
- Paquetes integrados en `bar/pets/packs/`; los del usuario en
  `$XDG_DATA_HOME/isla/pets/<id>/`.
- Herramientas: una plantilla mínima válida, `bar/pets-preview.qml` (arnés con
  percha falsa, vidrio claro/oscuro y botones por animación) y la skill
  `.agents/skills/eshell-pet-creator/`. La skill guía de idea a paleta, cuerpo
  base, poses por partes, validación, vista previa revisada y nuevo intento. Se
  probará creando una segunda mascota a partir de un único prompt.

## Qué se reutiliza y qué se reemplaza

| Se conserva | Motivo |
| --- | --- |
| Grupo `pets` de Settings/Config y página Edots | Vía oficial de ajustes; se cambian los campos |
| `petContext` por overlay y `petPresented`/`petEligible` de PillSurfaceHost | Indican cuándo una superficie está revelada: es la señal de salto |
| Disciplina de PetRuntime (settle al ocultar, armSleep, reduced) | Ya está probada; se rehace como máquina de estados |
| Eventos semánticos `notify(kind)` de media/wallpaper | Mismo contrato, más tipos |
| Arnés y pruebas de rendimiento y regresión de pets | Base de medición antes/después; se adaptan los fixtures |

| Se reemplaza | Motivo |
| --- | --- |
| BuiltinPet (vector fantasma/blob/pulpo con ojos IslandCompanion) | Pasa a sprite pixel art por paquete |
| PetHost como Loader local en cada superficie | Pasa a una única capa de mascota por overlay más perchas declaradas; con loaders locales no puede haber saltos ni continuidad |
| Fantasma en el botón de workspaces | Se devuelve el icono original |
| Botón de comer y ajustes `character`, `size`, `profile`, `feedingEnabled` | Pasan a paquete, escala entera y frecuencia de travesuras; sin necesidades |

## Personalización (Edots → Eshell Pets)

Activar; paquete; nombre (por defecto Mimo); tamaño ×1, ×2 o ×3; paleta (la del
paquete, sus variantes o Matugen); accesorio; superficies (una casilla por
superficie de la tabla b); frecuencia de travesuras; minutos hasta dormir;
reacciones (música, programar, noche, shell). Arriba, una vista previa en vivo.
Los campos antiguos se migran (`size`→`scale`) y las claves desconocidas se
conservan.

## Fases (tras aprobar)

1. Runtime, capa y Mimo en tres perchas (nicho, lanzador, música): idle, mirada,
   paseo, sueño y clic/caricia. Medición antes/después y QA con grim.
2. Saltos entre superficies, travesuras y eventos (programa, baila, noche).
3. Personalización en Edots.
4. Paquete, validador, plantilla, vista previa y skill; segunda mascota desde un prompt.

## Decisiones abiertas

1. Barra en reposo: **nicho tras el reloj** (recomendado) o sin percha en reposo.
2. Paleta por defecto: **Marea fija** (identidad estable, recomendada) o Matugen.
3. Tamaño por defecto ×2 y nombre Mimo.
