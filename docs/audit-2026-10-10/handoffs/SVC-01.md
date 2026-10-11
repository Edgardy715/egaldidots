# Traspaso SVC-01

Raíz del proyecto: `/home/zdito/.config/quickshell`. Auditoría del árbol existente al 2026-10-10; conservar cambios ajenos. No se aplicó el fix. Usar configuraciones/datos temporales y dependencias falsas; no probar contra perfiles personales, secretos ni acciones de sesión reales. Leer AGENTS.md y las skills pertinentes antes de corregir. El código actual prevalece si cambió después de esta evidencia.

### SVC-01 — P0 — Introducir una contraseña Wi-Fi puede borrar un perfil guardado antes de validar el reemplazo

- **Ruta/causa:** `bar/components/ConnectivityAdapter.qml:34-55` llama `Nmcli.connectWithPassword`; `bar/Singletons/Nmcli.qml:192-204,268-304` ejecuta `nmcli connection delete <ssid>` si `connection show <ssid>` tuvo éxito, y sólo después intenta añadir y activar el nuevo perfil. El resultado de `delete` se ignora. La búsqueda usa el *nombre* del perfil, no su UUID ni el SSID verificado: también puede coincidir con un perfil distinto que se llame igual.
- **Reproducción/evidencia:** con `nmcli` falso que responde éxito a `connection show/delete Casa` y fallo a `add` y al fallback, `Nmcli.connectWithPassword({ssid:"Casa",bssid:"AA:BB:CC:DD:EE:FF"},"incorrecta", callback)` registró `show → delete → add(fail) → device wifi connect(fail)` y callback `success=false`; [salida](../evidence/services-repro.txt). Resultado medido: 1/1 ejecución aislada. Un perfil de NetworkManager real no se tocó. El código busca por *nombre*: el caso de colisión con un perfil de otra red se infiere del argumento, pendiente de fixture específica.
- **Esperado/observado/impacto:** un intento fallido debe conservar el perfil previo; el orden observado elimina el existente antes de conocer el resultado, con pérdida potencial de contraseña, IP/DNS, autoconexión y otros ajustes en NetworkManager real. Frecuencia real no medida; condición: contraseña y BSSID presentes más nombre de conexión coincidente.
- **Aceptación/regresión propuesta:** simular alta y activación fallidas y colisión de nombre, exigir que el perfil previo permanezca hasta confirmar sustitución válida; luego probar contra NetworkManager de prueba, sin perfiles personales. Rol mínimo para corregir: `economy_implementer` (Sol/medium), lógica de servicio de red y prueba de error.


Reproducciones confirmadas: `python docs/audit-2026-10-10/evidence/services-repro.py`, desde la raíz. Usa HOME/XDG/PATH temporales, ejecutables falsos y copia del producto. SVC-03 no está confirmado; investigar antes de corregir.
