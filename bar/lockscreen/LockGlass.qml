import QtQuick
import "../components"

Item {
    id: root
    property real radius: 30
    property real unit: 1
    PillMaterial {
        s: root.unit
        morphRadius: root.radius
    }
}
