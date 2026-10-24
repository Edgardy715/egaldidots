# pets-auditoria: auditoría estática de bugs de Eshell Pets (SÓLO LECTURA)
No edites nada. Ahorra consumo: no cargues PROJECT_MEMORY/TASK_STATE/bóveda, no ejecutes Wayland,
grim ni qs (tu sandbox no puede; Claude hace la QA en pantalla), no ejecutes la batería de pruebas
(ya pasa). Lee sólo el código necesario y rastrea con rg.

## Alcance
Runtime: bar/pets/PetLayer.qml, PetActor.qml, PetPerch.qml, PetSprite.qml, PetPack.qml.
Perchas y su composición: bar/components/IslandRestStatus.qml (bar, nicho), la percha del riel
(p1), la de la línea de tiempo de media (p2, MediaView/MediaTimeline), la del borde del launcher (p3),
y bar/windows/IslandOverlay.qml (petLoader, petContext, hover de la pill). bar/settings/PetPreview.qml.

## Qué buscar (bugs reales, con escenario reproducible)
1. Relevos entre perchas: la mascota queda en una percha que ya no está disponible, salta a una
   percha invisible, o dos perchas se creen ocupadas a la vez; carreras al abrir/cerrar superficies
   rápido (launcher, media, notificación) o al cambiar de monitor/layout.
2. Geometría: px/escala que agranda percha, máscara o input; posición fuera de ventana o recortada;
   cambios de `bodyWidth`/pose que hacen oscilar el ancho del nicho (petNicheAnimating atascado).
3. Timers/estado: timers que siguen corriendo oculta/dormida/desactivada; flags (`pending`, `closing`,
   `flying`, `afterWake`) que pueden quedarse colgados ante interrupciones; Config.pets cambiando en caliente
   (enabled, palette, scale, barSurface, launcher…).
4. Clics/hover: la mascota roba clics al reloj, a la línea de tiempo o al launcher; hover sin efecto.
5. PetPreview: timers con la página oculta, draft vs guardado.
No informes estilo, nombres ni refactors.

## Informe (≤350 palabras, en este orden)
Hallazgos por severidad (alta/media/baja): archivo:línea, escenario concreto, consecuencia, arreglo
sugerido en una frase, y confianza (verificado leyendo / probable). Si no hay hallazgos en un área,
dilo en una línea. Sin commit ni push.
