import QtQuick
import Quickshell.Io

Item {
    id: root
    required property string entryId
    required property string previewDir
    property bool requested: true
    property bool selectedPreview: false
    property string imageSource: ""
    property bool failed: false

    Process {
        running: root.requested && root.previewDir.length > 0 && root.entryId.length > 0
            && !root.imageSource.length && !root.failed
        command: ["bash", "-o", "pipefail", "-c",
            root.selectedPreview
                ? 'cliphist decode "$1" | magick - -auto-orient -thumbnail 768x320 -strip "$2"'
                : 'cliphist decode "$1" | magick - -auto-orient -thumbnail 144x144 -strip "$2"',
            "clipboard-preview", root.entryId,
            root.previewDir + "/" + root.entryId + (root.selectedPreview ? "-preview.png" : ".png")]
        onExited: code => {
            if (code === 0) root.imageSource = "file://" + root.previewDir + "/" + root.entryId
                + (root.selectedPreview ? "-preview.png" : ".png")
            else if (root.requested) root.failed = true
        }
    }
}
