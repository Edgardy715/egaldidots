# Auditoría general y correcciones · 2026-10-18

Shell de escritorio personal: una sesión, varios monitores posibles, servicios
compartidos y paneles que se cargan bajo demanda. Revisión por flujos de datos,
procesos, entrada y ciclo de vida; no se declara lectura exhaustiva de cada archivo.
Se conservaron los cambios existentes de media, bloqueo y Edots.

## Hallazgos corregidos

| Área | Caso concreto y corrección | Evidencia |
| --- | --- | --- |
| Red: objetos retenidos | Cada executeCommand dejaba su Process/collectors parentados al singleton. Ahora destruye los objetos completados. | 25 comandos → 0 objetos vivos; nmcli-service.py. |
| Red: ráfagas | Eventos de monitor lanzaban lecturas concurrentes, capaces de publicar snapshots en orden inverso. Ahora agrupa peticiones pendientes y preserva callbacks. | 40 solicitudes → 2 lecturas, máximo1 simultánea; recuperación tras fallo. |
| Red: callbacks obsoletos | checkPendingConnection diferido podía leer null o completar otra petición; un callback reentrante podía perder su nueva conexión. Captura identidad y limpia antes de invocar. | Cancelación, reemplazo y reentrada en nmcli-service.py. |
| Brillo | Escritura activa perdía el último destino mientras pendingValue mutable lo anunciaba como escrito; las teclas rápidas no acumulaban. Ahora serializa, agrupa al último destino y confirma snapshots inmutables. | 60→70→80 escribe60→80; pasos acumulados; máximo1 escritor. |
| Brillo: lectura/fallback | Una lectura anterior podía sobrescribir una escritura; fallback podía competir con cambios nuevos. Revisión de lectura y ciclo único directo/fallback; denegación termina la ráfaga. | brightness-service.py con sysfs/comandos falsos, éxito, error y lectura retrasada. |
| Lanzador | Enter/clic durante debounce podía lanzar el resultado de la consulta anterior; consultas ocultas hacían trabajo y reabrir podía conservar lastQuery sin resultados. Ahora bloquea activación pendiente, difiere búsqueda oculta y refresca al abrir. | launcher-pending, controller y input-safety; Wayland teclado y prueba negativa. |
| Portapapeles: texto | Refrescar biblioteca reemplazaba el texto no guardado por preview100 caracteres y perdía coincidencias de búsqueda. Conserva texto original y usa índice por ID en lugar de búsquedas lineales repetidas. | Cadena de más de120 caracteres con sufijo buscable tras guardar otra entrada; biblioteca/copy/wipe PASS. |
| Portapapeles: recursos | Cada miniatura completada retenía jobs y dos árboles de delegates. Libera jobs conservando caché; closures independientes evitan que Qt.callLater pierda finalizaciones simultáneas. | Dos completados en mismo turno → 0 jobs; éxito/error/caché y reversión negativa. |
| Calendario: animación | Cada celda mantenía BreatheBorder infinito incluso con padre invisible; el umbral Motion.mult>=1 desactivaba también velocidad Ágil. Ahora observa visibilidad efectiva y reduceMotion explícitos. | BreatheBorder PASS oculto, visible, reducido y motionScale0.7; reversión negativa. |
| Navegación | Activar reduceMotion durante cierre de launcher conservaba temporizadores viejos. Ahora resuelve el cierre en curso. | surface-router-regression ampliada. |
| Espacios de trabajo | Evento urgent no refrescaba los modelos que alimentan la rail. Se incluye junto a eventos relevantes existentes. | Contrato IPC/consumidores revisados; no se provocó urgencia en ventana real. |
| Wallpapers | Overview encodeURI y bloqueo file:// directo interpretaban #/? como fragmento/consulta. Overview reutiliza Wallpapers.fileSource; bloqueo codifica segmentos. | Image.Ready en ambos con espacios/#/?/%/Unicode; preview Wayland sin aplicar wallpaper ni bloquear sesión. |

## Validación e integración

- nmcli-service.py, brightness-service.py: PASS con dobles de comandos reales,
  sin acciones sobre WiFi/brillo/polkit personales. El autor comprobó reversiones
  individuales que hacen fallar sus regresiones.
- clipboard-regression.sh, clipboard-library-regression.sh y
  clipboard-workflow-regression.sh: PASS con datos/comandos privados temporales;
  incluye el host Pill y copia exacta de contenido.
- Launcher controller/pending/input-safety, previews, border, calendario y router:
  PASS. Reversiones aisladas de guard del launcher, limpieza independiente y
  visibilidad del borde producen FAIL explícito (logs negative-*).
- Wayland secuencial: launcher pendiente y entrada de teclado QtTest, borde, bloqueo
  preview e integración layout-motion PASS. Esta última recorre ambas direcciones
  split/compact, once superficies no destructivas, media, interrupciones y reduced.
- Fuente de wallpaper: PASS Image.Ready y QA visual de overview/bloqueo con ruta
  especial. Capturas guardadas usan escritorios vacíos y media falsa.
- Gate de configuración y 8 pruebas backend audio PASS; py_compile y diff-check PASS.
- qmllint Qt6 exit0, con warnings conservados de scope/tipos de singleton/parent.
  No se declara ausencia de warnings. Las cargas/runtime pertinentes sí pasaron.
- Revisión independiente de servicios, callbacks y consumidores sin hallazgos
  pendientes. Encontró el problema de Qt.callLater que se corrigió y reprodujo
  con test negativo antes del cierre.

## Cobertura y límites

Se revisaron entrada/IPC/runtime/ventanas, routing/host/loaders, adaptadores de
launcher/clipboard/calendario/wallpapers/overview/notificaciones, servicios
Nmcli/Brightness/Players/WinMap/DesktopStatus y rutas de audio/letras. Media y
Edots ya auditados recientemente se conservaron; no se repitió su rediseño.
La exploración no probó un motivo para cambiar GPU, drivers, efectos aprobados,
dependencias o la arquitectura de la shell; no se hicieron esos cambios.

Las mejoras medidas son reducción de trabajo, serialización y vida de objetos;
no se midieron FPS de presentación, GPU, consumo energético ni un porcentaje de
mejora global. Sin conexión WiFi física, sysfs/polkit reales, PAM/unlock real,
AT-SPI ni varios monitores físicos. Un fallback exitoso con un destino nuevo
puede necesitar otra autorización secuencial; nunca se ejecutan simultáneamente.
La revisión no garantiza ausencia de bugs fuera de los escenarios comprobados.

Fuentes vigentes registradas en sources.json; los cambios posteriores invalidan
la evidencia correspondiente. Los logs de layout incluyen avisos del entorno
(avatar ausente, servicio de notificaciones ya registrado y textinput Wayland).
