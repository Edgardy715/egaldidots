#!/usr/bin/env python3
"""Exercise Auth in an isolated QML host with no Polkit agent or listening socket."""
import os
from pathlib import Path
import subprocess
import tempfile

source = Path(__file__).resolve().parents[1] / "Singletons/Auth.qml"
text = source.read_text()
text = text.replace('        active: true\n        path: root.sudoSocketPath',
                    '        active: false\n        path: ""')
start = text.index('    PolkitAgent {')
end = text.index('\n    Connections {', start)
text = text[:start] + '''    QtObject {
        id: agent
        property bool isRegistered: false
        property bool isActive: true
        property QtObject flow: QtObject {
            property bool isResponseRequired: true
            property string supplementaryMessage: ""
            property bool supplementaryIsError: false
            property int selectedIdentity: 0
            property int submissions: 0
            signal authenticationSucceeded()
            signal authenticationFailed()
            signal authenticationRequestCancelled()
            function submit(value) { submissions++; isResponseRequired = false }
            function cancelAuthenticationRequest() { authenticationRequestCancelled() }
        }
        signal authenticationRequestStarted()
    }
''' + text[end:]
text = text.replace('    id: root', '    id: root\n    function finishFakeFlow() { agent.isActive = false; agent.flow = null }', 1)
assert 'PolkitAgent {'  not in text and '        active: true' not in text
host = r'''import QtQuick
import Quickshell
import "backend"
ShellRoot {
    id: host
    property QtObject client: QtObject {
        property bool connected: true
        property int writes: 0
        function write(value) { writes++ }
        function flush() {}
    }
    property QtObject other: QtObject {
        property bool connected: true
        function write(value) {}
        function flush() {}
    }
    function check(value, label) {
        if (!value) { console.error("FAIL:", label); Qt.quit(1) }
    }
    function request(id, tracked) {
        client.connected = true
        Auth.beginSudoRequest(JSON.stringify({id: id, tracked: tracked, prompt: "Test"}), client)
    }
    Component.onCompleted: {
        for (const invalid of ['null', '[]', '{}', '{"id":4,"tracked":true,"prompt":"Test"}',
                               '{"id":"","tracked":true,"prompt":"Test"}',
                               '{"id":"bad\\nid","tracked":true,"prompt":"Test"}']) {
            client.connected = true
            Auth.beginSudoRequest(invalid, client)
            check(!client.connected && !Auth.sudoActive, "malformed request rejected")
        }
        request("first", true)
        check(Auth.sudoActive && !Auth.sudoSubmitting && Auth.sudoCanRespond, "request ready")
        Auth.beginSudoRequest('{"id":"other","tracked":true,"prompt":"Test"}', other)
        check(!other.connected && Auth.sudoRequestId === "first", "concurrent request rejected")
        check(!Auth.reportSudoResult("first", 0), "result before submit rejected")
        check(!Auth.submitSudo("fake\nresponse"), "invalid submission rejected")
        check(!Auth.submitSudo("__ISLA_CANCEL__"), "reserved token rejected")
        check(client.writes === 0, "line delimiter rejected")
        check(Auth.submitSudo("fixture-response"), "live sudo submission accepted")
        check(!Auth.submitSudo("fixture-response"), "duplicate submission rejected")
        request("first", true)
        Auth.submitSudo("fixture-response")
        check(client.writes === 1 && Auth.sudoSubmitting, "duplicate submit and message ignored")
        check(!Auth.reportSudoResult("stale", 0), "stale result rejected")
        check(!Auth.reportSudoResult("first", NaN), "NaN result rejected")
        check(!Auth.reportSudoResult("first", -1), "negative result rejected")
        check(!Auth.reportSudoResult("first", 256), "invalid status rejected")
        check(!Auth.reportSudoResult("first", 1.5), "fractional result rejected")
        client.connected = false
        Auth.disconnectSudo(client)
        check(Auth.sudoSubmitting && Auth.sudoActive && !Auth.sudoCanRespond, "tracked validation survives disconnect")
        request("first", true)
        check(Auth.sudoError && !Auth.sudoSubmitting, "same operation retry reports rejection")
        Auth.beginSudoRetry()
        check(!Auth.sudoError, "editing live retry clears rejection")
        Auth.submitSudo("fixture-response")
        check(Auth.reportSudoResult("first", 0), "success accepted before disconnect")
        client.connected = false
        Auth.disconnectSudo(client)
        check(Auth.sudoSuccess && Auth.sudoActive && !Auth.sudoCanRespond, "success survives disconnect")
        check(!Auth.reportSudoResult("first", 1), "duplicate final result rejected")
        Auth.cancelSudo()
        check(!Auth.sudoActive, "cancel clears operation")
        request("second", true)
        check(!Auth.reportSudoResult("first", 0), "old operation cannot affect next")
        Auth.submitSudo("fixture-response")
        Auth.disconnectSudo(client)
        check(Auth.reportSudoResult("second", 1), "failure accepted after disconnect")
        Auth.beginSudoRetry()
        check(Auth.sudoError && !Auth.sudoCanRespond, "final failure persists without live retry")
        check(!Auth.submitSudo("fixture-response"), "disconnected submission rejected")
        Auth.cancelSudo()
        request("untracked", false)
        Auth.submitSudo("fixture-response")
        check(!Auth.reportSudoResult("untracked", 0), "untracked cannot assert success")
        Auth.cancelSudo()
        request("retry-drop", true)
        Auth.submitSudo("fixture-response")
        client.connected = false
        Auth.disconnectSudo(client)
        request("retry-drop", true)
        check(Auth.sudoError, "retry has rejection feedback")
        client.connected = false
        Auth.disconnectSudo(client)
        check(!Auth.sudoActive, "disconnect during retry feedback closes")
        request("drop", true)
        client.connected = false
        Auth.disconnectSudo(client)
        check(!Auth.sudoActive, "disconnect before response closes")
        check(Auth.submit("fixture-response"), "Polkit live submission accepted")
        check(!Auth.submit("fixture-response"), "Polkit duplicate rejected")
        check(Auth.flow.submissions === 1 && Auth.polkitSubmitting, "Polkit duplicate submit rejected")
        Auth.flow.authenticationFailed()
        check(Auth.polkitError && !Auth.polkitSubmitting, "Polkit failure re-enables input")
        Auth.flow.supplementaryMessage = "Fixture rejection"
        Auth.flow.selectedIdentity = 1
        check(!Auth.polkitError && !Auth.polkitSubmitting && Auth.polkitMessage === "",
              "identity change clears conversation feedback")
        Auth.flow.isResponseRequired = true
        Auth.submit("fixture-response")
        check(Auth.flow.submissions === 2 && !Auth.polkitError, "Polkit retry")
        Auth.flow.authenticationSucceeded()
        check(Auth.polkitSuccess && !Auth.polkitSubmitting && Auth.presenting, "Polkit success retained")
        Auth.cancel()
        check(!Auth.polkitSuccess && !Auth.polkitSubmitting, "Polkit cancellation clears feedback")
        Auth.flow.isResponseRequired = true
        Auth.submit("fixture-response")
        Auth.flow.authenticationSucceeded()
        Auth.finishFakeFlow()
        check(Auth.flow === null && !Auth.active && Auth.polkitSuccess && Auth.presenting,
              "Polkit success survives removed flow")
        request("expiry", true)
        Auth.submitSudo("fixture-response")
        Auth.reportSudoResult("expiry", 0)
        expiry.start()
    }
    Timer {
        id: expiry
        interval: 1250
        onTriggered: {
            host.check(!Auth.polkitSuccess && !Auth.sudoActive && !Auth.presenting, "feedback timers expire")
            console.log("PASS: isolated Auth validation, retry, cancellation, stale results and feedback")
            Qt.quit()
        }
    }
}
'''
with tempfile.TemporaryDirectory(prefix="isla-auth-test-") as directory:
    root = Path(directory)
    backend = root / "backend"
    backend.mkdir()
    (backend / "qmldir").write_text("singleton Auth 1.0 Auth.qml\n")
    (backend / "Auth.qml").write_text(text)
    (root / "shell.qml").write_text(host)
    env = dict(os.environ, QT_QPA_PLATFORM="offscreen")
    result = subprocess.run(["quickshell", "-p", str(root)], env=env,
                            capture_output=True, text=True, timeout=12)
    output = result.stdout + result.stderr
    if result.returncode or "PASS: isolated Auth" not in output or "FAIL:" in output:
        raise SystemExit(output)
    print("PASS: isolated Auth validation, retry, cancellation, stale results and feedback")
