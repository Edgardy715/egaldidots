# Eshell Pets — propuesta de implementación

Fecha: 2026-10-22. Estado: fase4 implementada y validada;
objetivo inicial de memoria pendiente de mejora, fases5–6 pendientes.
Eshell Pets es el nombre de la función; el repositorio y sus rutas siguen siendo Isla.

Evidencia y relevo: `docs/eshell-pets-2026-10-22/REPORT.md`. Primer hogar en el
botón existente de abrir workspaces: sustituye su icono sin cambiar acción/input.
No camina sobre indicadores ocupados. Config/Edots integrados, tres personajes,
sin runtime cuando falta host. Fase2 y límites: `docs/eshell-pets-2026-10-22/phase2/REPORT.md`.
Sueño tras45s de quietud local, dos respiraciones finitas y despertar por
workspace/hover/foco. Fase3 añade música y wallpapers, con eventos confirmados,
mirada a portada/miniaturas y una sola mascota por ruta/monitor.
Evidencia: `docs/eshell-pets-2026-10-22/phase3/REPORT.md`.
Fase4: fantasma/blob/pulpo, controles por superficie y comportamiento, comida
explícita finita en música. Evidencia: `docs/eshell-pets-2026-10-22/phase4/REPORT.md`.
Siguiente entrega funcional: fase5 paquetes externos, plantilla, validador y skill.

## Aclaración del usuario tras fase1

El aspecto inicial se acepta por ahora. Se desea que sea una mascota con
comportamientos reconocibles, incluidos dormir animadamente y comer, además de
responder a interacciones en más superficies. Sueño queda implementado en fase2.
Comer se incorporará como gesto finito ligado a una acción explícita de mascota
en un host con espacio; conservar la acción principal de los controles existentes.
No simular hambre, penalizaciones ni necesidades que exijan atención permanente.
El perfil y futuros controles de comportamiento permitirán limitar estas acciones.

## Base comprobada

- `bar/components/IslandCompanion.qml` ya ofrece ojos expresivos, mirada,
  parpadeo por interacción, cooldown y cancelación al ocultarse/reducir movimiento.
- `bar/Pill.qml` conecta `appearance.personality`; evitar dos compañeros a la vez.
- `bar/components/TopWorkspaceRail.qml` calcula posiciones con navWidth, inset,
  slot y ancho disponible; la mascota debe seguir esa geometría real.
- `bar/surfaces/WallpaperSurface.qml` separa selección y aplicación mediante
  controlador y señales. Reaccionar a éxito confirmado, no solamente al click.
- `docs/SHELL_ARCHITECTURE.md` establece Config/Settings, composición por
  propiedades, SurfaceRouter, carga opcional y Theme/Matugen. No crear sustitutos.
- `bar/fluid/MOTION_LANGUAGE.md` exige continuidad, cancelación y reduced motion.

Inspección selectiva para decidir arquitectura, no auditoría exhaustiva del repo.

## Arquitectura propuesta

Tres responsabilidades dentro de un futuro `bar/pets/`, sin daemon:

1. **PetRuntime**: selección, estado y arbitraje de eventos; cargado sólo cuando
   pets esté habilitado. Una identidad lógica y como máximo una representación
   visible por sesión inicialmente, elegida por superficie/monitor activo.
2. **PetHost y anclajes**: composición local dentro de superficies existentes.
   Reciben región libre, destinos, visibilidad efectiva y contexto. Gestionan
   recorte, carga y conversión de coordenadas; nunca amplían máscaras de input.
3. **Personajes**: presentación por propiedades, sin conexiones directas a
   Players, Cava, compositor ni configuración. Reutilizar expresividad existente
   donde encaje; no confundir mascotas con el motor de gotas FluidCompanion.

No construir un bus global o registro dinámico de plugins antes de necesitarlo.
Inicialmente bastan adaptadores explícitos para tres contextos.

Contrato de anclaje v1: id estable, host local, región permitida, punto de reposo,
destinos semánticos, visibilidad efectiva e interacciones soportadas. El adaptador
expone posiciones reales; el personaje nunca calcula el layout del rail.
Si no cabe, se oculta: no desplaza controles ni invade texto para ganar espacio.
Cambiar de ventana/superficie no implica caminar por el escritorio: retirar la
representación anterior antes de mostrar la nueva dentro de su host.

Contrato de evento v1: tipo, identidad del contexto, destino opcional y secuencia.
Eventos previstos: workspace activo/estructura, playback, pista, selección de
wallpaper, aplicación confirmada, hover/foco y apertura/cierre de superficie.
No conservar referencias a elementos destruidos ni colas de reacciones antiguas.

Estados: hidden, idle, observing, reacting, moving y sleeping.
Prioridad: deshabilitar/ocultar > pérdida de espacio o contexto > reacción directa
> observación > idle. Último destino gana; retarget desde la pose actual.
Un propietario por propiedad animada. Al ocultar: detener animaciones y timers,
limpiar pendientes y liberar visuales cuando termine la retirada permitida.
Reduced motion mantiene expresiones estáticas, sin paseo ni movimiento idle.

## Personajes y personalización

Primero fantasma original: cuerpo sencillo y ojos, reposo quieto, mirada,
parpadeo y reacción corta. Después blob y pulpo para comprobar que el contrato
soporta deformación y movimiento secundario sin ramas especiales en el runtime.
Primitivas QML para ejemplos integrados; assets pequeños cuando aporten valor.
Sin shaders, físicas, seguimiento global del cursor ni audio adicional.

Settings.js seguirá siendo la fuente de defaults y validación. Proponer un grupo
pets con enabled (false inicialmente), selección, nombre, tamaño limitado,
superficies/anclajes preferidos, comportamientos habilitados y perfil
Minimal/Balanced/Playful. Separar frecuencia expresiva de calidad/rendimiento si
las mediciones justifican opciones distintas; no duplicar reduceMotion global.
La interfaz usará Edots y Config.update/discard/save/restablecimiento existentes.
Con pets activo se sustituye la expresión actual; al desactivarlo se respeta el
valor anterior de appearance.personality, sin reescribir la preferencia guardada.

## Paquetes comunitarios: decisión antes de desarrollar el cargador

Propuesta v1: paquetes de datos y assets locales interpretados por componentes
propios. Manifest versionado con id, nombre, autor/licencia, compatibilidad,
capacidades, defaults y estados; assets y poses/secuencias declarativas acotadas.
Sin JS, expresiones, imports ni rutas QML ejecutables en paquetes externos.
Instalación local propuesta: `$XDG_DATA_HOME/isla/pets/<id>` con fallback XDG.

Validar versión, tipos, eventos, límites de duración/tamaño/cantidad, rutas
contenidas (incluidos symlinks), formatos de imagen admitidos y referencias.
Rechazar URLs remotas y paquetes inválidos; volver al personaje integrado sin
romper la shell. No prometer aislamiento absoluto de decodificadores de assets.
QML comunitario arbitrario no satisface el requisito de restringir servicios:
si se exige más adelante, requerirá otro modelo explícito de confianza/aislamiento.
El formato de datos limita comportamientos a los soportados por el motor; ésta
es una decisión propuesta, no una capacidad implementada.

## Fases y condiciones de cierre

| Fase | Entrega | Comprobación para continuar |
| --- | --- | --- |
| 1 | Contrato mínimo, configuración, runtime y fantasma en workspaces | Activar/desactivar, espacio insuficiente, cambios rápidos, hidden/reduced y persistencia temporal |
| 2 | Acabado del primer personaje y baseline | QA Wayland grabada, input intacto, compact/split, escalas, monitor y CPU/PSS/frame times comparables |
| 3 | Música y wallpapers | Inicio/pausa/pista y selección/éxito real; cerrar/cambiar superficie cancela trabajo; sin procesos de audio nuevos |
| 4 | Blob, pulpo y personalización completa | Tres personajes usando mismo contrato; nombre/tamaño/perfiles/behaviors, restaurar/guardar/descartar |
| 5 | Paquetes externos, plantilla, validador y skill del proyecto | Cargar ejemplo fuera del core, rechazar paquetes inválidos, compatibilidad y ejemplo generado siguiendo la skill |
| 6 | Regresión y documentación final | Matriz de aceptación completa, revisión independiente de cargador/persistencia y mediciones reproducibles |

La fase 1 es un corte funcional, no la entrega completa del encargo original.
Al implementar se identificarán consumidores, fixtures, catálogo/settings,
shell.json.example, exports y pruebas afectadas antes de editar cada fase.
La skill de creación se redactará después de estabilizar el contrato y contendrá
API, estructura, ejemplos completos, plantilla, animación, seguridad y validación.

## Validación y rendimiento

- Fixtures para eventos rápidos, destrucción del anclaje, cambio de monitor,
  pérdida de espacio y cancelación. Comprobar que desaparecen timers/animaciones
  y que no hay instancias duplicadas al alternar superficies.
- Configuración con ISLA_CONFIG temporal: defaults, errores, guardar/descartar,
  reinicio y compatibilidad con personality. Sin modificar ajustes personales.
- Input de controles, teclado y foco intactos; mascota decorativa fuera del árbol
  accesible salvo información que necesite equivalente textual.
- QA visual real en compact/split, tamaños 16–48 lógicos, escalas/fuentes,
  interrupciones y movimiento reducido. Offscreen no certifica fluidez.
- Comparar mismo entorno y escenario: deshabilitado, visible quieto, reacción,
  música y oculto. Registrar CPU del árbol, PSS, procesos, animaciones/timers
  activos y frame times con herramienta disponible; no confundirlos con FPS físicos.
- Fijar presupuesto numérico después del baseline y antes de ampliar personajes.
  Requisitos desde el inicio: sin proceso adicional, sin bucle periódico oculto,
  runtime descargado al deshabilitar y sin trabajo de audio iniciado por pets.

## Control de alcance y consumo

Trabajar una fase por encargo, leyendo este plan y sólo sus fuentes afectadas.
No auditoría total, benchmarks globales, generación de imágenes, agentes de
supervisión ni investigación amplia de frameworks para esta planificación.
Revisiones independientes futuras sólo ante riesgo concreto o acabado sustancial.
No estimar ahorro porcentual, cuota restante ni rendimiento sin medición.

Geometría y convivencia con personality resueltas en fase1 y sus fixtures.
Fase2 añade sueño/despertar y baseline con dos rondas invertidas por escenario.
Repositorio conserva prueba SVG descartada por no mejorar recursos. Captura del
compositor descarta el bloom blanco como defecto visible del rail. El objetivo
inicial de8MiB no se alcanzó en animación aislada; no afirmar coste cero ni medir
ese delta como overhead global. Pruebas de ambas fases PASS; detalle en informes.
Esquema final de paquetes pendiente para fase5; multimonitor físico pendiente.

Fase3 probada con composición real y servicios privados simulados: media en
compact/split, selección/hover y aplicación confirmada de wallpaper; sin comandos
personales. `petContext` estable y `petPresented/petEligible` controlan carga y
destrucción entre superficies. No se midió nuevo coste global. Ver informe fase3.
