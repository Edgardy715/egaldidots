# Eshell Pets — fase 4

Fecha: 2026-10-22. Personajes y personalización implementados.

## Resultado

Fantasma, gota/blob y pulpo usan un único BuiltinPet con siluetas originales,
la misma mirada y el mismo PetRuntime. Cambiar personaje conserva el estado;
no carga personajes simultáneos ni añade servicios, dependencias o audio.

Config/Edots permite elegir personaje, nombre, tamaño y perfil; ahora también
habilitar cada superficie (workspaces, música, wallpapers), sueño, mirada,
reacciones de música/wallpapers y alimentación. Se conserva workspaceReactions.
Los ocho campos nuevos son booleanos true por defecto; pets.enabled sigue false.
Las configuraciones anteriores reciben defaults por el validador existente.

En el panel de música aparece un botón de cubiertos con nombre accesible
«Dar de comer a <nombre>», activable por teclado. Reserva espacio en la cabecera
independientemente de la carga final del personaje para evitar feedback de layout.
Sin mascota disponible permanece deshabilitado; ocultar alimentación, música,
pets o un tamaño mayor de32 retira el control. No cambia acciones del rail.

La comida dura1,6s: cuatro masticaciones nativas finitas, boca y bocado de acento.
Clicks repetidos durante la comida no la reinician. Minimal/reduced muestran un
acuse estático con la misma duración. Ocultar descarga el runtime; cambiar a
reduced/perfil o deshabilitar alimentación cancela la secuencia. No hay hambre,
penalizaciones ni animación periódica. El sueño local sigue siendo opcional45s.

## Validación vigente

- `QT_QPA_PLATFORM=wayland python bar/tests/pets.py --output .../phase4/qa`:
  PASS núcleo/rail/sueño, overlay real y MediaView. Extensión cubre los tres
  personajes, teclado para alimentar, fin de comida, opt-outs de sueño/mirada/
  reacciones/alimentación/superficie, reduced/minimal y no replay tras ocultar.
- `QT_QPA_PLATFORM=wayland python bar/tests/pets-surfaces.py --output .../phase4/qa`:
  PASS rutas reales compact/split con servicios privados simulados. Opciones
  individuales descargan cada host y personajes/comportamientos reciben Config;
  sigue comprobando instancia única, eventos semánticos y ningún consumidor nuevo.
- `python bar/tests/settings-integration.py`: PASS defaults, guardar/descarte
  del pulpo y los ocho flags, IPC/persistencia atómica y editor real con14campos.
- `sh bar/tests/verify-config.sh`, `git diff --check`: PASS.
- Qt6 qmllint: exit0; conserva advertencias de acceso no calificado y QObject
  dinámico de Loader, no se interpreta como lint sin advertencias.
- Revisión independiente Sol/medium: sin defectos sustentados; comprobación
  temporal offscreen de interrupciones, eventos durante comida y cancelación.

Nueve capturas del compositor de la ventana privada MediaView (936×1002 en esta
sesión), personaje × idle/eating/sleeping, inspeccionadas; `qa/native-media-*.png`.
`qa/characters-preview.png` sólo recorta y amplía esos estados. Qt grabToImage
mostró capturas parciales de contenido quieto; las nativas confirman el contenido
completo. La captura no demuestra FPS ni todos los fotogramas de una transición.
El segundo pase MediaView después del ajuste del icono también PASS (native-media.log).

## Límites y relevo

No se tocaron configuración, reproducción, wallpaper ni workspace personales,
ni se reinició la shell. Sin medición nueva de CPU/PSS/GPU/FPS o multimonitor
físico; el objetivo de8MiB de fase2 sigue pendiente. Los límites del anclaje se
conservan: media32, wallpaper28, rail compacto28/split36 lógicos útiles. Tamaños
mayores siguen ocultándose con fallback del control original.

Próxima fase5: contrato de paquetes externos, plantilla, validación y skill de
creación. No cargar QML externo como si estuviese aislado. Fase6: matriz final
y rendimiento. Historial previo y experimento SVG descartado se conservan.
