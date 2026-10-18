import QtQuick
import "../Singletons"

Text {
    property string iconName: ""
    readonly property var glyphs: ({"play_arrow": "\ue037", "pause": "\ue034", "skip_next": "\ue044", "skip_previous": "\ue045", "shuffle": "\ue043", "repeat": "\ue040", "repeat_one": "\ue041", "lyrics": "\uec0b", "close": "\ue14c", "chevron_left": "\ue408", "chevron_right": "\ue409", "music_note": "\ue3a1", "music_off": "\ue440", "my_location": "\ue1b3", "refresh": "\ue5d5", "graphic_eq": "\ue1b8"})
    text: glyphs[iconName] || glyphs.music_note
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    font.family: mediaFont.name
    font.pixelSize: 24
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    color: Theme.foreground
    Accessible.ignored: true
    FontLoader { id: mediaFont; source: "../assets/fonts/IslaMediaSymbols.ttf" }
}
