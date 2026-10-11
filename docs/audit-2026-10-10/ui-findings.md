# Auditoría de interacción y UI — 2026-10-10

No se corrigió el producto. Entorno: Quickshell 0.3.1 de Arch, Qt Quick, Hyprland/Wayland, DP-1 1920×1080, escala 1, modo de monitor 239.964 Hz. Ese modo no es una medición de FPS. Las reproducciones usan componentes reales copiados a `/tmp/isla-audit-isolated`, `ISLA_CONFIG` temporal y acciones inocuas. Las pruebas QtTest envían eventos a Qt; `wtype` envía teclado por Wayland. La invocación de una acción Accessible comprueba el contrato del componente, no un lector de pantalla real.

Para ejecutar los probes: copiar `bar/` a un directorio temporal, copiar allí el `.qml` indicado de `evidence/`, y ejecutar `ISLA_CONFIG=/tmp/qa-config.json QT_QPA_PLATFORM=wayland qs -p <copia>/<probe>.qml`. Los imports de los probes se resuelven desde esa copia. `launcher-probe.qml` requiere reemplazar su import `../../../bar/components` por `components`. No escribir `Qt.quit()` en el launcher de la sesión personal.

## UI-01 · P1 · Una búsqueda puede ejecutar código QML y cerrar Isla sin Enter

- **Área/precondición:** launcher/calculadora, proceso aislado; texto introducido en la búsqueda real.
- **Pasos mínimos:** ejecutar `launcher-native.qml` en la copia temporal; comprobar que su ventana tiene foco; consultar IPC `auditLauncher state` (query vacía); ejecutar `wtype 'Qt.quit()'`, sin Enter.
- **Esperado:** una búsqueda ajena a la gramática matemática se trata como texto, sin efectos sobre el proceso.
- **Observado:** el proceso aislado PID34315 terminó con exit 0 al completar el texto, antes del watchdog de 45 s. La sesión personal PID1645 continuó activa. Frecuencia: 1/1 entrada Wayland, más 1/1 llamada aislada al evaluador con el mismo resultado.
- **Evidencia:** `evidence/launcher-native.qml`, `launcher-native.txt`, `launcher-native-observation.md`, `launcher-probe.txt`. El probe imprime «before Qt.quit» y solicita cierre; no alcanza el temporizador «survived».
- **Código conectado:** `bar/components/LauncherView.qml:114` actualiza query al escribir; `bar/surfaces/LauncherSurface.qml:23` la conecta al controlador; `bar/components/LauncherController.qml:42-48` permite letras, puntos y llamadas, y hace `eval`; `:63-70` lo ejecuta al cambiar la búsqueda.
- **Causa confirmada:** una lista de caracteres permitidos no restringe nombres ni llamadas a APIs QML. La comprobación del resultado ocurre después de la llamada y sus efectos. No se ejecutaron procesos arbitrarios ni extracción de secretos para demostrarlo; esos impactos no están confirmados.
- **Consecuencia/regresiones:** escribir o pegar una expresión puede cerrar la shell; el evaluador tiene acceso al contexto QML. Corregirlo no debe romper búsqueda de aplicaciones ni matemáticas admitidas.
- **Aceptación:** rechazar nombres, miembros y llamadas fuera de la gramática matemática antes de evaluarlos; `Qt.quit()` debe dejar la aplicación activa y no producir efecto. Mantener `2+2`, constantes y funciones documentadas. Prueba de entrada real sin preparar query/resultado.
- **Regresión recomendada:** tabla de expresiones válidas/inválidas y prueba de búsqueda por teclado que compruebe supervivencia, ausencia de efectos y continuación de búsqueda.
- **Rol mínimo:** `economy_implementer`, Sol/medium; requiere limitar el evaluador y conservar su contrato, no una refactorización general del launcher.

## UI-02 · P2 · Las funciones trigonométricas inversas no se calculan

- **Área/precondición:** mismo evaluador, configuración temporal; no se necesitan servicios externos.
- **Pasos:** ejecutar `launcher-probe.qml`; evaluar `asin(0)`, `acos(1)`, `atan(0)` y los controles `2+2`, `sin(0)`.
- **Esperado:** las tres inversas producen `0`; los controles producen `4` y `0`.
- **Observado:** las tres inversas producen `null`, los controles son correctos. Frecuencia 3/3 expresiones, una ejecución.
- **Evidencia:** `evidence/launcher-probe.txt`; líneas verificadas `bar/components/LauncherController.qml:25-30`.
- **Causa confirmada:** sustituir `sin(`/`cos(`/`tan(` antes de `asin(`/`acos(`/`atan(` convierte los nombres largos en expresiones como `aMath.sin(0)`.
- **Consecuencia:** la calculadora deja sin resultado expresiones explícitamente implementadas. Su ausencia puede confundirse con una búsqueda normal.
- **Aceptación/regresión:** comprobar todas las funciones soportadas, no sólo `2+2`; las inversas y funciones anidadas deben conservar nombre y precedencia. Resolver junto a UI-01 si se sustituye el evaluador.
- **Rol mínimo:** `economy_worker`, Luna/high si es independiente; `economy_implementer`, Sol/medium al corregir la gramática de UI-01.

## UI-03 · P2 · Los botones e interruptores compartidos no responden a su acción accesible

- **Área:** `MotionArea`, `CtrlBtn`, `Toggle` y sus consumidores en paneles. La semántica existe, pero la activación accesible está desconectada.
- **Pasos:** ejecutar `accessibility-probe.qml`; envía clic y Espacio a MotionArea, después emite `Accessible.pressAction`; emite `pressAction` de CtrlBtn y `pressAction`/`toggleAction` de Toggle.
- **Esperado:** cada acción accesible activa una vez la misma operación del puntero, respetando disabled y checked.
- **Observado:** clic y teclado llevan el contador MotionArea a 2; pressAction lo deja en 2. CtrlBtn y Toggle registran 0 activaciones accesibles. Rol Button y nombre «QA action» sí están presentes. Frecuencia: 1/1 probe final offscreen y 1/1 Wayland, tres primitivas afectadas.
- **Evidencia:** `evidence/accessibility-probe.txt`, `accessibility-wayland.txt`, fixture del mismo nombre. El primer intento de la fixture cerraba QtTest demasiado pronto y abortó; fue corregido sólo en la fixture de auditoría. Los logs finales exit 0 no presentan ese aborto.
- **Código:** `bar/components/MotionArea.qml:12-24`, `bar/CtrlBtn.qml:24-39`, `bar/components/Toggle.qml:29-43`; declaran roles y eventos de teclado sin manejadores Accessible de activación.
- **Causa confirmada:** la señal Accessible no está conectada a la acción del control. No se probó la entrega de acciones desde AT-SPI/Orca.
- **Consecuencia:** una tecnología de asistencia que utilice esas acciones no activa el control aunque su nombre/rol sean expuestos.
- **Aceptación:** misma acción, una sola vez, por clic, teclado y API accesible; disabled no ejecuta acción; Toggle conserva el valor aplicado como fuente de verdad.
- **Regresión recomendada:** completar `interaction-regression.qml` con acciones accesibles y estados disabled; no reemplazar sus pruebas de puntero y teclado.
- **Rol mínimo:** `economy_worker`, Luna/high; conexión acotada de primitivas y prueba de comportamiento.
- **Criterio:** [Qt Accessible](https://doc.qt.io/qt-6/qml-qtquick-accessible.html) exige que la acción de pulsación tenga el mismo efecto que el clic; no se imponen tamaños de objetivos de iOS a Linux.

## UI-04 · P2 · El slider de brillo no se puede ajustar con teclado ni expone semántica de slider

- **Área/precondición:** Ajustes rápidos → Brillo disponible, vista inyectada con 50%; ningún dispositivo real se escribe.
- **Pasos:** ejecutar `brightness-probe.qml`, que carga QuickControlsView real; localizar `brightnessSlider`, enfocar y enviar flecha derecha; después hacer clic al 75% del track.
- **Esperado:** Tab puede llegar al slider; una flecha emite el ajuste acotado; rol/nombre/valor permiten identificarlo como Brillo.
- **Observado:** flecha: 0 señales, 50%, `activeFocusOnTab=false`, rol 0. Clic: 1 señal, 75.689655%. Frecuencia 1/1 vista real offscreen; el probe genérico del slider coincide en offscreen y Wayland.
- **Evidencia/código:** `evidence/brightness-probe.txt`; `bar/components/QuickControlsView.qml:203-210`; `bar/components/Slider.qml:18-38,77-88` carece de teclado/Accessible. Los sliders de MixerView sí añaden esas capacidades y MediaTimeline tiene otro control con acciones; no se afirma que todos los sliders de la aplicación fallen.
- **Causa confirmada:** este consumidor usa la primitiva sin los manejadores añadidos por MixerView.
- **Consecuencia:** el ajuste continuo de brillo excluye teclado/acciones accesibles. Los botones ± ofrecen una alternativa, pero no corrigen el control anunciado visualmente.
- **Aceptación/regresión:** foco visible y alcanzable por Tab; flechas y acciones increase/decrease ajustan una vez, con nombre y valor de brillo, límites y disabled. Fixture con señales simuladas; no necesita brillo físico.
- **Rol mínimo:** `economy_worker`, Luna/high; reutilizar el patrón existente de MixerView o completar la primitiva sin duplicar escrituras.

## UI-05 · P2 · Escape no cierra siete paneles abiertos por IPC mientras otra ventana tiene el foco

- **Áreas:** calendar, mixer, connectivity, workspaces, notifs, utils, appearance; navegación por shortcut/IPC sin clic posterior.
- **Entorno/precondición:** Wayland/Hyprland, ventana normal activa, barra separada. Confirmado en shell real y en IslandOverlay/SurfaceRouter aislados. El foco QML solicitado no implica propiedad del teclado del compositor.
- **Pasos:** iniciar `focus-native.qml`; `qs -p <copia>/focus-native.qml ipc call auditFocus open calendar`; esperar 900 ms; consultar `state`; `wtype -k Escape`; esperar 900 ms; volver a consultar `state`. Cerrar con el toggle IPC. Repetir con las otras rutas y launcher como control.
- **Esperado:** el Shortcut Escape de una surface modal abierta recibe la tecla y devuelve el router a reposo; launcher mantiene su cierre en dos fases.
- **Observado:** los siete paneles conservan `surface=<nombre>, wantsKeyboard=true`. Launcher retorna `surface="", wantsKeyboard=false`. Frecuencia: 2/2 por panel, 14 fallos de 14; launcher control 2/2 cierres. En la sesión personal, las capturas tras Escape conservan esos mismos paneles; no se cambió un workspace ni se confirmó ninguna acción.
- **Evidencia:** `evidence/focus-native-state.json`, `focus-native-runtime.txt`, fixture; `native-smoke.json`, capturas `native-*-open.png`/`native-*-escape.png` y montajes inspeccionados.
- **Código/causa probable:** `bar/components/OverlayInputPolicy.qml:45-53` solicita foco pero excluye esos paneles de Exclusive; `bar/windows/IslandOverlay.qml:112-115` usa OnDemand, `:214-217` define Escape. Resultado de foco confirmado; atribución al protocolo OnDemand sustentada por esa rama y el control Exclusive, sin prueba física de clic que demuestre la recuperación.
- **Consecuencia:** Escape y navegación por teclado se entregan a la aplicación anterior; abrir una surface modal por atajo no asegura poder cancelarla desde teclado.
- **Aceptación/regresión:** abrir cada panel desde shortcut/IPC con una ventana previa activa; Escape cierra y Tab/flechas llegan a sus controles; al cerrar, el teclado retorna a la ventana previa. Verificar fullscreen, selector modal y Auth sin ejecutar autenticación real; no capturar teclado en reposo ni en otro monitor.
- **Rol mínimo:** `economy_implementer`, Sol/medium; afecta política de foco, regiones y compositor, y necesita regresión nativa además de pruebas puras.
