import QtQuick
import QtTest
import Quickshell
import "components"
import "Singletons"

// Fake service: this file never imports Auth or registers Polkit/askpass.
ShellRoot {
    Window {
        id: window
        visible: true; width: 760; height: 280; color: Theme.background
        property bool expanded: true
        property real presentation: expanded ? 1 : 0
        Behavior on presentation { SmoothedAnimation { duration: Flags.reduceMotion ? 0 : Motion.morph; velocity: -1 } }
        QtObject { id: first; property string displayName: "Test User" }
        QtObject { id: second; property string displayName: "Administrator" }
        QtObject {
            id: flow
            property bool isResponseRequired: true
            property bool isCompleted: false
            property bool responseVisible: false
            property string inputPrompt: "Contraseña de prueba"
            property string message: "Una operación solicita autorización para modificar ajustes del sistema"
            property string supplementaryMessage: ""
            property bool supplementaryIsError: false
            property var identities: [first, second]
            property var selectedIdentity: first
            signal authenticationFailed()
        }
        QtObject {
            id: fake
            property var flow: flow
            property bool active: true
            property bool sudoActive: false
            property bool sudoCanRespond: false
            property bool sudoSubmitting: false
            property bool sudoSuccess: false
            property bool sudoError: false
            property string sudoPrompt: "Contraseña de prueba sudo"
            property bool polkitSubmitting: false
            property bool polkitSuccess: false
            property bool polkitError: false
            property string polkitMessage: ""
            property bool rejectNext: false
            property int submissions: 0
            property int cancellations: 0
            signal authenticationRequestStarted()
            signal sudoRequestStarted()
            function submit(secret) { if (rejectNext) { rejectNext = false; return false } if (!polkitSubmitting && flow.isResponseRequired) { submissions++; polkitSubmitting = true; flow.isResponseRequired = false; return true } return false }
            function submitSudo(secret) { if (sudoCanRespond) { submissions++; sudoSubmitting = true; sudoCanRespond = false; return true } return false }
            function beginSudoRetry() { sudoError = false }
            function cancel() { cancellations++; active = false; polkitSubmitting = false; polkitSuccess = false }
            function cancelSudo() { cancellations++; sudoActive = false; sudoCanRespond = false; sudoSubmitting = false }
        }
        Item {
            id: host
            x: 24; y: 65; width: 160 + 500 * window.presentation; height: 38 + (Math.max(82, Math.max(44, Theme.fontSizeBodyLg + Flags.fontScale + 20) + 3 + Math.max(18, Theme.fontSizeLabel + 6) + 16) - 38) * window.presentation
            Rectangle { anchors.fill: parent; radius: parent.height / 2; color: Theme.background; border.color: Theme.border }
            PillMaterial { morphRadius: parent.height / 2; surface: "auth" }
            Text { x: 30; anchors.verticalCenter: parent.verticalCenter; text: "12:45 PM"; font.family: Theme.font; font.pixelSize: 20; color: Theme.foreground }
            AuthPrompt { id: prompt; backend: fake; open: true; contextWidth: 260; morphCloseness: Math.max(0, Math.min(1, (window.presentation - 0.45) / 0.35)); onRequestClose: open = false }
        }
        Item { width: 660; height: 82; AuthPrompt { id: dormant; backend: fake } }
        TestCase {
            id: checks
            name: "AuthPrompt"
            when: window.visible
            property bool finished: false
            function check(ok, why) { if (!ok) { console.error("FAIL: auth prompt", why); throw new Error(why) } }
            function shot(name) { host.grabToImage(result => result.saveToFile((Quickshell.env("ISLA_AUTH_SHOTS") || "/tmp/isla-auth-") + name + ".png")); wait(80) }
            function test_flow() {
                const input = findChild(prompt, "authPassword")
                const send = findChild(prompt, "authSubmit")
                const cancel = findChild(prompt, "authCancel")
                const accounts = findChild(prompt, "authAccounts")
                wait(120)
                check(input && send && cancel && accounts, "controls available")
                check(dormant.response === "" && !dormant.canRespond, "closed construction stays clean")
                input.text = "discard-on-close"
                prompt.closing = true
                window.expanded = false
                wait(100)
                check(input.text === "" && !prompt.canRespond, "closing during geometry clears input")
                shot("closing")
                window.expanded = true
                prompt.closing = false
                wait(70)
                shot("reopening")
                wait(Motion.morph + 60)
                check(window.presentation > 0.999 && prompt.exposure > 0.999, "interrupted morph settles with full exposure")
                check(input.activeFocus && input.echoMode === TextInput.Password && input.passwordMaskDelay === 0, "masked field owns focus")
                shot("ready")
                keyClick(Qt.Key_Tab)
                check(accounts.activeFocus, "Tab reaches identity control with empty input")
                keyClick(Qt.Key_Tab)
                check(cancel.activeFocus, "Tab reaches cancel")
                keyClick(Qt.Key_Tab)
                check(input.activeFocus, "Tab returns to input")
                accounts.forceActiveFocus()
                accounts.popup.open()
                wait(40)
                keyClick(Qt.Key_Escape)
                wait(30)
                check(!accounts.popup.visible && fake.cancellations === 0 && prompt.open, "Escape dismisses account popup before cancelling request")
                input.forceActiveFocus()
                prompt.submitResponse()
                check(fake.submissions === 0, "empty response blocked")
                fake.rejectNext = true
                input.text = "fixture-rejected"
                prompt.submitResponse()
                check(fake.submissions === 0 && input.text === "fixture-rejected" && prompt.sendRejected, "backend rejection retains editable response")
                input.text = "fixture-response"
                keyPress(Qt.Key_Return); keyRelease(Qt.Key_Return)
                check(fake.submissions === 1 && input.text === "" && prompt.verifying && input.readOnly, "submit once and erase secret")
                prompt.submitResponse()
                mouseClick(send)
                check(fake.submissions === 1, "busy prevents duplicates")
                shot("verifying")
                fake.polkitMessage = "Contraseña incorrecta. Vuelve a intentarlo."
                fake.polkitSubmitting = false
                flow.isResponseRequired = true
                fake.polkitError = true
                flow.authenticationFailed()
                wait(70)
                check(input.activeFocus && !input.readOnly && input.visible && prompt.hasError, "retry immediately available")
                shot("rejected")
                wait(Motion.fast + 2 * Motion.press + 40)
                check(Math.abs(prompt.errorOffset) < 0.01, "error recoil settles")
                keyClick(Qt.Key_A)
                check(input.text.length === 1 && !prompt.hasError, "typing clears displayed error without timer")
                prompt.capsLockOn = true
                check(prompt.detail.indexOf("Bloq") >= 0, "caps lock hint")
                prompt.selectIdentity(1)
                check(flow.selectedIdentity === second && input.text === "", "account switch erases secret")
                flow.responseVisible = true
                check(input.echoMode === TextInput.Normal, "backend can request visible non-password response")
                flow.responseVisible = false
                input.text = "fixture-response"
                prompt.submitResponse()
                fake.polkitSubmitting = false
                fake.polkitSuccess = true
                wait(160)
                check(input.text === "" && !send.enabled && input.readOnly && prompt.successState, "success locks controls with cleared secret")
                shot("success")
                fake.sudoActive = true
                fake.sudoCanRespond = true
                check(!prompt.sudoMode, "Polkit keeps priority over simultaneous sudo")
                fake.flow = null
                fake.active = false
                check(prompt.successState && !prompt.sudoMode, "confirmed success survives completed flow")
                fake.polkitSuccess = false
                wait(30)
                check(prompt.sudoMode && input.activeFocus, "queued sudo receives clean focus after Polkit confirmation")
                fake.sudoActive = false
                fake.sudoCanRespond = false
                prompt.open = false
                fake.polkitSuccess = false
                fake.flow = flow
                fake.active = true
                flow.isResponseRequired = true
                prompt.open = true
                wait(50)
                check(input.text === "" && input.activeFocus, "reopen starts clean")
                input.text = "discarded"
                prompt.closing = true
                check(input.text === "" && !prompt.canRespond, "closing erases and blocks input before morph ends")
                prompt.closing = false
                wait(30)
                input.text = "cancelled"
                input.forceActiveFocus()
                keyClick(Qt.Key_Escape)
                check(fake.cancellations === 1 && input.text === "" && !prompt.open, "Escape cancels and clears")
                fake.sudoActive = true
                fake.sudoCanRespond = true
                prompt.open = true
                wait(30)
                input.text = "fixture-response"
                prompt.submitResponse()
                check(fake.sudoSubmitting && input.text === "", "sudo submits and clears")
                fake.sudoSubmitting = false
                fake.sudoCanRespond = true
                fake.sudoError = true
                fake.sudoRequestStarted()
                wait(40)
                check(!input.readOnly && prompt.hasError, "sudo retry ready")
                Config.update({appearance: {reduceMotion: true}})
                check(prompt.errorOffset === 0, "reduced motion resolves recoil")
                input.text = "cancelled"
                prompt.cancel()
                check(fake.cancellations === 2 && input.text === "", "sudo cancel clears")
                Config.update({appearance: {reduceMotion: true}})
                window.expanded = false
                check(window.presentation === 0 && prompt.exposure === 0, "reduced motion closes geometry directly")
                console.log("PASS: auth masking, focus, Enter, double-submit, immediate retry, accounts, echoed prompt, success, reopen, close, Escape, sudo and reduced motion")
                finished = true
            }
        }
        FrameAnimation {
            running: !checks.finished
            onTriggered: if (prompt.exposure > 0.001) checks.check(host.width > 635.9, "content waits for safe geometry")
        }
        Timer { interval: 70; running: checks.finished; onTriggered: Qt.quit() }
    }
}
