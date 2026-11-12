import QtQuick
import "components"

// Regresión: la pill reacciona a dropMode en el mismo instante (sin animación,
// p. ej. con el morph del ancho desactivado). Antes eso creaba un bucle de
// bindings en dropMode, que se quedaba en true: la gota se posaba y nunca se
// abría en launcher. Ejecutar: QT_QPA_PLATFORM=offscreen qs -p bar/launcher-drop-loop-regression.qml
Item {
    id: stage
    width: 400; height: 400
    property bool fail: false

    LauncherDropMotion {
        id: drop
        s: 1
        landing: 200
        dropSize: 38
        // La pill sigue a dropMode de forma síncrona: el peor caso de re-entrada.
        pillW: dropMode ? 38 : 680
        pillH: dropMode ? 38 : 620
    }

    function check(label, ok) {
        console.log((ok ? "PASS " : "FAIL ") + label)
        if (!ok) fail = true
    }

    Timer {
        id: phase
        property int n: 0
        interval: 1500; running: true; repeat: true
        onTriggered: {
            if (n === 0) {
                check("cerrado en reposo", !drop.dropMode && !drop.down && drop.offset === 0)
                drop.open = true
            } else if (n === 1) {
                check("abierto: se posó", drop.down && Math.abs(drop.offset - drop.landing) < 1)
                check("abierto: dejó de ser gota", !drop.dropMode)
                drop.open = false
            } else {
                check("cerrado: volvió arriba", !drop.down && drop.offset < 1)
                check("cerrado: dejó de ser gota", !drop.dropMode)
                console.log(stage.fail ? "RESULT FAIL" : "RESULT PASS")
                Qt.exit(stage.fail ? 1 : 0)
            }
            n++
        }
    }
}
