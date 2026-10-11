import QtQuick
import QtTest
import Quickshell
import "Singletons"
import "settings"

ShellRoot {
    settings.watchFiles: false
    Window {
        id: scene
        visible: true; width: 800; height: 650
        SettingsPage { id: page; anchors.fill: parent; config: Config; section: "paths" }
        Timer { interval: 80; running: checks.finished; onTriggered: Qt.quit() }
        TestCase {
            id: checks
            name: "PathPicker"
            when: scene.visible
            property bool finished: false
            function check(ok, message) { if (!ok) { console.error("FAIL: " + message); throw new Error(message) } }
            function test_selection() {
                tryVerify(() => Config.loaded)
                const picker = findChild(page, "edotsPathPicker")
                const model = findChild(picker, "pickerEntries")
                const preview = findChild(picker, "pickerPreview")
                const asset = Quickshell.shellDir + "/settings/assets/edots.png"
                Config.update({paths: {userAvatar: asset}})
                const before = Config.userAvatar
                wait(350)
                const browse = findChild(page, "browsePath")
                check(browse && browse.enabled, "path row has an enabled picker button")
                mouseClick(browse, browse.width / 2, browse.height / 2)
                tryVerify(() => picker.visible && model.count > 0)
                wait(350)
                check(page.pickerOpen && !picker.folderMode, "avatar opens integrated image selector")
                keyClick(Qt.Key_Escape)
                wait(180)
                check(Config.userAvatar === before && !page.pickerOpen, "cancel preserves value")
                page.choosePath("paths", "userAvatar")
                tryVerify(() => model.count > 0)
                const index = model.indexOf(page.fileUrl(asset))
                check(index >= 0, "image appears in file grid")
                picker.selectEntry(index, false)
                tryCompare(preview, "status", Image.Ready)
                check(picker.popupType === 0, "picker remains inside the shell layer")
                check(picker.selectedIsImage && String(preview.source) === page.fileUrl(asset), "selected image has loaded preview")
                check(Config.userAvatar === before, "preview does not commit")
                const confirm = findChild(picker, "confirmPath")
                wait(350)
                mouseClick(confirm, confirm.width / 2, confirm.height / 2)
                wait(180)
                check(Config.userAvatar === asset && !page.pickerOpen, "confirmation closes integrated picker")
                page.choosePath("paths", "wallpaperDir")
                picker.navigate("file:///tmp")
                tryCompare(model, "status", 2)
                check(picker.folderMode, "directory uses same selector in folder mode")
                picker.confirm()
                check(Config.wallpaperDir === "/tmp", "chosen folder reaches Config")
                const unusual = "/tmp/imagen con # y á.png"
                page.pickerSection = "paths"; page.pickerKey = "userAvatar"
                check(page.acceptPath(page.fileUrl(unusual)) && Config.userAvatar === unusual, "spaces unicode and hash roundtrip")
                check(decodeURIComponent(String(Config.userAvatarUrl).slice(7)) === unusual && String(Config.userAvatarUrl).includes("%23"), "avatar URL preserves special filename characters: " + String(Config.userAvatarUrl) + " != " + page.fileUrl(unusual))
                check(!page.acceptPath("https://example.com/a.png"), "nonlocal URL rejected")
                page.choosePath("paths", "wallpaperCacheDir")
                page.visible = false
                wait(180)
                check(!page.pickerOpen, "hidden editor closes picker")
                console.log("PASS: integrated thumbnails/preview, file/folder confirmation, Escape, URLs and lifecycle")
                finished = true
            }
        }
    }
}
