# Eshell Pets — fase 2: sueño, acabado y baseline

Fecha: 2026-10-22. Funcionalidad/QA verificadas, mediciones conservadas con límites.
El objetivo inicial de memoria no se alcanzó en los escenarios animados aislados.

## Comportamiento

PetRuntime duerme tras45s sin actividad en su host: cambios de workspace o
hover/foco del botón reinician el plazo. Es inactividad local, no vigilancia de
teclado/ratón del escritorio. Un Timer de un disparo conduce a sleeping; no se
repite mientras siga dormido. Los ojos se cierran, cuerpo y mirada acompañan
la entrada y una secuencia nativa hace dos respiraciones de3,6s. Después queda
completamente quieto. No se añade un loop perpetuo para representar el sueño.

Un workspace nuevo o entrar/enfocar su botón despierta al fantasma inmediatamente;
la respiración residual vuelve a cero desde su valor actual. El control ejecuta
su acción normal sin esperar la animación. Hidden/disabled/sin espacio destruyen
todo el host; una carga nueva no reproduce el sueño anterior. Reduced motion y
Minimal muestran sueño estático. No hay nuevos servicios, procesos de producción,
dependencias, paquetes externos ni ajustes de la sesión personal.

El usuario acepta el aspecto inicial y pide más superficies y comportamientos,
incluido comer. Se conserva esa dirección en el plan; esta fase añade sueño.
No se añadió un gesto de alimentación al botón de navegación ni se cambió su acción.

## Evidencia funcional y visual

- Qt6 lint PetRuntime/GhostPet/PetHost y fixtures: PASS.
- pets.py en Wayland: PASS, ambos fixtures. Sigue cubriendo los casos de fase1
  y añade timeout acelerado sólo en test, respiración finita real, despertar
  desde pose actual, hover, reduced/minimal y unload dormido.
- verify-config.sh: PASS; diff --check: PASS.
- Revisión independiente de lifecycle, límites de movimiento e input: sin
  defectos sustentados. La revisión posterior de SVG tampoco encontró un bug,
  pero ese experimento se descartó por mediciones desfavorables.
- Capturas Qt: qa/ y qa-compositor/. Los archivos definitivos de Shape están
  en qa-compositor/; qa/ incluye capturas del experimento SVG y no identifica
  por sí sola el renderer final.
- Captura real de compositor: `ISLA_PET_COMPOSITOR_GEOMETRY='0,0 1920x90'
  ISLA_PET_MOTION_CAPTURE=1 QT_QPA_PLATFORM=wayland python bar/tests/pets.py
  --output docs/eshell-pets-2026-10-22/phase2/qa-compositor`.
  Región inspeccionada de DP-1,1920×1080, escala1. No se movieron workspaces,
  ventanas ni cambió música/wallpaper del usuario: se alteró sólo la fixture.
- El bloom blanco visto con grabToImage NO aparece en compositor-split.png.
  Se conserva el rail; no se modifica su shader por un artefacto de capturaQt.
- 36 capturas del compositor registran dormir, despertar por workspace simulado
  y dormir de nuevo. frames.json guarda tiempos reales (~274ms entre muestras),
  estados y breath. sleep-wake.mp4 dura10,04s, recorte del rail ampliado3×.
  El concat usa los intervalos registrados; no se presenta como grabación a240Hz
  ni prueba exhaustiva de continuidad entre todos los fotogramas.

Inspeccionados reposo, ojos cerrados, reacción y vuelta a sueño en Qt y compositor.
La fixture real puede coexistir visualmente con la barra instalada detrás; no es
una captura limpia de todo el escritorio. El clip recorta sólo el área del rail.

## Baseline y decisión de render

Fixture de160×100 con PetHost real36×36. Config temporal,1s de arranque excluido,
dos rondas con orden invertido,3,5s por escenario. CPU es porcentaje de un núcleo;
PSS incluye páginas Qt/driver del proceso, con ruido entre procesos independientes.
Un proceso en todos los escenarios. No se midió overhead de la shell completa.

| Estado | CPU mediana % núcleo | PSS incremental frente a deshabilitado |
| --- | ---: | ---: |
| Reposo | 0,000 observado | +7,73 MiB |
| Reacción repetida de test | 8,425 | +9,55 MiB |
| Oculto, sin host | 0,000 observado | −2,27 MiB (ruido/compartición) |
| Sueño, durante las respiraciones | 9,275 | +12,92 MiB |

Driver QML durante animación: p95 de 5 ms y máximo de 8 ms sobre monitor de 239,964 Hz.
No son FPS físicos. Cero CPU significa que no se observó un tick de scheduler en
la ventana de medida; no es una afirmación de consumo literalmente nulo.
La comprobación a8,2s confirma sleeping=true, breathing=false y breath=0;
no se tomó otra serie de CPU/PSS del sueño ya asentado.

Presupuesto fijado antes de medir: quiet/hidden ≤0,5pp añadidos, animación ≤10%
de núcleo, PSS warm incremental ≤8MiB y driver p95≤25ms orientativo. CPU/driver
cumplen en las muestras iniciales, una respiración quedó cerca de10%. PSS cumple
en reposo pero supera8MiB animando. Se registra pendiente; no se subió el umbral.

Se probó reemplazar el Shape inmutable por Image con SVG cacheado del mismo
contorno y color. Se repitió el mismo ensayo por ese cambio concreto: PSS adicional
14,85/15,75/16,14MiB en reposo/reacción/respiración; CPU reacción9,994 y sueño8,425.
No mejoró el conjunto y se revirtió. Fuentes finales PetRuntime/GhostPet/PetHost
coinciden por SHA-256 exactamente con el primer benchmark. No hubo una tercera
serie para buscar un pase. Snapshot de las fuentes iniciales verificado contra
todos los hashes medidos en performance/sources/.

Datos y metodología detallados: performance/REPORT.md y results.json.
Experimento descartado: performance-cached/REPORT.md, results.json y comparison.json.
Los informes de ambos lotes se conservan; no confundir los datos SVG con la entrega.

## Relevo

Siguiente fase funcional: anclajes/eventos en música y wallpapers, conservando
una sola mascota, input y decisiones visuales aceptadas. Mantener vigilancia
del incremento de memoria al integrar hosts reales: la fixture aislada no prueba
el coste incremental sobre los renderers Qt que Isla ya tiene cargados. El objetivo
de8MiB sigue pendiente; no prometer rendimiento global ni ausencia de bugs.

Faltan consumo de GPU/energía, FPS de presentación y transferencia/hotplug entre
monitores físicos. Alimentación, personajes adicionales, paquetes comunitarios
y skill de creación permanecen en fases posteriores.
