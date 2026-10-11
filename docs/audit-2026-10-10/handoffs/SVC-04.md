# Traspaso SVC-04

Raíz del proyecto: `/home/zdito/.config/quickshell`. Auditoría del árbol existente al 2026-10-10; conservar cambios ajenos. No se aplicó el fix. Usar configuraciones/datos temporales y dependencias falsas; no probar contra perfiles personales, secretos ni acciones de sesión reales. Leer AGENTS.md y las skills pertinentes antes de corregir. El código actual prevalece si cambió después de esta evidencia.

### SVC-04 — P2 — «Limpiar todo» conserva copias temporales de imágenes mientras el panel sigue cargado

- **Ruta/causa:** `bar/components/ClipboardPreviewAdapter.qml:13-25` guarda cada vista previa decodificada como PNG en `previewDir`; `bar/components/ClipboardController.qml:138-164` ejecuta `cliphist wipe` y vacía `entries`, pero no vacía `previewJobs` ni borra los PNG o mapas de previews. La eliminación del directorio ocurre sólo en `Component.onDestruction` (`:24`); `bar/components/PillSurfaceHost.qml:75-79,95-105` retiene el Loader hasta acabar el cierre.
- **Reproducción/evidencia:** con `cliphist` falso, una imagen PNG sintética y una surface offscreen, `wipe` dejó `entries=0` y `clearing=false`, pero `runtime/isla-clipboard.*/2.png` seguía presente mientras la surface continuaba viva; [salida](../evidence/services-repro.txt). Resultado medido: 1/1 ejecución aislada. La fixture de producto `bar/tests/clipboard-regression.sh:20-35` verifica `wipe` y copia, pero no ausencia de PNG tras limpiar.
- **Esperado/observado/impacto:** la acción de limpiar historial debería retirar también las copias derivadas; la reproducción confirmó retención local de contenido hasta destruir el controlador. No se demostró exposición entre usuarios. Frecuencia real no medida; condición: preview de imagen generada antes de limpiar. **Aceptación/regresión:** tras `finishClear()`, la fixture debe afirmar ausencia de PNG sin cerrar la surface y poder cargar previews nuevas. Rol mínimo: `economy_worker` (Luna/high), ajuste del controlador y fixture.


Reproducciones confirmadas: `python docs/audit-2026-10-10/evidence/services-repro.py`, desde la raíz. Usa HOME/XDG/PATH temporales, ejecutables falsos y copia del producto. SVC-03 no está confirmado; investigar antes de corregir.
