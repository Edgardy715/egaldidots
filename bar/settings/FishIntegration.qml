import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../Singletons"

ColumnLayout {
    id: root
    property string sourcePath: {
        const url = Qt.resolvedUrl("../scripts/fish/isla.fish").toString()
        return decodeURIComponent(url.startsWith("file://") ? url.slice(7) : url)
    }
    property string fishConfigHome: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/fish/conf.d"
    property bool busy: false
    property string message: ""
    property alias installActionButton: installButton
    property alias removeActionButton: removeButton
    function run(args) { process.command = args; process.running = true }
    function install() {
        busy = true
        run(["python3", "-c", "import os,sys,pathlib; d=pathlib.Path(sys.argv[1]); d.mkdir(parents=True,exist_ok=True); p=d/'isla.fish'; t=pathlib.Path(sys.argv[2]); p.is_symlink() and p.resolve()==t.resolve() or (not p.exists() and not p.is_symlink()) or sys.exit('Archivo existente'); p.is_symlink() or p.symlink_to(t)", fishConfigHome, sourcePath])
    }
    function remove() {
        busy = true
        run(["python3", "-c", "import pathlib,sys; p=pathlib.Path(sys.argv[1])/'isla.fish'; (p.is_symlink() and p.resolve()==pathlib.Path(sys.argv[2]).resolve()) and p.unlink()", fishConfigHome, sourcePath])
    }
    Process {
        id: process
        stdout: StdioCollector { onStreamFinished: if (text.trim()) root.message = I18n.tr("No se pudo cambiar la integración con fish.") }
        stderr: StdioCollector { onStreamFinished: if (text.trim()) root.message = I18n.tr("No se pudo cambiar la integración con fish.") }
        onExited: root.busy = false
    }
    Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Theme.foreground; text: root.message || I18n.tr("La integración solo se modifica al pulsar un botón.") }
    RowLayout {
        Layout.fillWidth: true
        EdotsButton {
            id: installButton
            objectName: "fishIntegrationInstall"
            text: I18n.tr("Activar integración con fish"); symbol: "terminal"; enabled: !root.busy
            onClicked: root.install()
        }
        EdotsButton {
            id: removeButton
            objectName: "fishIntegrationRemove"
            text: I18n.tr("Quitar integración con fish"); symbol: "close"; enabled: !root.busy
            onClicked: root.remove()
        }
    }
}
