# Eshell Pets — fase 1

Fecha: 2026-10-22. Primer corte funcional implementado; fases 2–6 pendientes.

## Resultado

Fantasma original construido con Shape y los ojos de IslandCompanion. Vive en
el botón de abrir workspaces, sustituyendo únicamente su icono. Mantiene acción,
foco, teclado, hit target y geometría existentes. Mira al workspace activo y
responde con deformación/parpadeo finitos; no camina sobre números ocupados.

Este hogar resuelve la falta de una región libre de 24px en el rail compacto.
PetHost recibe tamaño, región segura, destino local y contexto desde composición;
PetRuntime gestiona la reacción y GhostPet sólo presenta datos. No hay daemon,
procesos de audio, timers idle ni JS por frame propios de pets.

Sólo el monitor cuyo nombre coincide con SurfaceRouter.focusedMonitorName puede
presentar mascota. Al retirar el módulo/contexto, ocultar un ancestro, desactivar
pets o perder espacio, Loader destruye personaje y runtime. Movimiento reducido
cancela impulso/mirada animada. Un nuevo workspace retoma la reacción desde el
impulso actual, sin cola de destinos antiguos.

La pill retira los ojos anteriores mientras se muestra la mascota y los recupera
según appearance.personality cuando no hay host disponible. La preferencia queda
intacta. No se amplían máscaras de input ni se cambia el layout para hacer espacio.

## Configuración y acceso

Edots tiene una sección Eshell Pets. Valores iniciales:

- enabled=false; character=ghost; name=Mimo; size=24 (rango16..48).
- profile=balanced (minimal, balanced, playful).
- workspaceReactions=true.

Activar en Ajustes → Eshell Pets → Eshell Pets, con rail habilitado. Guardar,
descartar y restablecer usan el editor existente. La sesión instalada necesita
cargar el código actualizado para mostrar la nueva sección; no se reinició la
shell ni se modificó la configuración personal durante las pruebas.

Nombre se guarda como identidad de configuración; no añade etiqueta permanente.
El selector sólo ofrece el fantasma en esta fase. Minimal elimina reacción
animada; Balanced/Playful varían amplitud, sin movimientos idle continuos.
Tamaño mayor que la región segura (28px compacta/36px split a escala1) devuelve
el icono original. La UI lo explica. Tamaños lógicos decimales son válidos.

## Evidencia actual

| Requisito | Comprobación | Resultado |
| --- | --- | --- |
| Defaults, tipos, rangos y enum | node bar/tests/settings.cjs | PASS, agente de configuración |
| Config update/discard/save, persistencia y editor real | python bar/tests/settings-integration.py | PASS, agente; ISLA_CONFIG temporal |
| Navegación Edots tras añadir sección | python bar/tests/hyprland-settings-ui.py | PASS, agente; enlaces Hyprland actualizados al índice7 |
| Layouts, input mouse/teclado, bursts, reduced, tamaños, escala, unload | QT_QPA_PLATFORM=wayland python bar/tests/pets.py --output docs/eshell-pets-2026-10-22/qa | PASS |
| Composición real IslandOverlay/Pill, monitor elegible, compact/split y fallback | Segundo fixture del mismo comando | PASS |
| Settings/boundaries/calculadora | sh bar/tests/verify-config.sh | PASS |
| QML nuevo y rail | /usr/lib/qt6/bin/qmllint bar/pets/*.qml bar/components/TopWorkspaceRail.qml | PASS sin diagnósticos |
| QML integrado/config/editor/overlay | qmllint Qt6 sobre archivos QML modificados | exit0 con avisos de cualificación y análisis de layout/singleton en componentes existentes |
| Revisión independiente | agency_reviewer, Sol medium; flujo runtime/settings/input/callers | Sin defectos sustentados |

El wrapper /usr/bin/qmllint devolvió255 sin diagnóstico; se usó el ejecutable Qt6
real. Logs originales de herramientas grandes quedaron bajo ~/.cache/codex-economy.
Evidencia retenida de ejecución QML: qa/pets-regression.qml.log y
qa/pets-overlay-regression.qml.log. Capturas: qa/rest.png, reaction.png,
reduced.png, size-16.png, size-32.png, size-fallback.png, scale-150.png,
overlay-split.png y overlay-compact.png. Revisadas silueta, separación con números,
fallback y escala. Capturas muestreadas no certifican todos los frames.

## Límites y siguiente fase

- No CPU/PSS, energía ni frame times medidos; no se afirma ahorro o coste cero.
- Monitor elegible se probó cambiando el router en la fixture real sobre una
  pantalla; falta transferencia entre monitores físicos y hotplug.
- La captura Qt de split muestra un bloom blanco del efecto del indicador,
  ajeno al dibujo del fantasma; falta contrastarlo con captura del compositor.
  No se da por cerrado el acabado de esa superficie a partir de grabToImage.
- No grabación continua ni evaluación del usuario del movimiento; fase2 debe
  medir baseline y ajustar acabado antes de ampliar superficies/personajes.
- Música, wallpapers, blob/pulpo, paquetes externos, plantilla y skill no están
  implementados. El esquema de paquetes sigue siendo propuesta; no hay cargador
  que ejecute código de terceros en esta fase.

Siguiente encargo: fase2 del plan, conservar este primer host y medir con mismo
entorno antes/después. Consultar sólo fuentes afectadas; no repetir inspección
completa ni activar supervisores permanentes.
