# Traspaso SVC-02

Raíz del proyecto: `/home/zdito/.config/quickshell`. Auditoría del árbol existente al 2026-10-10; conservar cambios ajenos. No se aplicó el fix. Usar configuraciones/datos temporales y dependencias falsas; no probar contra perfiles personales, secretos ni acciones de sesión reales. Leer AGENTS.md y las skills pertinentes antes de corregir. El código actual prevalece si cambió después de esta evidencia.

### SVC-02 — P2 — El comando de bloqueo de Session no sigue la ruta XDG usada por el instalador

- **Ruta/causa:** `bar/lockscreen/install.sh:4,12-16` instala en `${XDG_DATA_HOME:-$HOME/.local/share}/quickshell-lockscreen/lock.sh`; `bar/Singletons/Session.qml:25,32-37` ejecuta siempre `~/.local/share/quickshell-lockscreen/lock.sh` y silencia la excepción de `execDetached`.
- **Reproducción/evidencia:** con `XDG_DATA_HOME` temporal y un launcher falso allí, `Session.lock()` invocó `sh -c ~/.local/share/quickshell-lockscreen/lock.sh`; el launcher XDG no se ejecutó y la ruta fija no existía, [salida](../evidence/services-repro.txt). Resultado medido: 1/1 ejecución aislada. La fixture existente `bar/tests/lockscreen-launcher.py:17-22` confirma por separado que el instalador respeta XDG.
- **Esperado/observado/impacto:** el botón/IPC de bloqueo debe lanzar el wrapper instalado; con `XDG_DATA_HOME` personalizado puede no bloquear y no hay feedback de error. Frecuencia real no medida; condición: XDG personalizado sin copia en ruta fija. `Super+L` y `hypridle` versionados usan `hyprlock` directamente, así que este hallazgo se limita a Session/IPC. **Aceptación/regresión:** repetir la fixture con la ruta XDG y exigir que se invoque el marcador, sin adquirir bloqueo real. Rol mínimo: `economy_worker` (Luna/high), integración QML/launcher.


Reproducciones confirmadas: `python docs/audit-2026-10-10/evidence/services-repro.py`, desde la raíz. Usa HOME/XDG/PATH temporales, ejecutables falsos y copia del producto. SVC-03 no está confirmado; investigar antes de corregir.
