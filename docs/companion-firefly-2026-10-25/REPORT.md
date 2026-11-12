# Luciérnaga del compañero · 2026-10-25

Segunda fase completada: quinto clic seguido (intervalos <1.1s) o travesura rara existente inicia una luz de Theme que cruza el espacio30×26 durante2.6s. Los ojos la siguen y vuelven a su mirada anterior. No añade servicios, ajustes, dependencias ni relojes idle. La luz ocupa1.25% de cada oportunidad de10min, sustituyendo parte del estornudo, sin aumentar frecuencia.

Caricia/acercamiento, otro gesto, ocultación, reduced, suspensión, bloqueo y sueño cancelan. Reduced rechaza la escena. Recorrido/halo caben en el slot; layout y target no cambian. Preview incluye tarjeta reproducible y altura para la quinta fila.

## Pruebas y evidencia

- Targeted offscreen con ISLA_CONFIG temporal, timeout65s: PASS explícito en offscreen-result.txt. Escalas1/1.5/3, recorrido/mirada, desaparición finita, tres interrupciones, estados, cadencia y continuidad desde mirada no nula.
- `python docs/companion-firefly-2026-10-25/capture.py`: PASS Wayland actual en wayland-result.txt; ocho capturas nativas. Inspeccionadas izquierda/derecha/reposo. Script recorta fixture según layout1920×1080, sin aplicaciones circundantes. No equivale a análisis de todos los fotogramas.
- Personalidad Wayland con ISLA_CONFIG temporal, timeout110s: PASS explícito, clic/teclado, quinto clic, momentos finitos/reduced/hidden y contextos; personality-result.txt. Ejecutado antes de última corrección de continuidad; ésta se revalidó con targeted completa offscreen/Wayland actual, sin repetir áreas ajenas.
- Preview carga offscreen: Configuration Loaded en preview-result.txt, cierre acotado a4s. Composición completa no inspeccionada nativamente.
- Revisión independiente Sol medium: detectó salto al entrar/cancelar con mirada previa no nula; corregido capturando mirada inicial y devolviendo propiedad al Behavior antes de limpiar escena. Segunda ronda sin hallazgos; independent-review.md. Claude sin login según intento previo documentado.
- Diffcheck de archivos afectados PASS. IPC reload devolvió true; Configuration Loaded en live-reload.txt.

Prueba inicial detectó resorte retargeteado cada frame demasiado lento para seguir la luz. Durante escena, progreso y envolvente compartidos gobiernan mirada directamente. Test de continuidad encontró además salto al cambiar enabled y gesture simultáneamente: cesión explícita de mirada antes de limpiar escena lo corrige.

Fuentes finales en sources.json; change.patch contiene sólo esta fase contra snapshot previo. Cambios previos conservados, sin commit/push ni configuración personal modificada. Aviso textinput de Wayland en fixtures, sin fallo de carga.

## Pendientes

Memoria persistente/saludo aprendido y continuidad del personaje entre surfaces siguen pendientes del plan. Faltan ratón físico, tema claro y percepción en sesión larga. Sigue prototipo.
