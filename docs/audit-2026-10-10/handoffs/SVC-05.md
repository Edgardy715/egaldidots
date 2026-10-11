# Traspaso SVC-05

Raíz del proyecto: `/home/zdito/.config/quickshell`. Auditoría del árbol existente al 2026-10-10; conservar cambios ajenos. No se aplicó el fix. Usar configuraciones/datos temporales y dependencias falsas; no probar contra perfiles personales, secretos ni acciones de sesión reales. Leer AGENTS.md y las skills pertinentes antes de corregir. El código actual prevalece si cambió después de esta evidencia.

### SVC-05 — P2 — El selector confirma un perfil de energía que no se aplicó

- **Ruta/causa:** `bar/components/QuickControlsView.qml:383-390` emite la selección desde el control real; `bar/components/QuickControlsAdapter.qml:20-23` cambia `activeProfile` antes de lanzar `powerprofilesctl set` mediante `execDetached`, sin observar su resultado. El único `get` está en `Component.onCompleted` (`:44-54`). Resumen, segmento y estado accesible dependen de `activeProfile` (`QuickControlsView.qml:325-331,379-390`). La arquitectura ya documenta esta limitación en `docs/SHELL_ARCHITECTURE.md:321-323`.
- **Reproducción/evidencia:** con `powerprofilesctl` falso que devuelve `balanced` en `get` y falla `set performance`, una fixture QtTest hizo `mouseClick` al control `profile-performance`. El registro fue `get → set performance(fail) → get`; la segunda lectura seguía en `balanced`, mientras la UI mostró `active=performance` y «Máximo rendimiento · más consumo», [salida](../evidence/services-repro.txt). Resultado medido: 1/1 ejecución aislada. El perfil del sistema real no se cambió.
- **Esperado/observado/impacto:** la selección visual debe representar el perfil aplicado o indicar error pendiente; aquí afirma que el sistema está en rendimiento aunque siga equilibrado. Frecuencia real no medida; condición: `powerprofilesctl set` falla o no aplica el perfil. La ausencia de lectura posterior también deja obsoleta la UI ante cambios externos; ese segundo caso se deduce del ciclo de vida y no se reprodujo.
- **Aceptación/regresión:** con `set` fallido, el control debe conservar/refrescar el perfil efectivo y mostrar fallo; con éxito, confirmar mediante `get` o respuesta equivalente. Probar además cambio externo mientras el panel está abierto. Rol mínimo: `economy_implementer` (Sol/medium), resultado asíncrono y fixture de interacción.


Reproducciones confirmadas: `python docs/audit-2026-10-10/evidence/services-repro.py`, desde la raíz. Usa HOME/XDG/PATH temporales, ejecutables falsos y copia del producto. SVC-03 no está confirmado; investigar antes de corregir.
