# Traspaso SVC-03

Raíz del proyecto: `/home/zdito/.config/quickshell`. Auditoría del árbol existente al 2026-10-10; conservar cambios ajenos. No se aplicó el fix. Usar configuraciones/datos temporales y dependencias falsas; no probar contra perfiles personales, secretos ni acciones de sesión reales. Leer AGENTS.md y las skills pertinentes antes de corregir. El código actual prevalece si cambió después de esta evidencia.

### SVC-03 — P2 provisional — La restauración de notificaciones puede sobrescribir avisos recibidos durante el arranque

- **Ruta/causa:** `bar/Singletons/Notifs.qml:136-164` acepta notificaciones desde que se crea `NotificationServer` y las inserta en `root.list`; `bar/Singletons/Notifs.qml:168-203` asigna `root.list = rebuilt` cuando termina de cargar el historial, sin conservar las entradas que llegaron mientras el archivo estaba pendiente. `loaded` sólo retrasa el guardado (`:117-131`), no la recepción.
- **Evidencia/límite:** si llega un aviso tras activar el servidor y antes de `FileView.onLoaded`, entra en `list` y luego la asignación lo sustituye por el historial de disco. El código muestra esa ventana de carrera, pero no se reprodujo el orden real de eventos ni se midió su frecuencia; no se certifica como defecto observado.
- **Esperado/impacto posible:** el aviso nuevo debería permanecer en el centro junto al historial restaurado; bajo esa intercalación podría desaparecer y no persistirse. **Aceptación/comprobación:** fixture con carga de archivo retrasada y notificación simulada antes de `onLoaded`, que afirme la presencia de ambas entradas tras la restauración. Rol mínimo para investigar: `economy_researcher` (Luna/high); una corrección confirmada correspondería a implementación del servicio.


Reproducciones confirmadas: `python docs/audit-2026-10-10/evidence/services-repro.py`, desde la raíz. Usa HOME/XDG/PATH temporales, ejecutables falsos y copia del producto. SVC-03 no está confirmado; investigar antes de corregir.
