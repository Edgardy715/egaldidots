# Coucou: evidencia de código

Investigación independiente; commit 1e5180921c1326fc72e41d313e3e2855e9c10162. Checkout /tmp/coucou-analysis. No se ejecutó macOS ni se midió fluidez, CPU o accesibilidad efectiva.

## Estados que comunican tarea

BotStates relaciona estado con ojos, postura, badge, color y sonido. setState activa reacciones de entrada finitas (L314–341). Transferir el vocabulario de actividad/atención/resultado a las formas de Isla, sin replicar las expresiones de Mochi.

[Fuente fijada](https://github.com/Louis-CFM/coucou/blob/1e5180921c1326fc72e41d313e3e2855e9c10162/NotchBuddy/Sources/CoucouKit/BotEngine.swift#L90-L167).

## Apertura y cierre asimétricos

Abre con spring response 0.5/dampingFraction 0.72; cierra con Bézier de 340ms. No convertir literalmente estos números a Qt: conservar el motor físico de Isla y calibrar por comportamiento.

[Fuente fijada](https://github.com/Louis-CFM/coucou/blob/1e5180921c1326fc72e41d313e3e2855e9c10162/NotchBuddy/Sources/App/IslandRootView.swift#L23-L34).

## Objeto animado persistente

BotPlacement permanece montado mientras canvases especializados lo ocultan. Evita reiniciar su identidad geométrica al regresar. Badge intercambia contenido por fases y descarta callbacks obsoletos con token (BotEngine L343–357).

[Fuente fijada](https://github.com/Louis-CFM/coucou/blob/1e5180921c1326fc72e41d313e3e2855e9c10162/NotchBuddy/Sources/App/IslandRootView.swift#L95-L109).

## Hover con intención

Distingue origen hover/clic: gracia de salida 600ms, apertura normal 15s, compacto se oculta tras 60s. Clic interno consolida apertura (L239–243); escucha de voz impide cierre automático. Estos tiempos son evidencia, no valores aprobados para Isla.

[Fuente fijada](https://github.com/Louis-CFM/coucou/blob/1e5180921c1326fc72e41d313e3e2855e9c10162/NotchBuddy/Sources/App/IslandStateMachine.swift#L6-L119).

## Expresividad con cooldown

Hover produce respuesta inmediata; reacción afectiva tras 1.9s y cooldown de 6s. Salir cancela. BotEngine L406–432 distingue clics repetidos. En Isla, evitar que una broma intercepte controles funcionales.

[Fuente fijada](https://github.com/Louis-CFM/coucou/blob/1e5180921c1326fc72e41d313e3e2855e9c10162/NotchBuddy/Sources/App/IslandWindowController.swift#L553-L581).

## Arrastre con histéresis

Lock con distancia<60 y velocidad<180; libera al superar 90. Tilt acotado ±0.18rad y springs distintos en seguimiento/captura (constantes L20–39). Transferir tolerancia espacial y respuesta desde velocidad, con recepción original.

[Fuente fijada](https://github.com/Louis-CFM/coucou/blob/1e5180921c1326fc72e41d313e3e2855e9c10162/NotchBuddy/Sources/App/UploadSequenceEngine.swift#L245-L277).

## Atención y foco

Solicitud más antigua al frente; actualizar contador no repite sonido ni roba de nuevo foco. Primera solicitud conserva foco previo; última intenta restaurarlo. Solicitudes fuerzan expansión y retienen apertura (IslandWindowController L327–334).

[Fuente fijada](https://github.com/Louis-CFM/coucou/blob/1e5180921c1326fc72e41d313e3e2855e9c10162/NotchBuddy/Sources/App/HookServer.swift#L94-L161).

## Decoración subordinada

Mood ambiental restringido a estados secundarios; approval/question/error lo desplazan. Inspiración para que calor/batería/ambiente no compitan con una decisión del usuario.

[Fuente fijada](https://github.com/Louis-CFM/coucou/blob/1e5180921c1326fc72e41d313e3e2855e9c10162/NotchBuddy/Sources/CoucouKit/MochiMood.swift#L6-L80).

## Energía y relojes: no copiar a ciegas

Canvas se pausa oculto (L18–26), pero avance físico usa dt fijo 0.05 por frame dibujado. Inferencia pendiente de runtime: comportamiento físico puede depender del refresco; tweens usan otro reloj. Polling 60/20/8Hz según interacción y pantalla (IslandWindowController L392–437). No se midieron CPU ni Hz efectivos.

[Fuente fijada](https://github.com/Louis-CFM/coucou/blob/1e5180921c1326fc72e41d313e3e2855e9c10162/NotchBuddy/Sources/App/BotCanvasView.swift#L285-L320).

## Accesibilidad

Atajos numéricos de respuesta y botones SwiftUI. Búsqueda de reduceMotion/accessibilityReduceMotion y variantes en App/CoucouKit sin política encontrada; no demuestra ausencia de soporte implícito. Isla debe mantener teclado, texto redundante y movimiento reducido explícito.

[Fuente fijada](https://github.com/Louis-CFM/coucou/blob/1e5180921c1326fc72e41d313e3e2855e9c10162/NotchBuddy/Sources/App/IslandViewContent.swift#L533-L580).

## Código y recursos tienen condiciones distintas

Código MIT; nombre, Mochi, expresiones/animaciones como personaje, iconos, sonidos y demo media reservados por el archivo de assets. Desarrollar identidad y sonidos propios. Esto resume el archivo, no sustituye su lectura para redistribuir.

[Fuente fijada](https://github.com/Louis-CFM/coucou/blob/1e5180921c1326fc72e41d313e3e2855e9c10162/LICENSE-ASSETS.md#L3-L28).

El README anuncia un salto al terminar; el código inspeccionado activa un giro. Se prioriza código al describir el gesto. Los límites de plataforma importan: no se certifica paridad Linux/Windows/macOS.
