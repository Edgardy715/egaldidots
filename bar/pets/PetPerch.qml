import QtQuick

/**
 * A place a surface offers the pet. The surface sizes and positions this item
 * where the pet may stand without covering content; the layer reparents the
 * actor into the best available perch.
 *
 * kind "niche": the body is centred vertically in the perch.
 * kind "edge" / "line": the feet stand on floorY (an edge lets poses hang).
 * minX..maxX bound the pet's centre; avoidFrom..avoidTo is a centre range the
 * pet keeps clear of (a playhead, a caret).
 */
Item {
    id: perch

    property Item petLayer: null
    property string perchId: ""
    property int priority: 0
    property bool available: false
    property string kind: "line"
    property real floorY: height
    property real headroom: 1e6
    property real minX: 0
    property real maxX: width
    property real restX: (minX + maxX) / 2
    property real avoidFrom: -1
    property real avoidTo: -1
    property real reveal: 1
    property string mood: ""
    property bool interactive: true

    readonly property bool occupied: petLayer !== null && petLayer.activePerch === perch

    function notify(kind) {
        if (occupied) petLayer.notify(kind)
    }

    property Item _registered: null
    // A layer being destroyed has already lost its context; skip it.
    function _release() {
        if (_registered && !_registered.closing) _registered.unregister(perch)
        _registered = null
    }
    function _sync() {
        if (_registered === petLayer) return
        _release()
        _registered = petLayer
        if (petLayer) petLayer.register(perch)
    }
    onPetLayerChanged: _sync()
    Component.onCompleted: _sync()
    Component.onDestruction: _release()
}
