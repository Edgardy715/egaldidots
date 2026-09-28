pragma Singleton
import QtQuick
import QtQuick.Window
import Quickshell

/**
 * Isla · Motion system. Molde de Ricelin (pill/Singletons/Motion.qml) + curvas
 * emphasized de Material 3 / Apple. Curvas para coreografía; retorno físico breve para controles.
 * `mult` reduce duraciones si el usuario pide reduce-motion.
 *
 * Sistema de tokens (igual que caelestia Anim.qml / Material motion):
 *   · Entrada  → curva DECELERADA asimétrica (acelera rápido, decelera largo):
 *     emphasizedDecel = cubic-bezier(0.05, 0.7, 0.1, 1.0) — el sello Apple/Material.
 *   · Salida   → curva ACELERADA (larga, para que no se "arrastre" al salir):
 *     emphasizedAccel = cubic-bezier(0.3, 0.0, 0.8, 0.15).
 *   · Standard → decel/accel "limpios" (sin enfásis) para micro-interacciones.
 *
 * `stagger` base: las surfaces escalonan la entrada de sus filas/items con
 * `Motion.staggerIndex(i)` → delay por elemento. Todo multiplicado por mult.
 */
Singleton {
    id: root

    readonly property real mult: (Flags.reduceMotion ? 0.28 : 1) * Flags.motionScale

    // durations (ms)
    readonly property int fast:       Math.round(140 * mult)
    readonly property int standard:   Math.round(250 * mult)
    readonly property int morph:      Math.round(420 * mult)
    readonly property int shapeshift: Math.round(820 * mult)
    readonly property int glide:      Math.round(260 * mult)
    readonly property int heat:       Math.round(1100 * mult)
    readonly property int pulse:      Math.round(420 * mult)
    readonly property int breathe:    Math.round(3000 * mult)   // "lo vivo respira" (eco waybar 3.4s)

    // ── duraciones por rol (Material 3 / caelestia) ──
    readonly property int standardSmall:  Math.round(200 * mult)  // botones, chips
    readonly property int standardLarge:  Math.round(400 * mult)  // paneles, tarjetas
    readonly property int emphasized:     Math.round(350 * mult)  // notifs, surfaces
    readonly property int emphasizedLarge: Math.round(500 * mult) // morph de superficies

    // easings (Easing enums para las formas sin bezier)
    readonly property int easeStandard: Easing.OutCubic
    readonly property int easeMorph:    Easing.BezierSpline
    readonly property int easeInOut:    Easing.InOutCubic

    // cubic-bezier como [p1x,p1y, p2x,p2y, 1,1] (formato QML BezierSpline, 3 pts)
    // morphCurve: cubic-bezier(0.25, 1, 0.25, 1) — Apple-like, settle rápido sin bounce
    readonly property var morphCurve:  [0.25, 1, 0.25, 1, 1, 1]
    readonly property var bounceCurve: [0.2, 1.05, 0.35, 1.05, 1, 1]   // hypr bounceIn, minimal overshoot
    readonly property var slingCurve:  [0.35, -0.25, 0.15, 1.1, 1, 1] // hypr slingShot, softer
    readonly property var softFluid:   [0.2, 1, 0.2, 1, 1, 1]          // hypr softFluid
    // easeOut: cubic-bezier(0.25, 1, 0.5, 1) — settle natural, sin bounce
    readonly property var easeOut:     [0.25, 1, 0.5, 1, 1, 1]

    // ── curvas emphasized (Material 3 / Apple) ──
    // Entrada: cubic-bezier(0.05, 0.7, 0.1, 1.0) — arranque rápido, aterrizaje largo.
    readonly property var emphasizedDecelCurve: [0.05, 0.7, 0.1, 1.0, 1, 1]
    // Salida: cubic-bezier(0.3, 0.0, 0.8, 0.15) — se acelera hacia afuera.
    readonly property var emphasizedAccelCurve: [0.3, 0.0, 0.8, 0.15, 1, 1]
    // Standard decel/accel: cubic-bezier(0, 0, 0, 1) y (0.3, 0, 1, 1).
    readonly property var standardDecelCurve: [0, 0, 0, 1, 1, 1]
    readonly property var standardAccelCurve: [0.3, 0, 1, 1, 1, 1]

    // Shared control grammar. Reduced motion keeps color feedback, no travel.
    readonly property int hover: Math.round(120 * mult)
    readonly property int press: Math.round(70 * mult)
    readonly property int iconGesture: Flags.reduceMotion ? 0 : Math.round(650 * Flags.motionScale)
    readonly property int iconSwap: Flags.reduceMotion ? 0 : Math.round(190 * mult)
    readonly property real iconLift: Flags.reduceMotion ? 0 : 1.5
    readonly property real iconEmphasisSubtle: 0.025
    readonly property real iconEmphasis: 0.045
    readonly property real iconEmphasisStrong: 0.065
    readonly property real labelTravel: Flags.reduceMotion ? 0 : 1
    readonly property real gripScale: 1.08
    readonly property real iconTravel: Flags.reduceMotion ? 0 : 2
    readonly property real pressScaleSmall: 0.96
    readonly property real pressScale: 0.975
    readonly property real pressScaleExpressive: 0.965
    readonly property real controlSpring: Math.min(5, 4 / Flags.motionScale)
    readonly property real controlDamping: 0.35

    // radii
    readonly property real rSmall: 7
    readonly property real rTile:  13

    // ---- stagger de entrada (surfaces) ----
    // retraso por elemento en ms. `staggerIndex(i)` para el Timer/delegate.
    readonly property int staggerStep: Math.round(36 * mult)
    readonly property int staggerMax:  Math.round(360 * mult)   // cap total del stagger
    function stagger(i) { return Math.min(root.staggerMax, Math.round((i || 0) * root.staggerStep)) }

    // ---- Spring physics para el morph Dynamic Island (notifs) ----
    // Masa fija 1.0 (QML SpringAnimation usa masa implícita). damping/stiffness
    // afinados para spring visible con 2-3 oscilaciones antes de asentarse.
    // reduce-motion (mult < 1) → damping sube, stiffness baja = asentamiento rápido.
    readonly property real springMass: 1.0
    readonly property real springDamping: Flags.reduceMotion ? 28 : 15
    readonly property real springStiffness: Flags.reduceMotion ? 480 : 420
    readonly property real springVelocity: 0

    // Duraciones clave del ciclo notif (para timers/hold, NO para la anim del spring)
    readonly property int notifCollapse:  Math.round(350 * mult)   // pill -> circle
    readonly property int notifExpand:    Math.round(350 * mult)   // circle -> notif pill
    readonly property int notifHoldMin:   Math.round(1000 * mult)  // hold mínimo
    readonly property int notifHoldMax:   Math.round(2000 * mult)  // hold máximo
}
