#!/usr/bin/env python3
"""Exercise the real Nmcli QML service with isolated, deterministic commands."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FAKE = r'''#!/usr/bin/env python3
import fcntl, json, os, sys, time
from pathlib import Path
state = Path(os.environ['NMCLI_TEST_STATE'])
args = sys.argv[1:]
if args == ['monitor']:
    time.sleep(60)
    sys.exit(0)
if args[:1] == ['-g']:
    with (state / 'lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        stats = json.loads((state / 'stats').read_text())
        stats['calls'] += 1
        number = stats['calls']
        stats['active'] += 1
        stats['max_active'] = max(stats['max_active'], stats['active'])
        (state / 'stats').write_text(json.dumps(stats))
    time.sleep(0.08)
    with (state / 'lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        stats = json.loads((state / 'stats').read_text())
        stats['active'] -= 1
        (state / 'stats').write_text(json.dumps(stats))
    if (state / 'fail').exists():
        (state / 'fail').unlink()
        sys.exit(1)
    print('yes:90:2412:network%d:AA\\:BB\\:CC\\:DD\\:EE\\:FF:WPA2' % number)
elif args == ['test-fail-next']:
    (state / 'fail').touch()
elif args == ['radio', 'wifi']:
    print('enabled')
'''
QML = r'''
import QtQuick
import Quickshell
import "Singletons"
ShellRoot {
    id: test
    property int phase: 0
    property int completed: 0
    property int obsolete: 0
    property var replacement: null
    function check(condition, message) {
        if (!condition) { console.error("FAIL: " + message); Qt.exit(1) }
        return condition
    }
    Timer {
        interval: 20; repeat: true; running: true
        onTriggered: {
            if (Nmcli.activeProcesses.length || Nmcli._networkRefreshRunning) return
            if (phase === 0) {
                if (!test.check(Nmcli._testLiveProcesses === 0, "initial processes destroyed")) return
                phase = 1
                for (let i = 0; i < 40; i++) Nmcli.getNetworks(result => {
                    if (test.check(result.length === 1, "coalesced callback snapshot")) test.completed++
                })
            } else if (phase === 1) {
                if (!test.check(completed === 40 && Nmcli.active.ssid === "network3", "burst callbacks and latest snapshot")) return
                if (!test.check(Nmcli._testLiveProcesses === 0, "burst processes destroyed")) return
                phase = 2
                Nmcli.executeCommand(["test-fail-next"], () => Nmcli.getNetworks(result => {
                    test.check(result.length === 0 && Nmcli.active.ssid === "network3", "failure retains previous snapshot")
                    Nmcli.getNetworks(() => test.completed++)
                }))
            } else if (phase === 2) {
                if (!test.check(completed === 41 && Nmcli.active.ssid === "network5", "refresh recovers after failure")) return
                phase = 3
                for (let i = 0; i < 25; i++) Nmcli.executeCommand(["radio", "wifi"], () => test.completed++)
            } else if (phase === 3) {
                if (!test.check(completed === 66 && Nmcli._testLiveProcesses === 0, "all completed command objects destroyed")) return
                phase = 4
                Nmcli.pendingConnection = { ssid: "network5", callback: () => test.obsolete++ }
                Nmcli.checkPendingConnection()
                Nmcli.pendingConnection = null
                Qt.callLater(() => {
                    test.check(test.obsolete === 0, "cancel before deferred check")
                    Nmcli.pendingConnection = { ssid: "network5", callback: () => test.obsolete++ }
                    Nmcli.checkPendingConnection()
                    test.replacement = { ssid: "network5", callback: () => test.obsolete++ }
                    Nmcli.pendingConnection = test.replacement
                    Qt.callLater(() => {
                        test.check(test.obsolete === 0 && Nmcli.pendingConnection === test.replacement, "old check cannot consume replacement")
                        Nmcli.pendingConnection = { ssid: "network5", callback: () => {
                            Nmcli.pendingConnection = test.replacement
                        } }
                        Nmcli.checkPendingConnection()
                        Qt.callLater(() => {
                            test.check(Nmcli.pendingConnection === test.replacement, "success callback preserves reentrant request")
                            Nmcli.pendingConnection = { ssid: "network5", callback: () => {
                                Nmcli.pendingConnection = test.replacement
                            } }
                            Nmcli.immediateCheckTimer.triggered()
                            test.check(Nmcli.pendingConnection === test.replacement, "timer callback preserves reentrant request")
                            Nmcli.pendingConnection = null
                            Nmcli.connectionCheckTimer.stop()
                            Nmcli.immediateCheckTimer.stop()
                            console.log("PASS: Nmcli refresh coalescing, failure recovery, process lifetime and deferred connection identity")
                            Qt.quit()
                        })
                    })
                })
            }
        }
    }
    Timer { interval: 6000; running: true; onTriggered: { console.error("FAIL: timeout"); Qt.exit(1) } }
}
'''

with tempfile.TemporaryDirectory(prefix='isla-nmcli-') as directory:
    work = Path(directory)
    (work / 'Singletons').mkdir()
    (work / 'services').symlink_to(ROOT / 'services', target_is_directory=True)
    # Instrument lifecycle only in the temporary copy; no production test hooks.
    source = (ROOT / 'Singletons/Nmcli.qml').read_text()
    source = source.replace('property list<var> activeProcesses: []',
                            'property int _testLiveProcesses: 0\n    property list<var> activeProcesses: []')
    source = source.replace('component CommandProcess: Process {', '''component CommandProcess: Process {
        Component.onCompleted: root._testLiveProcesses++
        Component.onDestruction: root._testLiveProcesses--''')
    (work / 'Singletons/Nmcli.qml').write_text(source)
    (work / 'Singletons/qmldir').write_text('singleton Nmcli Nmcli.qml\n')
    (work / 'test.qml').write_text(QML)
    (work / 'nmcli').write_text(FAKE)
    (work / 'nmcli').chmod(0o755)
    (work / 'stats').write_text(json.dumps(dict(calls=0, active=0, max_active=0)))
    env = dict(os.environ, QT_QPA_PLATFORM='offscreen', NMCLI_TEST_STATE=str(work),
               PATH=str(work) + os.pathsep + os.environ['PATH'])
    result = subprocess.run([shutil.which('quickshell'), '-p', str(work / 'test.qml')],
                            env=env, text=True, capture_output=True, timeout=10)
    output = result.stdout + result.stderr
    assert result.returncode == 0 and 'PASS:' in output and 'FAIL:' not in output, output
    assert 'TypeError' not in output and 'ReferenceError' not in output, output
    stats = json.loads((work / 'stats').read_text())
    assert stats == dict(calls=5, active=0, max_active=1), stats
    print('PASS: Nmcli; 40 refresh requests produce 2 serialized reads, 25 commands leave 0 objects; failure recovery and stale callbacks')
