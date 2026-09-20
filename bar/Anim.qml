import QtQuick
import "Singletons"

/**
 * Isla · Anim. NumberAnimation tipado con tipos semánticos que mapean a
 * Motion.qml (durations + easings). Sistema de tokens estilo caelestia/Material:
 * cada tipo tiene SU curva — entradas deceleradas (emphasizedDecel, el sello
 * Apple/Material), salidas aceleradas (emphasizedAccel), micro-interacciones
 * con standardDecel.
 *
 * Uso:
 *   Behavior on opacity { Anim { type: Anim.FastEffects } }
 *   Behavior on width  { Anim { type: Anim.Morph } }
 */
NumberAnimation {
    enum Type {
        // Standard: entrada/salida genérica
        StandardSmall = 0,
        Standard,
        StandardLarge,
        StandardExtraLarge,
        // Emphasized: movimientos importantes (notifs, surfaces)
        EmphasizedSmall,
        Emphasized,
        EmphasizedLarge,
        EmphasizedExtraLarge,
        // Espaciales: morphs, transiciones de layout
        FastSpatial,
        DefaultSpatial,
        SlowSpatial,
        // Efectos: opacidad, escala, brillo
        FastEffects,
        DefaultEffects,
        SlowEffects,
        // Isla específicos
        Morph,
        Glide,
        Fast,
        FastIn,        // entrada rápida decelerada
        FastOut,       // salida rápida acelerada
        EmphasizedIn,  // entrada emphasized
        EmphasizedOut  // salida emphasized
    }

    property int type: Anim.DefaultSpatial

    duration: {
        switch (type) {
        case Anim.StandardSmall:      return Motion.fast
        case Anim.Standard:           return Motion.standard
        case Anim.StandardLarge:      return Motion.standardLarge
        case Anim.StandardExtraLarge: return Motion.shapeshift
        case Anim.EmphasizedSmall:    return Motion.fast
        case Anim.Emphasized:         return Motion.emphasized
        case Anim.EmphasizedLarge:    return Motion.emphasizedLarge
        case Anim.EmphasizedExtraLarge: return Motion.shapeshift
        case Anim.FastSpatial:        return Motion.glide
        case Anim.DefaultSpatial:     return Motion.morph
        case Anim.SlowSpatial:        return Motion.shapeshift
        case Anim.FastEffects:        return Motion.fast
        case Anim.DefaultEffects:     return Motion.standard
        case Anim.SlowEffects:        return Motion.morph
        case Anim.Morph:              return Motion.morph
        case Anim.Glide:              return Motion.glide
        case Anim.Fast:               return Motion.fast
        case Anim.FastIn:             return Motion.fast
        case Anim.FastOut:            return Motion.fast
        case Anim.EmphasizedIn:       return Motion.emphasized
        case Anim.EmphasizedOut:      return Motion.emphasized
        default:                      return Motion.standard
        }
    }

    // curva bezier por tipo; null → usa easing.type simple
    readonly property var _bezier: {
        switch (type) {
        // espaciales: morph suave asimétrico
        case Anim.Morph:
            return Motion.morphCurve
        case Anim.Glide:
            return Motion.softFluid
        case Anim.FastSpatial:
            return Motion.emphasizedDecelCurve
        case Anim.DefaultSpatial:
            return Motion.emphasizedDecelCurve
        case Anim.SlowSpatial:
            return Motion.emphasizedDecelCurve
        // efectos: entrada decelerada, salida acelerada
        case Anim.FastEffects:
            return Motion.emphasizedDecelCurve
        case Anim.DefaultEffects:
            return Motion.emphasizedDecelCurve
        case Anim.SlowEffects:
            return Motion.emphasizedDecelCurve
        // emphasized in/out asimétricos
        case Anim.EmphasizedIn:
            return Motion.emphasizedDecelCurve
        case Anim.EmphasizedOut:
            return Motion.emphasizedAccelCurve
        case Anim.StandardSmall:
            return Motion.standardDecelCurve
        case Anim.FastIn:
            return Motion.standardDecelCurve
        case Anim.FastOut:
            return Motion.standardAccelCurve
        case Anim.Emphasized:
        case Anim.EmphasizedLarge:
        case Anim.EmphasizedExtraLarge:
            return Motion.emphasizedDecelCurve
        default:
            return Motion.easeOut
        }
    }
    on_BezierChanged: {
        if (_bezier) easing.bezierCurve = _bezier
    }
    Component.onCompleted: {
        if (_bezier) easing.bezierCurve = _bezier
    }

    easing.type: Motion.easeMorph
}
