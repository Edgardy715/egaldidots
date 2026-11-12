# Diferenciadores de Isla · cierre 2026-11-06

ESTADO: parcial. Cinco fases implementadas y probadas offscreen; QA Wayland real parcial. Sin commit ni push.

| Fase | Implementó | QA nativa (shell real) | No verificado |
|---|---|---|---|
| gestos-f1 | Codex | arrastre 1:1, recoil, pull-open nítido, cierre, touchpad, IPC `pull` | Escape (sin teclado sintético) |
| gestos-f2 | Codex | descarte de notificación por swipe | gota media/recording, expiración al arrastrar |
| actividades | Codex | CLI `isla-activity` → gota, progreso, éxito/fallo, reabsorción, lista | atajos fish |
| dispositivos | Sonnet | punto de privacidad (mic naranja + app en hover); corregido: fuente viva sin tracker de links y `PwNodeType` comparado como bits | Bluetooth, corriente, USB (sin hardware), tarjeta |
| apps-nacen | Sonnet | carga sin errores | vuelo de la gota (el launcher necesita teclado) |
| material-vivo | Sonnet | carga sin errores, pill reacciona al OSD de volumen | onda/tinte/graves a ojo; coste GPU ≤0,15 ms |

Codex llegó a su límite de uso (reinicio 16:38) tras actividades; las fases siguientes las implementó un agente Sonnet.

## Rendimiento medido (shell real, DP-1, reposo)
- CPU: 0,0–0,5 % (top, 3 muestras de 2 s).
- RSS ≈ 580 MB.
- 0 cuadros/s en reposo: sin FrameAnimation ni Timer repetitivo nuevo (ver REPORT de cada fase).
- Único proceso nuevo: `isla-device-storage` (monitor de udisks), sólo con `devices.storage`.

## Instalación y primer arranque
`install.sh` existe (README, opciones `--stow-only`). No se añadió primer arranque presentado por la isla ni grabación de vídeo: pendiente.
