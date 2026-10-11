# Calidad de las pruebas — 2026-10-10

## QA-01 · P2 · El gate verify-config se detiene por una ruta personal en una fixture

- **Área/entorno:** comprobación estática del repositorio actual, desde su raíz, con Node/jq/rg disponibles. Defecto de infraestructura de prueba, no fallo de carga de Isla.
- **Reproducción:** `python ~/.codex/token-economy/output.py run -- sh bar/tests/verify-config.sh`.
- **Esperado:** fixtures portables, y ejecución de settings.cjs y surface-boundaries.cjs dentro del gate.
- **Observado:** exit 1, `Hardcoded user path in QML`; termina antes de las pruebas Node porque `bar/optional-modules-regression.qml:47` contiene una ruta `/home/zdito/...`. Frecuencia: 1/1 ejecución de esta auditoría; ya constaba en el historial anterior. Se conserva el hallazgo porque sigue vigente.
- **Evidencia:** `evidence/output-95wzp9i3.log`; gate `bar/tests/verify-config.sh:14-17` y llamadas Node al final del archivo. Las pruebas Node ejecutadas por separado sí pasan.
- **Causa confirmada:** la misma regla que protege portabilidad escanea fixtures; una fixture incumple el contrato. No se recomienda excluirla del gate para ocultar el problema.
- **Consecuencia:** no se puede usar el resultado global como validación de configuración y fronteras; CI/correcciones posteriores parten de un gate rojo.
- **Aceptación/regresión:** fixture independiente del home personal; verify-config ejecuta todos sus checks y termina con su marcador final de éxito. Mantener detección de rutas personales.
- **Rol mínimo:** `economy_worker`, Luna/high; cambio mecánico acotado en datos de prueba y ejecución del gate.

## Ejecuciones que no prueban defectos del producto

- **Letras sin servidor:** el primer lyrics-controller-regression devolvió exit 1 y FAIL; faltaba `ISLA_LYRICS_TEST_ENDPOINT`. La repetición con servidor HTTP local simulado cubrió synced/plain/vacío/error/instrumental/respuesta tardía/cierre y pasó. Véanse `evidence/lyrics-controller.raw.log`, `lyrics-local.py`, `lyrics-local.txt`. No se consultó LRCLIB real.
- **Tiempo insuficiente:** layout-motion se interrumpió a 25 s antes de acabar. La repetición con límite 100 s terminó con exit 0, PASS y sin FAIL. No es un defecto del producto ni un timeout interno confirmado. `evidence/layout-motion-full.txt` y su original preservado documentan el resultado.
- **Probes de auditoría iniciales:** un import externo al config root fue rechazado por Quickshell; se usó una copia temporal de bar. Los primeros probes QtTest cerraban durante su handler y abortaron; se corrigió el cierre sólo de esos probes mediante Timer. Los resultados finales no tienen ese aborto. No se atribuye al producto.
- **Warnings de fixtures:** servidor de notificaciones ocupado por la shell real, avatar inexistente `~/.face`, icono `input-keyboard` y portada `file://null` en preview. No se cuentan como fallos funcionales sin un resultado adverso demostrado. Los logs íntegros se conservan, incluyendo warnings.
- **Límite del detector:** Impeccable no reconoce la plataforma Linux/Wayland y cae a web. Se usaron sus criterios generales adaptados a QML; no se usó un resultado del detector web como certificación, ni se cambió PRODUCT.md para fingir una plataforma admitida.
