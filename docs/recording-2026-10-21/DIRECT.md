# Captura directa por GPU · 2026-10-21

Sustituye la integración OBS descrita en REPORT.md. Petición: acercar Isla a Caelestia con menor sobrecarga. Referencia consultada: https://raw.githubusercontent.com/caelestia-dots/shell/main/services/Recorder.qml (control gpu-screen-recorder y consulta limitada a superficie visible). Se conserva la identidad y movimiento de Isla.

## Resultado y contratos

- Captura por `gpu-screen-recorder`: portal Wayland para elegir pantalla/ventana, H.264 hardware, hasta30fps, VFR y tune performance; fallbackCPU deshabilitado. No requiere OBS ni conexión WebSocket. No replay permanente ni regiones KMS con permisos elevados.
- Sistema y micrófono independientes; micrófono apagado por defecto. Carpeta `~/Videos/Recordings`, nombres únicos MKV. Los controles de audio quedan fijos durante captura.
- Cuenta atrás3s cancelable al abandonar controles; selector nativo al terminar. Morph de botón y estados REC/pausa/guardando continúan. Sin bucles decorativos. Reduced y hidden resuelven movimiento.
- Backend sólo mientras Actividades está abierto o captura/operación activa; no proceso auxiliar al cerrar en reposo. Sin sondeo de procesos globales ni reloj en reposo. Durante captura la duración usa reloj monotónico y excluye pausa; IPC nativo absoluto confirma pausa/reanudar. Se controla sólo el PID propio.
- EOF/SIGTERM solicitan SIGINT propio y esperan finalizar. SIGKILL del puente propaga SIGINT por parent-death Linux. No SIGKILL automático al grabador; un encoder bloqueado puede retrasar el cierre para no truncar el archivo.
- Inicio usa apertura del MKV no vacío con proceso vivo tras preparación; guardado requiere salida0 y archivo no vacío. Esto no demuestra primer fotograma ni integridad multimedia completa. Error no se anuncia como guardado.

## Entorno y disponibilidad

Equipo Intel CometLake-H + NVIDIA GTX1660TiMobile. `--info` detecta NVIDIA y H.264/HEVC disponibles. `gpu-screen-recorder`6.1.4-1.1 descargado del repositorio CachyOS configurado y extraído en `~/.local/lib/isla/gpu-screen-recorder`; no se alteraron paquetes del sistema (sudo no interactivo no disponible). El backend prefiere PATH y luego esta ubicación. Python sólo usa biblioteca estándar. Para otros equipos instalar gpu-screen-recorder6.1.4 o posterior y portal ScreenCast funcional.

Origen del paquete: https://mirror.krfoss.org/cachyos/repo/x86_64_v3/cachyos-extra-v3/gpu-screen-recorder-6.1.4-1.1-x86_64_v3.pkg.tar.zst
Documentación de argumentos/protocolo: man incluido en ese paquete; README https://git.dec05eba.com/gpu-screen-recorder/about/ . No se promete consumo mínimo absoluto sin comparar una captura real.

## Evidencia

- Backend11tests PASS: ciclo propio, argumentos hardware/audio, validación, cancelación del selector, errores/archivo vacío, pauseIPC absoluto/rechazo, EOF/stdoutcerrado, SIGTERM y SIGKILL. Quickshell real con grabador simulado finaliza el MKV al destruirse; no hay captura real en estas pruebas. py_compile PASS. Revisión independiente confirma corregido SIGTERM sin nuevos defectos importantes sustentados.

- RecordingView Wayland PASS: controles/audio, teclado/mouse, busy, morph intermedio, reduced/hidden.
- RecordingIntegration Wayland PASS: ruta/tab, countdown cancelable, pill REC/pausa/incertidumbre, guardado y escala1.5. Capturas simuladas en direct-captures/; ready y texto grande inspeccionados visualmente.
- settings-integration y verify-config PASS; qmllint de RecordingView/ActivityView/FocusSurface/Recording/ShellRuntime sin salida; diffcheck PASS.
- Ruta real abierta y recording.status devuelve connectedtrue/idle; cierre real sin auxiliares en /proc. Panel abierto: auxiliar23,208kBRSS y0ticksCPU en3s (CLK_TCK100), muestra breve sin equivaler a benchmark continuo.
- NVENC real con fuente sintética negra1280×720/30 durante1s PASS; ffprobe confirma H.264/720p/30. No se capturó escritorio, cámara o audio personales.

## Límites

No se completó una captura real por el portal ni se midieron FPS, energía, frame pacing o audio con dispositivos reales. La prueba sintética acredita encoder, no todo el pipeline. El comportamiento de selección depende del portal/controladores de este equipo. La duración arranca al abrir el archivo, no de timestamps de vídeo. El informe OBS anterior conserva historia pero no describe el backend vigente.
