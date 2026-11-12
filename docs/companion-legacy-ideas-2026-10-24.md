# Ideas del sistema pixel eliminado para reinterpretar con los ojos (2026-10-24)

El sistema Eshell Pets (Mimo y Pip) se eliminó el 2026-10-24; copia en
`~/.local/state/isla/pets-archive-2026-10-24.tar.gz`. Sólo IslandCompanion sigue vivo.
Ideas con comportamiento exacto del código borrado, por si interesa darles forma con ojos:

- codingFocus: al pasar a enfocar una terminal o editor (kitty, foot, alacritty, wezterm, ghostty,
  code/codium, zed, neovide, jetbrains-*) se despertaba y se ponía a "programar" en casa; ojos: mirada
  concentrada o parpadeo lento mientras ese app tiene el foco.
- musicStart: al empezar a sonar música, cambio de pista incluido, celebraba ocho segundos
  (`musicDurationMs`) si estaba en casa y despierta; ojos: pequeño rebote de pupilas al ritmo.
- Música en el seekbar: se posaba en la línea de tiempo del reproductor y bailaba mientras sonaba; ojos:
  mirar hacia el cursor del seekbar o seguir la posición de reproducción.
- nightReaction: entre las 23:00 y las 06:00 acortaba el plazo de sueño a la mitad (mín. 60 s) y
  bostezaba (`nightYawn`, ~12 % por tick, máx. cada 2 min); ojos: párpados pesados y bostezo nocturno.
- sleepAfter: se dormía tras 2 min sin interacción (1-30 configurable) y quedaba inmóvil, sin
  consumo; despertaba con cualquier evento; ojos: dormitar y cero timers activos.
- mischief: travesuras al descansar con pesos (Mimo: twirl 3, sneeze 2, wave 2; Pip: tilt 3, hop 2,
  twirl 2, wave 2, sneeze 1), cadencia media ~15/6/2 min (rare/normal/frequent), nunca durante lanzador
  ni desplazamientos; ojos: guiño, estornudo o giro de pupilas ocasional.
- jumps: salto parabólico entre superficies (barra, lanzador, música) con altura 9-36 px y retorno a
  casa tras cerrar el lanzador (`holdForHome`); ojos: no aplica el salto, sí la mirada hacia donde se
  abre la superficie.
- pillLook: con el puntero sobre la pill miraba en esa dirección (izquierda, derecha o arriba) con
  retardo mínimo de 250 ms entre cambios y volvía al centro al salir; ojos: seguir al puntero igual.
- Rail de espacios: al pasar el puntero por un espacio, `lookAt(hoverId - activeId)` miraba hacia ese
  espacio y a 0 si no había hover; ojos: mirar la celda hovered del rail.
- Clic y caricia: tres clics en 1,5 s eran caricia (`pet()`, reacción feliz, anti-spam 2,5 s); ojos:
  entrecerrar contentos ante clics repetidos.
