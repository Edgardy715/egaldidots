import QtQuick
import "../Singletons"

Item {
    id: root
    property real s: 1
    property bool active: false
    readonly property bool popupOpen: view.popupOpen
    // El punto de privacidad abre Sonido en la página de entrada.
    onActiveChanged: if (active && DeviceMoments.consumeIntent("mixer") === "input") view.page = 1
    Component.onCompleted: if (active && DeviceMoments.consumeIntent("mixer") === "input") view.page = 1
    AudioController {
        id: audio
        active: root.active
        meterSources: view.meterSources
    }
    MixerView {
        id: view
        anchors.fill: parent
        s: root.s
        active: root.active
        ready: audio.ready
        busy: audio.busy
        error: audio.error
        outputs: audio.outputs
        inputs: audio.inputs
        playback: audio.playback
        recording: audio.recording
        cards: audio.cards
        defaultOutput: audio.defaultOutput
        defaultInput: audio.defaultInput
        levels: audio.levels
        onRequested: (action, args) => audio.request(action, args)
        onRefreshRequested: audio.refresh()
    }
}
